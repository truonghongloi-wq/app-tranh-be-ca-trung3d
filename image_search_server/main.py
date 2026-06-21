"""
main.py  –  FastAPI server cho Image Search (CLIP + FAISS)

Khởi động:
    uvicorn main:app --host 0.0.0.0 --port 8000 --reload

Endpoint chính:
    POST /search-image
        - Body: multipart/form-data với field "file" (ảnh)
        - Query param: top_k (int, default=10)
        - Response: JSON danh sách kết quả tương đồng
"""

import io
import json
import logging
import os
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Optional

import faiss
import numpy as np
import torch
from fastapi import FastAPI, File, HTTPException, Query, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from PIL import Image
from pydantic import BaseModel
from transformers import CLIPModel, CLIPProcessor

# ---------------------------------------------------------------------------
# Cấu hình
# ---------------------------------------------------------------------------
CLIP_MODEL_NAME = os.getenv("CLIP_MODEL", "openai/clip-vit-base-patch32")
FAISS_INDEX_PATH = Path(os.getenv("FAISS_INDEX_PATH", "faiss_index/faiss.index"))
METADATA_PATH = Path(os.getenv("METADATA_PATH", "faiss_index/metadata.json"))
STATIC_DIR = Path(os.getenv("STATIC_DIR", "product_images"))
MAX_FILE_SIZE_MB = 10

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Singleton state (load một lần khi khởi động)
# ---------------------------------------------------------------------------
class AppState:
    processor: Optional[CLIPProcessor] = None
    model: Optional[CLIPModel] = None
    index: Optional[faiss.Index] = None
    metadata: list[dict] = []
    device: str = "cpu"


state = AppState()


# ---------------------------------------------------------------------------
# Lifespan – load model & index khi server khởi động
# ---------------------------------------------------------------------------
@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Đang tải CLIP model...")
    state.device = "cuda" if torch.cuda.is_available() else "cpu"
    state.processor = CLIPProcessor.from_pretrained(CLIP_MODEL_NAME)
    state.model = CLIPModel.from_pretrained(CLIP_MODEL_NAME).to(state.device)
    state.model.eval()
    logger.info(f"CLIP model đã tải xong. Thiết bị: {state.device}")

    if FAISS_INDEX_PATH.exists():
        logger.info(f"Đang tải FAISS index từ: {FAISS_INDEX_PATH}")
        state.index = faiss.read_index(str(FAISS_INDEX_PATH))
        logger.info(f"FAISS index: {state.index.ntotal} vector")
    else:
        logger.warning(f"Không tìm thấy FAISS index tại {FAISS_INDEX_PATH}. "
                       "Hãy chạy build_index.py trước.")

    if METADATA_PATH.exists():
        with open(METADATA_PATH, "r", encoding="utf-8") as f:
            state.metadata = json.load(f)
        logger.info(f"Metadata: {len(state.metadata)} bản ghi")
    else:
        logger.warning(f"Không tìm thấy metadata tại {METADATA_PATH}.")

    yield  # server đang chạy

    logger.info("Dọn dẹp tài nguyên...")
    del state.model
    del state.processor
    if state.index:
        del state.index


# ---------------------------------------------------------------------------
# FastAPI app
# ---------------------------------------------------------------------------
app = FastAPI(
    title="Tranh 3D Image Search API",
    version="1.0.0",
    lifespan=lifespan,
)

# CORS – cho phép Flutter app gọi API
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Thay bằng domain cụ thể khi deploy production
    allow_methods=["POST", "GET"],
    allow_headers=["*"],
)

# Serve ảnh sản phẩm tĩnh (nếu không dùng Firebase/CDN)
if STATIC_DIR.exists():
    app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")


# ---------------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------------
class SearchResultItem(BaseModel):
    product_id: str
    image_url: str
    similarity: float  # 0.0 – 1.0


class SearchResponse(BaseModel):
    query_received: bool
    results: list[SearchResultItem]


# ---------------------------------------------------------------------------
# Helper – trích xuất vector từ ảnh PIL
# ---------------------------------------------------------------------------
def _embed_image(pil_image: Image.Image) -> np.ndarray:
    """Chuyển ảnh PIL thành vector CLIP đã L2-normalize, shape (1, 512)."""
    inputs = state.processor(images=pil_image, return_tensors="pt").to(state.device)
    with torch.no_grad():
        features = state.model.get_image_features(**inputs)
        features = features / features.norm(dim=-1, keepdim=True)
    return features.cpu().numpy().astype("float32")


# ---------------------------------------------------------------------------
# Endpoint chính
# ---------------------------------------------------------------------------
@app.post("/search-image", response_model=SearchResponse)
async def search_image(
    file: UploadFile = File(..., description="Ảnh cần tìm kiếm (jpg/png/webp)"),
    top_k: int = Query(default=10, ge=1, le=50, description="Số kết quả trả về"),
):
    """
    Nhận ảnh từ Flutter app, dùng CLIP tạo vector rồi tìm Top-K
    ảnh tương đồng nhất trong kho bằng FAISS.
    """
    # --- Kiểm tra server đã sẵn sàng ---
    if state.index is None:
        raise HTTPException(status_code=503, detail="FAISS index chưa được tải. Hãy chạy build_index.py.")
    if state.model is None:
        raise HTTPException(status_code=503, detail="CLIP model chưa sẵn sàng.")

    # --- Kiểm tra file upload ---
    if file.content_type not in {"image/jpeg", "image/png", "image/webp", "image/jpg"}:
        raise HTTPException(status_code=400, detail=f"Định dạng không hỗ trợ: {file.content_type}")

    raw = await file.read()
    if len(raw) > MAX_FILE_SIZE_MB * 1024 * 1024:
        raise HTTPException(status_code=413, detail=f"Ảnh vượt quá {MAX_FILE_SIZE_MB}MB.")

    # --- Decode ảnh ---
    try:
        pil_image = Image.open(io.BytesIO(raw)).convert("RGB")
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Không thể đọc ảnh: {e}")

    # --- Trích xuất vector ---
    query_vector = _embed_image(pil_image)  # (1, 512)

    # --- FAISS search ---
    actual_k = min(top_k, state.index.ntotal)
    similarities, indices = state.index.search(query_vector, actual_k)

    # --- Xây dựng response ---
    results: list[SearchResultItem] = []
    for sim, idx in zip(similarities[0], indices[0]):
        if idx < 0 or idx >= len(state.metadata):
            continue
        meta = state.metadata[idx]
        results.append(
            SearchResultItem(
                product_id=meta["product_id"],
                image_url=meta["image_url"],
                similarity=float(round(sim, 4)),
            )
        )

    logger.info(f"Tìm kiếm xong: {len(results)} kết quả trả về (top_k={top_k})")
    return SearchResponse(query_received=True, results=results)


@app.get("/health")
async def health():
    return {
        "status": "ok",
        "index_loaded": state.index is not None,
        "index_size": state.index.ntotal if state.index else 0,
        "model_loaded": state.model is not None,
        "device": state.device,
    }

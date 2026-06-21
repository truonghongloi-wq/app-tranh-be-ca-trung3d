"""
build_index.py  –  Chạy 1 LẦN để tạo FAISS index từ kho ảnh sản phẩm.

Cấu trúc thư mục ảnh mong đợi:
    product_images/
        product_001.jpg
        product_002.jpg
        ...

Sau khi chạy sẽ sinh ra:
    faiss_index/faiss.index   – FAISS binary index
    faiss_index/metadata.json – ánh xạ vector_id -> {product_id, image_url}

Cách dùng:
    python build_index.py --images_dir product_images --output_dir faiss_index
"""

import argparse
import json
import os
from pathlib import Path

import faiss
import numpy as np
import torch
from PIL import Image
from transformers import CLIPModel, CLIPProcessor

CLIP_MODEL_NAME = "openai/clip-vit-base-patch32"
BATCH_SIZE = 64


def load_clip(device: str):
    processor = CLIPProcessor.from_pretrained(CLIP_MODEL_NAME)
    model = CLIPModel.from_pretrained(CLIP_MODEL_NAME).to(device)
    model.eval()
    return processor, model


def extract_features(image_paths: list[Path], processor, model, device: str) -> np.ndarray:
    all_vectors = []
    for i in range(0, len(image_paths), BATCH_SIZE):
        batch_paths = image_paths[i : i + BATCH_SIZE]
        images = []
        for p in batch_paths:
            try:
                img = Image.open(p).convert("RGB")
                images.append(img)
            except Exception as e:
                print(f"[WARN] Bỏ qua ảnh lỗi: {p} – {e}")
                images.append(Image.new("RGB", (224, 224)))

        inputs = processor(images=images, return_tensors="pt", padding=True).to(device)
        with torch.no_grad():
            features = model.get_image_features(**inputs)
            # L2-normalize để dùng Inner-Product search (tương đương cosine)
            features = features / features.norm(dim=-1, keepdim=True)
        all_vectors.append(features.cpu().numpy())
        print(f"  Đã xử lý {min(i + BATCH_SIZE, len(image_paths))}/{len(image_paths)} ảnh")
    return np.vstack(all_vectors).astype("float32")


def build(images_dir: str, output_dir: str, base_url: str):
    device = "cuda" if torch.cuda.is_available() else "cpu"
    print(f"[INFO] Thiết bị: {device}")

    image_dir = Path(images_dir)
    extensions = {".jpg", ".jpeg", ".png", ".webp"}
    image_paths = sorted([p for p in image_dir.rglob("*") if p.suffix.lower() in extensions])
    if not image_paths:
        raise ValueError(f"Không tìm thấy ảnh trong: {images_dir}")
    print(f"[INFO] Tổng số ảnh: {len(image_paths)}")

    processor, model = load_clip(device)
    print("[INFO] Đang trích xuất đặc trưng...")
    vectors = extract_features(image_paths, processor, model, device)

    # FAISS IndexFlatIP – Inner Product (sau khi normalize = cosine similarity)
    dim = vectors.shape[1]  # 512 với clip-vit-base-patch32
    index = faiss.IndexFlatIP(dim)
    index.add(vectors)
    print(f"[INFO] Đã thêm {index.ntotal} vector vào FAISS index.")

    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)

    faiss.write_index(index, str(output_path / "faiss.index"))

    metadata = []
    for i, p in enumerate(image_paths):
        # product_id lấy từ tên file (không có đuôi)
        product_id = p.stem
        # image_url: nếu serve ảnh local, ghép base_url; nếu dùng Firebase thì điền thủ công sau
        image_url = f"{base_url.rstrip('/')}/{p.relative_to(image_dir).as_posix()}"
        metadata.append({"vector_id": i, "product_id": product_id, "image_url": image_url})

    with open(output_path / "metadata.json", "w", encoding="utf-8") as f:
        json.dump(metadata, f, ensure_ascii=False, indent=2)

    print(f"[DONE] Index & metadata đã lưu tại: {output_path}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--images_dir", default="product_images", help="Thư mục chứa ảnh sản phẩm")
    parser.add_argument("--output_dir", default="faiss_index", help="Thư mục lưu index")
    parser.add_argument(
        "--base_url",
        default="http://localhost:8000/static",
        help="Base URL để tạo image_url trong metadata",
    )
    args = parser.parse_args()
    build(args.images_dir, args.output_dir, args.base_url)

import base64
import io
import os
from datetime import datetime, timezone

import requests as http_requests
from PIL import Image
from firebase_admin import db, initialize_app
from firebase_functions import https_fn, options

_DB_URL = "https://apptranhbeca-default-rtdb.asia-southeast1.firebasedatabase.app"
initialize_app(options={"databaseURL": _DB_URL})

_OPENAI_KEY = os.environ.get("OPENAI_API_KEY", "").strip().lstrip('﻿')
_DAILY_LIMIT = 3

_PROMPT = (
    "Ảnh 1 là ảnh chụp bể cá thực tế của khách hàng. "
    "Ảnh 2 là tranh trang trí nền bể cá."
    " Nhiệm vụ: Xóa hoàn toàn hình nền cũ nhìn qua mặt kính sau của bể trong Ảnh 1,"
    " thay thế bằng đúng tranh từ Ảnh 2."
    " Đồng thời áp phần đáy của tranh Ảnh 2 lên sàn bể,"
    " tạo hình nền liên tục từ mặt sau xuống đáy bể."
    " Căn chỉnh phối cảnh, tỷ lệ và góc nhìn của tranh cho khớp với bể thực tế."
    " Không chỉnh sửa, không vẽ lại bất kỳ chi tiết nào của tranh trong Ảnh 2 —"
    " giữ nguyên 100% màu sắc, họa tiết, hoa văn."
    " Kết quả phải trông tự nhiên và chân thực như tranh được dán thật sự trong bể."
)


def _to_png_rgba(image_bytes: bytes) -> bytes:
    img = Image.open(io.BytesIO(image_bytes)).convert("RGBA")
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def _check_and_increment_quota(uid: str) -> int:
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    ref = db.reference(f"composite_quota/{uid}/{today}")
    count = ref.get() or 0
    if count >= _DAILY_LIMIT:
        raise https_fn.HttpsError(
            "resource-exhausted",
            f"Bạn đã dùng hết {_DAILY_LIMIT} lượt ghép ảnh hôm nay. Vui lòng quay lại vào ngày mai.",
        )
    ref.set(count + 1)
    return _DAILY_LIMIT - (count + 1)


def _generate_image(tank_b64: str, paint_b64: str) -> bytes:
    tank_png = _to_png_rgba(base64.b64decode(tank_b64))
    paint_png = _to_png_rgba(base64.b64decode(paint_b64))

    resp = http_requests.post(
        "https://api.openai.com/v1/images/edits",
        headers={"Authorization": f"Bearer {_OPENAI_KEY}"},
        files=[
            ("image[]", ("tank.png", tank_png, "image/png")),
            ("image[]", ("painting.png", paint_png, "image/png")),
        ],
        data={
            "model": "gpt-image-1",
            "prompt": _PROMPT,
            "quality": "medium",
            "n": "1",
            "size": "1024x1024",
        },
        timeout=120,
    )

    if resp.status_code != 200:
        raise Exception(f"OpenAI lỗi ({resp.status_code}): {resp.text[:500]}")

    result = resp.json()
    b64 = result["data"][0].get("b64_json")
    if not b64:
        raise Exception("OpenAI không trả về ảnh (b64_json)")
    return base64.b64decode(b64)


@https_fn.on_call(
    region="asia-southeast1",
    memory=options.MemoryOption.GB_1,
    timeout_sec=120,
    secrets=["OPENAI_API_KEY"],
)
def composite_image(req: https_fn.CallableRequest) -> dict:
    if req.auth is None:
        raise https_fn.HttpsError("unauthenticated", "Cần đăng nhập")

    uid = req.auth.uid
    tank_b64: str = req.data.get("tank_image_b64", "")
    painting_url: str = req.data.get("painting_url", "")

    if not tank_b64 or not painting_url:
        raise https_fn.HttpsError(
            "invalid-argument", "Thiếu tank_image_b64 hoặc painting_url"
        )

    remaining = _check_and_increment_quota(uid)

    try:
        paint_resp = http_requests.get(painting_url, timeout=30)
        paint_resp.raise_for_status()
    except Exception as e:
        raise https_fn.HttpsError("unavailable", f"Không tải được ảnh tranh: {e}")

    paint_b64 = base64.b64encode(paint_resp.content).decode("utf-8")

    try:
        image_bytes = _generate_image(tank_b64, paint_b64)
    except Exception as e:
        raise https_fn.HttpsError("internal", str(e))

    return {
        "image_b64": base64.b64encode(image_bytes).decode("utf-8"),
        "mime_type": "image/png",
        "remaining": remaining,
    }

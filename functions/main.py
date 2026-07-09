import base64
import hashlib
import hmac
import io
import os
import time
from datetime import datetime, timezone
from typing import Any

import requests as http_requests
from PIL import Image
from firebase_admin import auth as admin_auth
from firebase_admin import db, firestore, initialize_app
from firebase_functions import db_fn, https_fn, options

_DB_URL = "https://apptranhbeca-default-rtdb.asia-southeast1.firebasedatabase.app"
initialize_app(options={"databaseURL": _DB_URL})

_ADMIN_EMAIL = "tranhbeca2018@gmail.com"

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


# ── Zalo OA Notification ─────────────────────────────────────────────

_ZALO_CFG = "_zalo_oa"


def _get_zalo_config():
    """Read Zalo OA config + tokens from DB; auto-refresh if expired."""
    ref = db.reference(_ZALO_CFG)
    cfg = ref.get()
    if not cfg:
        return None

    settings = cfg.get("settings", {})
    tokens = cfg.get("tokens", {})
    access_token = tokens.get("access_token", "")
    refresh_token = tokens.get("refresh_token", "")
    expires_at = tokens.get("expires_at", 0)

    if not access_token or not settings.get("secret_key"):
        return None

    if time.time() > expires_at - 300:
        new_tokens = _refresh_zalo_token(
            refresh_token, settings.get("app_id", ""), settings["secret_key"]
        )
        if not new_tokens:
            print("Zalo OA: refresh token thất bại")
            return None
        db.reference(f"{_ZALO_CFG}/tokens").update(new_tokens)
        access_token = new_tokens["access_token"]

    return {
        "access_token": access_token,
        "secret_key": settings["secret_key"],
        "user_id": settings.get("user_id", ""),
    }


def _refresh_zalo_token(refresh_token, app_id, secret_key):
    try:
        resp = http_requests.post(
            "https://oauth.zaloapp.com/v4/oa/access_token",
            headers={
                "Content-Type": "application/x-www-form-urlencoded",
                "secret_key": secret_key,
            },
            data={
                "refresh_token": refresh_token,
                "app_id": app_id,
                "grant_type": "refresh_token",
            },
            timeout=10,
        )
        data = resp.json()
        if "access_token" not in data:
            print(f"Zalo OA refresh error: {data}")
            return None
        return {
            "access_token": data["access_token"],
            "refresh_token": data.get("refresh_token", ""),
            "expires_at": time.time() + float(data.get("expires_in", 90000)),
        }
    except Exception as e:
        print(f"Zalo OA refresh exception: {e}")
        return None


def _zalo_appsecret_proof(access_token, secret_key):
    return hmac.new(
        secret_key.encode(), access_token.encode(), hashlib.sha256
    ).hexdigest()


def _send_zalo_msg(access_token, secret_key, user_id, text):
    try:
        resp = http_requests.post(
            "https://openapi.zalo.me/v3.0/oa/message/cs",
            headers={
                "Content-Type": "application/json",
                "access_token": access_token,
                "appsecret_proof": _zalo_appsecret_proof(access_token, secret_key),
            },
            json={
                "recipient": {"user_id": user_id},
                "message": {"text": text},
            },
            timeout=10,
        )
        data = resp.json()
        return data.get("error") == 0
    except Exception as e:
        print(f"Zalo OA send error: {e}")
        return False


def _upload_image_to_zalo(access_token, secret_key, image_url):
    """Download image from URL and upload to Zalo OA, return attachment_id."""
    try:
        img_resp = http_requests.get(image_url, timeout=15)
        img_resp.raise_for_status()

        content_type = img_resp.headers.get("Content-Type", "image/jpeg")
        ext = "jpg"
        if "png" in content_type:
            ext = "png"

        resp = http_requests.post(
            "https://openapi.zalo.me/v2.0/oa/upload/image",
            headers={
                "access_token": access_token,
                "appsecret_proof": _zalo_appsecret_proof(access_token, secret_key),
            },
            files={"file": (f"painting.{ext}", img_resp.content, content_type)},
            timeout=15,
        )
        data = resp.json()
        if data.get("error") == 0:
            return data.get("data", {}).get("attachment_id")
        print(f"Zalo OA upload image error: {data}")
        return None
    except Exception as e:
        print(f"Zalo OA upload image exception: {e}")
        return None


def _send_zalo_image(access_token, secret_key, user_id, attachment_id):
    """Send an image CS message via Zalo OA using attachment_id."""
    try:
        resp = http_requests.post(
            "https://openapi.zalo.me/v3.0/oa/message/cs",
            headers={
                "Content-Type": "application/json",
                "access_token": access_token,
                "appsecret_proof": _zalo_appsecret_proof(access_token, secret_key),
            },
            json={
                "recipient": {"user_id": user_id},
                "message": {
                    "attachment": {
                        "type": "template",
                        "payload": {
                            "template_type": "media",
                            "elements": [
                                {
                                    "media_type": "image",
                                    "attachment_id": attachment_id,
                                }
                            ],
                        },
                    }
                },
            },
            timeout=10,
        )
        data = resp.json()
        return data.get("error") == 0
    except Exception as e:
        print(f"Zalo OA send image error: {e}")
        return False


def _as_list(value):
    """RTDB event payloads (2nd gen triggers) deliver JSON arrays as dicts
    with numeric string keys ("0", "1", ...) instead of real Python lists —
    normalize both shapes to an ordered list."""
    if isinstance(value, list):
        return value
    if isinstance(value, dict):
        return [value[k] for k in sorted(value.keys(), key=lambda x: int(x))]
    return []


def _panel_size(kt, mat):
    """Return 'W x H' for a panel based on dimension keys."""
    d, r, c = kt.get("D", "?"), kt.get("R", "?"), kt.get("C", "?")
    if mat == "lưng":
        return f"{d} x {c}"
    if mat == "đáy":
        return f"{d} x {r}"
    return f"{r} x {c}"


_MAT_ORDER = ["lưng", "đáy", "hông trái", "hông phải"]


def _format_order_msg(order):
    kt = order.get("kichThuoc", {})
    tien = f'{int(order.get("tongTien", 0)):,}'.replace(",", ".")
    cl_per_mat = order.get("chatLieuPerMat", {})
    cl_default = order.get("chatLieu", "N/A")

    lines = [
        "🛒 ĐƠN HÀNG MỚI - Tranh Bể Cá 3D",
        "",
        f"👤 Khách: {order.get('customerName', 'N/A')}",
        f"📞 SĐT: {order.get('customerPhone', 'N/A')}",
        f"📍 Địa chỉ: {order.get('customerAddress', 'N/A')}",
        "",
        f"🖼 Mã tranh: {order.get('imageId', 'N/A')}",
    ]

    cac_mat = _as_list(order.get("cacMatIn", []))
    for mat in cac_mat:
        size = _panel_size(kt, mat)
        cl = cl_per_mat.get(mat, cl_default)
        lines.append(f"📐 Tấm {mat}: {size} cm - {cl}")

    lines.append(f"💰 Tổng tiền: {tien} đ")
    return "\n".join(lines)


def _format_group_msg(data):
    """Gộp nhiều sản phẩm (giỏ hàng thanh toán cùng lượt) thành 1 tin nhắn.

    Mỗi mã tranh vẫn giữ kèm tấm của nó (kích thước, chất liệu) nhưng bỏ
    tiêu đề "Sản phẩm N" và tiền lẻ từng bức; cuối tin chỉ có 1 dòng tổng
    số tấm + 1 dòng tổng tiền chung cho cả đơn."""
    items = data.get("items", [])
    grand_total = f'{int(data.get("tongTien", 0)):,}'.replace(",", ".")

    lines = [
        f"🛒 ĐƠN HÀNG MỚI - Tranh Bể Cá 3D ({len(items)} sản phẩm)",
        "",
        f"👤 Khách: {data.get('customerName', 'N/A')}",
        f"📞 SĐT: {data.get('customerPhone', 'N/A')}",
        f"📍 Địa chỉ: {data.get('customerAddress', 'N/A')}",
        "",
    ]

    total_panels = 0
    for item in items:
        kt = item.get("kichThuoc", {})
        cl_per_mat = item.get("chatLieuPerMat", {})
        cl_default = item.get("chatLieu", "N/A")

        lines.append(f"🖼 Mã tranh: {item.get('imageId', 'N/A')}")
        for mat in _as_list(item.get("cacMatIn", [])):
            size = _panel_size(kt, mat)
            cl = cl_per_mat.get(mat, cl_default)
            lines.append(f"📐 Tấm {mat}: {size} cm - {cl}")
            total_panels += 1
        lines.append("")

    lines.append(f"📊 Tổng số tấm: {total_panels} tấm")
    lines.append(f"💰 Tổng tiền: {grand_total} đ")
    return "\n".join(lines)


@https_fn.on_call(region="asia-southeast1", timeout_sec=60)
def notify_order_group(req: https_fn.CallableRequest) -> dict:
    """Gộp nhiều đơn cùng 1 lượt thanh toán giỏ hàng thành 1 tin Zalo duy
    nhất — gọi bởi client SAU KHI đã lưu xong các đơn (mỗi đơn đó có
    groupId nên on_order_created sẽ bỏ qua, tránh gửi trùng)."""
    if req.auth is None:
        raise https_fn.HttpsError("unauthenticated", "Cần đăng nhập")

    data = req.data or {}
    items = data.get("items", [])
    if not items:
        raise https_fn.HttpsError("invalid-argument", "Thiếu items")

    zalo = _get_zalo_config()
    if not zalo:
        print("Zalo OA chưa cấu hình hoặc token hết hạn (notify_order_group)")
        return {"sent": False}

    at = zalo["access_token"]
    sk = zalo["secret_key"]
    uid = zalo["user_id"]

    for item in items:
        image_url = item.get("imageUrl", "")
        if image_url:
            att_id = _upload_image_to_zalo(at, sk, image_url)
            if att_id:
                _send_zalo_image(at, sk, uid, att_id)

    msg = _format_group_msg(data)
    ok = _send_zalo_msg(at, sk, uid, msg)
    print(f"Zalo OA group text {'OK' if ok else 'FAIL'}")
    return {"sent": ok}


@db_fn.on_value_created(
    reference="orders/{uid}/{order_id}",
    region="asia-southeast1",
)
def on_order_created(event: db_fn.Event[Any]) -> None:
    """Auto-send Zalo OA notification when a new order is saved."""
    order = event.data
    if not order or not isinstance(order, dict):
        return

    if order.get("groupId"):
        print(f"Bỏ qua auto-notify (thuộc group {order.get('groupId')}, sẽ gộp qua notify_order_group)")
        return

    zalo = _get_zalo_config()
    if not zalo:
        print("Zalo OA chưa cấu hình hoặc token hết hạn")
        return

    at = zalo["access_token"]
    sk = zalo["secret_key"]
    uid = zalo["user_id"]
    oid = event.params.get("order_id", "?")

    image_url = order.get("imageUrl", "")
    if image_url:
        att_id = _upload_image_to_zalo(at, sk, image_url)
        if att_id:
            img_ok = _send_zalo_image(at, sk, uid, att_id)
            print(f"Zalo OA image {'OK' if img_ok else 'FAIL'} cho đơn {oid}")
        else:
            print(f"Zalo OA upload image FAIL cho đơn {oid}")

    msg = _format_order_msg(order)
    ok = _send_zalo_msg(at, sk, uid, msg)
    print(f"Zalo OA text {'OK' if ok else 'FAIL'} cho đơn {oid}")


# ── Admin: xóa khách hàng (Dashboard web) ────────────────────────────


@https_fn.on_call(region="asia-southeast1")
def admin_delete_customer(req: https_fn.CallableRequest) -> dict:
    """Xóa toàn bộ 1 khách hàng: tài khoản Auth + hồ sơ RTDB + bản ghi CRM
    Firestore. Chỉ admin (email cố định) được gọi. Lịch sử đơn hàng
    (orders/{uid}) được GIỮ LẠI, giống chính sách tự xóa tài khoản trong app.
    """
    if req.auth is None or req.auth.token.get("email") != _ADMIN_EMAIL:
        raise https_fn.HttpsError("permission-denied", "Chỉ admin được xóa khách hàng.")

    uid = (req.data or {}).get("uid") or None
    firestore_doc_id = (req.data or {}).get("firestoreDocId") or None

    if not uid and not firestore_doc_id:
        raise https_fn.HttpsError("invalid-argument", "Thiếu uid hoặc firestoreDocId.")

    result = {"auth_deleted": False, "rtdb_deleted": False, "firestore_deleted": False}

    if uid:
        try:
            admin_auth.delete_user(uid)
            result["auth_deleted"] = True
        except admin_auth.UserNotFoundError:
            pass
        except Exception as e:
            print(f"admin_delete_customer: xóa Auth {uid} lỗi: {e}")

        try:
            db.reference(f"users/{uid}").delete()
            result["rtdb_deleted"] = True
        except Exception as e:
            print(f"admin_delete_customer: xóa RTDB users/{uid} lỗi: {e}")

    if firestore_doc_id:
        try:
            firestore.client().collection("users").document(firestore_doc_id).delete()
            result["firestore_deleted"] = True
        except Exception as e:
            print(f"admin_delete_customer: xóa Firestore {firestore_doc_id} lỗi: {e}")

    return result

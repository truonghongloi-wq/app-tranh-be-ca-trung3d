import base64
import hashlib
import hmac
import io
import os
import time
from datetime import datetime, timedelta, timezone
from typing import Any

import requests as http_requests
from PIL import Image
from firebase_admin import auth as admin_auth
from firebase_admin import db, firestore, initialize_app, storage
from firebase_functions import db_fn, https_fn, options

_DB_URL = "https://apptranhbeca-default-rtdb.asia-southeast1.firebasedatabase.app"
initialize_app(options={"databaseURL": _DB_URL, "storageBucket": "apptranhbeca.firebasestorage.app"})

_ADMIN_EMAIL = "tranhbeca2018@gmail.com"

_OPENAI_KEY = os.environ.get("OPENAI_API_KEY", "").strip().lstrip('﻿')
_DAILY_LIMIT = 3
# Trần chung cho cả app mỗi ngày — chặn chi phí OpenAI tăng vọt khi có người
# tạo hàng loạt tài khoản để ghép ảnh.
_GLOBAL_DAILY_LIMIT = 150
_VN_TZ = timezone(timedelta(hours=7))
# Chỉ nhận ảnh tranh từ Storage của app (không tải URL tùy ý).
_STORAGE_PREFIX = "https://firebasestorage.googleapis.com/v0/b/apptranhbeca.firebasestorage.app/"
_COMPOSITE_FAIL_MSG = "Ghép ảnh chưa thành công, lượt đã được hoàn lại. Vui lòng thử lại."
# Giới hạn lượt ghép/ngày; bật/tắt cùng _quotaEnabled ở composite_screen.dart
_QUOTA_ENABLED = True

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


def _today_vn() -> str:
    # Ngày theo giờ Việt Nam (khớp _todayKey() ở composite_screen.dart).
    return datetime.now(_VN_TZ).strftime("%Y-%m-%d")


def _try_increment(ref, limit: int) -> int | None:
    # Transaction để các yêu cầu gửi cùng lúc không vượt quá giới hạn.
    # Trả về số đã dùng sau khi cộng, hoặc None nếu đã hết lượt.
    exhausted = False

    def _inc(current):
        nonlocal exhausted
        count = current or 0
        exhausted = count >= limit
        return count if exhausted else count + 1

    count = ref.transaction(_inc)
    return None if exhausted else count


def _refund(ref) -> None:
    try:
        ref.transaction(lambda c: max((c or 0) - 1, 0))
    except Exception as e:
        print(f"Hoàn lượt ghép lỗi ({ref.path}): {e}")


def _take_quota(uid: str):
    """Trừ 1 lượt của khách + 1 lượt của trần chung.
    Trả về (số lượt còn lại, danh sách ref để hoàn nếu ghép lỗi)."""
    today = _today_vn()
    user_ref = db.reference(f"composite_quota/{uid}/{today}")
    used = _try_increment(user_ref, _DAILY_LIMIT)
    if used is None:
        raise https_fn.HttpsError(
            "resource-exhausted",
            f"Bạn đã dùng hết {_DAILY_LIMIT} lượt ghép ảnh hôm nay. Vui lòng quay lại vào ngày mai.",
        )
    global_ref = db.reference(f"composite_quota_global/{today}")
    if _try_increment(global_ref, _GLOBAL_DAILY_LIMIT) is None:
        _refund(user_ref)
        raise https_fn.HttpsError(
            "resource-exhausted",
            "Tính năng ghép ảnh đang quá tải hôm nay. Vui lòng quay lại vào ngày mai.",
        )
    return _DAILY_LIMIT - used, [user_ref, global_ref]


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
        timeout=150,
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
    # Lớn hơn tổng timeout bên trong (tải tranh 15s + OpenAI 150s) để khối
    # except kịp hoàn lượt; client đặt timeout 200s.
    timeout_sec=300,
    secrets=["OPENAI_API_KEY"],
)
def composite_image(req: https_fn.CallableRequest) -> dict:
    if req.auth is None:
        raise https_fn.HttpsError("unauthenticated", "Cần đăng nhập")

    uid = req.auth.uid
    tank_b64: str = req.data.get("tank_image_b64", "")
    painting_url: str = req.data.get("painting_url", "")

    if not tank_b64 or not painting_url:
        raise https_fn.HttpsError("invalid-argument", "Thiếu ảnh bể cá hoặc ảnh tranh.")
    if not painting_url.startswith(_STORAGE_PREFIX):
        raise https_fn.HttpsError("invalid-argument", "Ảnh tranh không hợp lệ.")

    remaining, quota_refs = _take_quota(uid) if _QUOTA_ENABLED else (None, [])

    try:
        paint_resp = http_requests.get(painting_url, timeout=15)
        paint_resp.raise_for_status()
        paint_b64 = base64.b64encode(paint_resp.content).decode("utf-8")
        image_bytes = _generate_image(tank_b64, paint_b64)
    except Exception as e:
        print(f"composite_image lỗi cho {uid}: {e}")
        for ref in quota_refs:
            _refund(ref)
        raise https_fn.HttpsError("internal", _COMPOSITE_FAIL_MSG)

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
    groupId nên on_order_created sẽ bỏ qua, tránh gửi trùng).

    Client chỉ gửi danh sách orderId; nội dung tin đọc từ chính đơn đã lưu
    trong orders/{uid} của người gọi — không tin dữ liệu client gửi lên."""
    if req.auth is None:
        raise https_fn.HttpsError("unauthenticated", "Cần đăng nhập")

    order_ids = (req.data or {}).get("orderIds", [])
    if not isinstance(order_ids, list) or not order_ids or len(order_ids) > 50:
        raise https_fn.HttpsError("invalid-argument", "Thiếu danh sách đơn")

    orders = []
    for oid in order_ids:
        if not isinstance(oid, str) or not oid or "/" in oid or "." in oid:
            continue
        order = db.reference(f"orders/{req.auth.uid}/{oid}").get()
        # Chỉ gộp đơn thuộc giỏ hàng (có groupId) — đơn lẻ đã được
        # on_order_created tự báo, tránh gửi trùng.
        if isinstance(order, dict) and order.get("groupId"):
            orders.append(order)
    if not orders:
        raise https_fn.HttpsError("not-found", "Không tìm thấy đơn")

    zalo = _get_zalo_config()
    if not zalo:
        print("Zalo OA chưa cấu hình hoặc token hết hạn (notify_order_group)")
        return {"sent": False}

    at = zalo["access_token"]
    sk = zalo["secret_key"]
    uid = zalo["user_id"]

    for order in orders:
        image_url = str(order.get("imageUrl", ""))
        if image_url.startswith(_STORAGE_PREFIX):
            att_id = _upload_image_to_zalo(at, sk, image_url)
            if att_id:
                _send_zalo_image(at, sk, uid, att_id)

    first = orders[0]
    msg = _format_group_msg({
        "customerName": first.get("customerName", "N/A"),
        "customerPhone": first.get("customerPhone", "N/A"),
        "customerAddress": first.get("customerAddress", "N/A"),
        "items": orders,
        "tongTien": sum(float(o.get("tongTien", 0) or 0) for o in orders),
    })
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

    image_url = str(order.get("imageUrl", ""))
    if image_url.startswith(_STORAGE_PREFIX):
        att_id = _upload_image_to_zalo(at, sk, image_url)
        if att_id:
            img_ok = _send_zalo_image(at, sk, uid, att_id)
            print(f"Zalo OA image {'OK' if img_ok else 'FAIL'} cho đơn {oid}")
        else:
            print(f"Zalo OA upload image FAIL cho đơn {oid}")

    msg = _format_order_msg(order)
    ok = _send_zalo_msg(at, sk, uid, msg)
    print(f"Zalo OA text {'OK' if ok else 'FAIL'} cho đơn {oid}")


def _format_cancel_msg(order):
    kt = order.get("kichThuoc", {})
    tien = f'{int(order.get("tongTien", 0) or 0):,}'.replace(",", ".")
    cl_per_mat = order.get("chatLieuPerMat", {})
    cl_default = order.get("chatLieu", "N/A")

    lines = [
        "❌ KHÁCH HỦY ĐƠN - Tranh Bể Cá 3D",
        "",
        f"👤 Khách: {order.get('customerName', 'N/A')}",
        f"📞 SĐT: {order.get('customerPhone', 'N/A')}",
        f"📍 Địa chỉ: {order.get('customerAddress', 'N/A')}",
        "",
        f"🖼 Mã tranh: {order.get('imageId', 'N/A')}",
    ]
    for mat in _as_list(order.get("cacMatIn", [])):
        size = _panel_size(kt, mat)
        cl = cl_per_mat.get(mat, cl_default)
        lines.append(f"📐 Tấm {mat}: {size} cm - {cl}")
    lines.append(f"💰 Tổng tiền: {tien} đ")
    lines.append("")
    lines.append(f"📝 Lý do hủy: {order.get('cancelReason', 'Không ghi lý do')}")
    return "\n".join(lines)


@db_fn.on_value_written(
    reference="orders/{uid}/{order_id}/status",
    region="asia-southeast1",
)
def on_order_status_changed(event: db_fn.Event[db_fn.Change[Any]]) -> None:
    """Gửi Zalo OA cho shop khi KHÁCH tự hủy đơn trong app.

    Khách hủy luôn kèm cancelReason (app bắt buộc chọn lý do); admin hủy
    từ trang quản lý đơn không có cancelReason nên không gửi lại cho shop."""
    before = event.data.before
    after = event.data.after
    if after != "da_huy" or before == "da_huy":
        return

    user_id = event.params.get("uid", "")
    oid = event.params.get("order_id", "?")
    order = db.reference(f"orders/{user_id}/{oid}").get()
    if not order or not isinstance(order, dict):
        return
    if not order.get("cancelReason"):
        print(f"Đơn {oid} do admin hủy — không gửi thông báo")
        return

    zalo = _get_zalo_config()
    if not zalo:
        print("Zalo OA chưa cấu hình hoặc token hết hạn (on_order_status_changed)")
        return

    ok = _send_zalo_msg(
        zalo["access_token"], zalo["secret_key"], zalo["user_id"],
        _format_cancel_msg(order),
    )
    print(f"Zalo OA hủy đơn {'OK' if ok else 'FAIL'} cho đơn {oid}")


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

    # Tài khoản quản trị duy nhất: không bao giờ cho xóa
    if uid == req.auth.uid:
        raise https_fn.HttpsError("permission-denied", "Không thể xóa tài khoản quản trị.")
    if uid:
        try:
            if (admin_auth.get_user(uid).email or "").lower() == _ADMIN_EMAIL:
                raise https_fn.HttpsError("permission-denied", "Không thể xóa tài khoản quản trị.")
        except admin_auth.UserNotFoundError:
            pass

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

        # Ảnh riêng của khách: ảnh đại diện + ảnh AI ghép
        try:
            bucket = storage.bucket()
            for prefix in (f"avatars/{uid}/", f"composites/{uid}/"):
                for blob in bucket.list_blobs(prefix=prefix):
                    blob.delete()
            result["storage_deleted"] = True
        except Exception as e:
            print(f"admin_delete_customer: xóa ảnh Storage của {uid} lỗi: {e}")

    if firestore_doc_id:
        try:
            firestore.client().collection("users").document(firestore_doc_id).delete()
            result["firestore_deleted"] = True
        except Exception as e:
            print(f"admin_delete_customer: xóa Firestore {firestore_doc_id} lỗi: {e}")

    return result


@db_fn.on_value_created(
    reference="users/{uid}",
    region="asia-southeast1",
)
def on_user_created(event: db_fn.Event[Any]) -> None:
    """Khách mới đăng ký → chép giá chung (settings/prices, admin cài trên
    Dashboard web) vào users/{uid}/prices để app tính đúng giá chung."""
    user = event.data
    if not isinstance(user, dict) or user.get("prices"):
        return
    prices = db.reference("settings/prices").get()
    if not isinstance(prices, dict) or not prices:
        return
    uid = event.params.get("uid", "?")
    db.reference(f"users/{uid}/prices").set(
        {k: prices[k] for k in ("p1", "p2", "p3", "p4", "p5") if k in prices}
    )
    print(f"Đã áp giá chung cho khách mới {uid}")

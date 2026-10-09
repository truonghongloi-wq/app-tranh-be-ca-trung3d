# CLAUDE.md — Tranh Bể Cá Trung 3D

## Tổng quan ứng dụng

**Tên app:** Tranh Bệ Cá 3D  
**Mục đích:** Ứng dụng thương mại điện tử mobile cho việc duyệt, tùy chỉnh và đặt hàng tranh tường 3D bể cá.  
**Platform:** Flutter (Android/iOS)  
**Ngôn ngữ UI:** Tiếng Việt toàn bộ

---

## Kiến trúc dự án

```
lib/
├── main.dart                          # Entry point, Firebase init, MaterialApp
├── app_globals.dart                   # GlobalKey cho Navigator và Scaffold
├── firebase_options.dart              # Cấu hình Firebase đa nền tảng
├── models/
│   └── painting_model.dart            # Model dữ liệu tranh
├── modules/
│   ├── ar_preview/
│   │   ├── ar_preview_screen.dart     # AR preview với chỉnh kích thước tranh
│   │   └── glb_generator.dart         # Tạo file GLB cho AR
│   ├── auth/
│   │   ├── auth_gate.dart             # Router xác thực (splash → login/home)
│   │   ├── login_page.dart            # Đăng nhập email/mật khẩu
│   │   └── register_page.dart         # Đăng ký tài khoản
│   ├── gallery/
│   │   └── gallery_page.dart          # Grid tranh theo danh mục, hỗ trợ sắp xếp
│   ├── home/
│   │   └── home_page.dart             # Trang chủ: slider, danh mục, tìm kiếm
│   ├── image_search/
│   │   └── image_search_screen.dart   # Tìm kiếm tranh bằng hình ảnh (CLIP/FAISS)
│   ├── order/
│   │   ├── order_confirmation_page.dart  # Form thông tin khách hàng trước đặt hàng
│   │   ├── order_history_page.dart       # Lịch sử giỏ hàng/đơn hàng
│   │   └── order_store.dart              # State đơn hàng toàn cục (ValueNotifier)
│   └── product_detail/
│       ├── product_detail_page.dart      # Form tùy chỉnh sản phẩm (kích thước, chất liệu)
│       └── widgets/
│           └── new_paintings_page.dart   # Grid tranh mới nhất
└── services/
    ├── auth_service.dart               # Wrapper Firebase Auth
    ├── image_search_service.dart       # Gọi FastAPI backend tìm kiếm ảnh
    ├── order_notification_service.dart # Lưu đơn vào Realtime DB + gửi Telegram
    └── storage_rest.dart               # Firebase Storage REST API client (có cache)
```

---

## Luồng điều hướng

```
AuthGate
  ├── (chưa đăng nhập) → LoginPage → RegisterPage
  └── (đã đăng nhập) → HomePage
        ├── GalleryPage (theo danh mục)
        │     └── ProductDetailPage
        │           ├── ArPreviewScreen
        │           └── OrderConfirmationPage
        ├── NewPaintingsPage (tranh mới)
        ├── ImageSearchScreen (tìm kiếm bằng ảnh)
        └── OrderHistoryPage (giỏ hàng)
```

---

## Backend & Dịch vụ

### Firebase
| Dịch vụ | Mục đích |
|---------|---------|
| **Authentication** | Đăng nhập/đăng ký email/mật khẩu |
| **Realtime Database** | Lưu đơn hàng; region: `asia-southeast1` |
| **Cloud Storage** | Lưu ảnh tranh theo danh mục |
| **App Check** | Bảo mật token |

- **Project ID:** `apptranhbeca` (dùng cho mọi nền tảng, Cloud Functions và dashboard)
- **Storage bucket:** `apptranhbeca.firebasestorage.app`
- **DB URL:** `https://apptranhbeca-default-rtdb.asia-southeast1.firebasedatabase.app`

### FastAPI Backend (tìm kiếm ảnh)
- **URL mặc định:** `http://192.168.1.100:8000`
- **Cấu hình:** `--dart-define=IMAGE_SEARCH_API=<url>`
- **Endpoint:** `POST /search-image?top_k=10` (multipart form)
- **Thuật toán:** CLIP embeddings + FAISS vector similarity

### Telegram Bot
- **Mục đích:** Thông báo khi có đơn hàng mới
- **Biến môi trường:** `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`

---

## State Management

Kiến trúc nhẹ, không dùng Provider/Bloc/Riverpod:

| Cơ chế | Phạm vi | Dùng cho |
|--------|---------|---------|
| `StatefulWidget` | Local | Form inputs, UI state từng màn hình |
| `ValueNotifier` (`OrderStore`) | Global | Danh sách đơn hàng trong giỏ |
| `Stream` (FirebaseAuth) | Global | Trạng thái xác thực, AuthGate lắng nghe |

```dart
// Thêm đơn hàng
OrderStore.addOrder(order);

// Đọc danh sách đơn
ValueListenableBuilder(valueListenable: OrderStore.orders, ...)
```

---

## Models chính

### `Painting`
```dart
String id, title, category
double pricePerM2        // Đơn giá 300.000 VND/m²
String imageUrl
List<String> tags
```

### `OrderRecord`
```dart
String imageId
double tongDienTich      // Tổng diện tích m²
double tongTien          // Tổng tiền
int tongSoTam            // Tổng số tấm
Map<String, String> kichThuoc    // Kích thước (dài/cao/rộng) theo từng mặt
List<String> cacMatIn   // Các mặt in: back/bottom/left/right
String chatLieu          // Chất liệu: trong/ngoài
String customerName, customerPhone, customerAddress
DateTime createdAt
```

### `ImageSearchResult`
```dart
String productId
String imageUrl
double similarity        // 0.0–1.0
```

---

## Tính năng đặc biệt

1. **AR Preview** — Xem tranh trên ảnh nền phòng thực, kéo để điều chỉnh vị trí/kích thước
2. **Tìm kiếm bằng ảnh** — Upload ảnh → CLIP embedding → FAISS tìm tranh tương tự
3. **Tính toán diện tích 3D** — Chọn 4 mặt (back/bottom/left/right), nhập kích thước từng mặt, tự tính m² và giá
4. **Slider tự động** — Trang chủ xoay ảnh mới mỗi 3 giây
5. **Thông báo Telegram** — Gửi tin nhắn khi đặt hàng thành công
6. **Cache Storage** — `StorageRest` cache danh sách file để tránh gọi API lặp lại

---

## Giao diện & Theme

**Màu chính:**
- Light Blue: `0xFF5CC1FF`
- Blue: `0xFF2563EB` (primaryColor)
- Background: `0xFFF4F7F9`

**Gradient:** Top→Bottom từ `0xFF5CC1FF` → `0xFF2563EB` (AppBar, splash, login)

**Font tiền tệ:** VND định dạng với dấu chấm phân cách hàng nghìn

---

## Dependencies chính

```yaml
# Firebase
firebase_core: ^2.30.0
firebase_auth: ^4.20.0
firebase_database: ^10.5.7
firebase_storage: ^11.7.4
firebase_app_check: ^0.2.2+7

# UI & Ảnh
cached_network_image: ^3.3.1
image_picker: ^1.1.2
image: ^4.2.0

# AR
ar_flutter_plugin: ^0.7.3
vector_math: ^2.1.4

# Khác
http: ^1.2.1
http_parser: ^4.0.2
path_provider: ^2.1.4
```

---

## Chạy ứng dụng

```bash
# Mặc định
flutter run

# Với backend tìm kiếm ảnh tùy chỉnh
flutter run --dart-define=IMAGE_SEARCH_API=http://192.168.1.x:8000

# Build release
flutter build apk --release
```

---

## Lưu ý khi phát triển

- **Thông báo lỗi** phải bằng tiếng Việt (Firebase error codes đã được map sang TV)
- **Storage** truy cập qua REST API (không dùng SDK trực tiếp) để có thêm control và caching
- **AR plugin** (`ar_flutter_plugin`) yêu cầu device hỗ trợ ARCore/ARKit
- **OrderStore** là singleton toàn cục — không persist qua restart app
- **Giá mặc định:** 300.000 VND/m²
- Assets: `assets/icons/trung_logo.png`

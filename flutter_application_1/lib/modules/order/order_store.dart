import 'package:flutter/foundation.dart';

class OrderRecord {
  final String? orderId; // Khóa đơn trên server (null khi chưa lưu)
  final String imageId;
  final String? imageUrl;
  final double tongDienTich;
  final double tongTien;
  final double discountTien;
  final int tongSoTam;
  final Map<String, String> kichThuoc;
  final List<String> cacMatIn;
  final String chatLieu;
  final Map<String, String> chatLieuPerMat;
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final DateTime createdAt;
  // Khi thanh toán nhiều sản phẩm cùng lúc (giỏ hàng), các đơn cùng lượt
  // thanh toán chia sẻ 1 groupId — Cloud Function dựa vào đây để KHÔNG tự
  // gửi Zalo riêng lẻ từng đơn, thay vào đó client gọi notify_order_group
  // để gộp thành 1 tin nhắn duy nhất.
  final String? groupId;

  const OrderRecord({
    this.orderId,
    required this.imageId,
    this.imageUrl,
    required this.tongDienTich,
    required this.tongTien,
    this.discountTien = 0,
    required this.tongSoTam,
    required this.kichThuoc,
    required this.cacMatIn,
    required this.chatLieu,
    required this.chatLieuPerMat,
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
    required this.createdAt,
    this.groupId,
  });

  Map<String, dynamic> toMap() {
    return {
      'imageId': imageId,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'tongDienTich': tongDienTich,
      'tongTien': tongTien,
      'discountTien': discountTien,
      'tongSoTam': tongSoTam,
      'kichThuoc': kichThuoc,
      'cacMatIn': cacMatIn,
      'chatLieu': chatLieu,
      'chatLieuPerMat': chatLieuPerMat,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerAddress': customerAddress,
      'createdAt': createdAt.toIso8601String(),
      if (groupId != null) 'groupId': groupId,
    };
  }

  // Tạo OrderRecord từ dữ liệu đọc về từ Realtime Database.
  factory OrderRecord.fromMap(String orderId, Map<dynamic, dynamic> map) {
    Map<String, String> strMap(dynamic v) => (v is Map)
        ? v.map((k, val) => MapEntry(k.toString(), val?.toString() ?? ''))
        : <String, String>{};
    List<String> strList(dynamic v) =>
        (v is List) ? v.map((e) => e.toString()).toList() : <String>[];
    double toD(dynamic v) => (v is num)
        ? v.toDouble()
        : double.tryParse(v?.toString() ?? '') ?? 0;

    return OrderRecord(
      orderId: orderId,
      imageId: map['imageId']?.toString() ?? '',
      imageUrl: map['imageUrl']?.toString(),
      tongDienTich: toD(map['tongDienTich']),
      tongTien: toD(map['tongTien']),
      discountTien: toD(map['discountTien']),
      tongSoTam: (map['tongSoTam'] is num)
          ? (map['tongSoTam'] as num).toInt()
          : int.tryParse(map['tongSoTam']?.toString() ?? '') ?? 0,
      kichThuoc: strMap(map['kichThuoc']),
      cacMatIn: strList(map['cacMatIn']),
      chatLieu: map['chatLieu']?.toString() ?? '',
      chatLieuPerMat: strMap(map['chatLieuPerMat']),
      customerName: map['customerName']?.toString() ?? '',
      customerPhone: map['customerPhone']?.toString() ?? '',
      customerAddress: map['customerAddress']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class CartItem {
  final String imageId;
  final String? imageUrl;
  final double tongDienTich;
  final double tongTien;
  final double discountTien;
  final double phiShip;
  final int tongSoTam;
  final Map<String, String> kichThuoc;
  final List<String> cacMatIn;
  final String chatLieu;
  final Map<String, String> chatLieuPerMat;
  final DateTime addedAt;

  const CartItem({
    required this.imageId,
    this.imageUrl,
    required this.tongDienTich,
    required this.tongTien,
    this.discountTien = 0,
    this.phiShip = 0,
    required this.tongSoTam,
    required this.kichThuoc,
    required this.cacMatIn,
    required this.chatLieu,
    required this.chatLieuPerMat,
    required this.addedAt,
  });
}

class OrderStore {
  static final ValueNotifier<List<OrderRecord>> orders =
      ValueNotifier<List<OrderRecord>>(<OrderRecord>[]);

  static final ValueNotifier<List<CartItem>> cartItems =
      ValueNotifier<List<CartItem>>(<CartItem>[]);

  static void addOrder(OrderRecord order) {
    orders.value = [order, ...orders.value];
  }

  static void addToCart(CartItem item) {
    cartItems.value = [...cartItems.value, item];
  }

  static void removeFromCart(int index) {
    final list = List<CartItem>.from(cartItems.value);
    list.removeAt(index);
    cartItems.value = list;
  }

  static void clearCart() {
    cartItems.value = <CartItem>[];
  }
}

import 'package:flutter/foundation.dart';

class OrderRecord {
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

  const OrderRecord({
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
    };
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

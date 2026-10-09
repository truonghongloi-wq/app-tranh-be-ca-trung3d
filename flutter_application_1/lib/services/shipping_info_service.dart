import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/widgets.dart';

/// Thông tin giao hàng lần đặt gần nhất, lưu ở users/{uid}/shipping
/// để khách không phải nhập lại (theo tài khoản, đổi máy vẫn còn).
class ShippingInfoService {
  static const _keys = [
    'name',
    'phone',
    'soNha',
    'duong',
    'phuongXa',
    'tinhTP',
  ];

  static DatabaseReference? _ref() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid == null
        ? null
        : FirebaseDatabase.instance.ref('users/$uid/shipping');
  }

  /// Điền thông tin đã lưu vào các ô còn trống. Thứ tự controllers theo [_keys].
  static Future<void> fillInto(List<TextEditingController> controllers) async {
    final ref = _ref();
    if (ref == null) return;
    try {
      final snap = await ref.get();
      final data = snap.value;
      if (data is! Map) return;
      for (var i = 0; i < _keys.length; i++) {
        final v = data[_keys[i]];
        if (v is String && v.isNotEmpty && controllers[i].text.isEmpty) {
          controllers[i].text = v;
        }
      }
    } catch (e) {
      debugPrint('[ShippingInfo] đọc lỗi: $e');
    }
  }

  static Future<void> save(List<TextEditingController> controllers) async {
    final ref = _ref();
    if (ref == null) return;
    try {
      await ref.set({
        for (var i = 0; i < _keys.length; i++)
          _keys[i]: controllers[i].text.trim(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[ShippingInfo] lưu lỗi: $e');
    }
  }
}

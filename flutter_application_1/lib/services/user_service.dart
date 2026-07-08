import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../firebase_options.dart';

// ---------------------------------------------------------------------------
// PriceConfig — bảng giá 5 bậc theo chiều dài bể (cm)
// ---------------------------------------------------------------------------
class PriceConfig {
  final double p1; // chieuDai <= 60
  final double p2; // chieuDai <= 80
  final double p3; // chieuDai <= 90
  final double p4; // chieuDai <= 99
  final double p5; // chieuDai >= 100
  // Giá sỉ cố định từ Firestore: nếu khác null, dùng thay toàn bộ bảng giá bậc thang
  final double? giaSi;
  // Phí ship từ Firestore dành cho khách sỉ (chỉ áp dụng khi giaSi != null)
  final double? phiShipSi;

  const PriceConfig({
    this.p1 = 400000,
    this.p2 = 350000,
    this.p3 = 300000,
    this.p4 = 270000,
    this.p5 = 230000,
    this.giaSi,
    this.phiShipSi,
  });

  factory PriceConfig.fromMap(Map<dynamic, dynamic> map) => PriceConfig(
        p1: (map['p1'] as num?)?.toDouble() ?? 400000,
        p2: (map['p2'] as num?)?.toDouble() ?? 350000,
        p3: (map['p3'] as num?)?.toDouble() ?? 300000,
        p4: (map['p4'] as num?)?.toDouble() ?? 270000,
        p5: (map['p5'] as num?)?.toDouble() ?? 230000,
        giaSi: (map['giaSi'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'p1': p1,
        'p2': p2,
        'p3': p3,
        'p4': p4,
        'p5': p5,
        'giaSi': giaSi,
      };

  // Nếu giaSi được set, áp dụng cho mọi kích thước (giá sỉ phẳng)
  double priceFor(double chieuDai) {
    if (giaSi != null && giaSi! > 0) return giaSi!;
    if (chieuDai <= 60) return p1;
    if (chieuDai <= 80) return p2;
    if (chieuDai <= 90) return p3;
    if (chieuDai <= 99) return p4;
    return p5;
  }

  bool get isWholesale => giaSi != null && giaSi! > 0;

  static const PriceConfig defaults = PriceConfig();
}

// ---------------------------------------------------------------------------
// UserRecord — thông tin user lưu trên Firebase Realtime DB
// ---------------------------------------------------------------------------
class UserRecord {
  final String uid;
  final String email;
  final String displayName;
  final String createdAt;
  final String role; // "customer" | "admin"
  final PriceConfig prices;

  const UserRecord({
    required this.uid,
    required this.email,
    this.displayName = '',
    required this.createdAt,
    this.role = 'customer',
    this.prices = PriceConfig.defaults,
  });

  factory UserRecord.fromMap(String uid, Map<dynamic, dynamic> map) =>
      UserRecord(
        uid: uid,
        email: map['email'] as String? ?? '',
        displayName: map['displayName'] as String? ?? '',
        createdAt: map['createdAt'] as String? ?? '',
        role: map['role'] as String? ?? 'customer',
        prices: map['prices'] != null
            ? PriceConfig.fromMap(map['prices'] as Map)
            : PriceConfig.defaults,
      );
}

// ---------------------------------------------------------------------------
// UserService
// ---------------------------------------------------------------------------
class UserService {
  static String get _dbBase {
    final url = DefaultFirebaseOptions.currentPlatform.databaseURL;
    if (url != null && url.isNotEmpty) {
      return url.replaceFirst(RegExp(r'/+$'), '');
    }
    return 'https://apptranhbeca-default-rtdb.asia-southeast1.firebasedatabase.app';
  }

  static Future<String?> _token() async {
    try {
      return await FirebaseAuth.instance.currentUser?.getIdToken();
    } catch (e) {
      debugPrint('[UserService] getToken lỗi: $e');
      return null;
    }
  }

  // Lưu user mới vào Realtime DB ngay sau khi đăng ký
  static Future<void> saveNewUser(User user, {String displayName = ''}) async {
    try {
      await FirebaseDatabase.instance.ref('users/${user.uid}').set({
        'email': user.email ?? '',
        'displayName': displayName,
        'createdAt': DateTime.now().toIso8601String(),
        'role': 'customer',
        'prices': PriceConfig.defaults.toMap(),
      });
    } catch (e) {
      debugPrint('[UserService] saveNewUser lỗi: $e');
    }
  }

  // Đọc bảng giá của user hiện tại.
  // Ưu tiên: Firestore (giá sỉ theo email) → Realtime DB (bảng giá bậc thang)
  static Future<PriceConfig> loadCurrentUserPrices() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return PriceConfig.defaults;

      // 1. Tìm giá sỉ trong Firestore theo email
      final email = user.email;
      if (email != null && email.isNotEmpty) {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          final data = snap.docs.first.data();
          final price = (data['price'] as num?)?.toDouble();
          if (price != null && price > 0) {
            final shipPrice = (data['shipPrice'] as num?)?.toDouble();
            return PriceConfig(giaSi: price, phiShipSi: shipPrice);
          }
        }
      }

      // 2. Fallback: bảng giá bậc thang từ Realtime DB
      final token = await user.getIdToken();
      final uri =
          Uri.parse('$_dbBase/users/${user.uid}/prices.json?auth=$token');
      final res = await http.get(uri);
      if (res.statusCode == 200 && res.body != 'null') {
        final data = jsonDecode(res.body) as Map<dynamic, dynamic>;
        return PriceConfig.fromMap(data);
      }
    } catch (e) {
      debugPrint('[UserService] loadCurrentUserPrices lỗi: $e');
    }
    return PriceConfig.defaults;
  }

  // Kiểm tra user hiện tại có phải admin không
  static Future<bool> isCurrentUserAdmin() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final snapshot = await FirebaseDatabase.instance
          .ref('users/${user.uid}/role')
          .get()
          .timeout(const Duration(seconds: 5));
      return (snapshot.value as String?) == 'admin';
    } catch (e) {
      debugPrint('[UserService] isCurrentUserAdmin lỗi: $e');
      return false;
    }
  }

  // Lấy danh sách tất cả users (chỉ dùng cho admin)
  static Future<List<UserRecord>> loadAllUsers() async {
    try {
      final token = await _token();
      if (token == null) return [];
      final uri = Uri.parse('$_dbBase/users.json?auth=$token');
      final res = await http.get(uri);
      if (res.statusCode == 200 && res.body != 'null') {
        final data = jsonDecode(res.body) as Map<dynamic, dynamic>;
        final list = data.entries
            .map((e) => UserRecord.fromMap(e.key as String, e.value as Map))
            .toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      }
    } catch (e) {
      debugPrint('[UserService] loadAllUsers lỗi: $e');
    }
    return [];
  }

  // Lấy thông tin user hiện tại từ Realtime DB
  static Future<UserRecord?> loadCurrentUserRecord() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      final snapshot = await FirebaseDatabase.instance
          .ref('users/${user.uid}')
          .get()
          .timeout(const Duration(seconds: 5));
      if (snapshot.exists && snapshot.value != null) {
        return UserRecord.fromMap(
          user.uid,
          snapshot.value as Map<dynamic, dynamic>,
        );
      }
    } catch (e) {
      debugPrint('[UserService] loadCurrentUserRecord lỗi: $e');
    }
    return null;
  }

  // Xóa toàn bộ 1 khách hàng: tài khoản Auth + hồ sơ RTDB (chỉ admin).
  // Lịch sử đơn hàng (orders/{uid}) được giữ lại.
  static Future<bool> deleteCustomer(String uid) async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-southeast1')
          .httpsCallable('admin_delete_customer');
      await callable.call({'uid': uid});
      return true;
    } catch (e) {
      debugPrint('[UserService] deleteCustomer lỗi: $e');
      return false;
    }
  }

  // Cập nhật bảng giá cho một user (chỉ admin)
  static Future<bool> updateUserPrices(String uid, PriceConfig prices) async {
    try {
      final token = await _token();
      if (token == null) return false;
      final uri =
          Uri.parse('$_dbBase/users/$uid/prices.json?auth=$token');
      final res = await http.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(prices.toMap()),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[UserService] updateUserPrices lỗi: $e');
      return false;
    }
  }
}

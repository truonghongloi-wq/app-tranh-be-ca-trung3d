import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import '../modules/order/order_store.dart';

class OrderNotificationService {
  static const String _ordersPath = 'orders';
  static const String _databaseUrlFromEnv = String.fromEnvironment(
    'FIREBASE_DATABASE_URL',
    defaultValue: '',
  );

  static String get _databaseUrl {
    final envUrl = _databaseUrlFromEnv.trim();
    if (envUrl.isNotEmpty) return envUrl.replaceFirst(RegExp(r'/+$'), '');

    final currentUrl = DefaultFirebaseOptions.currentPlatform.databaseURL;
    if (currentUrl != null && currentUrl.isNotEmpty) {
      return currentUrl.replaceFirst(RegExp(r'/+$'), '');
    }

    throw StateError(
      'Chưa cấu hình FIREBASE_DATABASE_URL cho Realtime Database.',
    );
  }

  static Future<String> submitOrder(OrderRecord order) async {
    final ids = await submitOrders([order]);
    return ids.first;
  }

  /// Lưu nhiều đơn trong 1 lệnh PATCH multi-path: hoặc lưu hết, hoặc không
  /// đơn nào — tránh giỏ hàng bị lưu dở (đơn mồ côi, shop không nhận Zalo,
  /// khách bấm lại tạo đơn trùng).
  static Future<List<String>> submitOrders(List<OrderRecord> orders) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Bạn cần đăng nhập để đặt hàng.');
    }
    // push() tạo khóa ngay trên máy, không cần mạng.
    final parent = FirebaseDatabase.instance.ref('$_ordersPath/${user.uid}');
    final ids = [for (final _ in orders) parent.push().key!];
    try {
      await _request(
        'PATCH',
        '$_ordersPath/${user.uid}',
        body: {
          for (var i = 0; i < orders.length; i++) ids[i]: orders[i].toMap(),
        },
      );
    } on TimeoutException {
      throw StateError(
        'Mạng chậm, chưa xác nhận được đơn. Vui lòng kiểm tra mục "Đơn mua" '
        'trước khi gửi lại để tránh đặt trùng.',
      );
    }
    return ids;
  }

  /// Tải danh sách đơn hàng của khách đang đăng nhập (mới nhất trước).
  static Future<List<OrderRecord>> loadMyOrders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return <OrderRecord>[];

    final body = await _request('GET', '$_ordersPath/${user.uid}');
    if (body.isEmpty || body == 'null') return <OrderRecord>[];

    final data = jsonDecode(body) as Map<String, dynamic>;
    final orders = [
      for (final e in data.entries)
        if (e.value is Map)
          OrderRecord.fromMap(e.key, e.value as Map<dynamic, dynamic>),
    ];
    orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return orders;
  }

  /// Tải toàn bộ đơn của mọi khách (chỉ admin đọc được), mới nhất trước.
  static Future<List<OrderRecord>> loadAllOrders() async {
    final body = await _request('GET', _ordersPath);
    if (body.isEmpty || body == 'null') return <OrderRecord>[];

    final data = jsonDecode(body) as Map<String, dynamic>;
    final orders = <OrderRecord>[];
    for (final user in data.entries) {
      if (user.value is! Map) continue;
      // Bản app cũ lưu đơn thẳng ở orders/{orderId} (không theo khách) —
      // bỏ qua, nếu không các field con (kichThuoc...) bị đọc nhầm thành đơn.
      if ((user.value as Map).containsKey('customerName')) continue;
      for (final o in (user.value as Map).entries) {
        if (o.value is! Map || !(o.value as Map).containsKey('customerName')) {
          continue;
        }
        orders.add(OrderRecord.fromMap(
          o.key.toString(),
          o.value as Map<dynamic, dynamic>,
          ownerUid: user.key,
        ));
      }
    }
    orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return orders;
  }

  /// Khách tự hủy đơn của mình (chỉ khi đơn còn "Chờ xác nhận").
  static Future<void> cancelMyOrder(OrderRecord order, String reason) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Bạn cần đăng nhập để hủy đơn.');
    if (!order.canCancel) {
      throw StateError('Đơn đã được xác nhận, không thể tự hủy.');
    }
    await _patchStatus(
      user.uid,
      order.orderId!,
      OrderStatus.daHuy,
      cancelReason: reason,
    );
  }

  /// Admin chuyển trạng thái đơn.
  static Future<void> updateStatus(OrderRecord order, String status) async {
    if (order.ownerUid == null || order.orderId == null) {
      throw StateError('Thiếu thông tin đơn hàng.');
    }
    await _patchStatus(order.ownerUid!, order.orderId!, status);
  }

  /// Admin nhập/sửa mã vận đơn do đơn vị vận chuyển cấp.
  /// Để trống cả 2 ô để xóa.
  static Future<void> updateTracking(
    OrderRecord order, {
    required String maVanDon,
    required String donViVanChuyen,
  }) async {
    if (order.ownerUid == null || order.orderId == null) {
      throw StateError('Thiếu thông tin đơn hàng.');
    }
    final code = maVanDon.trim();
    final carrier = donViVanChuyen.trim();
    await _request(
      'PATCH',
      '$_ordersPath/${order.ownerUid}/${order.orderId}',
      body: {
        // null = xóa field trên Realtime Database
        'maVanDon': code.isEmpty ? null : code,
        'donViVanChuyen': carrier.isEmpty ? null : carrier,
      },
    );
  }

  static Future<void> _patchStatus(
    String uid,
    String orderId,
    String status, {
    String? cancelReason,
  }) async {
    await _request(
      'PATCH',
      '$_ordersPath/$uid/$orderId',
      body: {
        'status': status,
        'timeline/$status': DateTime.now().toIso8601String(),
        if (cancelReason != null && cancelReason.isNotEmpty)
          'cancelReason': cancelReason,
      },
    );
  }

  static Future<String> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Bạn cần đăng nhập.');
    final authToken = await user.getIdToken();
    final uri = Uri.parse('$_databaseUrl/$path.json').replace(
      queryParameters: <String, String>{
        if (authToken != null && authToken.isNotEmpty) 'auth': authToken,
      },
    );

    final client = HttpClient();
    try {
      final req = await client.openUrl(method, uri);
      if (body != null) {
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode(body));
      }
      final res = await req.close().timeout(const Duration(seconds: 15));
      final resBody = await res.transform(const Utf8Decoder()).join();
      if (res.statusCode == 401 || res.statusCode == 403) {
        debugPrint('[Order] $method $path bị từ chối: $resBody');
        throw StateError(
          'Không thực hiện được thao tác này. Vui lòng đăng xuất, đăng nhập '
          'lại rồi thử lại.',
        );
      }
      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint('[Order] $method $path lỗi ${res.statusCode}: $resBody');
        throw StateError('Máy chủ đang bận, vui lòng thử lại sau ít phút.');
      }
      return resBody;
    } on SocketException {
      throw StateError('Không có kết nối mạng. Vui lòng kiểm tra Internet.');
    } on HandshakeException {
      throw StateError(
        'Kết nối không an toàn. Hãy kiểm tra mạng và ngày giờ trên điện thoại.',
      );
    } finally {
      client.close();
    }
  }
}

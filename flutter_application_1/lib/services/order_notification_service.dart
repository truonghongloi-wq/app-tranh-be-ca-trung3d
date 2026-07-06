import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';

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
    final orderId = await _saveOrder(order).timeout(
      const Duration(seconds: 12),
      onTimeout: () => throw StateError(
        'Lưu đơn quá lâu. Hãy kiểm tra Realtime Database URL và mạng.',
      ),
    );
    return orderId;
  }

  static Future<String> _saveOrder(OrderRecord order) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Bạn cần đăng nhập để đặt hàng.');
    }
    final authToken = await user.getIdToken();
    // Lưu đơn theo từng khách: orders/{uid}/{orderId}
    final baseUri = Uri.parse('$_databaseUrl/$_ordersPath/${user.uid}.json');
    final uri = authToken == null || authToken.isEmpty
        ? baseUri
        : baseUri.replace(
            queryParameters: <String, String>{'auth': authToken},
          );
    final client = HttpClient();

    try {
      final req = await client.postUrl(uri);
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(order.toMap()));

      final res = await req.close();
      final body = await res.transform(const Utf8Decoder()).join();
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw StateError(
          'Realtime Database lỗi ${res.statusCode}: $body. '
          'Hãy kiểm tra FIREBASE_DATABASE_URL và rules write của database.',
        );
      }

      final data = jsonDecode(body) as Map<String, dynamic>;
      final orderId = (data['name'] ?? '').toString();
      if (orderId.isEmpty) {
        throw StateError('Realtime Database không trả về mã đơn.');
      }
      return orderId;
    } on HandshakeException {
      throw StateError(
        'SSL handshake lỗi khi kết nối ${baseUri.host}. '
        'Hãy kiểm tra FIREBASE_DATABASE_URL đúng domain rtdb, mạng, và ngày giờ trên điện thoại.',
      );
    } on SocketException {
      throw StateError('Không kết nối được Realtime Database.');
    } finally {
      client.close();
    }
  }

  /// Tải danh sách đơn hàng của khách đang đăng nhập (mới nhất trước).
  static Future<List<OrderRecord>> loadMyOrders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return <OrderRecord>[];

    final authToken = await user.getIdToken();
    final baseUri = Uri.parse('$_databaseUrl/$_ordersPath/${user.uid}.json');
    final uri = authToken == null || authToken.isEmpty
        ? baseUri
        : baseUri.replace(queryParameters: <String, String>{'auth': authToken});

    final client = HttpClient();
    try {
      final req = await client.getUrl(uri);
      final res = await req.close();
      final body = await res.transform(const Utf8Decoder()).join();
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw StateError('Không tải được đơn hàng (${res.statusCode}).');
      }
      if (body.isEmpty || body == 'null') return <OrderRecord>[];

      final data = jsonDecode(body) as Map<String, dynamic>;
      final orders = data.entries
          .map((e) => OrderRecord.fromMap(
                e.key,
                e.value as Map<dynamic, dynamic>,
              ))
          .toList();
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    } on SocketException {
      throw StateError('Không kết nối được Realtime Database.');
    } finally {
      client.close();
    }
  }
}

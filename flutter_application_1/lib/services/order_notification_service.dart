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
    final authToken = await FirebaseAuth.instance.currentUser?.getIdToken();
    final baseUri = Uri.parse('$_databaseUrl/$_ordersPath.json');
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
}

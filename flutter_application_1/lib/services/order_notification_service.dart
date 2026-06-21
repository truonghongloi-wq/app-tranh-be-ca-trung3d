import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../firebase_options.dart';
import '../modules/order/order_store.dart';

class OrderSubmitResult {
  final String orderId;
  final bool zaloSent;
  final bool zaloEnabled;

  const OrderSubmitResult({
    required this.orderId,
    required this.zaloSent,
    required this.zaloEnabled,
  });
}

class OrderNotificationService {
  static const String _ordersPath = 'orders';
  static const String _databaseUrlFromEnv = String.fromEnvironment(
    'FIREBASE_DATABASE_URL',
    defaultValue: '',
  );
  static const String _zaloOaAccessToken = String.fromEnvironment(
    'ZALO_OA_ACCESS_TOKEN',
    defaultValue: '',
  );
  static const String _zaloOaUserId = String.fromEnvironment(
    'ZALO_OA_USER_ID',
    defaultValue: '',
  );
  static const String _zaloOaSecretKey = String.fromEnvironment(
    'ZALO_OA_SECRET_KEY',
    defaultValue: '',
  );

  static bool get zaloConfigured =>
      _zaloOaAccessToken.isNotEmpty &&
      _zaloOaUserId.isNotEmpty &&
      _zaloOaSecretKey.isNotEmpty;

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

  static Future<OrderSubmitResult> submitOrder(OrderRecord order) async {
    final orderId = await _saveOrder(order).timeout(
      const Duration(seconds: 12),
      onTimeout: () => throw StateError(
        'Lưu đơn quá lâu. Hãy kiểm tra Realtime Database URL và mạng.',
      ),
    );

    var zaloSent = false;
    if (zaloConfigured) {
      zaloSent = await _sendZaloOAMessage(_buildZaloMessage(order)).timeout(
        const Duration(seconds: 10),
        onTimeout: () => false,
      );
    }

    return OrderSubmitResult(
      orderId: orderId,
      zaloSent: zaloSent,
      zaloEnabled: zaloConfigured,
    );
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

  static String _buildZaloMessage(OrderRecord order) {
    final mats = order.cacMatIn.join(', ');
    return [
      '🛒 ĐƠN HÀNG MỚI - Tranh Bể Cá 3D',
      '',
      '👤 Khách: ${order.customerName}',
      '📞 SĐT: ${order.customerPhone}',
      '📍 Địa chỉ: ${order.customerAddress}',
      '',
      '🖼 Mã tranh: ${order.imageId}',
      '📐 Kích thước bể: ${order.kichThuoc['D']} x ${order.kichThuoc['R']} x ${order.kichThuoc['C']} cm',
      '📋 Mặt in: $mats',
      '🧱 Chất liệu: ${order.chatLieu}',
      '🔢 Số tấm: ${order.tongSoTam}',
      '📏 Tổng diện tích: ${order.tongDienTich.toStringAsFixed(2)} m²',
      '💰 Tổng tiền: ${_formatCurrency(order.tongTien)} đ',
      '',
      '🕐 Thời gian: ${order.createdAt.toIso8601String()}',
    ].join('\n');
  }

  static String _computeAppSecretProof() {
    final hmac = Hmac(sha256, utf8.encode(_zaloOaSecretKey));
    return hmac.convert(utf8.encode(_zaloOaAccessToken)).toString();
  }

  static Future<bool> _sendZaloOAMessage(String text) async {
    final uri = Uri.parse('https://openapi.zalo.me/v3.0/oa/message/cs');

    try {
      final client = HttpClient();
      final req = await client.postUrl(uri);
      req.headers.set('access_token', _zaloOaAccessToken);
      req.headers.set('appsecret_proof', _computeAppSecretProof());
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        'recipient': {'user_id': _zaloOaUserId},
        'message': {'text': text},
      }));

      final res = await req.close();
      final body = await res.transform(const Utf8Decoder()).join();
      client.close();
      if (res.statusCode != 200) return false;
      final data = jsonDecode(body) as Map<String, dynamic>;
      return data['error'] == 0;
    } catch (_) {
      return false;
    }
  }

  static String _formatCurrency(double amount) {
    return amount.toInt().toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '.',
    );
  }
}

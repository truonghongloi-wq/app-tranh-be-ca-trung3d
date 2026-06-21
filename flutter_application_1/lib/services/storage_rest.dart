import 'dart:convert';
import 'dart:io';

class StorageFileMeta {
  final String name;
  final String fullPath;
  final String url;
  final DateTime updatedAt;

  const StorageFileMeta({
    required this.name,
    required this.fullPath,
    required this.url,
    required this.updatedAt,
  });
}

class StorageRest {
  static const _bucket = 'apptranhbeca.firebasestorage.app';
  static const _api = 'https://firebasestorage.googleapis.com/v0/b/$_bucket/o';

  // Cache in-memory: key = prefix, value = danh sách file
  static final Map<String, List<({String name, String url})>> _listCache = {};

  static String buildUrl(String filePath) =>
      '$_api/${Uri.encodeComponent(filePath)}?alt=media';

  /// Xóa cache của một folder (dùng khi cần refresh)
  static void invalidate(String prefix) => _listCache.remove(prefix);

  /// Pre-warm cache nền — không block UI
  static void prewarm(String prefix) {
    if (_listCache.containsKey(prefix)) return;
    listFiles(prefix); // fire-and-forget
  }

  // Liệt kê tất cả file trong prefix, trả về list (name, url)
  static Future<List<({String name, String url})>> listFiles(
    String prefix, {
    int maxResults = 100,
    bool fetchAllPages = true,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _listCache.containsKey(prefix)) return _listCache[prefix]!;

    final result = <({String name, String url})>[];
    String? pageToken;
    do {
      final params = <String, String>{
        'prefix': prefix,
        'maxResults': maxResults.toString(),
      };
      if (pageToken != null) {
        params['pageToken'] = pageToken;
      }
      final uri = Uri.parse(_api).replace(queryParameters: params);
      try {
        final client = HttpClient();
        final req = await client.getUrl(uri);
        final res = await req.close();
        final body = await res.transform(const Utf8Decoder()).join();
        client.close();
        if (res.statusCode != 200) break;
        final json = jsonDecode(body) as Map<String, dynamic>;
        for (final item in (json['items'] as List? ?? [])) {
          final name = item['name'] as String;
          result.add((name: name.split('/').last, url: buildUrl(name)));
        }
        pageToken = json['nextPageToken'] as String?;
      } catch (_) {
        break;
      }
      if (!fetchAllPages) break;
    } while (pageToken != null);

    // Chỉ cache khi đã lấy hết tất cả trang (pageToken == null).
    // Nếu dừng sớm vì fetchAllPages:false mà vẫn còn trang tiếp theo,
    // kết quả chưa đầy đủ — không cache để tránh trả về danh sách thiếu.
    if (result.isNotEmpty && pageToken == null) _listCache[prefix] = result;
    return result;
  }

  /// Lấy file mới nhất theo thời gian cập nhật trên Firebase Storage.
  /// Dùng cho khu vực "Mẫu mới" để luôn bám theo ảnh vừa upload.
  static Future<List<StorageFileMeta>> listLatestFiles(
    String prefix, {
    int limit = 100,
    bool forceRefresh = false,
  }) async {
    final all = await _listFilesWithMeta(
      prefix,
      maxResults: 1000,
      fetchAllPages: true,
      forceRefresh: forceRefresh,
    );
    final imagesOnly = all.where((f) => _isImagePath(f.fullPath)).toList();
    imagesOnly.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return imagesOnly.take(limit).toList();
  }

  static bool _isImagePath(String path) {
    final p = path.toLowerCase();
    return p.endsWith('.jpg') ||
        p.endsWith('.jpeg') ||
        p.endsWith('.png') ||
        p.endsWith('.webp') ||
        p.endsWith('.gif') ||
        p.endsWith('.bmp');
  }

  static Future<List<StorageFileMeta>> _listFilesWithMeta(
    String prefix, {
    int maxResults = 100,
    bool fetchAllPages = true,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _listCache.containsKey(prefix)) {
      return _listCache[prefix]!
          .map(
            (f) => StorageFileMeta(
              name: f.name,
              fullPath: '$prefix${f.name}',
              url: f.url,
              updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
            ),
          )
          .toList();
    }

    final result = <StorageFileMeta>[];
    String? pageToken;
    do {
      final params = <String, String>{
        'prefix': prefix,
        'maxResults': maxResults.toString(),
      };
      if (pageToken != null) {
        params['pageToken'] = pageToken;
      }
      final uri = Uri.parse(_api).replace(queryParameters: params);
      try {
        final client = HttpClient();
        final req = await client.getUrl(uri);
        final res = await req.close();
        final body = await res.transform(const Utf8Decoder()).join();
        client.close();
        if (res.statusCode != 200) break;
        final json = jsonDecode(body) as Map<String, dynamic>;
        for (final item in (json['items'] as List? ?? [])) {
          final data = item as Map<String, dynamic>;
          final fullName = (data['name'] as String?) ?? '';
          if (fullName.isEmpty) continue;
          final updatedRaw =
              (data['updated'] ?? data['timeCreated'] ?? '').toString();
          final updatedAt = DateTime.tryParse(updatedRaw) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          result.add(
            StorageFileMeta(
              name: fullName.split('/').last,
              fullPath: fullName,
              url: buildUrl(fullName),
              updatedAt: updatedAt,
            ),
          );
        }
        pageToken = json['nextPageToken'] as String?;
      } catch (_) {
        break;
      }
      if (!fetchAllPages) break;
    } while (pageToken != null);

    return result;
  }

  // Liệt kê các folder con trực tiếp trong prefix
  static Future<List<String>> listSubFolders(String prefix) async {
    final params = <String, String>{
      'prefix': prefix.isEmpty ? '' : (prefix.endsWith('/') ? prefix : '$prefix/'),
      'delimiter': '/',
    };
    final uri = Uri.parse(_api).replace(queryParameters: params);
    try {
      final client = HttpClient();
      final req = await client.getUrl(uri);
      final res = await req.close();
      final body = await res.transform(const Utf8Decoder()).join();
      client.close();
      if (res.statusCode != 200) return [];
      final json = jsonDecode(body) as Map<String, dynamic>;
      return ((json['prefixes'] as List?) ?? []).cast<String>();
    } catch (_) {
      return [];
    }
  }
}

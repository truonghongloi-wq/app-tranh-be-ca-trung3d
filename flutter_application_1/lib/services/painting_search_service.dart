import 'dart:async';
import 'dart:convert';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'storage_rest.dart';

/// 1 bức tranh trong kho, kèm từ khóa để tìm kiếm.
class PaintingEntry {
  final String fileName; // vd: 6801.png (dùng làm imageId khi đặt hàng)
  final String url;
  final String category;
  final String code; // mã tranh, vd: 6801
  final List<String> tags;

  const PaintingEntry({
    required this.fileName,
    required this.url,
    required this.category,
    required this.code,
    required this.tags,
  });
}

/// 1 dòng gợi ý khi khách gõ ô tìm kiếm.
class KeywordSuggestion {
  final String keyword; // từ khóa hiển thị, vd: "hoa sen"
  final int count; // số tranh có từ khóa này
  final String? thumbnailUrl;

  const KeywordSuggestion({
    required this.keyword,
    required this.count,
    this.thumbnailUrl,
  });
}

/// Tìm tranh theo từ khóa nội dung (hoa sen, mặt trăng, đá...), không phân
/// biệt dấu/hoa thường. Từ khóa của từng tranh lưu ở Realtime DB
/// `painting_tags/{mã tranh}` = "hoa sen, hồ nước, ..." (admin sửa được
/// ngay trong app); bản đóng gói `assets/data/painting_tags.json` là dữ liệu
/// dự phòng khi chưa có mạng/chưa có dữ liệu trên DB.
class PaintingSearchService {
  static const _assetPath = 'assets/data/painting_tags.json';

  static List<PaintingEntry>? _catalog;
  static Future<List<PaintingEntry>>? _loading;

  /// Danh sách toàn bộ tranh (đã cache). Gọi nhiều lần chỉ tải 1 lần.
  static Future<List<PaintingEntry>> catalog({bool forceRefresh = false}) {
    if (forceRefresh) {
      _catalog = null;
      _loading = null;
    }
    if (_catalog != null) return Future.value(_catalog);
    return _loading ??= _load()
        .then((list) {
          _catalog = list;
          return list;
        })
        .whenComplete(() => _loading = null);
  }

  static Future<List<PaintingEntry>> _load() async {
    final tagsFuture = _loadTags();
    var folders = await StorageRest.listSubFolders('');
    if (folders.isEmpty) folders = await StorageRest.listSubFolders('images/');
    final perFolder = await Future.wait(
      folders.map((fp) async {
        final category = fp.split('/').where((s) => s.isNotEmpty).last;
        final files = await StorageRest.listFiles(fp);
        return [
          for (final f in files)
            (fileName: f.name, url: f.url, category: category),
        ];
      }),
    );
    final tags = await tagsFuture;
    return [
      for (final list in perFolder)
        for (final f in list)
          PaintingEntry(
            fileName: f.fileName,
            url: f.url,
            category: f.category,
            code: codeOf(f.fileName),
            tags: _splitTags(tags[codeOf(f.fileName)] ?? ''),
          ),
    ];
  }

  // Từ khóa trên DB ghi đè bản đóng gói theo từng mã tranh.
  static Future<Map<String, String>> _loadTags() async {
    final result = <String, String>{};
    try {
      final raw = await rootBundle.loadString(_assetPath);
      (jsonDecode(raw) as Map).forEach(
        (k, v) => result[k.toString()] = v.toString(),
      );
    } catch (e) {
      debugPrint('[Search] đọc $_assetPath lỗi: $e');
    }
    try {
      final snap = await FirebaseDatabase.instance
          .ref('painting_tags')
          .get()
          .timeout(const Duration(seconds: 8));
      final value = snap.value;
      if (value is Map) {
        value.forEach((k, v) {
          if (v is String) result[k.toString()] = v;
        });
      }
    } catch (e) {
      debugPrint('[Search] đọc painting_tags lỗi: $e');
    }
    return result;
  }

  /// Mã tranh từ tên file: "6817_lưng.png" → "6817", "abc.png" → "abc".
  static String codeOf(String fileName) {
    final stem = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;
    final digits = RegExp(r'^\d+').stringMatch(stem);
    return digits ?? stem;
  }

  static List<String> _splitTags(String raw) => raw
      .split(RegExp(r'[,;\n]'))
      .map((t) => t.trim().toLowerCase())
      .where((t) => t.isNotEmpty)
      .toSet()
      .toList();

  /// Từ khóa hiện tại của 1 mã tranh (đã gồm thay đổi admin vừa lưu).
  static List<String> tagsOf(String code) {
    for (final p in _catalog ?? const <PaintingEntry>[]) {
      if (p.code == code) return p.tags;
    }
    return const [];
  }

  /// Admin lưu từ khóa cho 1 mã tranh. Trả về thông báo lỗi hoặc null.
  static Future<String?> saveTags(String code, List<String> tags) async {
    final clean = tags.map((t) => t.trim()).where((t) => t.isNotEmpty);
    final value = clean.join(', ');
    if (value.length > 500) return 'Từ khóa quá dài (tối đa 500 ký tự).';
    try {
      final ref = FirebaseDatabase.instance.ref('painting_tags/$code');
      // Xóa hết từ khóa vẫn lưu chuỗi rỗng để ghi đè bản đóng gói trong app
      await ref.set(value);
      final list = _catalog;
      if (list != null) {
        _catalog = [
          for (final p in list)
            p.code == code
                ? PaintingEntry(
                    fileName: p.fileName,
                    url: p.url,
                    category: p.category,
                    code: p.code,
                    tags: _splitTags(value),
                  )
                : p,
        ];
      }
      return null;
    } catch (e) {
      debugPrint('[Search] lưu painting_tags/$code lỗi: $e');
      return 'Không lưu được từ khóa. Vui lòng thử lại.';
    }
  }

  // ---------------------------------------------------------------------------
  // So khớp không dấu
  // ---------------------------------------------------------------------------

  static const _accents = {
    'a': 'àáạảãâầấậẩẫăằắặẳẵ',
    'e': 'èéẹẻẽêềếệểễ',
    'i': 'ìíịỉĩ',
    'o': 'òóọỏõôồốộổỗơờớợởỡ',
    'u': 'ùúụủũưừứựửữ',
    'y': 'ỳýỵỷỹ',
    'd': 'đ',
  };

  static final Map<String, String> _accentMap = {
    for (final e in _accents.entries)
      for (final ch in e.value.split('')) ch: e.key,
  };

  /// "Hoa Sen  Hồng" → "hoa sen hong"
  static String normalize(String s) {
    final lower = s.toLowerCase().trim();
    final buf = StringBuffer();
    for (final ch in lower.split('')) {
      buf.write(_accentMap[ch] ?? ch);
    }
    return buf
        .toString()
        // Bỏ dấu kết hợp (khi bàn phím gõ kiểu tổ hợp Unicode NFD)
        .replaceAll(RegExp('[̀-ͯ]'), '')
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // Mức độ khớp của từ khóa với câu tìm (0 = không khớp). Mọi chữ khách gõ
  // phải khớp với đầu 1 chữ trong từ khóa: "hoa" → "hoa sen", "sen h" →
  // "sen hồng", nhưng "oa" không khớp "hoa".
  static int _score(String tagNorm, String queryNorm) {
    if (queryNorm.isEmpty) return 0;
    if (tagNorm == queryNorm) return 100;
    if (tagNorm.startsWith(queryNorm)) return 80;
    final words = tagNorm.split(' ');
    final qWords = queryNorm.split(' ');
    final allMatch = qWords.every((q) => words.any((w) => w.startsWith(q)));
    return allMatch ? 50 : 0;
  }

  /// Gợi ý từ khóa cho câu đang gõ, ưu tiên khớp đầu rồi nhiều tranh nhất.
  static List<KeywordSuggestion> suggest(
    List<PaintingEntry> catalog,
    String query, {
    int limit = 6,
  }) {
    final q = normalize(query);
    if (q.isEmpty) return const [];
    final byKeyword = <String, ({int score, int count, String thumb})>{};
    for (final p in catalog) {
      for (final tag in p.tags) {
        final score = _score(normalize(tag), q);
        if (score == 0) continue;
        final cur = byKeyword[tag];
        byKeyword[tag] = (
          score: score,
          count: (cur?.count ?? 0) + 1,
          thumb: cur?.thumb ?? p.url,
        );
      }
    }
    final list = byKeyword.entries.toList()
      ..sort((a, b) {
        final s = b.value.score.compareTo(a.value.score);
        if (s != 0) return s;
        final c = b.value.count.compareTo(a.value.count);
        if (c != 0) return c;
        return a.key.length.compareTo(b.key.length);
      });
    return [
      for (final e in list.take(limit))
        KeywordSuggestion(
          keyword: e.key,
          count: e.value.count,
          thumbnailUrl: e.value.thumb,
        ),
    ];
  }

  /// Tranh khớp câu tìm: theo từ khóa, mã tranh hoặc tên chủ đề.
  /// Tranh khớp tốt hơn (trùng hẳn từ khóa) đứng trước.
  static List<PaintingEntry> search(List<PaintingEntry> catalog, String query) {
    final q = normalize(query);
    if (q.isEmpty) return const [];
    // "T-6801", "t 6801", "6801" đều tìm theo mã tranh
    final codeQ = q.replaceFirst(RegExp(r'^t\s*(?=\d)'), '');
    final isCode = RegExp(r'^\d+$').hasMatch(codeQ);
    final scored = <(PaintingEntry, int)>[];
    for (final p in catalog) {
      var best = 0;
      if (isCode && p.code.startsWith(codeQ)) best = 90;
      for (final tag in p.tags) {
        final s = _score(normalize(tag), q);
        if (s > best) best = s;
      }
      final catScore = _score(normalize(p.category), q);
      if (catScore > best) best = catScore - 10;
      if (best > 0) scored.add((p, best));
    }
    scored.sort((a, b) {
      final s = b.$2.compareTo(a.$2);
      return s != 0 ? s : a.$1.fileName.compareTo(b.$1.fileName);
    });
    return [for (final e in scored) e.$1];
  }
}

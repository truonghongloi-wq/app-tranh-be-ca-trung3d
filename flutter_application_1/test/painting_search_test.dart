import 'package:flutter_application_1/services/painting_search_service.dart';
import 'package:flutter_test/flutter_test.dart';

PaintingEntry _p(String code, List<String> tags, {String cat = 'T-6800'}) =>
    PaintingEntry(
      fileName: '$code.png',
      url: 'https://x/$code',
      category: cat,
      code: code,
      tags: tags,
    );

void main() {
  final catalog = [
    _p('6826', ['hoa sen', 'hồ nước', 'vũ trụ']),
    _p('6828', ['hoa sen', 'sen hồng', 'hoa']),
    _p('6806', ['mặt trăng', 'trăng tròn', 'hồ nước']),
    _p('6829', ['đá', 'vân đá']),
  ];

  test('normalize bỏ dấu, đ → d', () {
    expect(PaintingSearchService.normalize('  Hoa SEN  Hồng '), 'hoa sen hong');
    expect(PaintingSearchService.normalize('Đá'), 'da');
    expect(PaintingSearchService.normalize('T-6801'), 't 6801');
  });

  test('codeOf', () {
    expect(PaintingSearchService.codeOf('6817_lưng.png'), '6817');
    expect(PaintingSearchService.codeOf('6801.png'), '6801');
  });

  test('gõ "hoa" gợi ý "hoa sen" đứng đầu', () {
    final s = PaintingSearchService.suggest(catalog, 'hoa');
    expect(s.first.keyword, 'hoa');
    expect(s.map((k) => k.keyword), contains('hoa sen'));
    expect(s.firstWhere((k) => k.keyword == 'hoa sen').count, 2);
    // "ho" khớp cả "hồ nước" nhờ so khớp không dấu
    expect(
      PaintingSearchService.suggest(catalog, 'ho').map((k) => k.keyword),
      contains('hồ nước'),
    );
  });

  test('không khớp giữa chữ', () {
    expect(PaintingSearchService.suggest(catalog, 'oa'), isEmpty);
  });

  test('tìm "hoa sen" ra đúng tranh hoa sen', () {
    final r = PaintingSearchService.search(catalog, 'hoa sen');
    expect(r.map((p) => p.code), ['6826', '6828']);
    expect(
      PaintingSearchService.search(catalog, 'trang').map((p) => p.code),
      ['6806'],
    );
  });

  test('tìm theo mã tranh', () {
    expect(
      PaintingSearchService.search(catalog, 'T-6829').map((p) => p.code),
      ['6829'],
    );
    expect(PaintingSearchService.search(catalog, '99'), isEmpty);
  });
}

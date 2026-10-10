import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../services/painting_search_service.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/app_ui.dart';
import 'search_results_page.dart';

/// Mở trang kết quả tìm kiếm tranh theo từ khóa.
void openSearchResults(
  BuildContext context,
  String query, {
  String selectedSize = '60x30',
}) {
  if (query.trim().isEmpty) return;
  FocusScope.of(context).unfocus();
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          SearchResultsPage(query: query.trim(), selectedSize: selectedSize),
    ),
  );
}

/// Khung gợi ý dưới ô tìm kiếm: từ khóa nội dung tranh ("hoa" → "hoa sen
/// · 2 tranh") và mã tranh khớp. [leading] là các dòng gợi ý riêng của trang
/// gọi (vd: chủ đề) hiển thị phía trên.
class SearchSuggestionsPanel extends StatelessWidget {
  final String query;
  final List<PaintingEntry> catalog;
  final String selectedSize;
  final List<Widget> leading;
  final EdgeInsetsGeometry margin;

  const SearchSuggestionsPanel({
    super.key,
    required this.query,
    required this.catalog,
    this.selectedSize = '60x30',
    this.leading = const [],
    this.margin = const EdgeInsets.fromLTRB(16, 8, 16, 0),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = appIsDark(context);
    final muted = appMutedColor(isDark);
    final keywords = PaintingSearchService.suggest(catalog, query, limit: 5);
    final codeQ = PaintingSearchService.normalize(
      query,
    ).replaceFirst(RegExp(r'^t\s*(?=\d)'), '');
    final codeMatches = RegExp(r'^\d+$').hasMatch(codeQ)
        ? catalog.where((p) => p.code.startsWith(codeQ)).take(3).toList()
        : const <PaintingEntry>[];

    final rows = <Widget>[
      ...leading,
      for (final k in keywords)
        ListTile(
          dense: true,
          leading: _thumb(k.thumbnailUrl),
          title: _highlight(k.keyword, query, isDark),
          subtitle: Text(
            '${k.count} tranh',
            style: TextStyle(fontSize: 12, color: muted),
          ),
          trailing: Icon(
            PhosphorIconsRegular.magnifyingGlass,
            size: 16,
            color: muted,
          ),
          onTap: () =>
              openSearchResults(context, k.keyword, selectedSize: selectedSize),
        ),
      for (final p in codeMatches)
        ListTile(
          dense: true,
          leading: _thumb(p.url),
          title: Text('Mã T-${p.code}'),
          subtitle: Text(
            p.category,
            style: TextStyle(fontSize: 12, color: muted),
          ),
          trailing: Icon(
            PhosphorIconsRegular.caretRight,
            size: 16,
            color: muted,
          ),
          onTap: () =>
              openSearchResults(context, p.code, selectedSize: selectedSize),
        ),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: margin,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? const []
            : [
                BoxShadow(
                  color: AppColors.blue.withValues(alpha: 0.07),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        children: [
          ...rows,
          ListTile(
            dense: true,
            leading: const SizedBox(
              width: 36,
              child: Icon(
                PhosphorIconsRegular.images,
                color: AppColors.blue,
                size: 20,
              ),
            ),
            title: Text(
              'Xem tất cả kết quả cho "${query.trim()}"',
              style: const TextStyle(
                color: AppColors.blue,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () =>
                openSearchResults(context, query, selectedSize: selectedSize),
          ),
        ],
      ),
    );
  }

  static Widget _thumb(String? url) => SizedBox(
    width: 36,
    height: 36,
    child: url == null
        ? const Icon(
            PhosphorIconsRegular.image,
            size: 20,
            color: AppColors.blue,
          )
        : ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              memCacheWidth: 108,
              errorWidget: (_, _, _) =>
                  const Icon(PhosphorIconsRegular.image, size: 20),
            ),
          ),
  );

  // In đậm phần từ khóa khớp với chữ khách đã gõ (so khớp không dấu).
  static Widget _highlight(String keyword, String query, bool isDark) {
    final base = TextStyle(
      fontSize: 14,
      color: appTextColor(isDark),
      fontWeight: FontWeight.w400,
    );
    final q = PaintingSearchService.normalize(query);
    final norm = PaintingSearchService.normalize(keyword);
    // normalize giữ nguyên độ dài khi từ khóa chỉ gồm chữ + khoảng trắng đơn
    if (q.isEmpty || norm.length != keyword.length || !norm.startsWith(q)) {
      return Text(keyword, style: base);
    }
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: keyword.substring(0, q.length),
            style: base.copyWith(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: keyword.substring(q.length), style: base),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../services/painting_search_service.dart';
import '../../services/user_service.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/app_ui.dart';
import '../gallery/gallery_page.dart';
import 'tag_editor_dialog.dart';

/// Kết quả tìm tranh theo từ khóa (vd: "hoa sen"), kèm các từ khóa liên
/// quan để khách bấm lọc tiếp.
class SearchResultsPage extends StatefulWidget {
  final String query;
  final String selectedSize;

  const SearchResultsPage({
    super.key,
    required this.query,
    this.selectedSize = '60x30',
  });

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage> {
  List<PaintingEntry>? _catalog;
  bool _error = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _load();
    UserService.isCurrentUserAdmin().then((v) {
      if (mounted) setState(() => _isAdmin = v);
    });
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() => _error = false);
    try {
      final list = await PaintingSearchService.catalog(
        forceRefresh: forceRefresh,
      );
      if (mounted) setState(() => _catalog = list);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _editTags(PaintingEntry p) async {
    final saved = await showTagEditorDialog(context, p);
    if (saved == true) {
      _load(); // lấy lại catalog đã cập nhật từ khóa
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = appIsDark(context);
    final catalog = _catalog;
    final results = catalog == null
        ? const <PaintingEntry>[]
        : PaintingSearchService.search(catalog, widget.query);
    // Từ khóa liên quan: gợi ý theo chữ đầu tiên khách gõ ("hoa sen" → "hoa…")
    final firstWord = PaintingSearchService.normalize(
      widget.query,
    ).split(' ').first;
    final related = catalog == null
        ? const <KeywordSuggestion>[]
        : PaintingSearchService.suggest(catalog, firstWord, limit: 8)
              .where(
                (k) =>
                    PaintingSearchService.normalize(k.keyword) !=
                    PaintingSearchService.normalize(widget.query),
              )
              .toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          AppSubHeader(title: 'Tìm: "${widget.query}"'),
          if (related.isNotEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 52,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  itemCount: related.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => ActionChip(
                    label: Text('${related[i].keyword} (${related[i].count})'),
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SearchResultsPage(
                          query: related[i].keyword,
                          selectedSize: widget.selectedSize,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (catalog != null && results.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Tìm thấy ${results.length} tranh'
                  '${_isAdmin ? ' · nhấn giữ tranh để sửa từ khóa' : ''}',
                  style: TextStyle(color: appMutedColor(isDark)),
                ),
              ),
            ),
          if (_error)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _message(
                isDark,
                PhosphorIconsRegular.warningCircle,
                'Không tải được danh sách tranh.',
                action: TextButton(
                  onPressed: () => _load(forceRefresh: true),
                  child: const Text('Thử lại'),
                ),
              ),
            )
          else if (catalog == null)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (results.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _message(
                isDark,
                PhosphorIconsRegular.magnifyingGlass,
                'Không tìm thấy tranh cho "${widget.query}".\n'
                'Thử từ khóa khác như: mặt trăng, vũ trụ, đá, thủy mặc…',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(12),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.78,
                ),
                delegate: SliverChildBuilderDelegate((_, i) {
                  final p = results[i];
                  final card = PaintingCard(
                    name: p.fileName,
                    url: p.url,
                    selectedSize: widget.selectedSize,
                  );
                  if (!_isAdmin) return card;
                  return GestureDetector(
                    onLongPress: () => _editTags(p),
                    child: card,
                  );
                }, childCount: results.length),
              ),
            ),
        ],
      ),
    );
  }

  Widget _message(bool isDark, IconData icon, String text, {Widget? action}) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: appMutedColor(isDark), height: 1.5),
          ),
          ?action,
        ],
      ),
    );
  }
}

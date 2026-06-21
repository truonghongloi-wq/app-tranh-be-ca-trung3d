import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/storage_rest.dart';
import '../gallery/gallery_page.dart';

class _Category {
  final String name;
  final String folderPath;
  final String? thumbnailUrl;
  const _Category({
    required this.name,
    required this.folderPath,
    this.thumbnailUrl,
  });
}

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  List<_Category> _categories = [];
  bool _loading = true;
  String _search = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      var folders = await StorageRest.listSubFolders('');
      if (folders.isEmpty) {
        folders = await StorageRest.listSubFolders('images/');
      }
      folders = folders
          .where(
            (fp) =>
                fp
                    .split('/')
                    .where((s) => s.isNotEmpty)
                    .last
                    .toLowerCase() !=
                'composites',
          )
          .toList();
      final cats = await Future.wait(
        folders.map((fp) async {
          final files = await StorageRest.listFiles(
            fp,
            maxResults: 1,
            fetchAllPages: false,
          );
          final thumb = files.isNotEmpty ? files.first.url : null;
          final name = fp.split('/').where((s) => s.isNotEmpty).last;
          return _Category(name: name, folderPath: fp, thumbnailUrl: thumb);
        }),
      );
      if (!mounted) return;
      setState(() {
        _categories = cats;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_Category> get _filtered {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _categories;
    return _categories.where((c) => c.name.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (_, _) => [
          SliverAppBar(
            expandedHeight: 0,
            floating: true,
            pinned: true,
            elevation: 0,
            automaticallyImplyLeading: false,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF5CC1FF), Color(0xFF2B678B)],
                ),
              ),
              child: const FlexibleSpaceBar(
                titlePadding: EdgeInsets.only(left: 16, bottom: 14),
                title: Text(
                  'Chủ Đề Tranh',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ),
        ],
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Tìm chủ đề tranh...',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF2B678B),
                  ),
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _search = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: theme.cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filtered.isEmpty
                  ? Center(
                      child: Text(
                        _search.isEmpty
                            ? 'Chưa có chủ đề nào.'
                            : 'Không tìm thấy chủ đề.',
                        style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1.0,
                          ),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) => _buildCard(_filtered[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(_Category cat) {
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GalleryPage(
            categoryName: cat.name,
            folderPath: cat.folderPath,
            selectedSize: '60x30',
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          fit: StackFit.expand,
          children: [
            cat.thumbnailUrl != null
                ? CachedNetworkImage(
                    imageUrl: cat.thumbnailUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) =>
                        Container(color: const Color(0xFF2B678B)),
                  )
                : Container(color: const Color(0xFF2B678B)),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.65),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 10,
              left: 10,
              right: 10,
              child: Text(
                cat.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

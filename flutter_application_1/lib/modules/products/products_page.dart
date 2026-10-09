import '../../widgets/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/storage_rest.dart';
import '../../widgets/app_ui.dart';
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
      body: CustomScrollView(
        slivers: [
          const AppTabHeader(title: 'Chủ đề tranh'),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(child: _buildSearchBar(isDark)),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: AppSectionTitle(
                _search.isEmpty ? 'Tất cả chủ đề' : 'Kết quả tìm kiếm',
                padding: const EdgeInsets.only(top: 24, bottom: 12),
                trailing: _loading
                    ? null
                    : AppHint('${_filtered.length} chủ đề'),
              ),
            ),
          ),
          if (_loading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (_filtered.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    _search.isEmpty
                        ? 'Chưa có chủ đề nào.'
                        : 'Không tìm thấy chủ đề.',
                    style: TextStyle(color: appMutedColor(isDark)),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.2,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _buildCard(_filtered[i]),
                  childCount: _filtered.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: appSoftShadow(isDark),
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _search = v),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Tìm chủ đề tranh...',
          hintStyle: TextStyle(color: appMutedColor(isDark), fontSize: 14),
          prefixIcon: Icon(
            PhosphorIconsRegular.magnifyingGlass,
            color: appAccentColor(isDark),
          ),
          suffixIcon: _search.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    PhosphorIconsRegular.x,
                    color: appMutedColor(isDark),
                  ),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _search = '');
                  },
                )
              : null,
          filled: true,
          fillColor: Theme.of(context).cardColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: const BorderSide(color: AppColors.sky, width: 1.2),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildCard(_Category cat) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
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
        child: Stack(
          fit: StackFit.expand,
          children: [
            cat.thumbnailUrl != null
                ? CachedNetworkImage(
                    imageUrl: cat.thumbnailUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => Container(color: AppColors.blue),
                  )
                : Container(color: AppColors.blue),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.4, 1.0],
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Text(
                cat.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
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

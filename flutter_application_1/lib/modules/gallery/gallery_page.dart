import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../product_detail/product_detail_page.dart';
import '../profile/favorite_store.dart';
import '../../services/storage_rest.dart';

class GalleryPage extends StatefulWidget {
  final String categoryName;
  final String? folderPath;
  final String selectedSize;

  const GalleryPage({
    super.key,
    required this.categoryName,
    this.folderPath,
    required this.selectedSize,
  });

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  static const _primary = Color(0xFF2B678B);
  static const _gradientTop = Color(0xFF5CC1FF);

  late Future<List<_StorageItem>> _imagesFuture;
  String _sortOrder = 'default';

  @override
  void initState() {
    super.initState();
    _imagesFuture = _loadImages();
  }

  Future<List<_StorageItem>> _loadImages() async {
    final path = widget.folderPath ?? widget.categoryName;
    final prefix = path.endsWith('/') ? path : '$path/';
    final files = await StorageRest.listFiles(prefix);
    if (files.isNotEmpty) {
      return files.map((f) => _StorageItem(name: f.name, url: f.url)).toList();
    }
    final files2 = await StorageRest.listFiles(path);
    return files2.map((f) => _StorageItem(name: f.name, url: f.url)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 80,
            floating: true,
            pinned: true,
            elevation: 0,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_gradientTop, _primary],
                ),
              ),
              child: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 56, bottom: 14),
                title: Text(
                  widget.categoryName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.sort_rounded, color: Colors.white),
                tooltip: 'Sắp xếp',
                onSelected: (v) => setState(() => _sortOrder = v),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'default', child: Text('Mặc định')),
                  PopupMenuItem(value: 'az', child: Text('Tên A → Z')),
                  PopupMenuItem(value: 'za', child: Text('Tên Z → A')),
                ],
              ),
            ],
          ),
        ],
        body: FutureBuilder<List<_StorageItem>>(
          future: _imagesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _SkeletonGrid();
            }
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text('Lỗi tải ảnh: ${snapshot.error}',
                        textAlign: TextAlign.center),
                  ],
                ),
              );
            }
            final raw = snapshot.data ?? [];
            if (raw.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.image_search,
                        size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Text('Chưa có ảnh trong danh mục này',
                        style: TextStyle(color: Colors.black54)),
                  ],
                ),
              );
            }
            final images = _sorted(raw);
            return GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.78,
              ),
              itemCount: images.length,
              itemBuilder: (context, index) => _GalleryCard(
                item: images[index],
                selectedSize: widget.selectedSize,
              ),
            );
          },
        ),
      ),
    );
  }

  List<_StorageItem> _sorted(List<_StorageItem> items) {
    final copy = List<_StorageItem>.from(items);
    if (_sortOrder == 'az') copy.sort((a, b) => a.name.compareTo(b.name));
    if (_sortOrder == 'za') copy.sort((a, b) => b.name.compareTo(a.name));
    return copy;
  }
}

class _GalleryCard extends StatelessWidget {
  final _StorageItem item;
  final String selectedSize;

  const _GalleryCard({required this.item, required this.selectedSize});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailPage(
            imageId: item.name,
            imageUrl: item.url,
            pricePerM2: 300000,
            initialSize: selectedSize,
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: item.url,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => const _ShimmerBox(
                        borderRadius: BorderRadius.zero,
                      ),
                      errorWidget: (_, _, _) => Container(
                        color: const Color(0xFFE3F2FD),
                        child: const Icon(Icons.broken_image,
                            color: Color(0xFF2B678B), size: 36),
                      ),
                    ),
                    // subtle gradient overlay
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 50,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Color(0x55000000),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // heart / favourite button
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: ValueListenableBuilder<List<FavoriteItem>>(
                        valueListenable: FavoriteStore.favorites,
                        builder: (_, favs, _) {
                          final isFav = favs.any((f) => f.id == item.name);
                          return GestureDetector(
                            onTap: () => FavoriteStore.toggle(
                              FavoriteItem(id: item.name, url: item.url),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.88),
                                shape: BoxShape.circle,
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Icon(
                                isFav
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color:
                                    isFav ? Colors.red : Colors.grey.shade500,
                                size: 18,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: Color(0xFF1B3A4B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2B678B).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.arrow_forward_ios_rounded,
                        size: 10, color: Color(0xFF2B678B)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemCount: 8,
      itemBuilder: (_, _) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: _ShimmerBox(
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(16)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ShimmerBox(
                    height: 12,
                    width: 80,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  final double? height;
  final double? width;
  final BorderRadius borderRadius;

  const _ShimmerBox({
    this.height,
    this.width,
    required this.borderRadius,
  });

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.35, end: 0.75).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          color: Colors.grey.withValues(alpha: _anim.value),
        ),
      ),
    );
  }
}

class _StorageItem {
  final String name;
  final String url;
  const _StorageItem({required this.name, required this.url});
}

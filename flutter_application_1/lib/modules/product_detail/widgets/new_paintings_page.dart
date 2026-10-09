import '../../../widgets/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../product_detail_page.dart';
import '../../../services/storage_rest.dart';
import '../../../widgets/app_ui.dart';

class NewPaintingsPage extends StatefulWidget {
  const NewPaintingsPage({super.key});

  @override
  State<NewPaintingsPage> createState() => _NewPaintingsPageState();
}

class _NewPaintingsPageState extends State<NewPaintingsPage> {
  late Future<List<_StorageItem>> _imagesFuture;

  @override
  void initState() {
    super.initState();
    _imagesFuture = _loadImages();
  }

  Future<List<_StorageItem>> _loadImages() async {
    final latest = await StorageRest.listLatestFiles(
      '',
      limit: 100,
      forceRefresh: true,
    );
    return latest.map((f) => _StorageItem(name: f.name, url: f.url)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: appSubAppBar(context, 'Tranh mới cập nhật'),
      body: FutureBuilder<List<_StorageItem>>(
        future: _imagesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi tải ảnh: ${snapshot.error}'));
          }
          final images = snapshot.data ?? [];
          if (images.isEmpty) {
            return const Center(child: Text('Chưa có ảnh mới'));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 15,
              crossAxisSpacing: 10,
              childAspectRatio: 0.85,
            ),
            itemCount: images.length,
            itemBuilder: (context, index) {
              final item = images[index];
              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProductDetailPage(
                        imageId: item.name,
                        imageUrl: item.url,
                        pricePerM2: 300000,
                        initialSize: "60x30",
                      ),
                    ),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: item.url,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[200],
                            child: const Icon(
                              PhosphorIconsRegular.imageBroken,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _StorageItem {
  final String name;
  final String url;
  const _StorageItem({required this.name, required this.url});
}

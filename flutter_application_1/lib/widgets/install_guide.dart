import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_icons.dart';
import 'app_ui.dart';

/// Danh sách video YouTube hướng dẫn dán tranh — sửa/thêm video tại đây,
/// tab Quà tặng và trang hóa đơn đều lấy từ danh sách này.
const kInstallVideos = [
  (
    id: 'HPMifAo5sWI',
    title: 'Dán tranh trong bể không nẹp',
    subtitle: 'Mặt đáy & lưng, ngập nước',
  ),
  (
    id: 'rBf5Bjudbqg',
    title: 'Dán tranh trong bể có nẹp',
    subtitle: 'Bể có nẹp viền, mặt đáy & lưng',
  ),
  (
    id: '1JOcMpJ9o8o',
    title: 'Dán tranh ngoài bể',
    subtitle: 'Mặt ngoài kính, không tiếp nước',
  ),
];

String installVideoThumb(String id) =>
    'https://img.youtube.com/vi/$id/hqdefault.jpg';

Future<void> openInstallVideo(BuildContext context, String id) async {
  final ok = await launchUrl(
    Uri.parse('https://youtu.be/$id'),
    mode: LaunchMode.externalApplication,
  );
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Không mở được video')));
  }
}

/// Thẻ gọn liệt kê đủ các video hướng dẫn (dùng ở trang hóa đơn).
class InstallGuideCard extends StatelessWidget {
  const InstallGuideCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = appIsDark(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: appCardDecoration(context, radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                PhosphorIconsRegular.bookOpen,
                size: 20,
                color: appAccentColor(isDark),
              ),
              const SizedBox(width: 8),
              Text(
                'Hướng dẫn dán tranh',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: appTextColor(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final v in kInstallVideos)
            _VideoRow(id: v.id, title: v.title, subtitle: v.subtitle),
        ],
      ),
    );
  }
}

class _VideoRow extends StatelessWidget {
  final String id;
  final String title;
  final String subtitle;
  const _VideoRow({
    required this.id,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = appIsDark(context);
    return InkWell(
      onTap: () => openInstallVideo(context, id),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 80,
                height: 45,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: installVideoThumb(id),
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          const ColoredBox(color: Color(0xFF1E3A8A)),
                      errorWidget: (_, _, _) =>
                          const ColoredBox(color: Color(0xFF1E3A8A)),
                    ),
                    const ColoredBox(color: Color(0x33000000)),
                    const Center(
                      child: Icon(
                        PhosphorIconsFill.playCircle,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: appTextColor(isDark),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: appMutedColor(isDark),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              PhosphorIconsRegular.caretRight,
              size: 18,
              color: appMutedColor(isDark),
            ),
          ],
        ),
      ),
    );
  }
}

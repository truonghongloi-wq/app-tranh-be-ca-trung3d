import '../../widgets/app_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/install_guide.dart';

// Cả trang chỉ dùng 1 màu nhấn (xanh thương hiệu) trên nền trung tính.
Color _accent(bool isDark) => appAccentColor(isDark);

/// Nền nhạt ánh màu nhấn cho ô icon / khối nổi bật.
Color _accentTint(bool isDark) => isDark
    ? AppColors.sky.withValues(alpha: 0.14)
    : AppColors.blue.withValues(alpha: 0.07);

/// Ô vuông bo góc chứa icon — dùng chung cho mọi icon trên trang.
class _IconTile extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final double size;
  const _IconTile(this.icon, {required this.isDark, this.size = 44});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: _accentTint(isDark),
      borderRadius: BorderRadius.circular(size * 0.3),
    ),
    child: Icon(icon, color: _accent(isDark), size: size * 0.5),
  );
}

class GiftPage extends StatelessWidget {
  const GiftPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          const AppTabHeader(title: 'Quà tặng & Ưu đãi'),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _HeroCard(isDark: isDark),
                const SizedBox(height: 14),
                _DiscountCard(isDark: isDark),
                const AppSectionTitle('Quà tặng khi mua'),
                _GiftGrid(isDark: isDark),
                const AppSectionTitle('Hướng dẫn dán tranh'),
                for (final (i, v) in kInstallVideos.indexed) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _VideoCard(
                    isDark: isDark,
                    videoId: v.id,
                    title: v.title,
                    subtitle: v.subtitle,
                  ),
                ],
                const AppSectionTitle('Cam kết chất lượng'),
                _TrustRow(isDark: isDark),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final bool isDark;
  const _HeroCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: appSoftShadow(isDark),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _accentTint(isDark),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'ƯU ĐÃI ĐẶC BIỆT',
                    style: TextStyle(
                      color: _accent(isDark),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Quà tặng hấp dẫn',
                  style: TextStyle(
                    fontSize: 24,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    color: appTextColor(isDark),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Áp dụng cho mọi đơn tranh bể cá',
                  style: TextStyle(fontSize: 13, color: appMutedColor(isDark)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          _IconTile(PhosphorIconsRegular.gift, isDark: isDark, size: 72),
        ],
      ),
    );
  }
}

class _DiscountCard extends StatelessWidget {
  final bool isDark;
  const _DiscountCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: appSoftShadow(isDark),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _accentTint(isDark),
              borderRadius: BorderRadius.circular(72 * 0.3),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'GIẢM',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                    color: _accent(isDark),
                  ),
                ),
                Text(
                  '10%',
                  style: TextStyle(
                    fontSize: 22,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    color: _accent(isDark),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Khi đặt cả bộ lưng + đáy',
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                    color: appTextColor(isDark),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Đặt tranh đồng bộ mặt lưng và mặt đáy bể để nhận ưu đãi.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: appMutedColor(isDark),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Vẽ 1 icon với kích thước và màu cho trước.
typedef _IconBuilder = Widget Function(double size, Color color);

_IconBuilder _duotone(DuotoneGlyph g) =>
    (size, color) => DuotoneIcon(g, size: size, color: color);

/// Icon quà tặng (duotone) trong ô 44px. 2 icon = ghép chồng chéo:
/// icon đầu lớn ở góc trên trái, icon sau nhỏ hơn ở góc dưới phải
/// (vd: dao rọc giấy + thẻ gạt = bộ dụng cụ dán).
class _GiftIcon extends StatelessWidget {
  final List<_IconBuilder> glyphs;
  final bool isDark;
  const _GiftIcon(this.glyphs, {required this.isDark});

  @override
  Widget build(BuildContext context) {
    final color = _accent(isDark);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: _accentTint(isDark),
        borderRadius: BorderRadius.circular(44 * 0.3),
      ),
      alignment: Alignment.center,
      child: glyphs.length == 1
          ? glyphs.first(24, color)
          : SizedBox(
              width: 30,
              height: 30,
              child: Stack(
                children: [
                  Positioned(left: 0, top: 0, child: glyphs[0](23, color)),
                  Positioned(right: 0, bottom: 0, child: glyphs[1](17, color)),
                ],
              ),
            ),
    );
  }
}

class _GiftGrid extends StatelessWidget {
  final bool isDark;
  const _GiftGrid({required this.isDark});

  static final _gifts = [
    (
      [
        (size, color) => BoxCutterIcon(size: size, color: color),
        _duotone(PhosphorIconsDuotone.creditCard),
      ],
      'Bộ dụng cụ dán',
      'Đủ dụng cụ để dán tranh gọn gàng',
    ),
    (
      [_duotone(PhosphorIconsDuotone.sticker)],
      'Sticker không trêu cá',
      'Nhắc mọi người không chọc phá cá',
    ),
    (
      [_duotone(PhosphorIconsDuotone.fish)],
      'Móc khóa mica cá koi',
      'In hình cá koi may mắn, tài lộc',
    ),
    (
      [_duotone(PhosphorIconsDuotone.truck)],
      'Miễn phí vận chuyển',
      'Giao hàng toàn quốc',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardColor;
    Widget tile(int i) {
      final g = _gifts[i];
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: appSoftShadow(isDark),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GiftIcon(g.$1, isDark: isDark),
            const SizedBox(height: 10),
            Text(
              g.$2,
              style: TextStyle(
                fontSize: 14,
                height: 1.3,
                fontWeight: FontWeight.w700,
                color: appTextColor(isDark),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              g.$3,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: appMutedColor(isDark),
              ),
            ),
          ],
        ),
      );
    }

    // 2 cột, các ô cùng hàng cao bằng nhau
    return Column(
      children: [
        for (var row = 0; row < _gifts.length; row += 2) ...[
          if (row > 0) const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: tile(row)),
                const SizedBox(width: 12),
                Expanded(child: tile(row + 1)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _VideoCard extends StatelessWidget {
  final bool isDark;
  final String videoId;
  final String title;
  final String subtitle;
  const _VideoCard({
    required this.isDark,
    required this.videoId,
    required this.title,
    required this.subtitle,
  });

  // Nền dự phòng khi chưa tải được ảnh (mất mạng)
  static const _fallback = Color(0xFF1E3A8A);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: appSoftShadow(isDark),
      ),
      child: Material(
        color: _fallback,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openInstallVideo(context, videoId),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Ảnh thumbnail thật của video; hqdefault là 4:3 có viền đen,
                // cắt về 16:9 bằng BoxFit.cover để bỏ viền.
                CachedNetworkImage(
                  imageUrl: installVideoThumb(videoId),
                  fit: BoxFit.cover,
                  fadeInDuration: const Duration(milliseconds: 200),
                  placeholder: (_, _) => const ColoredBox(color: _fallback),
                  errorWidget: (_, _, _) => const ColoredBox(color: _fallback),
                ),
                // Lớp tối dần phía dưới để chữ trắng luôn đọc được
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.35, 1],
                      colors: [Color(0x00000000), Color(0xCC000000)],
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    // Lệch phải một chút để tam giác play trông cân giữa
                    padding: const EdgeInsets.only(left: 3),
                    child: const Icon(
                      PhosphorIconsFill.play,
                      color: AppColors.blue,
                      size: 26,
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'VIDEO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 14,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Row(
                        children: [
                          Text(
                            'Xem ngay',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            PhosphorIconsRegular.arrowRight,
                            color: Colors.white,
                            size: 14,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrustRow extends StatelessWidget {
  final bool isDark;
  const _TrustRow({required this.isDark});

  static const _badges = [
    (PhosphorIconsRegular.shieldCheck, 'Decal 4 lớp 3M', 'Chống trầy, bay màu'),
    (PhosphorIconsRegular.ruler, 'Đo cắt chuẩn', 'Vừa khít từng milimet'),
    (PhosphorIconsRegular.truck, 'Đóng gói trong ống PVC', 'Không gãy nếp'),
  ];

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardColor;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < _badges.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: appSoftShadow(isDark),
                ),
                child: Column(
                  children: [
                    Icon(_badges[i].$1, size: 22, color: _accent(isDark)),
                    const SizedBox(height: 6),
                    Text(
                      _badges[i].$2,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: appTextColor(isDark),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _badges[i].$3,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: appMutedColor(isDark),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

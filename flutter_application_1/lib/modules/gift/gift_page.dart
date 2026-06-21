import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const _kDanTrongUrl = 'https://youtu.be/HPMifAo5sWI';
const _kDanNgoaiUrl = 'https://youtu.be/1JOcMpJ9o8o';

class GiftPage extends StatelessWidget {
  const GiftPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 0,
            floating: false,
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
                  'Quà Tặng & Ưu Đãi',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMainBanner(),
                const SizedBox(height: 24),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    'Quà Tặng Khi Mua',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                _buildGiftItem(
                  icon: Icons.build_rounded,
                  color: const Color(0xFF667EEA),
                  title: 'Bộ dụng cụ dán',
                  description:
                      'Tặng kèm đầy đủ dụng cụ hỗ trợ dán tranh gọn gàng, chuyên nghiệp.',
                ),
                _buildGiftItem(
                  icon: Icons.do_not_touch_rounded,
                  color: const Color(0xFFFF9800),
                  title: 'Sticker cảnh báo không trêu cá',
                  description:
                      'Sticker ngộ nghĩnh dán bên ngoài bể, nhắc nhở mọi người không chọc phá cá cưng.',
                ),
                _buildGiftItem(
                  icon: Icons.percent_rounded,
                  color: const Color(0xFF11998E),
                  title: 'Ưu đãi lên đến 10% khi đặt cả bộ lưng + đáy',
                  description:
                      'Đặt tranh đồng bộ cả mặt lưng và mặt đáy bể — nhận ngay ưu đãi giảm giá 10%.',
                ),
                _buildGiftItem(
                  icon: Icons.key_rounded,
                  color: const Color(0xFFE91E8C),
                  title: 'Móc chìa khóa mica ảnh cá koi may mắn',
                  description:
                      'Móc chìa khóa mica in hình cá koi độc đáo — mang lại may mắn và tài lộc.',
                ),
                _buildGiftItem(
                  icon: Icons.local_shipping_rounded,
                  color: const Color(0xFF43A047),
                  title: 'Miễn phí vận chuyển',
                  description:
                      'Giao hàng miễn phí toàn quốc cho mọi đơn hàng tranh bể cá.',
                ),
                const SizedBox(height: 24),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    'Hướng Dẫn Dán Tranh',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                _buildGuideCard(
                  context: context,
                  icon: Icons.water_rounded,
                  color: const Color(0xFF2196F3),
                  title: 'Hướng dẫn dán tranh trong bể',
                  subtitle: 'Cách dán tranh đáy và lưng bể bên trong (ngập nước)',
                  url: _kDanTrongUrl,
                ),
                _buildGuideCard(
                  context: context,
                  icon: Icons.home_work_rounded,
                  color: const Color(0xFF9C27B0),
                  title: 'Hướng dẫn dán tranh ngoài bể',
                  subtitle: 'Cách dán tranh mặt ngoài kính bể (không tiếp nước)',
                  url: _kDanNgoaiUrl,
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF6B6B), Color(0xFFFF4081)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B6B).withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'ƯU ĐÃI ĐẶC BIỆT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Quà Tặng\nHấp Dẫn 🎁',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '• Tặng bộ dụng cụ dán\n'
                  '• Sticker cảnh báo không trêu cá\n'
                  '• Móc chìa khóa mica cá koi may mắn\n'
                  '• Ưu đãi lên đến 10% khi đặt cả bộ lưng + đáy\n'
                  '• Miễn phí vận chuyển',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.card_giftcard_rounded,
            size: 90,
            color: Colors.white30,
          ),
        ],
      ),
    );
  }

  Widget _buildGiftItem({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1B3A4B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideCard({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String url,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF1B3A4B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_circle_rounded, color: color, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Xem',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

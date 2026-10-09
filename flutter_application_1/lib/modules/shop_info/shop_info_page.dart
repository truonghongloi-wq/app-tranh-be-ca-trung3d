import '../../widgets/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../widgets/app_ui.dart';

// ─────────────────────────────────────────────────────────────
// NỘI DUNG THÔNG TIN SHOP — sửa trực tiếp tại đây.
// Ô nào để trống ('') sẽ tự ẩn trên app.
// ─────────────────────────────────────────────────────────────
class ShopInfo {
  static const name = 'Tranh Bể Cá 3D';
  static const slogan = 'Tranh nền 3D in theo kích thước bể của bạn';

  static const hotline = '0944908880'; // gọi điện
  static const zalo = '0888196789'; // số điện thoại Zalo
  static const facebook = ''; // vd: 'https://facebook.com/tranhbeca'
  static const email = 'tranhbeca2018@gmail.com';
  static const address = ''; // địa chỉ cửa hàng / xưởng
  static const privacyPolicyUrl =
      'https://apptranhbeca.web.app/privacy-policy.html';

  static const intro = [
    'Tranh Bể Cá 3D chuyên thiết kế và in tranh nền 3D trang trí bể cá: '
        'tranh mặt lưng, mặt đáy và hai mặt hông, giúp bể cá trông sâu và sống '
        'động như một thủy cung thu nhỏ.',
    'Mỗi bức tranh được in riêng theo đúng kích thước bể của khách, trên '
        'chất liệu chống nước, bền màu. Khách có thể chọn dán trong bể hoặc '
        'dán ngoài mặt kính tùy nhu cầu.',
    'Ngay trên ứng dụng, bạn có thể xem hàng trăm mẫu tranh theo chủ đề, tìm '
        'mẫu bằng hình ảnh, ghép thử tranh vào ảnh bể cá thật bằng AI, tự tính '
        'giá theo kích thước và đặt hàng chỉ trong vài bước.',
  ];

  static const highlights = [
    (PhosphorIconsRegular.ruler, 'In theo kích thước riêng của từng bể'),
    (PhosphorIconsRegular.drop, 'Chất liệu chống nước, bền màu'),
    (PhosphorIconsRegular.images, 'Kho mẫu đa dạng, cập nhật thường xuyên'),
    (PhosphorIconsRegular.truck, 'Giao hàng toàn quốc'),
    (PhosphorIconsRegular.headset, 'Hướng dẫn dán tranh và hỗ trợ tận tình'),
  ];

  // TODO: chủ shop đọc lại và chỉnh các con số (số ngày, thời gian bảo hành...)
  // cho đúng thực tế trước khi phát hành.
  static const policies = [
    (
      PhosphorIconsRegular.shoppingBag,
      'Đặt hàng & thanh toán',
      [
        'Khách chọn mẫu tranh, nhập kích thước bể, chọn các mặt in và chất '
            'liệu rồi đặt hàng ngay trên ứng dụng. Giá được tính tự động theo '
            'diện tích (m²).',
        'Sau khi nhận đơn, shop sẽ gọi điện hoặc nhắn Zalo để xác nhận lại '
            'kích thước, mẫu tranh và hình thức thanh toán.',
        'Shop chỉ tiến hành in sau khi đơn đã được xác nhận với khách.',
      ],
    ),
    (
      PhosphorIconsRegular.truck,
      'Vận chuyển & giao hàng',
      [
        'Giao hàng toàn quốc qua đơn vị vận chuyển. Phí vận chuyển được thông '
            'báo khi xác nhận đơn.',
        'Thời gian in và đóng gói thường từ 1–2 ngày sau khi xác nhận đơn.',
        'Thời gian giao hàng tùy khu vực, thường từ 3–4 ngày.',
        'Tranh được cuộn và đóng gói cẩn thận để tránh gãy, nhăn khi vận '
            'chuyển. Khách theo dõi tình trạng đơn tại mục Cá nhân → Đơn mua.',
      ],
    ),
    (
      PhosphorIconsRegular.xCircle,
      'Hủy đơn hàng',
      [
        'Khách có thể tự hủy đơn trong ứng dụng khi đơn còn ở trạng thái '
            '"Chờ xác nhận".',
        'Khi shop đã xác nhận, tranh được đưa vào in theo kích thước riêng '
            'nên không thể hủy trên ứng dụng. Vui lòng liên hệ shop để được '
            'hỗ trợ.',
      ],
    ),
    (
      PhosphorIconsRegular.arrowsLeftRight,
      'Đổi trả',
      [
        'Vì tranh được in riêng theo kích thước của từng khách, shop không '
            'nhận đổi trả với lý do không còn nhu cầu hoặc khách nhập sai '
            'kích thước.',
        'Shop in lại miễn phí nếu tranh bị lỗi in, sai mẫu, sai kích thước so '
            'với đơn đã xác nhận, hoặc bị hư hỏng trong quá trình vận chuyển.',
        'Vui lòng báo cho shop trong vòng 3 ngày kể từ khi nhận hàng, kèm '
            'hình ảnh hoặc video mở hàng để được hỗ trợ nhanh nhất.',
      ],
    ),
    (
      PhosphorIconsRegular.shieldCheck,
      'Bảo hành',
      [
        'Tranh được bảo hành phai màu, bong tróc lớp in trong điều kiện sử '
            'dụng bình thường.',
        'Không bảo hành với các trường hợp: tranh bị rách, trầy xước do tác '
            'động bên ngoài, hoặc dán sai cách so với hướng dẫn.',
        'Xem video hướng dẫn dán trong bể và ngoài bể ngay trong mục đơn hàng '
            'đã đặt.',
      ],
    ),
    (
      PhosphorIconsRegular.lock,
      'Bảo mật thông tin',
      [
        'Thông tin cá nhân (họ tên, số điện thoại, địa chỉ) chỉ dùng để xử '
            'lý và giao đơn hàng, không chia sẻ cho bên thứ ba ngoài đơn vị '
            'vận chuyển.',
        'Khách có thể xóa tài khoản bất kỳ lúc nào tại mục Cá nhân → Xóa '
            'tài khoản.',
      ],
    ),
  ];
}

/// Trang thông tin shop: Thông tin liên hệ · Giới thiệu · Chính sách.
class ShopInfoPage extends StatelessWidget {
  final int initialTab;
  const ShopInfoPage({super.key, this.initialTab = 0});

  @override
  Widget build(BuildContext context) {
    final isDark = appIsDark(context);
    return DefaultTabController(
      length: 3,
      initialIndex: initialTab,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0.5,
          toolbarHeight: 60,
          backgroundColor: Theme.of(context).cardColor,
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: false,
          leading: const AppBackButton(),
          leadingWidth: 56,
          titleSpacing: 8,
          title: Text(
            'Về shop',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: appTextColor(isDark),
            ),
          ),
          bottom: TabBar(
            labelColor: appAccentColor(isDark),
            unselectedLabelColor: appMutedColor(isDark),
            indicatorColor: appAccentColor(isDark),
            labelStyle: const TextStyle(fontWeight: FontWeight.w700),
            tabs: const [
              Tab(text: 'Thông tin'),
              Tab(text: 'Giới thiệu'),
              Tab(text: 'Chính sách'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_ContactTab(), _IntroTab(), _PolicyTab()],
        ),
      ),
    );
  }
}

Future<void> _open(BuildContext context, Uri uri) async {
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Không mở được liên kết.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _ShopHeader extends StatelessWidget {
  const _ShopHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.sky, AppColors.blue],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/icons/trung_logo.png',
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ShopInfo.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  ShopInfo.slogan,
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactTab extends StatelessWidget {
  const _ContactTab();

  @override
  Widget build(BuildContext context) {
    final isDark = appIsDark(context);
    final rows = <Widget>[
      if (ShopInfo.hotline.isNotEmpty)
        _InfoTile(
          icon: PhosphorIconsRegular.phone,
          color: appAccentColor(isDark),
          label: 'Hotline',
          value: ShopInfo.hotline,
          onTap: () => _open(context, Uri.parse('tel:${ShopInfo.hotline}')),
        ),
      if (ShopInfo.zalo.isNotEmpty)
        _InfoTile(
          icon: PhosphorIconsRegular.chatCircle,
          color: appAccentColor(isDark),
          label: 'Zalo',
          value: ShopInfo.zalo,
          onTap: () =>
              _open(context, Uri.parse('https://zalo.me/${ShopInfo.zalo}')),
        ),
      if (ShopInfo.facebook.isNotEmpty)
        _InfoTile(
          icon: PhosphorIconsRegular.facebookLogo,
          color: appAccentColor(isDark),
          label: 'Facebook',
          value: ShopInfo.facebook.replaceFirst(RegExp(r'^https?://'), ''),
          onTap: () => _open(context, Uri.parse(ShopInfo.facebook)),
        ),
      if (ShopInfo.email.isNotEmpty)
        _InfoTile(
          icon: PhosphorIconsRegular.envelopeSimple,
          color: appAccentColor(isDark),
          label: 'Email',
          value: ShopInfo.email,
          onTap: () => _open(context, Uri.parse('mailto:${ShopInfo.email}')),
        ),
      if (ShopInfo.address.isNotEmpty)
        _InfoTile(
          icon: PhosphorIconsRegular.mapPin,
          color: appAccentColor(isDark),
          label: 'Địa chỉ',
          value: ShopInfo.address,
          onTap: () => _open(
            context,
            Uri.https('www.google.com', '/maps/search/', {
              'api': '1',
              'query': ShopInfo.address,
            }),
          ),
        ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        const _ShopHeader(),
        const AppSectionTitle('Liên hệ'),
        Container(
          decoration: appCardDecoration(context),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      indent: 68,
                      color: isDark
                          ? Colors.white12
                          : AppColors.blue.withValues(alpha: 0.08),
                    ),
                  rows[i],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _InfoTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = appIsDark(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.18 : 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: appMutedColor(isDark),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: appTextColor(isDark),
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                PhosphorIconsRegular.caretRight,
                color: appMutedColor(isDark),
              ),
          ],
        ),
      ),
    );
  }
}

class _IntroTab extends StatelessWidget {
  const _IntroTab();

  @override
  Widget build(BuildContext context) {
    final isDark = appIsDark(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        const _ShopHeader(),
        const AppSectionTitle('Về chúng tôi'),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: appCardDecoration(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < ShopInfo.intro.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                Text(
                  ShopInfo.intro[i],
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.55,
                    color: appTextColor(isDark),
                  ),
                ),
              ],
            ],
          ),
        ),
        const AppSectionTitle('Vì sao chọn chúng tôi'),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: appCardDecoration(context),
          child: Column(
            children: [
              for (final (icon, text) in ShopInfo.highlights)
                ListTile(
                  leading: Icon(icon, color: appAccentColor(isDark)),
                  title: Text(
                    text,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: appTextColor(isDark),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PolicyTab extends StatelessWidget {
  const _PolicyTab();

  @override
  Widget build(BuildContext context) {
    final isDark = appIsDark(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        for (final (icon, title, items) in ShopInfo.policies)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              decoration: appCardDecoration(context),
              clipBehavior: Clip.antiAlias,
              child: Theme(
                // Bỏ đường kẻ mặc định của ExpansionTile
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  leading: Icon(icon, color: appAccentColor(isDark)),
                  title: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: appTextColor(isDark),
                    ),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final item in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 7, right: 10),
                              child: Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: appAccentColor(isDark),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                item,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                  color: appTextColor(isDark),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 4),
        Center(
          child: TextButton.icon(
            onPressed: () =>
                _open(context, Uri.parse(ShopInfo.privacyPolicyUrl)),
            icon: const Icon(PhosphorIconsRegular.arrowSquareOut, size: 18),
            label: const Text('Xem đầy đủ Chính sách bảo mật'),
          ),
        ),
      ],
    );
  }
}

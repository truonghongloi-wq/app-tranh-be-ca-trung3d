import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/auth_service.dart';
import '../../services/avatar_service.dart';
import '../../services/theme_store.dart';
import '../../services/user_service.dart';
import '../../services/order_notification_service.dart';
import '../admin/admin_dashboard_page.dart';
import '../admin/admin_orders_page.dart';
import '../order/my_orders_page.dart';
import '../order/order_store.dart';
import '../order/order_widgets.dart';
import '../shop_info/shop_info_page.dart';
import '../../widgets/app_ui.dart';
import '../product_detail/product_detail_page.dart';
import 'favorite_store.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName ?? 'Khách';
    final email = user?.email ?? '';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          const AppTabHeader(title: 'Cá nhân'),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildUserCard(context, name, email, isDark),
                  const _MyOrdersSection(),
                  ValueListenableBuilder<List<FavoriteItem>>(
                    valueListenable: FavoriteStore.favorites,
                    builder: (context, favorites, _) =>
                        _buildFavSection(context, favorites, isDark),
                  ),
                  const AppSectionTitle('Về shop'),
                  _buildShopCard(context, isDark),
                  const AppSectionTitle('Cài đặt'),
                  FutureBuilder<bool>(
                    future: UserService.isCurrentUserAdmin(),
                    builder: (context, snap) => _buildSettingsCard(
                      context,
                      isDark,
                      isAdmin: snap.data ?? false,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(
    BuildContext context,
    String name,
    String email,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: appCardDecoration(context, radius: 20),
      child: Row(
        children: [
          _AvatarEditor(name: name),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: appTextColor(isDark),
                  ),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: appMutedColor(isDark),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavSection(
    BuildContext context,
    List<FavoriteItem> favorites,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionTitle(
          'Tranh yêu thích',
          trailing: AppHint('${favorites.length} tranh'),
        ),
        if (favorites.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: appCardDecoration(context),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.sky.withValues(alpha: 0.12)
                        : AppColors.blue.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    PhosphorIconsRegular.heart,
                    color: appAccentColor(isDark),
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Chưa có tranh yêu thích',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: appTextColor(isDark),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Nhấn biểu tượng trái tim trên tranh để lưu vào đây.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: appMutedColor(isDark)),
                ),
              ],
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.82,
            ),
            itemCount: favorites.length,
            itemBuilder: (_, i) => _FavoriteCard(item: favorites[i]),
          ),
      ],
    );
  }

  Widget _buildShopCard(BuildContext context, bool isDark) {
    final divider = Divider(
      height: 1,
      indent: 68,
      color: isDark ? Colors.white12 : AppColors.blue.withValues(alpha: 0.08),
    );
    void open(int tab) => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ShopInfoPage(initialTab: tab)),
    );
    return Container(
      decoration: appCardDecoration(context),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            _SettingsTile(
              icon: PhosphorIconsRegular.storefront,
              iconColor: appAccentColor(isDark),
              title: 'Thông tin & liên hệ',
              subtitle: 'Hotline, Zalo, email',
              onTap: () => open(0),
            ),
            divider,
            _SettingsTile(
              icon: PhosphorIconsRegular.info,
              iconColor: appAccentColor(isDark),
              title: 'Giới thiệu',
              subtitle: 'Về ${ShopInfo.name}',
              onTap: () => open(1),
            ),
            divider,
            _SettingsTile(
              icon: PhosphorIconsRegular.scroll,
              iconColor: appAccentColor(isDark),
              title: 'Chính sách',
              subtitle: 'Đổi trả, bảo hành, vận chuyển, bảo mật',
              onTap: () => open(2),
            ),
          ],
        ),
      ),
    );
  }

  // Một thẻ gom: chế độ tối, đăng xuất, xóa tài khoản
  Widget _buildSettingsCard(
    BuildContext context,
    bool isDark, {
    bool isAdmin = false,
  }) {
    final divider = Divider(
      height: 1,
      indent: 68,
      color: isDark ? Colors.white12 : AppColors.blue.withValues(alpha: 0.08),
    );
    return Container(
      decoration: appCardDecoration(context),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            ValueListenableBuilder<ThemeMode>(
              valueListenable: ThemeStore.mode,
              builder: (_, mode, _) {
                final dark = mode == ThemeMode.dark;
                return _SettingsTile(
                  icon: dark
                      ? PhosphorIconsRegular.moon
                      : PhosphorIconsRegular.sun,
                  iconColor: appAccentColor(isDark),
                  title: dark ? 'Chế độ tối' : 'Chế độ sáng',
                  subtitle: dark
                      ? 'Nhấn để chuyển sang sáng'
                      : 'Nhấn để chuyển sang tối',
                  onTap: ThemeStore.toggle,
                  trailing: Switch(
                    value: dark,
                    activeTrackColor: AppColors.blue,
                    onChanged: (_) => ThemeStore.toggle(),
                  ),
                );
              },
            ),
            if (isAdmin) ...[
              divider,
              _SettingsTile(
                icon: PhosphorIconsRegular.userGear,
                iconColor: appAccentColor(isDark),
                title: 'Trang quản trị',
                subtitle: 'Quản lý khách hàng và bảng giá',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
                ),
              ),
              divider,
              _SettingsTile(
                icon: PhosphorIconsRegular.truck,
                iconColor: appAccentColor(isDark),
                title: 'Quản lý đơn hàng',
                subtitle: 'Xác nhận, giao hàng, hủy đơn',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminOrdersPage()),
                ),
              ),
            ],
            divider,
            _SettingsTile(
              icon: PhosphorIconsRegular.key,
              iconColor: appAccentColor(isDark),
              title: 'Đổi mật khẩu',
              subtitle: 'Cần nhập mật khẩu hiện tại',
              onTap: () => showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (_) => const _ChangePasswordDialog(),
              ),
            ),
            divider,
            _SettingsTile(
              icon: PhosphorIconsRegular.signOut,
              iconColor: appAccentColor(isDark),
              title: 'Đăng xuất',
              onTap: () => _confirmLogout(context),
            ),
            // Tài khoản quản trị duy nhất: không cho tự xóa
            if (!isAdmin) divider,
            if (!isAdmin)
              _SettingsTile(
                icon: PhosphorIconsRegular.trash,
                iconColor: Colors.red,
                title: 'Xóa tài khoản',
                titleColor: Colors.red,
                subtitle: 'Xóa vĩnh viễn tài khoản và hồ sơ cá nhân',
                onTap: () => _showDeleteAccountDialog(context),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Đăng xuất', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await AuthService.signOut();
    }
  }

  Future<void> _showDeleteAccountDialog(BuildContext context) async {
    final passwordController = TextEditingController();
    bool obscure = true;
    bool loading = false;
    String? errorText;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              title: const Text('Xóa tài khoản'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hành động này không thể hoàn tác. Tài khoản, hồ sơ và '
                      'thông tin cá nhân của bạn sẽ bị xóa vĩnh viễn.\n\n'
                      'Riêng thông tin các đơn hàng đã đặt sẽ được giữ lại '
                      'phục vụ kế toán/bảo hành và không còn gắn với tài '
                      'khoản đăng nhập của bạn nữa.',
                      style: TextStyle(fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Nhập mật khẩu để xác nhận:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: passwordController,
                      obscureText: obscure,
                      enabled: !loading,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Mật khẩu',
                        border: const OutlineInputBorder(),
                        errorText: errorText,
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscure
                                ? PhosphorIconsRegular.eyeSlash
                                : PhosphorIconsRegular.eye,
                          ),
                          onPressed: () => setState(() => obscure = !obscure),
                        ),
                      ),
                      onSubmitted: (_) {},
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: loading
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Hủy'),
                ),
                TextButton(
                  onPressed: loading
                      ? null
                      : () async {
                          final password = passwordController.text;
                          if (password.isEmpty) {
                            setState(
                              () => errorText = 'Vui lòng nhập mật khẩu.',
                            );
                            return;
                          }
                          setState(() {
                            loading = true;
                            errorText = null;
                          });
                          final error = await AuthService.deleteAccount(
                            password: password,
                          );
                          if (error != null) {
                            setState(() {
                              loading = false;
                              errorText = error;
                            });
                            return;
                          }
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        },
                  child: loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Xóa tài khoản',
                          style: TextStyle(color: Colors.red),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static String _initials(String name) {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }
}

/// Mục "Đơn mua": lối tắt tới từng trạng thái đơn kèm số lượng.
class _MyOrdersSection extends StatefulWidget {
  const _MyOrdersSection();

  @override
  State<_MyOrdersSection> createState() => _MyOrdersSectionState();
}

class _MyOrdersSectionState extends State<_MyOrdersSection> {
  Map<String, int> _counts = const {};

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    try {
      final orders = await OrderNotificationService.loadMyOrders();
      if (!mounted) return;
      final counts = <String, int>{};
      for (final o in orders) {
        counts[o.status] = (counts[o.status] ?? 0) + 1;
      }
      setState(() => _counts = counts);
    } catch (_) {
      // Không chặn trang cá nhân nếu mạng lỗi; chỉ ẩn số đếm.
    }
  }

  Future<void> _open(String status) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MyOrdersPage(initialStatus: status)),
    );
    _loadCounts();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = appIsDark(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionTitle(
          'Đơn mua',
          trailing: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _open(OrderStatus.daGiao),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Xem lịch sử mua hàng',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: appAccentColor(isDark),
                    ),
                  ),
                  Icon(
                    PhosphorIconsRegular.caretRight,
                    size: 18,
                    color: appAccentColor(isDark),
                  ),
                ],
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          decoration: appCardDecoration(context),
          child: Row(
            children: [
              for (final s in OrderStatus.all)
                Expanded(child: _statusButton(s, isDark)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statusButton(String status, bool isDark) {
    final count = _counts[status] ?? 0;
    // Chỉ hiện chấm đỏ cho các đơn đang xử lý
    final showBadge =
        count > 0 &&
        status != OrderStatus.daGiao &&
        status != OrderStatus.daHuy;
    final color = appAccentColor(isDark);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _open(status),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isDark ? 0.18 : 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(orderStatusIcon(status), color: color, size: 24),
                ),
                if (showBadge)
                  Positioned(
                    top: -6,
                    right: -8,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 20),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Theme.of(context).cardColor,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              myOrderTabLabel(status),
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: appTextColor(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Color? titleColor;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
    this.titleColor,
    this.subtitle,
    this.trailing,
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
                color: iconColor.withValues(alpha: isDark ? 0.18 : 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: titleColor ?? appTextColor(isDark),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        color: appMutedColor(isDark),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            trailing ??
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

class _FavoriteCard extends StatelessWidget {
  final FavoriteItem item;
  const _FavoriteCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final isDark = appIsDark(context);
    return Container(
      decoration: appCardDecoration(context),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductDetailPage(
                imageId: item.id,
                imageUrl: item.url,
                pricePerM2: 300000,
                initialSize: '60x30',
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: item.url,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => Container(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFEFF6FF),
                        child: const Icon(
                          PhosphorIconsRegular.imageBroken,
                          color: AppColors.blue,
                          size: 36,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        color: isDark
                            ? Colors.black54
                            : Colors.white.withValues(alpha: 0.92),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => FavoriteStore.toggle(item),
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(
                              PhosphorIconsFill.heart,
                              color: Colors.red,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Text(
                  item.id,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: appTextColor(isDark),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarEditor extends StatefulWidget {
  final String name;
  const _AvatarEditor({required this.name});

  @override
  State<_AvatarEditor> createState() => _AvatarEditorState();
}

class _AvatarEditorState extends State<_AvatarEditor> {
  bool _busy = false;

  Future<void> _run(Future<String?> Function() action) async {
    setState(() => _busy = true);
    final error = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  void _openSheet(bool hasPhoto) {
    final isDark = appIsDark(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        Widget option(
          IconData icon,
          String label,
          Color color,
          VoidCallback onTap,
        ) {
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.18 : 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            title: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: color == Colors.red ? Colors.red : appTextColor(isDark),
              ),
            ),
            onTap: () {
              Navigator.pop(sheetContext);
              onTap();
            },
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Ảnh đại diện',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: appTextColor(isDark),
                  ),
                ),
                const SizedBox(height: 8),
                option(
                  PhosphorIconsRegular.camera,
                  'Chụp ảnh',
                  appAccentColor(isDark),
                  () => _run(
                    () => AvatarService.pickAndUpload(ImageSource.camera),
                  ),
                ),
                option(
                  PhosphorIconsRegular.images,
                  'Chọn từ thư viện',
                  appAccentColor(isDark),
                  () => _run(
                    () => AvatarService.pickAndUpload(ImageSource.gallery),
                  ),
                ),
                if (hasPhoto)
                  option(
                    PhosphorIconsRegular.trash,
                    'Xóa ảnh đại diện',
                    Colors.red,
                    () => _run(AvatarService.remove),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        final photoUrl = snapshot.data?.photoURL;
        final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
        final initials = Text(
          ProfilePage._initials(widget.name),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        );
        return GestureDetector(
          onTap: _busy || snapshot.data == null
              ? null
              : () => _openSheet(hasPhoto),
          child: SizedBox(
            width: 68,
            height: 68,
            child: Stack(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.sky, AppColors.blue],
                    ),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.blue.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  alignment: Alignment.center,
                  child: _busy
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : hasPhoto
                      ? CachedNetworkImage(
                          imageUrl: photoUrl,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => initials,
                        )
                      : initials,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: AppColors.blue,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).cardColor,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      PhosphorIconsRegular.camera,
                      color: Colors.white,
                      size: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Hộp thoại đổi mật khẩu: mật khẩu hiện tại + mật khẩu mới + nhập lại.
class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final error = await AuthService.changePassword(
      currentPassword: _currentCtrl.text,
      newPassword: _newCtrl.text,
    );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _loading = false;
        _error = error;
      });
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Đã đổi mật khẩu thành công.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    String? Function(String?) validator, {
    bool autofocus = false,
  }) {
    return TextFormField(
      controller: ctrl,
      obscureText: _obscure,
      enabled: !_loading,
      autofocus: autofocus,
      autocorrect: false,
      enableSuggestions: false,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Đổi mật khẩu'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(
                _currentCtrl,
                'Mật khẩu hiện tại',
                (v) => (v ?? '').isEmpty
                    ? 'Vui lòng nhập mật khẩu hiện tại.'
                    : null,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              _field(_newCtrl, 'Mật khẩu mới', (v) {
                final value = v ?? '';
                if (value.length < 6) return 'Mật khẩu ít nhất 6 ký tự.';
                if (value == _currentCtrl.text) {
                  return 'Mật khẩu mới phải khác mật khẩu hiện tại.';
                }
                return null;
              }),
              const SizedBox(height: 12),
              _field(
                _confirmCtrl,
                'Nhập lại mật khẩu mới',
                (v) =>
                    v != _newCtrl.text ? 'Mật khẩu nhập lại không khớp.' : null,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? PhosphorIconsRegular.eye
                        : PhosphorIconsRegular.eyeSlash,
                    size: 18,
                  ),
                  label: Text(_obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu'),
                ),
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Đổi mật khẩu'),
        ),
      ],
    );
  }
}

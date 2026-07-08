import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/auth_service.dart';
import '../../services/theme_store.dart';
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
                  'Cá Nhân',
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
                _buildUserCard(name, email, theme),
                _buildDarkModeToggle(context, isDark, theme),
                ValueListenableBuilder<List<FavoriteItem>>(
                  valueListenable: FavoriteStore.favorites,
                  builder: (context, favorites, _) => _buildFavSection(
                    context,
                    favorites,
                    theme,
                  ),
                ),
                _buildDeleteAccountSection(context, theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteAccountSection(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 30),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
        title: const Text(
          'Xóa tài khoản',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red),
        ),
        subtitle: const Text(
          'Xóa vĩnh viễn tài khoản và hồ sơ cá nhân',
          style: TextStyle(fontSize: 12),
        ),
        onTap: () => _showDeleteAccountDialog(context),
      ),
    );
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
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
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
                  onPressed:
                      loading ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Hủy'),
                ),
                TextButton(
                  onPressed: loading
                      ? null
                      : () async {
                          final password = passwordController.text;
                          if (password.isEmpty) {
                            setState(() => errorText = 'Vui lòng nhập mật khẩu.');
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

  Widget _buildUserCard(String name, String email, ThemeData theme) {
    final initials = _initials(name);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF5CC1FF), Color(0xFF2B678B)],
              ),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.brightness == Brightness.dark
                        ? Colors.white
                        : const Color(0xFF1B3A4B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.brightness == Brightness.dark
                        ? Colors.white60
                        : Colors.black54,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDarkModeToggle(
      BuildContext context, bool isDark, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: ThemeStore.mode,
        builder: (_, mode, _) {
          final dark = mode == ThemeMode.dark;
          return SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: Icon(
              dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              color: dark ? const Color(0xFF5CC1FF) : const Color(0xFFFFB74D),
              size: 26,
            ),
            title: Text(
              dark ? 'Chế độ tối' : 'Chế độ sáng',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: theme.brightness == Brightness.dark
                    ? Colors.white
                    : const Color(0xFF1B3A4B),
              ),
            ),
            subtitle: Text(
              dark ? 'Nhấn để chuyển sang sáng' : 'Nhấn để chuyển sang tối',
              style: TextStyle(
                fontSize: 12,
                color: theme.brightness == Brightness.dark
                    ? Colors.white54
                    : Colors.black45,
              ),
            ),
            value: dark,
            activeTrackColor: const Color(0xFF5CC1FF).withValues(alpha: 0.4),
            activeThumbColor: const Color(0xFF5CC1FF),
            onChanged: (_) => ThemeStore.toggle(),
          );
        },
      ),
    );
  }

  Widget _buildFavSection(
      BuildContext context, List<FavoriteItem> favorites, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Row(
            children: [
              const Icon(
                Icons.favorite_rounded,
                color: Colors.red,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Tranh Yêu Thích (${favorites.length})',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
        if (favorites.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.favorite_border_rounded,
                    size: 64,
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Chưa có tranh yêu thích.\nNhấn ♥ trên tranh để lưu vào đây.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black45,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.78,
            ),
            itemCount: favorites.length,
            itemBuilder: (_, i) => _FavoriteCard(item: favorites[i]),
          ),
      ],
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

class _FavoriteCard extends StatelessWidget {
  final FavoriteItem item;
  const _FavoriteCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
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
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 10,
              offset: const Offset(0, 4),
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
                      errorWidget: (_, _, _) => Container(
                        color: theme.brightness == Brightness.dark
                            ? const Color(0xFF1A2A35)
                            : const Color(0xFFE3F2FD),
                        child: const Icon(
                          Icons.broken_image,
                          color: Color(0xFF2B678B),
                          size: 36,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => FavoriteStore.toggle(item),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: theme.brightness == Brightness.dark
                                ? Colors.black54
                                : Colors.white.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.favorite_rounded,
                            color: Colors.red,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Text(
                item.id,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: theme.brightness == Brightness.dark
                      ? Colors.white70
                      : const Color(0xFF1B3A4B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

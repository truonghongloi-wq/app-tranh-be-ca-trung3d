import 'app_icons.dart';
import 'package:flutter/material.dart';

/// Bảng màu chung của app (theo thiết kế Stitch, màu chủ đạo #2563EB).
class AppColors {
  static const blue = Color(0xFF2563EB);
  static const sky = Color(0xFF5CC1FF);
  static const ink = Color(0xFF1E293B);
  static const muted = Color(0xFF64748B);
  static const coral = Color(0xFFFF6B4A);
  static const coralDark = Color(0xFFB23418);
  static const success = Color(0xFF22C55E);
}

bool appIsDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

Color appTextColor(bool isDark) => isDark ? Colors.white : AppColors.ink;
Color appMutedColor(bool isDark) => isDark ? Colors.white60 : AppColors.muted;
Color appAccentColor(bool isDark) => isDark ? AppColors.sky : AppColors.blue;

/// Bóng đổ nhẹ ánh xanh cho thẻ trắng; tắt ở chế độ tối.
List<BoxShadow> appSoftShadow(bool isDark) => isDark
    ? const []
    : [
        BoxShadow(
          color: AppColors.blue.withValues(alpha: 0.07),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ];

/// Thẻ trắng bo góc dùng chung.
BoxDecoration appCardDecoration(BuildContext context, {double radius = 18}) =>
    BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: appSoftShadow(appIsDark(context)),
    );

/// Đầu trang trắng của các tab (Sản phẩm, Quà tặng, Cá nhân).
class AppTabHeader extends StatelessWidget {
  final String title;
  final List<Widget>? actions;
  const AppTabHeader({super.key, required this.title, this.actions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      toolbarHeight: 64,
      backgroundColor: theme.cardColor,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      title: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: appIsDark(context) ? Colors.white : Colors.black,
        ),
      ),
      actions: actions,
    );
  }
}

/// Tiêu đề mục: luôn 1 dòng, có thể kèm chữ phụ bên phải.
class AppSectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  const AppSectionTitle(
    this.title, {
    super.key,
    this.trailing,
    this.padding = const EdgeInsets.only(top: 28, bottom: 12),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: appTextColor(appIsDark(context)),
                ),
              ),
            ),
          ),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

/// Chữ phụ nhỏ màu xám (vd: "5 chủ đề").
class AppHint extends StatelessWidget {
  final String text;
  const AppHint(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(fontSize: 12, color: appMutedColor(appIsDark(context))),
  );
}

/// Nút quay lại tròn cho màn hình con.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = appIsDark(context);
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Center(
        child: Material(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFF1F5F9),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => Navigator.maybePop(context),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(
                PhosphorIconsRegular.caretLeft,
                size: 18,
                color: appTextColor(isDark),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

TextStyle _subTitleStyle(BuildContext context) => TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.w700,
  color: appIsDark(context) ? Colors.white : Colors.black,
);

/// Đầu trang trắng cho màn hình con (dạng sliver, trong CustomScrollView).
class AppSubHeader extends StatelessWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBack;
  const AppSubHeader({
    super.key,
    required this.title,
    this.actions,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      toolbarHeight: 60,
      backgroundColor: Theme.of(context).cardColor,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      leading: showBack ? const AppBackButton() : null,
      leadingWidth: showBack ? 56 : null,
      titleSpacing: showBack ? 8 : 16,
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _subTitleStyle(context),
      ),
      iconTheme: IconThemeData(color: appTextColor(appIsDark(context))),
      actions: actions,
    );
  }
}

/// Đầu trang trắng cho màn hình con (dùng ở Scaffold.appBar).
PreferredSizeWidget appSubAppBar(
  BuildContext context,
  String title, {
  List<Widget>? actions,
  bool showBack = true,
  bool centerTitle = false,
}) {
  return AppBar(
    elevation: 0,
    scrolledUnderElevation: 0.5,
    toolbarHeight: 60,
    backgroundColor: Theme.of(context).cardColor,
    surfaceTintColor: Colors.transparent,
    automaticallyImplyLeading: false,
    leading: showBack ? const AppBackButton() : null,
    leadingWidth: showBack ? 56 : null,
    titleSpacing: showBack ? 8 : 16,
    centerTitle: centerTitle,
    title: Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: _subTitleStyle(context),
    ),
    iconTheme: IconThemeData(color: appTextColor(appIsDark(context))),
    actions: actions,
  );
}

import '../widgets/app_icons.dart';
import 'package:flutter/material.dart';
import 'home/home_page.dart';
import 'products/products_page.dart';
import 'gift/gift_page.dart';
import 'profile/profile_page.dart';
import 'profile/favorite_store.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    FavoriteStore.favorites.value = [];
    FavoriteStore.loadFromFirebase();
  }

  void _switchTab(int index) => setState(() => _currentIndex = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomePage(
            onGiftTap: () => _switchTab(2),
            onAvatarTap: () => _switchTab(3),
          ),
          const ProductsPage(),
          const GiftPage(),
          const ProfilePage(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: const Color(0xFF2563EB).withValues(alpha: 0.08),
            ),
          ),
          boxShadow: Theme.of(context).brightness == Brightness.dark
              ? null
              : [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _switchTab,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          backgroundColor: Theme.of(
            context,
          ).bottomNavigationBarTheme.backgroundColor,
          selectedItemColor: Theme.of(
            context,
          ).bottomNavigationBarTheme.selectedItemColor,
          unselectedItemColor: const Color(0xFF94A3B8),
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(PhosphorIconsRegular.house),
              activeIcon: Icon(PhosphorIconsFill.house),
              label: 'Trang chủ',
            ),
            BottomNavigationBarItem(
              icon: Icon(PhosphorIconsRegular.squaresFour),
              activeIcon: Icon(PhosphorIconsFill.squaresFour),
              label: 'Sản phẩm',
            ),
            BottomNavigationBarItem(
              icon: Icon(PhosphorIconsRegular.gift),
              activeIcon: Icon(PhosphorIconsFill.gift),
              label: 'Quà tặng',
            ),
            BottomNavigationBarItem(
              icon: Icon(PhosphorIconsRegular.user),
              activeIcon: Icon(PhosphorIconsFill.user),
              label: 'Cá nhân',
            ),
          ],
        ),
      ),
    );
  }
}

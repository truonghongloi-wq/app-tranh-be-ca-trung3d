import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../admin/admin_dashboard_page.dart';
import '../main_shell.dart';
import 'login_page.dart';

/// Điều hướng dựa trên trạng thái đăng nhập + role của user.
/// - Chưa đăng nhập → LoginPage
/// - Admin           → AdminDashboardPage
/// - Customer        → HomePage
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool? _isAdmin;
  String? _checkedUid;

  Future<void> _checkRole(String uid) async {
    if (_checkedUid == uid) return;
    _checkedUid = uid;
    final admin = await UserService.isCurrentUserAdmin();
    if (mounted) setState(() => _isAdmin = admin);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }

        if (snapshot.hasData) {
          final user = snapshot.data!;
          if (_isAdmin == null || _checkedUid != user.uid) {
            _checkRole(user.uid);
            return const _SplashScreen();
          }
          return _isAdmin! ? const AdminDashboardPage() : const MainShell();
        }

        // Đăng xuất → reset cache role
        _isAdmin = null;
        _checkedUid = null;
        return const LoginPage();
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5CC1FF), Color(0xFF1B4F6A)],
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.water_outlined, size: 64, color: Colors.white),
            SizedBox(height: 16),
            CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
          ],
        ),
      ),
    );
  }
}

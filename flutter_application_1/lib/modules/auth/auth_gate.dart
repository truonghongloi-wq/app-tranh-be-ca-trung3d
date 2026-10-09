import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../main_shell.dart';
import 'login_page.dart';
import 'video_intro.dart';

/// Điều hướng theo trạng thái đăng nhập:
/// - Chưa đăng nhập → LoginPage
/// - Đã đăng nhập   → MainShell (admin mở trang quản trị từ tab Cá nhân)
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _introDone = false;

  @override
  Widget build(BuildContext context) {
    if (!_introDone) {
      return VideoIntro(onDone: () => setState(() => _introDone = true));
    }
    return StreamBuilder<User?>(
      stream: AuthService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }

        if (snapshot.hasData) return const MainShell();
        return const LoginPage();
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
      ),
    );
  }
}

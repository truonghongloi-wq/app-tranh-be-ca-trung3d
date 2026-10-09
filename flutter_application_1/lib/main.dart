import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'app_globals.dart';
import 'modules/auth/auth_gate.dart';
import 'services/theme_store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([_initFirebase(), ThemeStore.load()]);
  runApp(const AquaDecorApp());
}

Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseAppCheck.instance.activate(
      // Debug provider khi chạy `flutter run` (để test bình thường không cần
      // qua Play Store); Play Integrity chỉ áp dụng cho bản release thật.
      androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: AppleProvider.debug,
    );
  } catch (e) {
    debugPrint('[Startup] Firebase init lỗi: $e');
  }
}

class AquaDecorApp extends StatelessWidget {
  const AquaDecorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeStore.mode,
      builder: (_, themeMode, _) {
        return MaterialApp(
          navigatorKey: appNavigatorKey,
          scaffoldMessengerKey: appScaffoldMessengerKey,
          title: 'Tranh Bể Cá 3D',
          debugShowCheckedModeBanner: false,
          theme: ThemeStore.lightTheme,
          darkTheme: ThemeStore.darkTheme,
          themeMode: themeMode,
          home: const AuthGate(),
          // Chạm ra ngoài ô nhập ở bất kỳ màn hình nào để thu bàn phím
          builder: (context, child) => GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: child,
          ),
        );
      },
    );
  }
}

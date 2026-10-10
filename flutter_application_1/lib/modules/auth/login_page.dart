import 'dart:math' as math;
import 'dart:ui';

import '../../widgets/app_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../widgets/video_background.dart';
import '../../services/auth_service.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _loading = false;
  bool _googleLoading = false;
  bool _appleLoading = false;

  bool get _busy => _loading || _googleLoading || _appleLoading;

  // Đăng nhập Apple chỉ hiện trên iPhone/iPad (Apple yêu cầu khi có Google)
  bool get _showApple => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  bool _obscurePassword = true;
  String? _errorMessage;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final error = await AuthService.signIn(
      email: _emailCtrl.text,
      password: _passwordCtrl.text,
    );

    if (!mounted) return;
    setState(() {
      _loading = false;
      _errorMessage = error;
    });
  }

  Future<void> _handleGoogleLogin() async {
    setState(() {
      _googleLoading = true;
      _errorMessage = null;
    });

    final error = await AuthService.signInWithGoogle();

    if (!mounted) return;
    setState(() {
      _googleLoading = false;
      _errorMessage = error;
    });
  }

  Future<void> _handleAppleLogin() async {
    setState(() {
      _appleLoading = true;
      _errorMessage = null;
    });

    final error = await AuthService.signInWithApple();

    if (!mounted) return;
    setState(() {
      _appleLoading = false;
      _errorMessage = error;
    });
  }

  Future<void> _showForgotPasswordDialog() async {
    final emailCtrl = TextEditingController(text: _emailCtrl.text);
    bool sending = false;
    String? dialogError;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Quên mật khẩu'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nhập email đã đăng ký, hệ thống sẽ gửi link đặt lại mật khẩu.',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    enabled: !sending,
                    decoration: _inputDecoration(
                      hint: 'example@gmail.com',
                      icon: PhosphorIconsRegular.envelopeSimple,
                    ),
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      dialogError!,
                      style: const TextStyle(
                        color: Color(0xFFE53935),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: sending
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Huỷ'),
                ),
                ElevatedButton(
                  onPressed: sending
                      ? null
                      : () async {
                          final email = emailCtrl.text.trim();
                          if (email.isEmpty ||
                              !RegExp(
                                r'^[\w.+-]+@[\w-]+\.\w+$',
                              ).hasMatch(email)) {
                            setDialogState(
                              () => dialogError = 'Email không đúng định dạng.',
                            );
                            return;
                          }
                          setDialogState(() {
                            sending = true;
                            dialogError = null;
                          });
                          final error = await AuthService.resetPassword(
                            email: email,
                          );
                          if (error != null) {
                            setDialogState(() {
                              sending = false;
                              dialogError = error;
                            });
                            return;
                          }
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Đã gửi email đặt lại mật khẩu tới $email. Vui lòng kiểm tra hộp thư.',
                                ),
                                backgroundColor: const Color(0xFF2563EB),
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                  ),
                  child: sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text('Gửi'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const VideoBackground(asset: 'assets/videos/login_bg.mp4'),
          // Lớp tối nhẹ để logo, chữ trắng dễ đọc trên nền video
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x59000000), Color(0x8C000000)],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildLogo(),
                        const SizedBox(height: 32),
                        _buildCard(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.85),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset('assets/icons/trung_logo.png', fit: BoxFit.cover),
        ),
        const SizedBox(height: 16),
        const Text(
          'Tranh Bể Cá Trung 3D',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Hệ Thống Quản Lý',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildCard() {
    // Khung kính mờ: thấy video nền phía sau, chữ trắng
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Đăng Nhập',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),

                // Email field
                _buildLabel('Email'),
                const SizedBox(height: 6),
                TextFormField(
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  enabled: !_loading,
                  decoration: _inputDecoration(
                    hint: 'example@gmail.com',
                    icon: PhosphorIconsRegular.envelopeSimple,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Vui lòng nhập email.';
                    }
                    if (!RegExp(r'^[\w.+-]+@[\w-]+\.\w+$').hasMatch(v.trim())) {
                      return 'Email không đúng định dạng.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password field
                _buildLabel('Mật Khẩu'),
                const SizedBox(height: 6),
                TextFormField(
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  enabled: !_loading,
                  onFieldSubmitted: (_) => _handleLogin(),
                  decoration:
                      _inputDecoration(
                        hint: '••••••••',
                        icon: PhosphorIconsRegular.lock,
                      ).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? PhosphorIconsRegular.eyeSlash
                                : PhosphorIconsRegular.eye,
                            color: Colors.white70,
                            size: 20,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Vui lòng nhập mật khẩu.';
                    }
                    if (v.length < 6) return 'Mật khẩu ít nhất 6 ký tự.';
                    return null;
                  },
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _loading ? null : _showForgotPasswordDialog,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Quên mật khẩu?',
                      style: TextStyle(
                        color: Color(0xFF93C5FD),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Error message
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFEF9A9A)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          PhosphorIconsRegular.warningCircle,
                          color: Color(0xFFE53935),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Color(0xFFE53935),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Nút đăng nhập
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(
                        0xFF2563EB,
                      ).withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 2,
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'ĐĂNG NHẬP',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 18),
                _buildOrDivider(),
                const SizedBox(height: 18),
                if (_showApple) ...[
                  _buildAppleButton(),
                  const SizedBox(height: 12),
                ],
                _buildGoogleButton(),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Chưa có tài khoản? ',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RegisterPage()),
                      ),
                      child: const Text(
                        'Đăng ký',
                        style: TextStyle(
                          color: Color(0xFF93C5FD),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrDivider() {
    final line = Expanded(
      child: Container(height: 1, color: Colors.white.withValues(alpha: 0.28)),
    );
    return Row(
      children: [
        line,
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'hoặc',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
        line,
      ],
    );
  }

  // Nút theo chuẩn Apple: nền đen, logo Apple, chữ trắng
  Widget _buildAppleButton() {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: _busy ? null : _handleAppleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.black.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _appleLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.apple, size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Đăng nhập với Apple',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: _busy ? null : _handleGoogleLogin,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1F1F1F),
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.6),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _googleLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Color(0xFF2563EB),
                  strokeWidth: 2.5,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CustomPaint(painter: _GoogleLogoPainter()),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Đăng nhập với Google',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      errorStyle: const TextStyle(color: Color(0xFFFFB4A9)),
      hintStyle: const TextStyle(color: Colors.white54, fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.white70, size: 20),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.12),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0x47FFFFFF), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE53935), width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.5),
      ),
    );
  }
}

// Logo chữ "G" 4 màu của Google, vẽ bằng Canvas để không cần thêm file ảnh.
class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  static double _rad(double deg) => deg * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.2;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    Paint arc(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    canvas.drawArc(
      rect,
      _rad(-160),
      _rad(120),
      false,
      arc(const Color(0xFFEA4335)),
    );
    canvas.drawArc(
      rect,
      _rad(145),
      _rad(55),
      false,
      arc(const Color(0xFFFBBC05)),
    );
    canvas.drawArc(
      rect,
      _rad(40),
      _rad(105),
      false,
      arc(const Color(0xFF34A853)),
    );
    canvas.drawArc(
      rect,
      _rad(-2),
      _rad(44),
      false,
      arc(const Color(0xFF4285F4)),
    );
    // Thanh ngang của chữ G
    canvas.drawRect(
      Rect.fromLTWH(
        size.width / 2,
        size.height / 2 - stroke / 2,
        size.width / 2,
        stroke,
      ),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

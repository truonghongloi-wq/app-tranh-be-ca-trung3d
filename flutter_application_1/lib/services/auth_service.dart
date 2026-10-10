import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'avatar_service.dart';
import 'user_service.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  static User? get currentUser => _auth.currentUser;

  static bool get isLoggedIn => _auth.currentUser != null;

  static final GoogleSignIn _google = GoogleSignIn(scopes: ['email']);

  // Tài khoản có mật khẩu (đăng ký bằng email) — tài khoản chỉ đăng nhập
  // Google thì không có mật khẩu để đổi/xác nhận.
  static bool get hasPassword =>
      _auth.currentUser?.providerData.any((p) => p.providerId == 'password') ??
      false;

  static bool _hasProvider(String id) =>
      _auth.currentUser?.providerData.any((p) => p.providerId == id) ?? false;

  // Tài khoản đăng nhập bằng Apple (không có mật khẩu)
  static bool get isAppleUser => _hasProvider('apple.com');

  // Đăng nhập bằng Apple (bắt buộc trên iOS khi app có đăng nhập Google —
  // App Store guideline 4.8). Trả về null nếu thành công hoặc khách tự hủy.
  static Future<String?> signInWithApple() async {
    try {
      final provider = AppleAuthProvider()
        ..addScope('email')
        ..addScope('name');
      final cred = await _auth.signInWithProvider(provider);
      final user = cred.user;
      if (user != null && (cred.additionalUserInfo?.isNewUser ?? false)) {
        // Apple chỉ gửi họ tên ở lần đăng nhập đầu tiên
        final name = (user.displayName ?? '').trim();
        unawaited(UserService.saveNewUser(user, displayName: name));
      }
      return null;
    } on FirebaseAuthException catch (e) {
      if (_isAppleCanceled(e)) return null;
      debugPrint('[Auth] Apple signIn lỗi: ${e.code} ${e.message}');
      return _mapErrorMessage(e.code);
    } catch (e) {
      debugPrint('[Auth] Apple signIn lỗi: $e');
      return 'Không đăng nhập được bằng Apple. Vui lòng thử lại.';
    }
  }

  // Khách đóng hộp đăng nhập Apple (ASAuthorizationError 1001)
  static bool _isAppleCanceled(FirebaseAuthException e) =>
      e.code.contains('cancel') ||
      (e.message ?? '').contains('1001') ||
      (e.message ?? '').toLowerCase().contains('canceled');

  // Đăng nhập bằng Google. Trả về null nếu thành công hoặc khách tự hủy
  // (đóng hộp chọn tài khoản), ngược lại trả về thông báo lỗi.
  static Future<String?> signInWithGoogle() async {
    try {
      final account = await _google.signIn();
      if (account == null) return null; // khách đóng hộp chọn tài khoản
      final auth = await account.authentication;
      final cred = await _auth.signInWithCredential(
        GoogleAuthProvider.credential(
          accessToken: auth.accessToken,
          idToken: auth.idToken,
        ),
      );
      final user = cred.user;
      if (user != null && (cred.additionalUserInfo?.isNewUser ?? false)) {
        final name = (user.displayName ?? '').trim();
        unawaited(UserService.saveNewUser(user, displayName: name));
      }
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapErrorMessage(e.code);
    } on PlatformException catch (e) {
      debugPrint('[Auth] Google signIn lỗi: ${e.code} ${e.message}');
      if (e.code == GoogleSignIn.kNetworkError) {
        return _mapErrorMessage('network-request-failed');
      }
      if (e.code == GoogleSignIn.kSignInCanceledError) return null;
      return 'Không đăng nhập được bằng Google. Vui lòng thử lại.';
    } catch (e) {
      debugPrint('[Auth] Google signIn lỗi: $e');
      return 'Không đăng nhập được bằng Google. Vui lòng thử lại.';
    }
  }

  // Xác thực lại tài khoản Google (Firebase yêu cầu trước khi xóa tài khoản).
  static Future<AuthCredential?> _googleCredential() async {
    // Đăng xuất phiên Google cũ để hộp chọn tài khoản luôn hiện ra
    await _google.signOut().catchError((_) => null);
    final account = await _google.signIn();
    if (account == null) return null;
    final auth = await account.authentication;
    return GoogleAuthProvider.credential(
      accessToken: auth.accessToken,
      idToken: auth.idToken,
    );
  }

  static Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapErrorMessage(e.code);
    } catch (e) {
      debugPrint('[Auth] signIn lỗi: $e');
      return 'Đã xảy ra lỗi, vui lòng thử lại.';
    }
  }

  static Future<String?> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (cred.user != null) {
        await cred.user!.updateDisplayName(displayName.trim());
        final name = displayName.trim();
        final uid = cred.user!.uid;
        // Ghi đè Firestore (Extension tự tạo doc với email prefix trước khi updateDisplayName xong)
        unawaited(
          FirebaseFirestore.instance.collection('users').doc(uid).set({
            'displayName': name,
          }, SetOptions(merge: true)),
        );
        unawaited(UserService.saveNewUser(cred.user!, displayName: name));
      }
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapErrorMessage(e.code);
    } catch (e) {
      debugPrint('[Auth] signUp lỗi: $e');
      return 'Đã xảy ra lỗi, vui lòng thử lại.';
    }
  }

  static Future<void> signOut() async {
    // Đăng xuất cả phiên Google để lần sau được chọn lại tài khoản
    try {
      await _google.signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  static Future<String?> resetPassword({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapErrorMessage(e.code);
    } catch (e) {
      debugPrint('[Auth] resetPassword lỗi: $e');
      return 'Đã xảy ra lỗi, vui lòng thử lại.';
    }
  }

  // Đổi mật khẩu khi đang đăng nhập: xác thực lại bằng mật khẩu hiện tại
  // (Firebase bắt buộc với thao tác nhạy cảm) rồi đặt mật khẩu mới.
  static Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      return 'Không tìm thấy tài khoản đang đăng nhập.';
    }

    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(
          email: user.email!,
          password: currentPassword,
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return 'Mật khẩu hiện tại không đúng.';
      }
      return _mapErrorMessage(e.code);
    } catch (e) {
      debugPrint('[Auth] reauthenticate lỗi: $e');
      return 'Đã xảy ra lỗi, vui lòng thử lại.';
    }

    try {
      await user.updatePassword(newPassword);
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapErrorMessage(e.code);
    } catch (e) {
      debugPrint('[Auth] updatePassword lỗi: $e');
      return 'Đã xảy ra lỗi, vui lòng thử lại.';
    }
  }

  // Xóa tài khoản: cần mật khẩu để re-authenticate (Firebase yêu cầu đăng
  // nhập gần đây trước khi cho xóa). Xóa hồ sơ (users/{uid}) trên Realtime DB
  // + Firestore, sau đó xóa tài khoản Auth.
  // Lịch sử đơn hàng (orders/{uid}) được GIỮ LẠI phục vụ kế toán/khiếu nại
  // (đã disclose trong Privacy Policy), không còn gắn với tài khoản đăng nhập.
  // Tài khoản Google/Apple (không có mật khẩu): truyền password = null, khách
  // xác nhận lại bằng Google/Apple.
  static Future<String?> deleteAccount({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) {
      return 'Không tìm thấy tài khoản đang đăng nhập.';
    }

    // Mã ủy quyền Apple để thu hồi quyền khi xóa (Apple bắt buộc)
    String? appleAuthCode;
    try {
      if (password != null) {
        if (user.email == null) {
          return 'Không tìm thấy tài khoản đang đăng nhập.';
        }
        await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: user.email!, password: password),
        );
      } else if (isAppleUser) {
        final cred = await user.reauthenticateWithProvider(AppleAuthProvider());
        appleAuthCode = cred.additionalUserInfo?.authorizationCode;
      } else {
        final cred = await _googleCredential();
        if (cred == null) return 'Bạn chưa xác nhận tài khoản Google.';
        await user.reauthenticateWithCredential(cred);
      }
    } on FirebaseAuthException catch (e) {
      if (password == null && isAppleUser && _isAppleCanceled(e)) {
        return 'Bạn chưa xác nhận tài khoản Apple.';
      }
      if (e.code == 'user-mismatch') {
        return 'Tài khoản vừa chọn không phải tài khoản đang đăng nhập.';
      }
      return _mapErrorMessage(e.code);
    } catch (e) {
      debugPrint('[Auth] reauthenticate lỗi: $e');
      return 'Đã xảy ra lỗi, vui lòng thử lại.';
    }

    final uid = user.uid;

    try {
      await FirebaseDatabase.instance.ref('users/$uid').remove();
    } catch (e) {
      debugPrint('[Auth] xóa users/$uid trên Realtime DB lỗi: $e');
    }

    try {
      await AvatarService.deleteAllUserFiles(uid);
    } catch (e) {
      debugPrint('[Auth] xóa ảnh của khách lỗi: $e');
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();
    } catch (e) {
      debugPrint('[Auth] xóa Firestore users/$uid lỗi: $e');
    }

    if (appleAuthCode != null) {
      try {
        await _auth.revokeTokenWithAuthorizationCode(appleAuthCode);
      } catch (e) {
        debugPrint('[Auth] thu hồi token Apple lỗi: $e');
      }
    }

    try {
      await user.delete();
      try {
        await _google.signOut();
      } catch (_) {}
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapErrorMessage(e.code);
    } catch (e) {
      debugPrint('[Auth] deleteAccount lỗi: $e');
      return 'Đã xảy ra lỗi, vui lòng thử lại.';
    }
  }

  static String _mapErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Tài khoản không tồn tại.';
      case 'wrong-password':
        return 'Mật khẩu không đúng.';
      case 'invalid-email':
        return 'Email không hợp lệ.';
      case 'email-already-in-use':
        return 'Email này đã được sử dụng. Vui lòng đăng ký bằng email khác (hoặc đăng nhập nếu đây là email của bạn).';
      case 'user-disabled':
        return 'Tài khoản đã bị vô hiệu hóa.';
      case 'too-many-requests':
        return 'Quá nhiều lần thử. Vui lòng chờ và thử lại.';
      case 'invalid-credential':
        return 'Email hoặc mật khẩu không đúng.';
      case 'weak-password':
        return 'Mật khẩu quá yếu, vui lòng dùng ít nhất 6 ký tự.';
      case 'requires-recent-login':
        return 'Vui lòng đăng xuất, đăng nhập lại rồi thử lại.';
      case 'account-exists-with-different-credential':
        return 'Email này đã đăng ký bằng mật khẩu. Vui lòng đăng nhập bằng email và mật khẩu.';
      case 'operation-not-allowed':
        return 'Hình thức đăng nhập này chưa được bật. Vui lòng liên hệ shop.';
      case 'network-request-failed':
        return 'Không có kết nối mạng. Vui lòng kiểm tra Internet.';
      default:
        return 'Đã xảy ra lỗi ($code). Vui lòng thử lại.';
    }
  }
}

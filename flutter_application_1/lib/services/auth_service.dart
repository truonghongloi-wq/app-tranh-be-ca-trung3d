import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'avatar_service.dart';
import 'user_service.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  static User? get currentUser => _auth.currentUser;

  static bool get isLoggedIn => _auth.currentUser != null;

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
  static Future<String?> deleteAccount({required String password}) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      return 'Không tìm thấy tài khoản đang đăng nhập.';
    }

    try {
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(cred);
    } on FirebaseAuthException catch (e) {
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

    try {
      await user.delete();
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
      case 'network-request-failed':
        return 'Không có kết nối mạng. Vui lòng kiểm tra Internet.';
      default:
        return 'Đã xảy ra lỗi ($code). Vui lòng thử lại.';
    }
  }
}

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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
          FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .set({'displayName': name}, SetOptions(merge: true)),
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

  static String _mapErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Tài khoản không tồn tại.';
      case 'wrong-password':
        return 'Mật khẩu không đúng.';
      case 'invalid-email':
        return 'Email không hợp lệ.';
      case 'email-already-in-use':
        return 'Email này đã được đăng ký. Vui lòng đăng nhập hoặc dùng email khác.';
      case 'user-disabled':
        return 'Tài khoản đã bị vô hiệu hóa.';
      case 'too-many-requests':
        return 'Quá nhiều lần thử. Vui lòng chờ và thử lại.';
      case 'invalid-credential':
        return 'Email hoặc mật khẩu không đúng.';
      default:
        return 'Đã xảy ra lỗi ($code). Vui lòng thử lại.';
    }
  }
}

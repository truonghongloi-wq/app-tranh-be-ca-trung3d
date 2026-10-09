import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Ảnh đại diện của khách: lưu ở Storage avatars/{uid}/avatar.jpg,
/// link ảnh gắn vào User.photoURL (Trang chủ + Cá nhân tự cập nhật qua userChanges).
class AvatarService {
  static Reference _ref(String uid) =>
      FirebaseStorage.instance.ref('avatars/$uid/avatar.jpg');

  /// Trả về null nếu thành công hoặc khách hủy chọn ảnh, ngược lại là lỗi tiếng Việt.
  static Future<String?> pickAndUpload(ImageSource source) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Vui lòng đăng nhập để đổi ảnh đại diện.';

    final XFile? file;
    try {
      file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
    } catch (e) {
      debugPrint('[Avatar] chọn ảnh lỗi: $e');
      return 'Không mở được ${source == ImageSource.camera ? 'máy ảnh' : 'thư viện ảnh'}.';
    }
    if (file == null) return null;

    try {
      final bytes = await file.readAsBytes();
      final ref = _ref(user.uid);
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();
      await user.updatePhotoURL(url);
      return null;
    } catch (e) {
      debugPrint('[Avatar] tải ảnh lên lỗi: $e');
      return 'Không lưu được ảnh đại diện, vui lòng thử lại.';
    }
  }

  static Future<String?> remove() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    try {
      await user.updatePhotoURL(null);
      await deleteFile(user.uid);
      return null;
    } catch (e) {
      debugPrint('[Avatar] xóa ảnh lỗi: $e');
      return 'Không xóa được ảnh đại diện, vui lòng thử lại.';
    }
  }

  /// Xóa mọi ảnh riêng của khách trên Storage: ảnh đại diện + ảnh AI ghép.
  static Future<void> deleteAllUserFiles(String uid) async {
    await deleteFile(uid);
    final composites = await FirebaseStorage.instance
        .ref('composites/$uid')
        .listAll();
    await Future.wait(composites.items.map((f) => f.delete()));
  }

  static Future<void> deleteFile(String uid) async {
    try {
      await _ref(uid).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }
  }
}

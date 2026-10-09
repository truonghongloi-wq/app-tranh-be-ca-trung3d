import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../widgets/app_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import '../../widgets/app_ui.dart';

enum _Step { pickPhoto, processing, result, error }

/// Đổi ảnh (PNG) sang JPEG chất lượng 90; giữ nguyên nếu không đọc được.
Uint8List _toJpeg(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;
  return Uint8List.fromList(img.encodeJpg(decoded, quality: 90));
}

class CompositeScreen extends StatefulWidget {
  final String paintingUrl;
  final String imageId;
  final String? imageUrl;
  final double tongDienTich;
  final double tongTien;
  final int tongSoTam;
  final Map<String, String> kichThuoc;
  final List<String> cacMatIn;
  final String chatLieu;

  const CompositeScreen({
    super.key,
    required this.paintingUrl,
    required this.imageId,
    this.imageUrl,
    required this.tongDienTich,
    required this.tongTien,
    required this.tongSoTam,
    required this.kichThuoc,
    required this.cacMatIn,
    required this.chatLieu,
  });

  @override
  State<CompositeScreen> createState() => _CompositeScreenState();
}

class _CompositeScreenState extends State<CompositeScreen> {
  static const _primary = Color(0xFF2563EB);
  static const _dailyLimit = 3;
  // Giới hạn lượt ghép/ngày; bật/tắt cùng _QUOTA_ENABLED ở Cloud Function
  static const _quotaEnabled = true;

  _Step _step = _Step.pickPhoto;
  Uint8List? _tankBytes;
  // Ảnh ghép chỉ giữ trong bộ nhớ máy — không lưu lên Firebase.
  // Khách muốn giữ thì bấm "Lưu ảnh" để lưu vào thư viện điện thoại.
  Uint8List? _resultBytes;
  String _errorMsg = '';
  bool _errorIsQuota = false;
  bool _reported = false;
  int? _remaining;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (_quotaEnabled) _loadQuota();
  }

  // Ngày theo giờ Việt Nam (UTC+7), khớp _today_vn() ở Cloud Function.
  String _todayKey() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 7));
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadQuota() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final snap = await FirebaseDatabase.instance
          .ref('composite_quota/$uid/${_todayKey()}')
          .get();
      final used = (snap.value as num?)?.toInt() ?? 0;
      if (mounted) {
        setState(() => _remaining = (_dailyLimit - used).clamp(0, _dailyLimit));
      }
    } catch (e) {
      // Không đọc được số lượt thì ẩn thanh đếm; server vẫn chặn khi hết lượt.
      debugPrint('Đọc lượt ghép lỗi: $e');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final xFile = await ImagePicker().pickImage(
      source: source,
      imageQuality: 90,
    );
    if (xFile == null) return;

    var bytes = await xFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded != null && decoded.width > 1024) {
      final resized = img.copyResize(decoded, width: 1024);
      bytes = Uint8List.fromList(img.encodeJpg(resized, quality: 85));
    }

    if (!mounted) return;
    setState(() => _tankBytes = bytes);
    _startProcessing();
  }

  Future<void> _startProcessing() async {
    setState(() => _step = _Step.processing);
    try {
      final tankB64 = base64Encode(_tankBytes!);
      final callable = FirebaseFunctions.instanceFor(region: 'asia-southeast1')
          .httpsCallable(
            'composite_image',
            options: HttpsCallableOptions(
              timeout: const Duration(seconds: 200),
            ),
          );

      final result = await callable.call({
        'tank_image_b64': tankB64,
        'painting_url': widget.paintingUrl,
      });

      final imageB64 = result.data['image_b64'] as String?;
      if (imageB64 == null) throw Exception('Không nhận được ảnh từ server');
      final imageBytes = base64Decode(imageB64);

      final remaining = result.data['remaining'] as int?;

      if (!mounted) return;
      setState(() {
        _resultBytes = imageBytes;
        _step = _Step.result;
        if (remaining != null) _remaining = remaining;
      });
    } on FirebaseFunctionsException catch (e) {
      debugPrint('composite_image lỗi: ${e.code} ${e.message}');
      if (!mounted) return;
      final msg = switch (e.code) {
        'resource-exhausted' || 'internal' || 'invalid-argument' =>
          e.message ?? _genericError,
        'deadline-exceeded' =>
          'Máy chủ phản hồi quá lâu. Vui lòng thử lại sau ít phút.',
        'unavailable' => 'Không có kết nối mạng. Vui lòng kiểm tra Internet.',
        'unauthenticated' => 'Phiên đăng nhập đã hết, vui lòng đăng nhập lại.',
        _ => _genericError,
      };
      setState(() {
        _errorMsg = msg;
        _errorIsQuota = e.code == 'resource-exhausted';
        _step = _Step.error;
      });
      if (_quotaEnabled) _loadQuota();
    } catch (e) {
      debugPrint('composite_image lỗi: $e');
      if (!mounted) return;
      setState(() {
        _errorMsg = _genericError;
        _errorIsQuota = false;
        _step = _Step.error;
      });
      if (_quotaEnabled) _loadQuota();
    }
  }

  Future<void> _saveImage() async {
    if (_resultBytes == null || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) {
        final granted = await Gal.requestAccess(toAlbum: true);
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cần cấp quyền truy cập thư viện ảnh'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
      }
      // Server trả PNG (~1,5 MB); đổi sang JPEG (~200 KB) trước khi lưu
      // vào thư viện ảnh. Chạy ở isolate riêng để không giật giao diện.
      final jpg = await compute(_toJpeg, _resultBytes!);
      await Gal.putImageBytes(
        jpg,
        name: 'tranh_be_ca_${DateTime.now().millisecondsSinceEpoch}',
        album: 'Tranh Bể Cá 3D',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã lưu ảnh vào thư viện'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF2563EB),
          ),
        );
      }
    } catch (e) {
      debugPrint('Lưu ảnh lỗi: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lưu ảnh thất bại, vui lòng thử lại.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _retry() => setState(() {
    _step = _Step.pickPhoto;
    _tankBytes = null;
    _resultBytes = null;
    _errorMsg = '';
    _errorIsQuota = false;
    _reported = false;
  });

  static const _genericError =
      'Ghép ảnh chưa thành công, lượt đã được hoàn lại. Vui lòng thử lại.';

  static const _reportReasons = [
    'Ảnh phản cảm hoặc không phù hợp',
    'Ảnh bị méo, sai lệch so với tranh',
    'Ảnh chứa người hoặc nội dung lạ',
    'Lý do khác',
  ];

  /// Báo cáo ảnh AI (chính sách Google Play về nội dung do AI tạo):
  /// ghi vào ai_reports/{uid} để cửa hàng xem xét.
  Future<void> _reportImage() async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Báo cáo ảnh AI',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
            for (final r in _reportReasons)
              ListTile(
                title: Text(r),
                onTap: () => Navigator.pop(sheetContext, r),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (reason == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    try {
      if (uid == null) throw StateError('Chưa đăng nhập');
      await FirebaseDatabase.instance.ref('ai_reports/$uid').push().set({
        'reason': reason,
        'paintingUrl': widget.paintingUrl,
        'createdAt': DateTime.now().toIso8601String(),
      });
      if (mounted) setState(() => _reported = true);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Cảm ơn bạn! Cửa hàng sẽ xem xét báo cáo này.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('Gửi báo cáo ảnh lỗi: $e');
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Chưa gửi được báo cáo, vui lòng thử lại.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _goToOrder() {
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: appSubAppBar(context, 'Xem thử trên bể'),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    switch (_step) {
      case _Step.pickPhoto:
        return _buildPickStep();
      case _Step.processing:
        return _buildProcessingStep();
      case _Step.result:
        return _buildResultStep();
      case _Step.error:
        return _buildErrorStep();
    }
  }

  Widget _buildQuotaBanner() {
    final remaining = _remaining;
    if (remaining == null) return const SizedBox.shrink();

    final color = remaining == 0
        ? Colors.red.shade600
        : remaining == 1
        ? Colors.orange.shade700
        : _primary;

    final message = remaining == 0
        ? 'Hết lượt hôm nay — quay lại vào ngày mai'
        : 'Còn $remaining/$_dailyLimit lượt ghép ảnh hôm nay';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            remaining == 0
                ? PhosphorIconsRegular.prohibit
                : PhosphorIconsRegular.info,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ...List.generate(
            _dailyLimit,
            (i) => Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(
                i < remaining
                    ? PhosphorIconsFill.circle
                    : PhosphorIconsRegular.circle,
                color: color,
                size: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickStep() {
    final outOfQuota = _remaining == 0;
    // Cuộn được trên màn hình nhỏ / cỡ chữ lớn; Spacer vẫn đẩy nút xuống đáy
    // khi đủ chỗ.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(child: _pickStepColumn(outOfQuota)),
        ),
      ),
    );
  }

  Widget _pickStepColumn(bool outOfQuota) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F2563EB),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              widget.paintingUrl,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                height: 160,
                color: Colors.grey.shade200,
                child: const Icon(
                  PhosphorIconsRegular.imageBroken,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        ),
        const Text(
          'Tranh đã chọn',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: _primary,
          ),
        ),
        const Spacer(),
        _buildQuotaBanner(),
        const Text(
          'Chụp ảnh bể cá của bạn',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'AI sẽ ghép tranh vào mặt kính sau bể cá',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54, fontSize: 13),
        ),
        const SizedBox(height: 4),
        const Text(
          'Ảnh do AI tạo nên có thể sẽ mắc lỗi',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFFB45309),
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFFCC02), width: 1),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('💡', style: TextStyle(fontSize: 15)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Chụp toàn bộ bể trong không gian thực, tránh chụp nửa bể hay bị cắt mất góc để ảnh ghép ra đẹp nhất.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF5D4037),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Row(
            children: [
              Expanded(
                child: _BigButton(
                  icon: PhosphorIconsRegular.camera,
                  label: 'Chụp ảnh',
                  onTap: outOfQuota
                      ? null
                      : () => _pickImage(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _BigButton(
                  icon: PhosphorIconsRegular.images,
                  label: 'Thư viện',
                  onTap: outOfQuota
                      ? null
                      : () => _pickImage(ImageSource.gallery),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildProcessingStep() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_tankBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  _tankBytes!,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(color: _primary),
            const SizedBox(height: 16),
            const Text(
              'AI đang ghép tranh vào bể...',
              style: TextStyle(
                fontSize: 16,
                color: _primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Quá trình mất khoảng 20–60 giây',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black45, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultStep() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            'Ảnh xem thử',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: _buildQuotaBanner(),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                _resultBytes!,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) =>
                    const Center(child: Text('Không tải được ảnh kết quả')),
              ),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFFCC02)),
          ),
          child: const Row(
            children: [
              Icon(
                PhosphorIconsRegular.warningCircle,
                size: 18,
                color: Color(0xFFB45309),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ảnh do AI tạo nên có thể sẽ mắc lỗi. Ảnh chỉ mang tính '
                  'minh họa, tranh thực tế có thể khác đôi chút.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF5D4037),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _reported ? null : _reportImage,
              icon: Icon(
                _reported
                    ? PhosphorIconsRegular.check
                    : PhosphorIconsRegular.flag,
                size: 16,
              ),
              label: Text(_reported ? 'Đã báo cáo' : 'Báo cáo ảnh'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.black54,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                icon: const Icon(PhosphorIconsRegular.checkCircle),
                label: const Text(
                  'Xác nhận & Quay lại cấu hình',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                onPressed: _goToOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(PhosphorIconsRegular.camera),
                      label: const Text('Chụp lại'),
                      onPressed: _remaining == 0 ? null : _retry,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _primary,
                              ),
                            )
                          : const Icon(PhosphorIconsRegular.downloadSimple),
                      label: Text(_isSaving ? 'Đang lưu...' : 'Lưu ảnh'),
                      onPressed: _isSaving ? null : _saveImage,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorStep() {
    final isQuotaError = _errorIsQuota;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isQuotaError
                  ? PhosphorIconsRegular.hourglass
                  : PhosphorIconsRegular.warningCircle,
              size: 64,
              color: isQuotaError ? Colors.orange : Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              isQuotaError ? 'Hết lượt hôm nay' : 'Ghép ảnh thất bại',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMsg,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 24),
            if (!isQuotaError)
              ElevatedButton.icon(
                icon: const Icon(PhosphorIconsRegular.arrowClockwise),
                label: const Text('Thử lại'),
                onPressed: _retry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _BigButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: disabled ? Colors.grey.shade100 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: disabled
                ? Colors.grey.shade300
                : const Color(0xFF2563EB).withValues(alpha: 0.3),
          ),
          boxShadow: disabled
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x122563EB),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: disabled ? Colors.grey : const Color(0xFF2563EB),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: disabled ? Colors.grey : const Color(0xFF2563EB),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

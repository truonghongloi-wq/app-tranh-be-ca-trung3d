import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_globals.dart';
import '../../services/order_notification_service.dart';
import 'order_store.dart';

// TODO: Điền link hướng dẫn dán tranh thực tế vào đây
const _kDanTrongUrl = 'https://youtu.be/HPMifAo5sWI';
const _kDanNgoaiUrl = 'https://youtu.be/1JOcMpJ9o8o';

Future<void> _launchInstructionUrl(BuildContext context, String url) async {
  if (url.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link đang được cập nhật')),
    );
    return;
  }
  final uri = Uri.parse(url);
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không mở được link')),
      );
    }
  }
}

class OrderConfirmationPage extends StatefulWidget {
  final String imageId;
  final String? imageUrl;
  final double tongDienTich;
  final double tongTien;
  final double discountTien;
  final int tongSoTam;
  final Map<String, String> kichThuoc;
  final List<String> cacMatIn;
  final String chatLieu;
  final Map<String, String> chatLieuPerMat;

  const OrderConfirmationPage({
    super.key,
    required this.imageId,
    this.imageUrl,
    required this.tongDienTich,
    required this.tongTien,
    this.discountTien = 0,
    required this.tongSoTam,
    required this.kichThuoc,
    required this.cacMatIn,
    required this.chatLieu,
    required this.chatLieuPerMat,
  });

  @override
  State<OrderConfirmationPage> createState() => _OrderConfirmationPageState();
}

class _OrderConfirmationPageState extends State<OrderConfirmationPage> {
  static const Color _primary = Color(0xFF2B678B);
  static const Color _gradientTop = Color(0xFF5CC1FF);

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _soNhaCtrl = TextEditingController();
  final TextEditingController _duongCtrl = TextEditingController();
  final TextEditingController _phuongXaCtrl = TextEditingController();
  final TextEditingController _tinhTPCtrl = TextEditingController();
  bool _submitting = false;

  String get _fullAddress =>
      '${_soNhaCtrl.text.trim()}, ${_duongCtrl.text.trim()}, ${_phuongXaCtrl.text.trim()}, ${_tinhTPCtrl.text.trim()}';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _soNhaCtrl.dispose();
    _duongCtrl.dispose();
    _phuongXaCtrl.dispose();
    _tinhTPCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 70,
            floating: true,
            pinned: true,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_gradientTop, _primary],
                ),
              ),
              child: const FlexibleSpaceBar(
                titlePadding: EdgeInsets.only(left: 56, bottom: 14),
                title: Text(
                  'Xác nhận đơn hàng',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildImagePreview(),
                  const SizedBox(height: 20),
                  _buildOrderSummaryCard(),
                  const SizedBox(height: 16),
                  _buildDeliveryForm(),
                  const SizedBox(height: 20),
                  _buildTotalCard(),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildConfirmButton(),
    );
  }

  Widget _buildImagePreview() {
    final url = widget.imageUrl;
    return Container(
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            url != null && url.isNotEmpty
                ? Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _previewPlaceholder(),
                  )
                : _previewPlaceholder(),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xBB000000)],
                  ),
                ),
                child: Text(
                  'Mã tranh: ${widget.imageId}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF5CC1FF), Color(0xFF2B678B)],
        ),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.image, size: 52, color: Colors.white38),
    );
  }

  Widget _buildOrderSummaryCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(icon: Icons.description_rounded, title: 'Thông tin tranh'),
          const SizedBox(height: 12),
          _InfoRow(label: 'Mã tranh', value: widget.imageId),
          _InfoRow(
            label: 'Số lượng tấm',
            value: '${widget.tongSoTam} tấm',
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: Color(0xFFEEF2F5)),
          ),
          _CardHeader(
              icon: Icons.straighten_rounded, title: 'Kích thước tranh (cm)'),
          const SizedBox(height: 12),
          ...widget.cacMatIn.map(
            (mat) => _InfoRow(
              label: 'Mặt $mat',
              value: '${_getSize(mat)} cm (${widget.chatLieuPerMat[mat] ?? widget.chatLieu})',
            ),
          ),
        ],
      ),
    );
  }

  String _getSize(String mat) {
    if (mat == 'lưng') return '${widget.kichThuoc['D']} × ${widget.kichThuoc['C']}';
    if (mat == 'đáy')  return '${widget.kichThuoc['D']} × ${widget.kichThuoc['R']}';
    return '${widget.kichThuoc['R']} × ${widget.kichThuoc['C']}';
  }

  Widget _buildDeliveryForm() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
              icon: Icons.local_shipping_rounded,
              title: 'Thông tin giao hàng'),
          const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: Column(
              children: [
                _StyledField(
                  controller: _nameCtrl,
                  label: 'Tên người nhận',
                  icon: Icons.person_outline_rounded,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Vui lòng nhập tên người nhận';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _StyledField(
                  controller: _phoneCtrl,
                  label: 'Số điện thoại',
                  icon: Icons.phone_outlined,
                  hint: 'Nhập đủ 10 số',
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Vui lòng nhập số điện thoại';
                    }
                    if (!RegExp(r'^[0-9]{10}$').hasMatch(v)) {
                      return 'Số điện thoại phải đúng 10 chữ số';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _StyledField(
                  controller: _soNhaCtrl,
                  label: 'Số nhà (không bắt buộc)',
                  icon: Icons.home_outlined,
                ),
                const SizedBox(height: 12),
                _StyledField(
                  controller: _duongCtrl,
                  label: 'Đường',
                  icon: Icons.signpost_outlined,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Vui lòng nhập tên đường';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _StyledField(
                  controller: _phuongXaCtrl,
                  label: 'Phường / Xã',
                  icon: Icons.location_city_outlined,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Vui lòng nhập phường/xã';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _StyledField(
                  controller: _tinhTPCtrl,
                  label: 'Tỉnh / Thành phố',
                  icon: Icons.location_on_outlined,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Vui lòng nhập tỉnh/thành phố';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1F5C7A), Color(0xFF2B678B)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.discountTien > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Giá gốc',
                    style: TextStyle(color: Colors.white54, fontSize: 13)),
                Text(
                  '${_formatCurrency(widget.tongTien + widget.discountTien)} đ',
                  style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: Colors.white38),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Giảm giá',
                    style: TextStyle(color: Color(0xFFFFD54F), fontSize: 13)),
                Text(
                  '- ${_formatCurrency(widget.discountTien)} đ',
                  style: const TextStyle(
                      color: Color(0xFFFFD54F),
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(color: Colors.white24, height: 1),
            ),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TỔNG THANH TOÁN',
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                  SizedBox(height: 4),
                  Text('Đã bao gồm VAT',
                      style: TextStyle(color: Colors.white30, fontSize: 11)),
                ],
              ),
              Text(
                '${_formatCurrency(widget.tongTien)} đ',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    return amount.toInt().toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (m) => '.',
        );
  }

  Future<void> _submitOrder() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    final order = OrderRecord(
      imageId: widget.imageId,
      tongDienTich: widget.tongDienTich,
      tongTien: widget.tongTien,
      discountTien: widget.discountTien,
      tongSoTam: widget.tongSoTam,
      kichThuoc: widget.kichThuoc,
      cacMatIn: widget.cacMatIn,
      chatLieu: widget.chatLieu,
      chatLieuPerMat: widget.chatLieuPerMat,
      customerName: _nameCtrl.text.trim(),
      customerPhone: _phoneCtrl.text.trim(),
      customerAddress: _fullAddress,
      createdAt: DateTime.now(),
    );

    try {
      OrderStore.addOrder(order);
      final orderId = await OrderNotificationService.submitOrder(order);
      if (!mounted) return;

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => _InvoicePage(
            order: order,
            orderId: orderId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gửi đơn thất bại: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _buildConfirmButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 3,
          ),
          onPressed: _submitting ? null : _submitOrder,
          child: _submitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'XÁC NHẬN GỬI ĐƠN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Trang hóa đơn hiển thị sau khi đặt hàng thành công
// ─────────────────────────────────────────────────────────────

class _InvoicePage extends StatelessWidget {
  final OrderRecord order;
  final String orderId;

  const _InvoicePage({required this.order, required this.orderId});

  String _formatCurrency(double amount) {
    return amount.toInt().toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (m) => '.',
        );
  }

  String _formatDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '$d/$mo/${dt.year} • $h:$mi';
  }

  String _paintingSize(String mat) {
    final kt = order.kichThuoc;
    if (mat == 'lưng') return '${kt['D']} × ${kt['C']}';
    if (mat == 'đáy') return '${kt['D']} × ${kt['R']}';
    return '${kt['R']} × ${kt['C']}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF2B678B),
        title: const Text(
          'Hóa đơn đặt hàng',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(
          children: [
            // Success banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: Colors.green.shade600, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Đặt hàng thành công!',
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        if (orderId.isNotEmpty)
                          Text(
                            'Mã đơn: $orderId',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Invoice card
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _CardHeader(
                      icon: Icons.receipt_long, title: 'Chi tiết đơn hàng'),
                  const SizedBox(height: 12),
                  _InfoRow(label: 'Mã tranh', value: order.imageId),
                  _InfoRow(
                      label: 'Thời gian', value: _formatDate(order.createdAt)),
                  _InfoRow(
                      label: 'Số tấm', value: '${order.tongSoTam} tấm'),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(height: 1, color: Color(0xFFEEF2F5)),
                  ),
                  const _CardHeader(
                      icon: Icons.straighten_rounded,
                      title: 'Kích thước tranh (cm)'),
                  const SizedBox(height: 10),
                  ...order.cacMatIn.map(
                    (mat) => _InfoRow(
                        label: 'Mặt $mat',
                        value: '${_paintingSize(mat)} cm (${order.chatLieuPerMat[mat] ?? order.chatLieu})'),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(height: 1, color: Color(0xFFEEF2F5)),
                  ),
                  const _CardHeader(
                      icon: Icons.local_shipping_rounded,
                      title: 'Thông tin giao hàng'),
                  const SizedBox(height: 10),
                  _InfoRow(label: 'Tên', value: order.customerName),
                  _InfoRow(label: 'SĐT', value: order.customerPhone),
                  _InfoRow(label: 'Địa chỉ', value: order.customerAddress),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Total card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1F5C7A), Color(0xFF2B678B)],
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x44000000),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (order.discountTien > 0) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Giá gốc',
                            style: TextStyle(
                                color: Colors.white54, fontSize: 13)),
                        Text(
                          '${_formatCurrency(order.tongTien + order.discountTien)} đ',
                          style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                              decoration: TextDecoration.lineThrough,
                              decorationColor: Colors.white38),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Giảm giá',
                            style: TextStyle(
                                color: Color(0xFFFFD54F), fontSize: 13)),
                        Text(
                          '- ${_formatCurrency(order.discountTien)} đ',
                          style: const TextStyle(
                              color: Color(0xFFFFD54F),
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(color: Colors.white24, height: 1),
                    ),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('TỔNG THANH TOÁN',
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 12)),
                          SizedBox(height: 4),
                          Text('Đã bao gồm VAT',
                              style: TextStyle(
                                  color: Colors.white30, fontSize: 11)),
                        ],
                      ),
                      Text(
                        '${_formatCurrency(order.tongTien)} đ',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Instruction links
            _buildInstructionLinks(context),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2B678B),
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 3,
            ),
            onPressed: () =>
                appNavigatorKey.currentState?.popUntil((r) => r.isFirst),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.home_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text(
                  'Về trang chủ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionLinks(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
              icon: Icons.menu_book_rounded, title: 'Hướng dẫn dán tranh'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _LinkButton(
                  label: 'Hướng dẫn dán trong bể',
                  onTap: () => _launchInstructionUrl(context, _kDanTrongUrl),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LinkButton(
                  label: 'Hướng dẫn dán ngoài bể',
                  onTap: () => _launchInstructionUrl(context, _kDanNgoaiUrl),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LinkButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _LinkButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          border: Border.all(color: const Color(0xFFE53935)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_circle_filled_rounded,
                size: 20, color: Color(0xFFE53935)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFC62828),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Shared sub-widgets
// ─────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CardHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _CardHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFF2B678B).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: const Color(0xFF2B678B), size: 16),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1B3A4B),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(color: isDark ? Colors.white38 : Colors.black45, fontSize: 13)),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: isDark ? Colors.white : const Color(0xFF1B3A4B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StyledField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final String? Function(String?)? validator;

  const _StyledField({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
  }) : maxLines = 1;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      validator: validator,
      style: TextStyle(
          fontSize: 14,
          color: isDark ? Colors.white : const Color(0xFF1B3A4B),
          fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
            color: Color(0xFF2B678B), fontSize: 13),
        hintText: hint,
        hintStyle:
            TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 13),
        prefixIcon:
            Icon(icon, color: const Color(0xFF2B678B), size: 20),
        filled: true,
        fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF4F7F9),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFFDDE3E9), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFF2B678B), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFFE53935), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFFE53935), width: 1.5),
        ),
      ),
    );
  }
}

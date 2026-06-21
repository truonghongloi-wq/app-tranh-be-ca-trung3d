import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_globals.dart';
import '../../services/order_notification_service.dart';
import 'order_store.dart';

class CartCheckoutPage extends StatefulWidget {
  final List<CartItem> items;

  const CartCheckoutPage({super.key, required this.items});

  @override
  State<CartCheckoutPage> createState() => _CartCheckoutPageState();
}

class _CartCheckoutPageState extends State<CartCheckoutPage> {
  static const Color _primary = Color(0xFF2B678B);
  static const Color _gradientTop = Color(0xFF5CC1FF);
  static const Color _bg = Color(0xFFF4F7F9);

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

  String _formatCurrency(double amount) {
    return amount.toInt().toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (m) => '.',
        );
  }

  // Giảm giá thêm ở cấp giỏ hàng khi có 2+ tranh
  // Chỉ áp dụng cho item chưa có giảm giá từ per-product logic
  double _extraDiscountForItem(CartItem item) {
    if (item.discountTien > 0) return 0;
    if (widget.items.length <= 1) return 0;
    final chieuDai = double.tryParse(item.kichThuoc['D'] ?? '0') ?? 0;
    final rate = chieuDai <= 90 ? 0.05 : 0.10;
    return (item.tongTien - item.phiShip) * rate;
  }

  double get _cartLevelExtraDiscount =>
      widget.items.fold(0.0, (sum, item) => sum + _extraDiscountForItem(item));

  double get _cartTotal =>
      widget.items.fold(0.0, (sum, item) => sum + item.tongTien) -
      _cartLevelExtraDiscount;

  double get _cartDiscount =>
      widget.items.fold(0.0, (sum, item) => sum + item.discountTien) +
      _cartLevelExtraDiscount;

  String _getSize(CartItem item, String mat) {
    if (mat == 'lưng') return '${item.kichThuoc['D']} × ${item.kichThuoc['C']}';
    if (mat == 'đáy') return '${item.kichThuoc['D']} × ${item.kichThuoc['R']}';
    return '${item.kichThuoc['R']} × ${item.kichThuoc['C']}';
  }

  Future<void> _submitAll() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final address = _fullAddress;
    final now = DateTime.now();

    final results = <String>[];

    try {
      for (final item in widget.items) {
        final extraDiscount = _extraDiscountForItem(item);
        final record = OrderRecord(
          imageId: item.imageId,
          tongDienTich: item.tongDienTich,
          tongTien: item.tongTien - extraDiscount,
          discountTien: item.discountTien + extraDiscount,
          tongSoTam: item.tongSoTam,
          kichThuoc: item.kichThuoc,
          cacMatIn: item.cacMatIn,
          chatLieu: item.chatLieu,
          chatLieuPerMat: item.chatLieuPerMat,
          customerName: name,
          customerPhone: phone,
          customerAddress: address,
          createdAt: now,
        );
        OrderStore.addOrder(record);
        final result = await OrderNotificationService.submitOrder(record);
        results.add(result.orderId);
      }

      OrderStore.clearCart();

      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => _CartInvoicePage(
            items: widget.items,
            orderIds: results,
            customerName: name,
            customerPhone: phone,
            customerAddress: address,
            submittedAt: now,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
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
              child: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 56, bottom: 14),
                title: Text(
                  'Thanh toán giỏ hàng (${widget.items.length} sản phẩm)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCartSummary(),
                  const SizedBox(height: 16),
                  _buildDeliveryForm(),
                  const SizedBox(height: 16),
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

  Widget _buildCartSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.shopping_cart_outlined,
                    color: _primary, size: 16),
              ),
              const SizedBox(width: 10),
              const Text(
                'Sản phẩm trong giỏ',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B3A4B),
                ),
              ),
            ],
          ),
        ),
        ...widget.items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return _buildCartItemCard(i, item);
        }),
      ],
    );
  }

  Widget _buildCartItemCard(int index, CartItem item) {
    final extraDiscount = _extraDiscountForItem(item);
    final hasCartDiscount = extraDiscount > 0;
    final chieuDai = double.tryParse(item.kichThuoc['D'] ?? '0') ?? 0;
    final discountLabel = hasCartDiscount
        ? (chieuDai <= 90 ? 'Giảm 5%' : 'Giảm 10%')
        : (item.discountTien > 0
            ? (chieuDai <= 90 ? 'Giảm 5%' : 'Giảm 10%')
            : null);
    final effectiveTongTien = item.tongTien - extraDiscount;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: item.imageUrl != null
                ? Image.network(
                    item.imageUrl!,
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _thumbPlaceholder(),
                  )
                : _thumbPlaceholder(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Tranh ${item.imageId}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF1B3A4B),
                        ),
                      ),
                    ),
                    if (discountLabel != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: Colors.orange.shade300, width: 1),
                        ),
                        child: Text(
                          discountLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                ...item.cacMatIn.map((mat) => Text(
                      'Mặt $mat: ${_getSize(item, mat)} cm',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black54),
                    )),
                Text(
                  '${item.tongSoTam} tấm · ${item.chatLieu}',
                  style: const TextStyle(fontSize: 12, color: Colors.black45),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatCurrency(effectiveTongTien)} đ',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _primary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF2B678B).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: _primary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumbPlaceholder() {
    return Container(
      width: 70,
      height: 70,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF5CC1FF), Color(0xFF2B678B)],
        ),
      ),
      child: const Icon(Icons.image, color: Colors.white38, size: 28),
    );
  }

  Widget _buildDeliveryForm() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.local_shipping_rounded,
                    color: _primary, size: 16),
              ),
              const SizedBox(width: 10),
              const Text(
                'Thông tin giao hàng',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B3A4B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Nhập một lần cho tất cả sản phẩm',
            style: TextStyle(fontSize: 12, color: Colors.black38),
          ),
          const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: Column(
              children: [
                _StyledField(
                  controller: _nameCtrl,
                  label: 'Tên người nhận',
                  icon: Icons.person_outline_rounded,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Vui lòng nhập tên người nhận'
                      : null,
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
                    if (v == null || v.isEmpty) return 'Vui lòng nhập số điện thoại';
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
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Vui lòng nhập tên đường'
                      : null,
                ),
                const SizedBox(height: 12),
                _StyledField(
                  controller: _phuongXaCtrl,
                  label: 'Phường / Xã',
                  icon: Icons.location_city_outlined,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Vui lòng nhập phường/xã'
                      : null,
                ),
                const SizedBox(height: 12),
                _StyledField(
                  controller: _tinhTPCtrl,
                  label: 'Tỉnh / Thành phố',
                  icon: Icons.location_on_outlined,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Vui lòng nhập tỉnh/thành phố'
                      : null,
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
          BoxShadow(color: Color(0x44000000), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Số sản phẩm',
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
              Text('${widget.items.length} tranh',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          if (_cartDiscount > 0) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _cartLevelExtraDiscount > 0
                      ? 'Ưu đãi nhiều tranh'
                      : 'Giảm giá',
                  style: const TextStyle(
                      color: Color(0xFFFFD54F), fontSize: 13),
                ),
                Text('- ${_formatCurrency(_cartDiscount)} đ',
                    style: const TextStyle(
                        color: Color(0xFFFFD54F),
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Colors.white24, height: 1),
          ),
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
                '${_formatCurrency(_cartTotal)} đ',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade600,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 3,
          ),
          onPressed: _submitting ? null : _submitAll,
          child: _submitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_outline_rounded,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'ĐẶT TẤT CẢ (${widget.items.length} SẢN PHẨM)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Trang hóa đơn sau khi đặt thành công từ giỏ hàng
// ─────────────────────────────────────────────────────────────

class _CartInvoicePage extends StatelessWidget {
  final List<CartItem> items;
  final List<String> orderIds;
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final DateTime submittedAt;

  const _CartInvoicePage({
    required this.items,
    required this.orderIds,
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
    required this.submittedAt,
  });

  String _formatCurrency(double amount) {
    return amount.toInt().toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (m) => '.',
        );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} • ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  double get _total => items.fold(0, (s, i) => s + i.tongTien);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF2B678B),
        title: const Text(
          'Đặt hàng thành công',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(
          children: [
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
                          'Đặt ${items.length} sản phẩm thành công!',
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          _formatDate(submittedAt),
                          style: TextStyle(
                              color: Colors.green.shade700, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...items.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              final orderId = i < orderIds.length ? orderIds[i] : '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildItemInvoiceCard(item, orderId, i + 1),
              );
            }),
            const SizedBox(height: 6),
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
                      offset: Offset(0, 6)),
                ],
              ),
              child: Column(
                children: [
                  _row('Khách hàng', customerName),
                  const SizedBox(height: 4),
                  _row('SĐT', customerPhone),
                  const SizedBox(height: 4),
                  _row('Địa chỉ', customerAddress),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(color: Colors.white24, height: 1),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('TỔNG THANH TOÁN',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 12)),
                      Text(
                        '${_formatCurrency(_total)} đ',
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
                  borderRadius: BorderRadius.circular(16)),
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

  Widget _buildItemInvoiceCard(CartItem item, String orderId, int no) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF2B678B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '#$no',
                  style: const TextStyle(
                      color: Color(0xFF2B678B),
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tranh ${item.imageId}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              if (orderId.isNotEmpty)
                Text(orderId,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.black38)),
            ],
          ),
          const SizedBox(height: 8),
          ...item.cacMatIn.map((mat) {
            String size;
            if (mat == 'lưng') {
              size = '${item.kichThuoc['D']} × ${item.kichThuoc['C']} cm';
            } else if (mat == 'đáy') {
              size = '${item.kichThuoc['D']} × ${item.kichThuoc['R']} cm';
            } else {
              size = '${item.kichThuoc['R']} × ${item.kichThuoc['C']} cm';
            }
            return Text(
              'Mặt $mat: $size (${item.chatLieuPerMat[mat] ?? item.chatLieu})',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            );
          }),
          const SizedBox(height: 4),
          Text(
            '${_formatCurrency(item.tongTien)} đ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF2B678B),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 13)),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Shared field widget
// ─────────────────────────────────────────────────────────────

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
    const primary = Color(0xFF2B678B);
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF1B3A4B),
          fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: primary, fontSize: 13),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black26, fontSize: 13),
        prefixIcon: Icon(icon, color: primary, size: 20),
        filled: true,
        fillColor: const Color(0xFFF4F7F9),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDDE3E9), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE53935), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.5),
        ),
      ),
    );
  }
}

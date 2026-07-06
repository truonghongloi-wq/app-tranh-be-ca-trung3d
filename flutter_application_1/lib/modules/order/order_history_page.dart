import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/order_notification_service.dart';
import 'cart_checkout_page.dart';
import 'order_store.dart';

// TODO: Điền link hướng dẫn dán tranh thực tế vào đây
const _kDanTrongUrl = 'https://youtu.be/HPMifAo5sWI';
const _kDanNgoaiUrl = 'https://youtu.be/1JOcMpJ9o8o';

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  static const Color _primary = Color(0xFF2B678B);

  List<OrderRecord> _myOrders = <OrderRecord>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    if (mounted) setState(() => _error = null);
    try {
      final orders = await OrderNotificationService.loadMyOrders();
      if (mounted) {
        setState(() {
          _myOrders = orders;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Không tải được đơn hàng. Kéo xuống để thử lại.';
          _loading = false;
        });
      }
    }
  }

  String _formatCurrency(double amount) {
    return amount.toInt().toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '.',
    );
  }

  String _formatDate(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$day/$month/$year • $hour:$minute';
  }

  String _paintingSize(Map<String, String> kt, String mat) {
    if (mat == 'lưng') return '${kt['D']} × ${kt['C']}';
    if (mat == 'đáy') return '${kt['D']} × ${kt['R']}';
    return '${kt['R']} × ${kt['C']}';
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Giỏ hàng & Đơn đã đặt',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: _primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ValueListenableBuilder<List<CartItem>>(
        valueListenable: OrderStore.cartItems,
        builder: (context, cartItems, _) {
          final orders = _myOrders;
          final isEmpty = cartItems.isEmpty && orders.isEmpty;

          if (_loading && isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (isEmpty) {
            final emptyDark = theme.brightness == Brightness.dark;
            return RefreshIndicator(
              onRefresh: _loadOrders,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 120),
                  Icon(Icons.shopping_cart_outlined,
                      size: 64,
                      color: emptyDark ? Colors.white24 : Colors.black26),
                  const SizedBox(height: 16),
                  Text(
                    _error ?? 'Giỏ hàng trống\nChưa có đơn hàng nào.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 15,
                        color: emptyDark ? Colors.white38 : Colors.black45),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadOrders,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                // ── Giỏ hàng ──
                if (cartItems.isNotEmpty) ...[
                  _SectionHeader(
                    icon: Icons.shopping_cart_outlined,
                    title: 'Giỏ hàng',
                    badge: '${cartItems.length}',
                  ),
                  const SizedBox(height: 10),
                  ...cartItems.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _CartItemCard(
                        item: item,
                        onRemove: () => OrderStore.removeFromCart(index),
                        formatCurrency: _formatCurrency,
                        paintingSize: _paintingSize,
                      ),
                    );
                  }),
                  _buildCartTotal(context, cartItems),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),
                ],

                // ── Đơn đã đặt ──
                if (orders.isNotEmpty) ...[
                  _SectionHeader(
                    icon: Icons.receipt_long_outlined,
                    title: 'Đơn đã đặt',
                    badge: '${orders.length}',
                  ),
                  const SizedBox(height: 10),
                  ...orders.map((order) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildOrderCard(context, order),
                      )),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCartTotal(BuildContext context, List<CartItem> items) {
    final total = items.fold(0.0, (s, i) => s + i.tongTien);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tổng giỏ hàng (${items.length} sản phẩm)',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1B3A4B)),
              ),
              Text(
                '${_formatCurrency(total)} đ',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _primary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade600,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 2,
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CartCheckoutPage(items: List.from(items)),
              ),
            );
          },
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shopping_bag_outlined,
                  color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'THANH TOÁN GIỎ HÀNG',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrderCard(BuildContext context, OrderRecord order) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
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
              const Icon(Icons.receipt_long, color: _primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Đơn ${order.imageId}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Thời gian: ${_formatDate(order.createdAt)}',
              style: TextStyle(color: isDark ? Colors.white70 : null)),
          Text('Khách: ${order.customerName}',
              style: TextStyle(color: isDark ? Colors.white70 : null)),
          Text('SĐT: ${order.customerPhone}',
              style: TextStyle(color: isDark ? Colors.white70 : null)),
          Text('Địa chỉ: ${order.customerAddress}',
              style: TextStyle(color: isDark ? Colors.white70 : null)),
          Text('Số tấm: ${order.tongSoTam}',
              style: TextStyle(color: isDark ? Colors.white70 : null)),
          ...order.cacMatIn.map(
            (mat) => Text(
              'Tranh mặt $mat: ${_paintingSize(order.kichThuoc, mat)} cm (${order.chatLieuPerMat[mat] ?? order.chatLieu})',
              style: TextStyle(color: isDark ? Colors.white70 : null),
            ),
          ),
          const Divider(height: 20),
          Text(
            'Tổng tiền: ${_formatCurrency(order.tongTien)} đ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          _buildInstructionLinks(context),
        ],
      ),
    );
  }

  Widget _buildInstructionLinks(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => _launchUrl(context, _kDanTrongUrl),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              decoration: BoxDecoration(
                border: Border.all(color: _primary),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_circle_outline, size: 16, color: _primary),
                  SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'HD dán trong bể',
                      style: TextStyle(
                        color: _primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: InkWell(
            onTap: () => _launchUrl(context, _kDanNgoaiUrl),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              decoration: BoxDecoration(
                border: Border.all(color: _primary),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_circle_outline, size: 16, color: _primary),
                  SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'HD dán ngoài bể',
                      style: TextStyle(
                        color: _primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Cart item card với nút xóa
// ─────────────────────────────────────────────────────────────

class _CartItemCard extends StatelessWidget {
  final CartItem item;
  final VoidCallback onRemove;
  final String Function(double) formatCurrency;
  final String Function(Map<String, String>, String) paintingSize;

  const _CartItemCard({
    required this.item,
    required this.onRemove,
    required this.formatCurrency,
    required this.paintingSize,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
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
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _placeholder(),
                  )
                : _placeholder(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tranh ${item.imageId}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF1B3A4B),
                  ),
                ),
                const SizedBox(height: 4),
                ...item.cacMatIn.map((mat) => Text(
                      'Mặt $mat: ${paintingSize(item.kichThuoc, mat)} cm'
                      ' (${item.chatLieuPerMat[mat] ?? item.chatLieu})',
                      style: TextStyle(
                          fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
                    )),
                Text(
                  '${item.tongSoTam} tấm',
                  style: TextStyle(
                      fontSize: 12, color: isDark ? Colors.white38 : Colors.black38),
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatCurrency(item.tongTien)} đ',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2B678B),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: Colors.red, size: 22),
            tooltip: 'Xóa khỏi giỏ',
            onPressed: () {
              onRemove();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã xóa khỏi giỏ hàng'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 72,
      height: 72,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF5CC1FF), Color(0xFF2B678B)],
        ),
      ),
      child: const Icon(Icons.image, color: Colors.white38, size: 28),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String badge;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.badge,
  });

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
          child: Icon(icon, color: const Color(0xFF2B678B), size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1B3A4B),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF2B678B),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            badge,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

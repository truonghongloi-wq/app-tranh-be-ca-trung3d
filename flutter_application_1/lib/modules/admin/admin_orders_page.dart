import '../../widgets/app_icons.dart';
import 'package:flutter/material.dart';

import '../../services/order_notification_service.dart';
import '../../widgets/app_ui.dart';
import '../order/order_store.dart';
import '../order/order_widgets.dart';

/// Quản lý đơn hàng (admin): xem đơn của mọi khách theo trạng thái và
/// chuyển trạng thái: Chờ xác nhận → Chờ lấy hàng → Chờ giao hàng → Đã giao.
class AdminOrdersPage extends StatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {
  List<OrderRecord> _orders = <OrderRecord>[];
  bool _loading = true;
  String? _error;
  final Set<String> _busy = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final orders = await OrderNotificationService.loadAllOrders();
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Không tải được đơn hàng. Kéo xuống để thử lại.';
        _loading = false;
      });
    }
  }

  static String _actionLabel(String next) => switch (next) {
    OrderStatus.choLayHang => 'Xác nhận đơn',
    OrderStatus.dangGiao => 'Đã lấy hàng',
    _ => 'Đã giao hàng',
  };

  Future<void> _setStatus(OrderRecord order, String status) async {
    if (status == OrderStatus.daHuy) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Hủy đơn hàng'),
          content: Text(
            'Hủy đơn tranh ${order.imageId} của ${order.customerName}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Không'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Hủy đơn', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy.add(order.orderId!));
    try {
      await OrderNotificationService.updateStatus(order, status);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Đã chuyển sang "${OrderStatus.label(status)}".'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e is StateError ? e.message : 'Cập nhật thất bại.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
    await _load();
    if (mounted) setState(() => _busy.remove(order.orderId));
  }

  /// Nhập mã vận đơn sau khi đơn vị vận chuyển cấp mã — không tự sinh.
  Future<void> _editTracking(OrderRecord order) async {
    final result = await showDialog<({String code, String carrier})>(
      context: context,
      builder: (_) => _TrackingDialog(order: order),
    );
    if (result == null || !mounted) return;
    final code = result.code;
    final carrier = result.carrier;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy.add(order.orderId!));
    try {
      await OrderNotificationService.updateTracking(
        order,
        maVanDon: code,
        donViVanChuyen: carrier,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            code.trim().isEmpty
                ? 'Đã xóa mã vận đơn.'
                : 'Đã lưu mã vận đơn.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e is StateError ? e.message : 'Cập nhật thất bại.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
    await _load();
    if (mounted) setState(() => _busy.remove(order.orderId));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = appIsDark(context);
    return DefaultTabController(
      length: OrderStatus.all.length,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0.5,
          toolbarHeight: 60,
          backgroundColor: Theme.of(context).cardColor,
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: false,
          leading: const AppBackButton(),
          leadingWidth: 56,
          titleSpacing: 8,
          title: Text(
            'Quản lý đơn hàng',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: appTextColor(isDark),
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Tải lại',
              icon: Icon(
                PhosphorIconsRegular.arrowClockwise,
                color: appTextColor(isDark),
              ),
              onPressed: _load,
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: appAccentColor(isDark),
            unselectedLabelColor: appMutedColor(isDark),
            indicatorColor: appAccentColor(isDark),
            labelStyle: const TextStyle(fontWeight: FontWeight.w700),
            tabs: [
              for (final s in OrderStatus.all)
                Tab(
                  text:
                      '${OrderStatus.label(s)} '
                      '(${_orders.where((o) => o.status == s).length})',
                ),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  for (final s in OrderStatus.all) _buildList(s, isDark),
                ],
              ),
      ),
    );
  }

  Widget _buildList(String status, bool isDark) {
    final orders = _orders.where((o) => o.status == status).toList();
    if (orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            const SizedBox(height: 140),
            Center(
              child: Text(
                _error ?? 'Không có đơn nào.',
                style: TextStyle(color: appMutedColor(isDark)),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: orders.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final order = orders[i];
          final next = OrderStatus.next(order.status);
          final busy = _busy.contains(order.orderId);
          final finished =
              order.status == OrderStatus.daGiao ||
              order.status == OrderStatus.daHuy;
          return OrderSummaryCard(
            order: order,
            onTap: () => showOrderDetailSheet(context, order),
            header: Text(
              '${order.customerName} • ${order.customerPhone}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: appTextColor(isDark),
              ),
            ),
            actions: [
              if (busy)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else ...[
                if (order.status != OrderStatus.daHuy)
                  IconButton.outlined(
                    tooltip: order.maVanDon == null
                        ? 'Nhập mã vận đơn'
                        : 'Sửa mã vận đơn',
                    onPressed: () => _editTracking(order),
                    icon: const Icon(PhosphorIconsRegular.truck, size: 20),
                  ),
                if (!finished)
                  OutlinedButton(
                    onPressed: () => _setStatus(order, OrderStatus.daHuy),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: const Text('Hủy'),
                  ),
                if (next != null)
                  FilledButton(
                    onPressed: () => _setStatus(order, next),
                    child: Text(_actionLabel(next)),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _TrackingDialog extends StatefulWidget {
  final OrderRecord order;
  const _TrackingDialog({required this.order});

  @override
  State<_TrackingDialog> createState() => _TrackingDialogState();
}

class _TrackingDialogState extends State<_TrackingDialog> {
  late final _codeCtrl = TextEditingController(text: widget.order.maVanDon);
  late final _carrierCtrl = TextEditingController(
    text: widget.order.donViVanChuyen,
  );
  String? _codeError;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _carrierCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final code = _codeCtrl.text.trim();
    final carrier = _carrierCtrl.text.trim();
    if (code.isEmpty && carrier.isNotEmpty) {
      setState(() => _codeError = 'Nhập mã vận đơn (hoặc xóa trống cả 2 ô)');
      return;
    }
    Navigator.pop(context, (code: code, carrier: carrier));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Mã vận đơn'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _carrierCtrl,
            maxLength: 60,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Đơn vị vận chuyển',
              hintText: 'VD: GHN, GHTK, Viettel Post...',
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _codeCtrl,
            maxLength: 60,
            autofocus: widget.order.maVanDon == null,
            // Bàn phím không dấu: bộ gõ telex (Laban, Gboard tiếng Việt)
            // biến "GHNS..." thành "GHNÍ..." nếu dùng bàn phím thường.
            keyboardType: TextInputType.visiblePassword,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) {
              if (_codeError != null) setState(() => _codeError = null);
            },
            decoration: InputDecoration(
              labelText: 'Mã vận đơn',
              hintText: 'Mã do đơn vị vận chuyển cấp',
              counterText: '',
              errorText: _codeError,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
        FilledButton(onPressed: _save, child: const Text('Lưu')),
      ],
    );
  }
}

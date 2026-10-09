import '../../widgets/app_icons.dart';
import 'package:flutter/material.dart';

import '../../services/order_notification_service.dart';
import '../../widgets/app_ui.dart';
import 'order_store.dart';
import 'order_widgets.dart';

/// Tên tab trên trang "Đơn mua" (đơn đã giao hiển thị là "Đã mua").
String myOrderTabLabel(String status) =>
    status == OrderStatus.daGiao ? 'Đã mua' : OrderStatus.label(status);

const _cancelReasons = [
  'Muốn thay đổi kích thước / chất liệu',
  'Muốn đổi sang mẫu tranh khác',
  'Muốn thay đổi địa chỉ nhận hàng',
  'Đặt nhầm / trùng đơn',
  'Không còn nhu cầu mua',
  'Lý do khác',
];

/// Trang "Đơn mua" của khách: Chờ xác nhận, Chờ lấy hàng, Chờ giao hàng,
/// Đã mua, Đã hủy.
class MyOrdersPage extends StatefulWidget {
  final String initialStatus;
  const MyOrdersPage({super.key, this.initialStatus = OrderStatus.choXacNhan});

  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> {
  List<OrderRecord> _orders = <OrderRecord>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final orders = await OrderNotificationService.loadMyOrders();
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _error = null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Không tải được đơn hàng. Kéo xuống để thử lại.';
        _loading = false;
      });
    }
  }

  Future<void> _cancel(OrderRecord order) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _CancelReasonSheet(),
    );
    if (reason == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await OrderNotificationService.cancelMyOrder(order, reason);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Đã hủy đơn hàng.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text(
            'Không hủy được đơn. Có thể shop vừa xác nhận đơn này — '
            'vui lòng liên hệ shop để được hỗ trợ.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = appIsDark(context);
    return DefaultTabController(
      length: OrderStatus.all.length,
      initialIndex: OrderStatus.all.indexOf(widget.initialStatus).clamp(0, 4),
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
            'Đơn mua',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: appTextColor(isDark),
            ),
          ),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: appAccentColor(isDark),
            unselectedLabelColor: appMutedColor(isDark),
            indicatorColor: appAccentColor(isDark),
            labelStyle: const TextStyle(fontWeight: FontWeight.w700),
            tabs: [for (final s in OrderStatus.all) Tab(text: _tabText(s))],
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

  String _tabText(String status) {
    final label = myOrderTabLabel(status);
    // Chỉ hiện số đếm cho các đơn đang xử lý
    if (status == OrderStatus.daGiao || status == OrderStatus.daHuy) {
      return label;
    }
    final n = _orders.where((o) => o.status == status).length;
    return n > 0 ? '$label ($n)' : label;
  }

  Widget _buildList(String status, bool isDark) {
    final orders = _orders.where((o) => o.status == status).toList();
    if (orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 100),
            Icon(
              orderStatusIcon(status),
              size: 64,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Chưa có đơn hàng nào.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: appMutedColor(isDark)),
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
          return OrderSummaryCard(
            order: order,
            onTap: () => showOrderDetailSheet(context, order),
            actions: [
              if (order.canCancel)
                OutlinedButton(
                  onPressed: () => _cancel(order),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                  child: const Text('Hủy đơn'),
                ),
              FilledButton.tonal(
                onPressed: () => showOrderDetailSheet(context, order),
                style: FilledButton.styleFrom(
                  backgroundColor: appAccentColor(
                    isDark,
                  ).withValues(alpha: isDark ? 0.16 : 0.08),
                  foregroundColor: appAccentColor(isDark),
                ),
                child: const Text('Xem chi tiết'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CancelReasonSheet extends StatefulWidget {
  const _CancelReasonSheet();

  @override
  State<_CancelReasonSheet> createState() => _CancelReasonSheetState();
}

class _CancelReasonSheetState extends State<_CancelReasonSheet> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final isDark = appIsDark(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chọn lý do hủy đơn',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: appTextColor(isDark),
              ),
            ),
            const SizedBox(height: 8),
            for (final r in _cancelReasons)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                onTap: () => setState(() => _selected = r),
                leading: Icon(
                  _selected == r
                      ? PhosphorIconsFill.radioButton
                      : PhosphorIconsRegular.circle,
                  color: _selected == r ? Colors.red : appMutedColor(isDark),
                ),
                title: Text(r, style: TextStyle(color: appTextColor(isDark))),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _selected == null
                    ? null
                    : () => Navigator.pop(context, _selected),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Xác nhận hủy đơn'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

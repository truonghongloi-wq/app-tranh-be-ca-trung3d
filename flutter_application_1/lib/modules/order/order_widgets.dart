import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/app_ui.dart';
import 'order_store.dart';

// Widget dùng chung cho trang "Đơn mua" của khách và trang quản lý đơn của admin.

String formatOrderMoney(double amount) => amount
    .toInt()
    .toString()
    .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');

String formatOrderDate(DateTime d) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} • ${two(d.hour)}:${two(d.minute)}';
}

/// "GHN • 123456" — hoặc chỉ mã nếu chưa nhập đơn vị vận chuyển.
String orderTrackingText(OrderRecord order) => [
  if (order.donViVanChuyen != null) order.donViVanChuyen!,
  if (order.maVanDon != null) order.maVanDon!,
].join(' • ');

String orderPanelSize(Map<String, String> kt, String mat) {
  if (mat == 'lưng') return '${kt['D']} × ${kt['C']}';
  if (mat == 'đáy') return '${kt['D']} × ${kt['R']}';
  return '${kt['R']} × ${kt['C']}';
}

/// Một màu nhấn cho mọi trạng thái đang xử lý; đơn đã xong dùng màu chữ,
/// đơn đã hủy dùng màu xám — tránh bảng màu sặc sỡ.
Color orderStatusColor(String status, bool isDark) => switch (status) {
  OrderStatus.daGiao => appTextColor(isDark),
  OrderStatus.daHuy => appMutedColor(isDark),
  _ => appAccentColor(isDark),
};

IconData orderStatusIcon(String status) => switch (status) {
  OrderStatus.choLayHang => PhosphorIconsRegular.package,
  OrderStatus.dangGiao => PhosphorIconsRegular.truck,
  OrderStatus.daGiao => PhosphorIconsRegular.checkCircle,
  OrderStatus.daHuy => PhosphorIconsRegular.xCircle,
  _ => PhosphorIconsRegular.clockCountdown,
};

class OrderStatusChip extends StatelessWidget {
  final String status;
  const OrderStatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = orderStatusColor(status, appIsDark(context));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: appIsDark(context) ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        OrderStatus.label(status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Thẻ tóm tắt 1 đơn: ảnh, mã tranh, kích thước, tổng tiền, trạng thái.
class OrderSummaryCard extends StatelessWidget {
  final OrderRecord order;
  final VoidCallback? onTap;
  final Widget? header; // vd: tên khách (trang admin)
  final List<Widget> actions;

  const OrderSummaryCard({
    super.key,
    required this.order,
    this.onTap,
    this.header,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final isDark = appIsDark(context);
    final muted = TextStyle(fontSize: 12, color: appMutedColor(isDark));
    return Container(
      decoration: appCardDecoration(context, radius: 16),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child:
                          header ??
                          Text(formatOrderDate(order.createdAt), style: muted),
                    ),
                    OrderStatusChip(order.status),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 72,
                        height: 72,
                        child: order.imageUrl != null
                            ? CachedNetworkImage(
                                imageUrl: order.imageUrl!,
                                fit: BoxFit.cover,
                                errorWidget: (_, _, _) => _placeholder(isDark),
                              )
                            : _placeholder(isDark),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tranh ${order.imageId}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: appTextColor(isDark),
                            ),
                          ),
                          const SizedBox(height: 4),
                          ...order.cacMatIn.map(
                            (mat) => Text(
                              'Mặt $mat: ${orderPanelSize(order.kichThuoc, mat)} cm'
                              ' (${order.chatLieuPerMat[mat] ?? order.chatLieu})',
                              style: muted,
                            ),
                          ),
                          Text('${order.tongSoTam} tấm', style: muted),
                          if (order.maVanDon != null)
                            Text(
                              'Mã vận đơn: ${orderTrackingText(order)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: muted.copyWith(
                                fontWeight: FontWeight.w600,
                                color: appTextColor(isDark),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (header != null)
                      Text(formatOrderDate(order.createdAt), style: muted),
                    const Spacer(),
                    Text('Thành tiền: ', style: muted),
                    Text(
                      '${formatOrderMoney(order.tongTien)} đ',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        actions[i],
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder(bool isDark) => Container(
    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
    child: const Icon(PhosphorIconsRegular.image, color: AppColors.blue),
  );
}

/// Chi tiết đơn: thông tin nhận hàng + dòng thời gian trạng thái.
Future<void> showOrderDetailSheet(BuildContext context, OrderRecord order) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      final isDark = appIsDark(sheetContext);
      final text = appTextColor(isDark);
      final muted = appMutedColor(isDark);
      Widget info(IconData icon, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: muted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(value, style: TextStyle(color: text, height: 1.3)),
            ),
          ],
        ),
      );

      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Đơn tranh ${order.imageId}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: text,
                    ),
                  ),
                ),
                OrderStatusChip(order.status),
              ],
            ),
            const SizedBox(height: 12),
            _TrackingRow(order: order),
            const SizedBox(height: 20),
            Text(
              'Trạng thái đơn hàng',
              style: TextStyle(fontWeight: FontWeight.w700, color: text),
            ),
            const SizedBox(height: 12),
            OrderTimeline(order: order),
            if (order.status == OrderStatus.daHuy &&
                (order.cancelReason ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              info(
                PhosphorIconsRegular.info,
                'Lý do hủy: ${order.cancelReason}',
              ),
            ],
            const SizedBox(height: 20),
            Text(
              'Thông tin nhận hàng',
              style: TextStyle(fontWeight: FontWeight.w700, color: text),
            ),
            const SizedBox(height: 10),
            info(PhosphorIconsRegular.user, order.customerName),
            info(PhosphorIconsRegular.phone, order.customerPhone),
            info(PhosphorIconsRegular.mapPin, order.customerAddress),
            const SizedBox(height: 14),
            Text(
              'Sản phẩm',
              style: TextStyle(fontWeight: FontWeight.w700, color: text),
            ),
            const SizedBox(height: 10),
            ...order.cacMatIn.map(
              (mat) => info(
                PhosphorIconsRegular.square,
                'Mặt $mat: ${orderPanelSize(order.kichThuoc, mat)} cm'
                ' (${order.chatLieuPerMat[mat] ?? order.chatLieu})',
              ),
            ),
            info(PhosphorIconsRegular.stack, '${order.tongSoTam} tấm'),
            if (order.discountTien > 0)
              info(
                PhosphorIconsRegular.sealPercent,
                'Giảm giá: ${formatOrderMoney(order.discountTien)} đ',
              ),
            const Divider(height: 24),
            Row(
              children: [
                Text('Thành tiền', style: TextStyle(color: muted)),
                const Spacer(),
                Text(
                  '${formatOrderMoney(order.tongTien)} đ',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

/// Mã vận đơn do đơn vị vận chuyển cấp; chạm để sao chép.
class _TrackingRow extends StatefulWidget {
  final OrderRecord order;
  const _TrackingRow({required this.order});

  @override
  State<_TrackingRow> createState() => _TrackingRowState();
}

class _TrackingRowState extends State<_TrackingRow> {
  bool _copied = false;

  Future<void> _copy(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    HapticFeedback.lightImpact();
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final isDark = appIsDark(context);
    final code = order.maVanDon;
    final cancelled = order.status == OrderStatus.daHuy;
    if (code == null && cancelled) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: appAccentColor(isDark).withValues(alpha: isDark ? 0.15 : 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            PhosphorIconsRegular.truck,
            size: 20,
            color: appAccentColor(isDark),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mã vận đơn',
                  style: TextStyle(fontSize: 12, color: appMutedColor(isDark)),
                ),
                Text(
                  code == null
                      ? 'Sẽ cập nhật khi giao cho đơn vị vận chuyển'
                      : orderTrackingText(order),
                  style: TextStyle(
                    fontWeight: code == null ? FontWeight.w400 : FontWeight.w700,
                    color: code == null
                        ? appMutedColor(isDark)
                        : appTextColor(isDark),
                  ),
                ),
              ],
            ),
          ),
          if (code != null)
            IconButton(
              tooltip: _copied ? 'Đã sao chép' : 'Sao chép mã vận đơn',
              icon: Icon(
                _copied ? PhosphorIconsRegular.check : PhosphorIconsRegular.copy,
                size: 20,
                color: appAccentColor(isDark),
              ),
              onPressed: () => _copy(code),
            ),
        ],
      ),
    );
  }
}

/// Dòng thời gian dọc: Đặt hàng → Chờ lấy hàng → Chờ giao hàng → Đã giao
/// (hoặc kết thúc ở "Đã hủy").
class OrderTimeline extends StatelessWidget {
  final OrderRecord order;
  const OrderTimeline({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final isDark = appIsDark(context);
    final cancelled = order.status == OrderStatus.daHuy;
    final reached = OrderStatus.flow.indexOf(order.status);

    // Với đơn đã hủy: hiện các bước đã có mốc thời gian rồi tới "Đã hủy".
    final steps = cancelled
        ? [
            ...OrderStatus.flow.where(
              (s) => s == OrderStatus.choXacNhan || order.timeline[s] != null,
            ),
            OrderStatus.daHuy,
          ]
        : OrderStatus.flow;

    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          _step(
            context,
            isDark,
            steps[i],
            done: cancelled || OrderStatus.flow.indexOf(steps[i]) <= reached,
            isLast: i == steps.length - 1,
          ),
      ],
    );
  }

  Widget _step(
    BuildContext context,
    bool isDark,
    String status, {
    required bool done,
    required bool isLast,
  }) {
    final color = done
        ? orderStatusColor(status, isDark)
        : (isDark ? Colors.white24 : Colors.black12);
    final time = status == OrderStatus.choXacNhan
        ? (order.timeline[status] ?? order.createdAt)
        : order.timeline[status];
    final title = status == OrderStatus.choXacNhan
        ? 'Đã đặt hàng'
        : OrderStatus.label(status);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: done ? color : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Icon(
                    orderStatusIcon(status),
                    size: 15,
                    color: done ? Colors.white : color,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: color,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 4, bottom: isLast ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: done
                          ? appTextColor(isDark)
                          : appMutedColor(isDark),
                    ),
                  ),
                  if (time != null)
                    Text(
                      formatOrderDate(time),
                      style: TextStyle(
                        fontSize: 12,
                        color: appMutedColor(isDark),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

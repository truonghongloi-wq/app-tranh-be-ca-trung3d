import '../../widgets/app_icons.dart';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  static const Color _primary = Color(0xFF2563EB);
  static const Color _gradientTop = Color(0xFF5CC1FF);

  List<UserRecord> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    final users = await UserService.loadAllUsers();
    if (mounted) {
      setState(() {
        _users = users;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 110,
            pinned: true,
            floating: true,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                icon: const Icon(
                  PhosphorIconsRegular.arrowClockwise,
                  color: Colors.white,
                ),
                tooltip: 'Tải lại',
                onPressed: _loadUsers,
              ),
              IconButton(
                icon: const Icon(
                  PhosphorIconsRegular.signOut,
                  color: Colors.white,
                ),
                tooltip: 'Đăng xuất',
                onPressed: _confirmLogout,
              ),
              const SizedBox(width: 4),
            ],
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_gradientTop, _primary],
                ),
              ),
              child: const FlexibleSpaceBar(
                titlePadding: EdgeInsets.only(left: 20, bottom: 14),
                title: Text(
                  'Dashboard Quản Trị',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ),

          // Stat card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: _StatCard(count: _users.length, loading: _loading),
            ),
          ),

          // Danh sách users
          if (_loading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (_users.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: Center(
                  child: Text(
                    'Chưa có khách hàng nào.',
                    style: TextStyle(color: Colors.black45),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _UserTile(
                    record: _users[index],
                    onPricesSaved: _loadUsers,
                  ),
                  childCount: _users.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đăng xuất', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await AuthService.signOut();
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }
}

// ---------------------------------------------------------------------------

class _StatCard extends StatelessWidget {
  final int count;
  final bool loading;
  const _StatCard({required this.count, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1F5C7A), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            PhosphorIconsRegular.users,
            color: Colors.white70,
            size: 36,
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tổng khách hàng',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 4),
              loading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _UserTile extends StatelessWidget {
  final UserRecord record;
  final VoidCallback onPricesSaved;
  const _UserTile({required this.record, required this.onPricesSaved});

  @override
  Widget build(BuildContext context) {
    final date = _formatDate(record.createdAt);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.12),
          child: Text(
            _avatarChar(record),
            style: const TextStyle(
              color: Color(0xFF2563EB),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          record.displayName.isNotEmpty ? record.displayName : record.email,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          record.displayName.isNotEmpty
              ? '${record.email} · $date'
              : 'Đăng ký: $date',
          style: const TextStyle(fontSize: 12, color: Colors.black45),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _shortPrice(record.prices),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'đ/m²',
                  style: TextStyle(fontSize: 11, color: Colors.black38),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(
                PhosphorIconsRegular.trash,
                color: Colors.red,
                size: 20,
              ),
              tooltip: 'Xóa khách hàng',
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ),
        // Giá chỉ cài trên Dashboard web để không có hai nơi sửa lệch nhau.
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cài đặt giá cho khách trên Dashboard web (apptranhbeca.web.app)',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa khách hàng'),
        content: Text(
          'Xóa hẳn tài khoản đăng nhập của "${record.displayName.isNotEmpty ? record.displayName : record.email}"?\n\n'
          'Khách sẽ không đăng nhập được nữa. Lịch sử đơn hàng vẫn được giữ lại.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final success = await UserService.deleteCustomer(record.uid);
    if (!context.mounted) return;
    if (success) {
      onPricesSaved();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã xóa khách hàng')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Xóa thất bại, vui lòng thử lại'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _avatarChar(UserRecord r) {
    if (r.displayName.isNotEmpty) return r.displayName[0].toUpperCase();
    if (r.email.isNotEmpty) return r.email[0].toUpperCase();
    return '?';
  }

  String _shortPrice(PriceConfig p) {
    if (p.giaSi != null && p.giaSi! > 0) return '${_fmt(p.giaSi!)} (sỉ)';
    final vals = [p.p1, p.p2, p.p3, p.p4, p.p5];
    final lo = vals.reduce((a, b) => a < b ? a : b);
    final hi = vals.reduce((a, b) => a > b ? a : b);
    if (lo == hi) return _fmt(lo);
    return '${_fmt(lo)}–${_fmt(hi)}';
  }

  String _fmt(double v) => v.toInt().toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );

  String _formatDate(String iso) {
    if (iso.isEmpty) return '—';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year}';
    } catch (_) {
      return iso.substring(0, 10);
    }
  }
}

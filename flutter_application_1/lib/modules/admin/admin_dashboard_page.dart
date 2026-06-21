import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  static const Color _primary = Color(0xFF2B678B);
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
    if (mounted) setState(() { _users = users; _loading = false; });
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
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                tooltip: 'Tải lại',
                onPressed: _loadUsers,
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
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
              child: const Text('Hủy')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Đăng xuất',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) await AuthService.signOut();
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
          colors: [Color(0xFF1F5C7A), Color(0xFF2B678B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.people_alt_rounded, color: Colors.white70, size: 36),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tổng khách hàng',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 4),
              loading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text(
                      '$count',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold),
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
          BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 2))
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF2B678B).withValues(alpha: 0.12),
          child: Text(
            _avatarChar(record),
            style: const TextStyle(
                color: Color(0xFF2B678B), fontWeight: FontWeight.bold),
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
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _shortPrice(record.prices),
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF2B678B),
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            const Text('đ/m²', style: TextStyle(fontSize: 11, color: Colors.black38)),
          ],
        ),
        onTap: () => _openEditSheet(context),
      ),
    );
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
      RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');

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

  void _openEditSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PriceEditSheet(
        record: record,
        onSaved: onPricesSaved,
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _PriceEditSheet extends StatefulWidget {
  final UserRecord record;
  final VoidCallback onSaved;
  const _PriceEditSheet({required this.record, required this.onSaved});

  @override
  State<_PriceEditSheet> createState() => _PriceEditSheetState();
}

class _PriceEditSheetState extends State<_PriceEditSheet> {
  static const Color _primary = Color(0xFF2B678B);

  late final TextEditingController _cSi;
  late final TextEditingController _c1;
  late final TextEditingController _c2;
  late final TextEditingController _c3;
  late final TextEditingController _c4;
  late final TextEditingController _c5;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.record.prices;
    _cSi = TextEditingController(
        text: p.giaSi != null ? p.giaSi!.toInt().toString() : '');
    _c1 = TextEditingController(text: p.p1.toInt().toString());
    _c2 = TextEditingController(text: p.p2.toInt().toString());
    _c3 = TextEditingController(text: p.p3.toInt().toString());
    _c4 = TextEditingController(text: p.p4.toInt().toString());
    _c5 = TextEditingController(text: p.p5.toInt().toString());
  }

  @override
  void dispose() {
    _cSi.dispose();
    _c1.dispose(); _c2.dispose(); _c3.dispose(); _c4.dispose(); _c5.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final giaSiVal = _cSi.text.trim().isEmpty
        ? null
        : double.tryParse(_cSi.text.trim());
    final prices = PriceConfig(
      giaSi: giaSiVal,
      p1: double.tryParse(_c1.text) ?? widget.record.prices.p1,
      p2: double.tryParse(_c2.text) ?? widget.record.prices.p2,
      p3: double.tryParse(_c3.text) ?? widget.record.prices.p3,
      p4: double.tryParse(_c4.text) ?? widget.record.prices.p4,
      p5: double.tryParse(_c5.text) ?? widget.record.prices.p5,
    );
    final ok = await UserService.updateUserPrices(widget.record.uid, prices);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      widget.onSaved();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã lưu bảng giá'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lưu thất bại, vui lòng thử lại'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.tune_rounded, color: _primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Cài đặt bảng giá',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF1B3A4B))),
                        Text(widget.record.email,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black45)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  // --- Giá sỉ ---
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F4FD),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _primary.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.sell_rounded, size: 16, color: _primary),
                            SizedBox(width: 6),
                            Text(
                              'Giá sỉ (ưu tiên cao nhất)',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: _primary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Nếu nhập giá sỉ, công thức = m² × giá sỉ + phí ship.\nĐể trống để dùng bảng giá bậc thang bên dưới.',
                          style: TextStyle(fontSize: 11, color: Colors.black54),
                        ),
                        const SizedBox(height: 10),
                        _priceField('Giá sỉ cố định', _cSi, hint: 'Để trống nếu không áp dụng'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Bảng giá bậc thang (VND/m²) theo kích thước bể',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  _priceField('Bể ≤ 60 cm', _c1),
                  _priceField('Bể ≤ 80 cm', _c2),
                  _priceField('Bể ≤ 90 cm', _c3),
                  _priceField('Bể ≤ 99 cm', _c4),
                  _priceField('Bể ≥ 100 cm', _c5),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 2,
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5))
                          : const Text('LƯU BẢNG GIÁ',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  letterSpacing: 0.5)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _priceField(String label, TextEditingController ctrl, {String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2B678B))),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF4F7F9),
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 13, color: Colors.black26),
              suffixText: 'đ/m²',
              suffixStyle:
                  const TextStyle(fontSize: 13, color: Colors.black38),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _primary, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

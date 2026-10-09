import '../../widgets/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app_globals.dart';
import '../../services/user_service.dart';
import '../composite/composite_screen.dart';
import '../order/order_confirmation_page.dart';
import '../order/order_history_page.dart';
import '../order/order_store.dart';
import '../../widgets/app_ui.dart';

class ProductDetailPage extends StatefulWidget {
  final String imageId;
  final String? imageUrl;
  final double pricePerM2;
  final String initialSize;

  const ProductDetailPage({
    super.key,
    required this.imageId,
    this.imageUrl,
    required this.pricePerM2,
    this.initialSize = '60x30',
  });

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  static const Color _primary = Color(0xFF2563EB);

  final Map<String, String?> selectedFacesData = {
    'Mặt lưng': 'Tranh dán ngoài',
    'Mặt đáy': null,
    'Hông trái': null,
    'Hông phải': null,
  };

  PriceConfig _priceConfig = PriceConfig.defaults;

  late double chieuDai;
  late double chieuCao;
  late double chieuRong;
  bool _showDimErrors = false;
  int soLuongSi = 1;
  String chatLieu = 'Tranh dán ngoài';

  final List<String> _chatLieuOptions = const [
    'Tranh dán ngoài',
    'Tranh dán trong',
  ];

  late final TextEditingController _daiController;
  late final TextEditingController _caoController;
  late final TextEditingController _rongController;
  late final TextEditingController _soLuongController;

  @override
  void initState() {
    super.initState();
    // Khách bắt buộc tự nhập kích thước bể, không điền sẵn để tránh hiểu nhầm giá
    chieuDai = 0;
    chieuCao = 0;
    chieuRong = 0;

    _daiController = TextEditingController();
    _caoController = TextEditingController();
    _rongController = TextEditingController();
    _soLuongController = TextEditingController(text: soLuongSi.toString());

    UserService.loadCurrentUserPrices().then((cfg) {
      if (mounted) setState(() => _priceConfig = cfg);
    });
  }

  @override
  void dispose() {
    _daiController.dispose();
    _caoController.dispose();
    _rongController.dispose();
    _soLuongController.dispose();
    super.dispose();
  }

  bool _isFaceSelected(String faceName) => selectedFacesData[faceName] != null;

  String _displayFaceName(String faceName) {
    switch (faceName) {
      case 'Mặt lưng':
        return 'lưng';
      case 'Mặt đáy':
        return 'đáy';
      case 'Hông trái':
        return 'hông trái';
      case 'Hông phải':
        return 'hông phải';
      default:
        return faceName;
    }
  }

  bool get _hasDims => chieuDai > 0 && chieuRong > 0 && chieuCao > 0;

  bool _validateDims() {
    if (_hasDims) return true;
    setState(() => _showDimErrors = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Vui lòng nhập đủ kích thước bể (dài, rộng, cao)'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return false;
  }

  int get soTamTichChon =>
      selectedFacesData.values.where((m) => m != null).length;

  int get tongSoTam => soTamTichChon * soLuongSi;

  double get tongDienTich {
    double d = 0;
    if (_isFaceSelected('Mặt lưng')) d += chieuDai * chieuCao;
    if (_isFaceSelected('Mặt đáy')) d += chieuDai * chieuRong;
    if (_isFaceSelected('Hông trái')) d += chieuRong * chieuCao;
    if (_isFaceSelected('Hông phải')) d += chieuRong * chieuCao;
    return (d / 10000) * soLuongSi;
  }

  double get donGia => _priceConfig.priceFor(chieuDai);

  double get phiShip {
    if (_priceConfig.isWholesale) return _priceConfig.phiShipSi ?? 0;
    // Kích thước >= 100cm: luôn +40k ship bất kể số lượng
    if (chieuDai >= 100) return 40000;
    // Kích thước < 100cm: miễn ship nếu lấy >= 2 tấm
    return tongSoTam >= 2 ? 0 : 35000;
  }

  double get discountPercent {
    if (_priceConfig.isWholesale) return 0;
    if (tongSoTam >= 2) {
      return chieuDai <= 90 ? 0.05 : 0.10;
    }
    return 0;
  }

  double get subtotalTruocGiam => tongDienTich * donGia;
  double get discountAmount => subtotalTruocGiam * discountPercent;
  double get thanhTien => subtotalTruocGiam - discountAmount + phiShip;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPreviewCard(),
                  const SizedBox(height: 8),
                  _buildViewOnTankButton(),
                  const SizedBox(height: 12),
                  _buildSection(
                    icon: PhosphorIconsRegular.ruler,
                    title: '1. Kích thước bể (cm) *',
                    subtitle: 'Bắt buộc: đo kích thước thực tế bể của bạn',
                    child: _buildDimensionInputs(),
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    icon: PhosphorIconsRegular.squaresFour,
                    title: '2. Chọn mặt cần in',
                    subtitle: 'Chọn những mặt bạn muốn in tranh',
                    child: _buildFaceSelector(),
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    icon: PhosphorIconsRegular.slidersHorizontal,
                    title: '3. Tùy chọn thêm',
                    child: _buildExtraOptions(),
                  ),
                  const SizedBox(height: 20),
                  _buildSummaryCard(),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildOrderButton(),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return const AppSubHeader(title: 'Cấu hình tranh');
  }

  Widget _buildPreviewCard() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F2563EB),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            widget.imageUrl != null
                ? Image.network(
                    widget.imageUrl!,
                    width: double.infinity,
                    height: 230,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        width: double.infinity,
                        height: 230,
                        color: const Color(0xFFEFF6FF),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: _primary,
                            strokeWidth: 2.5,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (_, _, _) => _placeholder(),
                  )
                : _placeholder(),

            // bottom gradient
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 80,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xCC000000)],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: double.infinity,
      height: 230,
      color: const Color(0xFFEFF6FF),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            PhosphorIconsRegular.image,
            size: 64,
            color: Color(0x992563EB),
          ),
          const SizedBox(height: 10),
          Text(
            widget.imageId,
            style: const TextStyle(
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewOnTankButton() {
    if (widget.imageUrl == null) return const SizedBox();
    return OutlinedButton.icon(
      icon: const Icon(PhosphorIconsRegular.magicWand),
      label: const Text('Xem thử trên bể nhà bạn'),
      onPressed: () async {
        if (!_validateDims()) return;
        final selectedFaces = selectedFacesData.entries
            .where((e) => e.value != null)
            .map((e) => _displayFaceName(e.key))
            .toList();
        if (selectedFaces.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vui lòng chọn ít nhất 1 mặt cần in trước'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
        final materials = selectedFacesData.values
            .whereType<String>()
            .toSet()
            .join(', ');
        final tried = await Navigator.push<bool?>(
          context,
          MaterialPageRoute(
            builder: (_) => CompositeScreen(
              paintingUrl: widget.imageUrl!,
              imageId: widget.imageId,
              imageUrl: widget.imageUrl,
              tongDienTich: tongDienTich,
              tongTien: thanhTien,
              tongSoTam: tongSoTam,
              chatLieu: materials.isEmpty ? chatLieu : materials,
              cacMatIn: selectedFaces,
              kichThuoc: {
                'D': _daiController.text,
                'R': _rongController.text,
                'C': _caoController.text,
              },
            ),
          ),
        );
        if (tried == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Đã xem thử — nhập kích thước và chọn mặt in rồi đặt đơn',
              ),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 4),
            ),
          );
        }
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: _primary,
        minimumSize: const Size.fromHeight(44),
        side: const BorderSide(color: _primary),
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x122563EB),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: _primary, size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.ink,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : Colors.black45,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildDimensionInputs() {
    return Row(
      children: [
        Expanded(
          child: _dimField(
            label: 'Dài',
            controller: _daiController,
            onChanged: (v) =>
                setState(() => chieuDai = double.tryParse(v) ?? 0),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _dimField(
            label: 'Rộng',
            controller: _rongController,
            onChanged: (v) =>
                setState(() => chieuRong = double.tryParse(v) ?? 0),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _dimField(
            label: 'Cao',
            controller: _caoController,
            onChanged: (v) =>
                setState(() => chieuCao = double.tryParse(v) ?? 0),
          ),
        ),
      ],
    );
  }

  Widget _dimField({
    required String label,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2563EB),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.ink,
          ),
          decoration: InputDecoration(
            hintText: 'Nhập',
            hintStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white30 : Colors.black26,
            ),
            filled: true,
            fillColor: isDark
                ? const Color(0xFF2A2A2A)
                : const Color(0xFFF4F7F9),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  _showDimErrors && (double.tryParse(controller.text) ?? 0) <= 0
                  ? BorderSide(color: Colors.red.shade400, width: 1.5)
                  : BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 8,
            ),
            suffix: const Text(
              'cm',
              style: TextStyle(fontSize: 11, color: Colors.black38),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _primary, width: 1.5),
            ),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildFaceSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: selectedFacesData.keys.map((faceName) {
        final isSelected = _isFaceSelected(faceName);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() {
              selectedFacesData[faceName] = isSelected ? null : chatLieu;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark
                          ? const Color(0xFF1A3A4B)
                          : const Color(0xFFE8F4FD))
                    : (isDark
                          ? const Color(0xFF2A2A2A)
                          : const Color(0xFFF8FAFB)),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? _primary
                      : (isDark ? Colors.white12 : const Color(0xFFDDE3E9)),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected
                        ? PhosphorIconsFill.checkSquare
                        : PhosphorIconsRegular.square,
                    color: isSelected ? _primary : Colors.black26,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      faceName,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected
                            ? (isDark ? Colors.white : AppColors.ink)
                            : (isDark ? Colors.white54 : Colors.black54),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (isSelected)
                    DropdownButton<String>(
                      value: selectedFacesData[faceName],
                      underline: const SizedBox(),
                      icon: const Icon(
                        PhosphorIconsRegular.caretDown,
                        size: 18,
                        color: _primary,
                      ),
                      style: const TextStyle(
                        color: _primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      items: _chatLieuOptions
                          .map(
                            (v) => DropdownMenuItem(value: v, child: Text(v)),
                          )
                          .toList(),
                      onChanged: (newVal) => setState(() {
                        selectedFacesData[faceName] = newVal;
                        if (newVal != null) chatLieu = newVal;
                      }),
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExtraOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            'Số bộ',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.ink,
            ),
          ),
        ),
        _QtyButton(
          icon: PhosphorIconsRegular.minus,
          onTap: () {
            if (soLuongSi <= 1) return;
            setState(() {
              soLuongSi--;
              _soLuongController.text = soLuongSi.toString();
            });
          },
        ),
        SizedBox(
          width: 52,
          child: TextField(
            controller: _soLuongController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.ink,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: isDark
                  ? const Color(0xFF2A2A2A)
                  : const Color(0xFFF4F7F9),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _primary),
              ),
            ),
            onChanged: (v) {
              final parsed = int.tryParse(v);
              setState(
                () => soLuongSi = (parsed == null || parsed < 1) ? 1 : parsed,
              );
            },
          ),
        ),
        _QtyButton(
          icon: PhosphorIconsRegular.plus,
          onTap: () {
            setState(() {
              soLuongSi++;
              _soLuongController.text = soLuongSi.toString();
            });
          },
        ),
      ],
    );
  }

  String _faceDimensions(String faceName) {
    final d = chieuDai.toInt();
    final r = chieuRong.toInt();
    final c = chieuCao.toInt();
    switch (faceName) {
      case 'Mặt lưng':
        return '$d×$c cm';
      case 'Mặt đáy':
        return '$d×$r cm';
      case 'Hông trái':
      case 'Hông phải':
        return '$r×$c cm';
      default:
        return '';
    }
  }

  Widget _buildSummaryCard() {
    final hasSelection = soTamTichChon > 0 && _hasDims;
    final selectedFaces = selectedFacesData.keys
        .where((k) => _isFaceSelected(k))
        .toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x402563EB),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                PhosphorIconsRegular.receipt,
                color: Colors.white70,
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'Tóm tắt đơn hàng',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (hasSelection) ...[
            for (final face in selectedFaces)
              _summaryRow(
                '$face · ${selectedFacesData[face]}',
                _faceDimensions(face),
              ),
            _summaryRow('Số lượng', '$tongSoTam tấm'),
            if (discountAmount > 0) ...[
              _summaryRow(
                'Giá gốc',
                '${_formatCurrency(subtotalTruocGiam + phiShip)} đ',
                lineThrough: true,
              ),
              _summaryRow(
                'Giảm giá',
                '- ${_formatCurrency(discountAmount)} đ',
                valueColor: Colors.white,
              ),
            ],
          ] else if (!_hasDims)
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    PhosphorIconsRegular.info,
                    color: Colors.white,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Nhập đủ kích thước bể (dài, rộng, cao) để xem giá',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            _summaryRow('Số lượng', '—'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Colors.white24, height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'TỔNG TIỀN',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                hasSelection ? '${_formatCurrency(thanhTien)} đ' : '—',
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

  Widget _summaryRow(
    String label,
    String value, {
    Color? valueColor,
    bool lineThrough = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          Text(
            value,
            style: TextStyle(
              color:
                  valueColor ?? (lineThrough ? Colors.white54 : Colors.white),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              decoration: lineThrough ? TextDecoration.lineThrough : null,
              decorationColor: Colors.white38,
            ),
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

  Map<String, dynamic> _buildOrderParams() {
    final selectedFaces = selectedFacesData.entries
        .where((e) => e.value != null)
        .map((e) => _displayFaceName(e.key))
        .toList();
    final materials = selectedFacesData.values.whereType<String>().toSet().join(
      ', ',
    );
    final chatLieuPerMat = {
      for (final e in selectedFacesData.entries)
        if (e.value != null) _displayFaceName(e.key): e.value!,
    };
    return {
      'selectedFaces': selectedFaces,
      'materials': materials.isEmpty ? chatLieu : materials,
      'chatLieuPerMat': chatLieuPerMat,
    };
  }

  bool _validateSelection() {
    final hasSelection = selectedFacesData.values.any((v) => v != null);
    if (!hasSelection) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ít nhất 1 mặt cần in'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return hasSelection;
  }

  Widget _buildOrderButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.blue,
                minimumSize: const Size(double.infinity, 50),
                side: const BorderSide(color: AppColors.blue, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () {
                if (!_validateDims() || !_validateSelection()) return;
                final params = _buildOrderParams();
                final item = CartItem(
                  imageId: widget.imageId,
                  imageUrl: widget.imageUrl,
                  tongDienTich: tongDienTich,
                  tongTien: thanhTien,
                  discountTien: discountAmount,
                  phiShip: phiShip,
                  tongSoTam: tongSoTam,
                  chatLieu: params['materials'] as String,
                  chatLieuPerMat:
                      params['chatLieuPerMat'] as Map<String, String>,
                  cacMatIn: params['selectedFaces'] as List<String>,
                  kichThuoc: {
                    'D': _daiController.text,
                    'R': _rongController.text,
                    'C': _caoController.text,
                  },
                  addedAt: DateTime.now(),
                );
                OrderStore.addToCart(item);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Đã thêm vào giỏ hàng'),
                    behavior: SnackBarBehavior.floating,
                    action: SnackBarAction(
                      label: 'Xem giỏ',
                      onPressed: () {
                        appNavigatorKey.currentState?.push(
                          MaterialPageRoute(
                            builder: (_) => const OrderHistoryPage(),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(PhosphorIconsRegular.shoppingCart, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'THÊM VÀO GIỎ HÀNG',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 3,
              ),
              onPressed: () {
                if (!_validateDims() || !_validateSelection()) return;
                final params = _buildOrderParams();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrderConfirmationPage(
                      imageId: widget.imageId,
                      imageUrl: widget.imageUrl,
                      tongDienTich: tongDienTich,
                      tongTien: thanhTien,
                      discountTien: discountAmount,
                      tongSoTam: tongSoTam,
                      chatLieu: params['materials'] as String,
                      chatLieuPerMat:
                          params['chatLieuPerMat'] as Map<String, String>,
                      cacMatIn: params['selectedFaces'] as List<String>,
                      kichThuoc: {
                        'D': _daiController.text,
                        'R': _rongController.text,
                        'C': _caoController.text,
                      },
                    ),
                  ),
                );
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    PhosphorIconsRegular.printer,
                    color: Colors.white,
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'ĐẶT IN NGAY',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
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
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF2563EB).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF2563EB)),
      ),
    );
  }
}

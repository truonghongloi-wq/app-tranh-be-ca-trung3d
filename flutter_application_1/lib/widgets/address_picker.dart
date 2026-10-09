import 'dart:convert';

import 'app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_ui.dart';

/// Danh sách tỉnh/thành và phường/xã sau sáp nhập 1/7/2025 (34 tỉnh, 3.321 phường/xã).
/// Nguồn: provinces.open-api.vn v2, đóng gói sẵn ở assets/data/vn_dvhc_2025.json.
class VnAddressData {
  static Map<String, List<String>>? _cache;

  static Future<Map<String, List<String>>> load() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/data/vn_dvhc_2025.json');
    final list = jsonDecode(raw) as List;
    _cache = {
      for (final p in list)
        p['n'] as String: (p['w'] as List).cast<String>()
          ..sort((a, b) => _plain(a).compareTo(_plain(b))),
    };
    return _cache!;
  }
}

const _accents = {
  'a': 'àáạảãâầấậẩẫăằắặẳẵ',
  'e': 'èéẹẻẽêềếệểễ',
  'i': 'ìíịỉĩ',
  'o': 'òóọỏõôồốộổỗơờớợởỡ',
  'u': 'ùúụủũưừứựửữ',
  'y': 'ỳýỵỷỹ',
  'd': 'đ',
};

/// Bỏ dấu tiếng Việt để tìm kiếm ("thu duc" khớp "Thủ Đức").
String _plain(String s) {
  var out = s.toLowerCase();
  _accents.forEach((base, chars) {
    for (final c in chars.split('')) {
      out = out.replaceAll(c, base);
    }
  });
  return out;
}

/// Hai ô Tỉnh/Thành phố → Phường/Xã, chỉ chọn theo danh sách (không gõ tay).
/// Giá trị lưu thẳng vào [provinceCtrl], [wardCtrl] để form cũ dùng như trước.
class AddressPickerFields extends StatefulWidget {
  final TextEditingController provinceCtrl;
  final TextEditingController wardCtrl;
  const AddressPickerFields({
    super.key,
    required this.provinceCtrl,
    required this.wardCtrl,
  });

  @override
  State<AddressPickerFields> createState() => _AddressPickerFieldsState();
}

class _AddressPickerFieldsState extends State<AddressPickerFields> {
  Map<String, List<String>>? _data;

  @override
  void initState() {
    super.initState();
    VnAddressData.load().then((d) {
      if (mounted) setState(() => _data = d);
    });
    widget.provinceCtrl.addListener(_refresh);
    widget.wardCtrl.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.provinceCtrl.removeListener(_refresh);
    widget.wardCtrl.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  List<String> get _wardsOfProvince =>
      _data?[widget.provinceCtrl.text.trim()] ?? const [];

  Future<void> _pickProvince() async {
    final data = _data;
    if (data == null) return;
    final picked = await _showPicker(
      title: 'Chọn Tỉnh / Thành phố',
      options: data.keys.toList(),
      selected: widget.provinceCtrl.text.trim(),
    );
    if (picked == null || picked == widget.provinceCtrl.text.trim()) return;
    widget.provinceCtrl.text = picked;
    // Đổi tỉnh: phường/xã cũ không còn thuộc tỉnh mới
    if (!(data[picked] ?? const []).contains(widget.wardCtrl.text.trim())) {
      widget.wardCtrl.clear();
    }
  }

  Future<void> _pickWard() async {
    final wards = _wardsOfProvince;
    if (wards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn Tỉnh / Thành phố trước'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final picked = await _showPicker(
      title: 'Chọn Phường / Xã',
      options: wards,
      selected: widget.wardCtrl.text.trim(),
    );
    if (picked != null) widget.wardCtrl.text = picked;
  }

  Future<String?> _showPicker({
    required String title,
    required List<String> options,
    required String selected,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) =>
          _PickerSheet(title: title, options: options, selected: selected),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Column(
      children: [
        _PickerField(
          controller: widget.provinceCtrl,
          label: 'Tỉnh / Thành phố',
          icon: PhosphorIconsRegular.mapPin,
          onTap: _pickProvince,
          validator: (v) {
            final value = v?.trim() ?? '';
            if (value.isEmpty) return 'Vui lòng chọn tỉnh/thành phố';
            if (data != null && !data.containsKey(value)) {
              return 'Địa chỉ cũ, vui lòng chọn lại theo danh sách mới';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        _PickerField(
          controller: widget.wardCtrl,
          label: 'Phường / Xã',
          icon: PhosphorIconsRegular.buildings,
          onTap: _pickWard,
          validator: (v) {
            final value = v?.trim() ?? '';
            if (value.isEmpty) return 'Vui lòng chọn phường/xã';
            if (data != null && !_wardsOfProvince.contains(value)) {
              return 'Địa chỉ cũ, vui lòng chọn lại theo danh sách mới';
            }
            return null;
          },
        ),
      ],
    );
  }
}

class _PickerField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final String? Function(String?) validator;
  const _PickerField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.onTap,
    required this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = appIsDark(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    );
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: onTap,
      validator: validator,
      style: TextStyle(
        fontSize: 14,
        color: appTextColor(isDark),
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.blue, fontSize: 13),
        hintText: 'Chạm để chọn',
        prefixIcon: Icon(icon, color: AppColors.blue, size: 20),
        suffixIcon: Icon(
          PhosphorIconsRegular.caretDown,
          color: appMutedColor(isDark),
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF4F7F9),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 12,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.blue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
        ),
      ),
    );
  }
}

class _PickerSheet extends StatefulWidget {
  final String title;
  final List<String> options;
  final String selected;
  const _PickerSheet({
    required this.title,
    required this.options,
    required this.selected,
  });

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  late final List<String> _plainOptions = widget.options.map(_plain).toList();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final isDark = appIsDark(context);
    final q = _plain(_query.trim());
    final results = <String>[
      for (var i = 0; i < widget.options.length; i++)
        if (q.isEmpty || _plainOptions[i].contains(q)) widget.options[i],
    ];
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          children: [
            Text(
              widget.title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: appTextColor(isDark),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                autofocus: false,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Tìm nhanh (gõ không dấu cũng được)',
                  prefixIcon: Icon(
                    PhosphorIconsRegular.magnifyingGlass,
                    color: appAccentColor(isDark),
                  ),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF2A2A2A)
                      : const Color(0xFFF4F7F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Text(
                        'Không tìm thấy',
                        style: TextStyle(color: appMutedColor(isDark)),
                      ),
                    )
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (_, i) {
                        final name = results[i];
                        final isSelected = name == widget.selected;
                        return ListTile(
                          title: Text(
                            name,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? appAccentColor(isDark)
                                  : appTextColor(isDark),
                            ),
                          ),
                          trailing: isSelected
                              ? Icon(
                                  PhosphorIconsRegular.check,
                                  color: appAccentColor(isDark),
                                )
                              : null,
                          onTap: () => Navigator.pop(context, name),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

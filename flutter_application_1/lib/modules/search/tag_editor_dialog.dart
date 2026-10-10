import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../services/painting_search_service.dart';
import '../../widgets/app_icons.dart';

/// Admin sửa từ khóa tìm kiếm của 1 tranh. Trả về true nếu đã lưu.
Future<bool?> showTagEditorDialog(BuildContext context, PaintingEntry p) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _TagEditorDialog(painting: p),
  );
}

class _TagEditorDialog extends StatefulWidget {
  final PaintingEntry painting;
  const _TagEditorDialog({required this.painting});

  @override
  State<_TagEditorDialog> createState() => _TagEditorDialogState();
}

class _TagEditorDialogState extends State<_TagEditorDialog> {
  late final List<String> _tags = [...widget.painting.tags];
  final _ctrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // Thêm 1 hoặc nhiều từ khóa (cách nhau bởi dấu phẩy)
  void _addFromInput() {
    final parts = _ctrl.text
        .split(',')
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.isNotEmpty && !_tags.contains(t));
    setState(() {
      _tags.addAll(parts);
      _ctrl.clear();
    });
  }

  Future<void> _save() async {
    _addFromInput();
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await PaintingSearchService.saveTags(
      widget.painting.code,
      _tags,
    );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Từ khóa tranh T-${widget.painting.code}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: widget.painting.url,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Khách gõ một phần từ khóa (không cần dấu) sẽ thấy gợi ý, '
              'vd: gõ "hoa" → gợi ý "hoa sen".',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in _tags)
                  InputChip(
                    label: Text(t),
                    onDeleted: _saving
                        ? null
                        : () => setState(() => _tags.remove(t)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _ctrl,
              enabled: !_saving,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _addFromInput(),
              decoration: InputDecoration(
                hintText: 'Thêm từ khóa, vd: hoa sen, cá koi',
                border: const OutlineInputBorder(),
                isDense: true,
                errorText: _error,
                suffixIcon: IconButton(
                  icon: const Icon(PhosphorIconsRegular.plus),
                  onPressed: _saving ? null : _addFromInput,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Lưu'),
        ),
      ],
    );
  }
}

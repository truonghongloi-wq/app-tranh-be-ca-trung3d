import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;

// Truyền API key qua: --dart-define=GEMINI_API_KEY=AIza...
const String _kGeminiKey =
    String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

const String _kSystemPrompt =
    'Bạn là trợ lý bán hàng thân thiện của cửa hàng "Tranh Bể Cá Trung 3D" '
    '– chuyên cung cấp tranh dán 3D tùy chỉnh kích thước cho bể cá. '
    'Hãy luôn trả lời bằng tiếng Việt, ngắn gọn và nhiệt tình.\n\n'
    '"Nếu khách hàng ưng ý hãy gợi ý đặt hàng ngay bằng cách hướng dẫn họ mở app, chọn tranh, nhập kích thước, chọn mặt dán và điền thông tin liên hệ để xác nhận đơn."\n\n'
    'Nếu khách hỏi về sản phẩm, giá cả, cách đặt hàng hoặc bất kỳ thắc mắc nào liên quan, hãy trả lời dựa trên thông tin dưới đây:\n\n'
    '=== SẢN PHẨM ===\n'
    'Tranh 3D dán vào mặt trong/ngoài bể cá, tùy chỉnh theo kích thước (chiều dài × chiều cao × chiều rộng, cm).\n'
    'Các mặt có thể dán:\n'
    '  • Mặt lưng  (dài × cao)\n'
    '  • Mặt đáy   (dài × rộng)\n'
    '  • Hông trái (rộng × cao)\n'
    '  • Hông phải (rộng × cao)\n'
    'Chất liệu: "Trong nhà" (màu sắc nét, bền trong nước) / "Ngoài trời" (chống UV, bền hơn).\n\n'
    '=== BẢNG GIÁ (VND/m²) ===\n'
    'Chiều dài bể ≤ 40 cm  → 500,000 VND/m²\n'
    'Chiều dài bể ≤ 60 cm  → 480,000 VND/m²\n'
    'Chiều dài bể ≤ 100 cm → 350,000 VND/m²\n'
    'Chiều dài bể ≤ 120 cm → 300,000 VND/m²\n'
    'Chiều dài bể > 120 cm → 230,000 VND/m²\n'
    'Phí ship: +40,000 VND khi chiều dài > 120 cm (miễn phí nếu ≤ 120 cm).\n\n'
    '=== CÁCH TÍNH GIÁ ===\n'
    '1. Xác định đơn giá theo chiều dài bể.\n'
    '2. Tính diện tích từng mặt (cm²) ÷ 10,000 = m².\n'
    '3. Thành tiền = tổng m² × đơn giá + phí ship.\n\n'
    'Ví dụ: Bể 120×60×40 cm, dán Mặt lưng (120×60 = 0.72 m²):\n'
    '  → 0.72 × 300,000 = 216,000 VND (miễn phí ship vì dài ≤ 120).\n\n'
    '=== ĐẶT HÀNG ===\n'
    'Khách mở app → chọn tranh → nhập kích thước → chọn mặt dán → điền tên/SĐT/địa chỉ → xác nhận.\n\n'
    'Nếu khách hỏi giá cụ thể, hãy tính và trả lời trực tiếp. '
    'Không bịa thêm tính năng hay sản phẩm ngoài danh sách trên.';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------
enum _Role { user, model }

class _Msg {
  final String content;
  final String? imageUrl;
  final _Role role;
  const _Msg({required this.content, this.imageUrl, required this.role});
  bool get isUser => role == _Role.user;
  bool get isImage => imageUrl != null;
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------
class ChatbotPage extends StatefulWidget {
  final String? initialImageUrl;
  const ChatbotPage({super.key, this.initialImageUrl});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final List<_Msg> _messages = [];
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _loading = false;
  late final GenerativeModel _model;
  late ChatSession _chat;

  static const _primary = Color(0xFF2B678B);
  static const _light = Color(0xFF5CC1FF);

  // Firestore ref cho lịch sử chat của user hiện tại
  CollectionReference<Map<String, dynamic>>? get _historyRef {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('chats')
        .doc(uid)
        .collection('messages');
  }

  @override
  void initState() {
    super.initState();
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _kGeminiKey,
      systemInstruction: Content.system(_kSystemPrompt),
      generationConfig: GenerationConfig(
        temperature: 0.7,
        maxOutputTokens: 1024,
      ),
    );
    _chat = _model.startChat();
    _loadHistory().then((_) {
      if (widget.initialImageUrl != null) {
        _sendImageToChat(widget.initialImageUrl!);
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // Đọc lịch sử 20 tin nhắn gần nhất từ Firestore
  Future<void> _loadHistory() async {
    final ref = _historyRef;
    if (ref == null) {
      _addGreeting();
      return;
    }
    try {
      final snap = await ref
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();
      if (!mounted) return;
      if (snap.docs.isEmpty) {
        _addGreeting();
        return;
      }
      // Đảo lại để hiển thị cũ → mới
      final docs = snap.docs.reversed.toList();
      setState(() {
        for (final doc in docs) {
          final d = doc.data();
          _messages.add(_Msg(
            content: d['content'] as String? ?? '',
            role: (d['role'] as String?) == 'user' ? _Role.user : _Role.model,
          ));
        }
      });
      _scrollToBottom();
    } catch (_) {
      _addGreeting();
    }
  }

  void _addGreeting() {
    setState(() {
      _messages.add(const _Msg(
        content: 'Xin chào! Tôi là trợ lý bán hàng của Tranh Bể Cá Trung 3D 🐠\n'
            'Tôi có thể giúp bạn tính giá, tư vấn kích thước hoặc giải đáp thắc mắc về sản phẩm.',
        role: _Role.model,
      ));
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Lưu 1 tin nhắn vào Firestore (bỏ qua tin nhắn ảnh)
  Future<void> _saveMsg(_Msg msg) async {
    if (msg.isImage) return;
    try {
      await _historyRef?.add({
        'role': msg.isUser ? 'user' : 'model',
        'content': msg.content,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // Gửi ảnh ghép vào chat và nhờ Gemini nhận xét
  Future<void> _sendImageToChat(String imageUrl) async {
    final imgMsg = _Msg(content: '', imageUrl: imageUrl, role: _Role.user);
    setState(() {
      _messages.add(imgMsg);
      _loading = true;
    });
    _scrollToBottom();

    try {
      final response = await http.get(Uri.parse(imageUrl));
      final imageBytes = Uint8List.fromList(response.bodyBytes);

      final content = Content.multi([
        DataPart('image/jpeg', imageBytes),
        TextPart('Đây là ảnh bể cá của tôi với tranh đã ghép thử. Bạn thấy thế nào? Hãy nhận xét và tư vấn thêm nhé!'),
      ]);

      final geminiResponse = await _chat.sendMessage(content);
      final reply = geminiResponse.text ?? 'Ảnh trông rất đẹp! Bạn có muốn đặt hàng không?';
      final botMsg = _Msg(content: reply, role: _Role.model);
      setState(() => _messages.add(botMsg));
      _saveMsg(botMsg);
    } catch (e) {
      setState(() => _messages.add(_Msg(
            content: 'Xin lỗi, không thể phân tích ảnh: $e',
            role: _Role.model,
          )));
    } finally {
      setState(() => _loading = false);
      _scrollToBottom();
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _loading) return;

    final userMsg = _Msg(content: text, role: _Role.user);
    setState(() {
      _messages.add(userMsg);
      _loading = true;
    });
    _ctrl.clear();
    _scrollToBottom();
    _saveMsg(userMsg);

    try {
      final response = await _chat.sendMessage(Content.text(text));
      final reply = response.text ?? 'Xin lỗi, tôi không có phản hồi. Bạn hỏi lại nhé?';
      final botMsg = _Msg(content: reply, role: _Role.model);
      setState(() => _messages.add(botMsg));
      _saveMsg(botMsg);
    } catch (e) {
      setState(() => _messages.add(_Msg(
            content: 'Xin lỗi, có lỗi xảy ra: $e',
            role: _Role.model,
          )));
    } finally {
      setState(() => _loading = false);
      _scrollToBottom();
    }
  }

  // Xóa toàn bộ lịch sử chat
  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa lịch sử chat?'),
        content: const Text('Toàn bộ tin nhắn sẽ bị xóa.'),
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
    if (confirmed != true) return;

    // Xóa trong Firestore
    try {
      final ref = _historyRef;
      if (ref != null) {
        final snap = await ref.get();
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in snap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } catch (_) {}

    // Reset chat session
    if (!mounted) return;
    _chat = _model.startChat();
    setState(() {
      _messages.clear();
    });
    _addGreeting();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_light, _primary],
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.support_agent, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trợ lý bán hàng',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Tranh Bể Cá Trung 3D',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            tooltip: 'Xóa lịch sử',
            onPressed: _clearHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          if (_loading) _buildTypingIndicator(),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      itemCount: _messages.length,
      itemBuilder: (_, i) => _buildBubble(_messages[i]),
    );
  }

  Widget _buildBubble(_Msg msg) {
    final isUser = msg.isUser;
    final isImage = msg.isImage;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * (isImage ? 0.65 : 0.78),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isImage ? 4 : 14,
          vertical: isImage ? 4 : 10,
        ),
        decoration: BoxDecoration(
          color: isUser ? _primary : Theme.of(context).cardColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: isImage
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  msg.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.broken_image, color: Colors.white54, size: 48),
                ),
              )
            : Text(
                msg.content,
                style: TextStyle(
                  color: isUser ? Colors.white
                      : (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A2E)),
                  fontSize: 14.5,
                  height: 1.45,
                ),
              ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 16, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) => _Dot(delay: i * 200)),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: const [
            BoxShadow(color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, -2)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                maxLines: 3,
                minLines: 1,
                style: const TextStyle(fontSize: 14.5),
                decoration: InputDecoration(
                  hintText: 'Nhập câu hỏi...',
                  hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF0F4F8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _SendButton(loading: _loading, onTap: _send),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Send button
// ---------------------------------------------------------------------------
class _SendButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _SendButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          gradient: loading
              ? null
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF5CC1FF), Color(0xFF2B678B)],
                ),
          color: loading ? Colors.grey.shade300 : null,
          shape: BoxShape.circle,
        ),
        child: loading
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Animated typing dots
// ---------------------------------------------------------------------------
class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        transform: Matrix4.translationValues(0, _anim.value, 0),
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Color(0xFF2B678B),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

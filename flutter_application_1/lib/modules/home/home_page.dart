import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/auth_service.dart';
import '../../services/storage_rest.dart';
import '../../services/user_service.dart';
import '../gallery/gallery_page.dart';
import '../order/order_history_page.dart';
import '../order/order_store.dart';
import '../product_detail/widgets/new_paintings_page.dart';

class _FbCategory {
  final String name;        // Tên hiển thị (vd: "DEMO")
  final String folderPath;  // Đường dẫn Firebase (vd: "images/DEMO")
  final String? thumbnailUrl;
  const _FbCategory({
    required this.name,
    required this.folderPath,
    this.thumbnailUrl,
  });
}

class HomePage extends StatefulWidget {
  final VoidCallback? onGiftTap;
  const HomePage({super.key, this.onGiftTap});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<_FbCategory> _categories = [];
  List<String> _sliderUrls = [];
  bool _loadingData = true;
  String _displayName = '';
  StreamSubscription<User?>? _authSubscription;

  String selectedSize = "60x30";
  String searchQuery = '';
  bool _showTopZalo = true;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final PageController _pageController = PageController(viewportFraction: 0.9);
  Timer? _timer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleMainScroll);
    _loadFirebaseData();
    _loadUser();
    // userChanges() fire khi updateDisplayName hoàn thành —
    // xử lý race condition: HomePage có thể load trước khi signUp gọi xong updateDisplayName
    _authSubscription = FirebaseAuth.instance.userChanges().listen((user) {
      if (!mounted || user == null) return;
      final name = user.displayName ?? '';
      if (name.isNotEmpty && name != _displayName) {
        setState(() => _displayName = name);
      }
    });
  }

  Future<void> _loadUser() async {
    await FirebaseAuth.instance.currentUser?.reload();
    if (!mounted) return;

    final authName = FirebaseAuth.instance.currentUser?.displayName ?? '';
    if (authName.isNotEmpty) {
      setState(() => _displayName = authName);
      return;
    }

    // Fallback: đọc từ Realtime DB nếu Auth chưa có displayName
    final record = await UserService.loadCurrentUserRecord();
    if (!mounted || record == null) return;
    if (record.displayName.isNotEmpty) {
      setState(() => _displayName = record.displayName);
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _timer?.cancel();
    _scrollController.removeListener(_handleMainScroll);
    _scrollController.dispose();
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFirebaseData() async {
    final categories = await _loadCategoriesFromStorage();
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _loadingData = false;
    });

    // Pre-warm cache cho từng folder ngay khi danh mục hiển thị xong
    for (final cat in categories) {
      final prefix = cat.folderPath.endsWith('/')
          ? cat.folderPath
          : '${cat.folderPath}/';
      StorageRest.prewarm(prefix);
    }

    // Slider tải nền để tránh chặn hiển thị danh mục đầu tiên.
    unawaited(() async {
      final sliderUrls = await _loadSliderUrls();
      if (!mounted) return;
      setState(() {
        _sliderUrls = sliderUrls;
      });
      _setupTimer();
    }());
  }

  Future<List<_FbCategory>> _loadCategoriesFromStorage() async {
    try {
      // Lấy 1 cấp folder trực tiếp dưới root bucket.
      // Fallback về 'images/' để tương thích cấu trúc cũ nếu có.
      var categoryFolders = await StorageRest.listSubFolders('');
      if (categoryFolders.isEmpty) {
        categoryFolders = await StorageRest.listSubFolders('images/');
      }
      if (categoryFolders.isEmpty) return [];
      categoryFolders = categoryFolders
          .where((fp) => fp.split('/').where((s) => s.isNotEmpty).last.toLowerCase() != 'composites')
          .toList();
      final cats = await Future.wait(categoryFolders.map((folderPath) async {
        String? thumbUrl;
        final files = await StorageRest.listFiles(
          folderPath,
          maxResults: 1,
          fetchAllPages: false,
        );
        if (files.isNotEmpty) thumbUrl = files.first.url;
        final name = folderPath.split('/').where((s) => s.isNotEmpty).last;
        return _FbCategory(
          name: name,
          folderPath: folderPath,
          thumbnailUrl: thumbUrl,
        );
      }));
      return cats;
    } catch (e) {
      debugPrint('[Storage] _loadCategoriesFromStorage lỗi: $e');
      return [];
    }
  }

  Future<List<String>> _loadSliderUrls() async {
    final latest = await StorageRest.listLatestFiles(
      '',
      limit: 100,
      forceRefresh: true,
    );
    return latest.map((f) => f.url).take(8).toList();
  }

  void _setupTimer() {
    _timer?.cancel();
    final count = _sliderUrls.isEmpty ? 1 : _sliderUrls.length;
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      setState(() {
        _currentPage = (_currentPage + 1) % count;
      });
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _handleMainScroll() {
    final shouldShow =
        !_scrollController.hasClients || _scrollController.offset < 40;
    if (shouldShow != _showTopZalo && mounted) {
      setState(() => _showTopZalo = shouldShow);
    }
  }

  List<_FbCategory> get _filteredCategories {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _categories;
    return _categories
        .where((c) => c.name.toLowerCase().contains(query))
      .toList();
  }

  void _openCart() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OrderHistoryPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            expandedHeight: 120.0,
            floating: true,
            pinned: true,
            elevation: 0,
            actions: [_buildCartAction(), _buildLogoutAction()],
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF5CC1FF), Color(0xFF2B678B)],
                ),
              ),
              child: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(
                  left: 16,
                  bottom: 12,
                  right: 12,
                ),
                title: LayoutBuilder(
                  builder: (context, constraints) {
                    final bool isCollapsed = constraints.maxHeight < 105;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x33000000),
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Image.asset(
                                  'assets/icons/trung_logo.png',
                                  width: isCollapsed ? 24 : 30,
                                  height: isCollapsed ? 24 : 30,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  'Tranh Bể Cá Trung 3D',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: isCollapsed ? 16 : 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                centerTitle: false,
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSearchBar(),
                if (_displayName.isNotEmpty) _buildGreetingBanner(),
                _buildSectionTitle("TRANH MỚI NỔI BẬT"),
                _buildNewArrivalsSlider(),
                _buildGiftBanner(),
                _buildSectionTitle("Kích Thước Tranh"),
                _buildSizeChips(),
                _buildSectionTitle("Tất Cả Chủ Đề"),
                if (searchQuery.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Kết quả cho: "$searchQuery"',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
              ],
            ),
          ),

          _loadingData
              ? const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              : _filteredCategories.isEmpty
                  ? const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'Không tìm thấy chủ đề phù hợp.',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.0,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildCategoryCard(
                            _filteredCategories[index],
                          ),
                          childCount: _filteredCategories.length,
                        ),
                      ),
                    ),

          const SliverToBoxAdapter(child: SizedBox(height: 30)),
        ],
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildCartAction() {
    return ValueListenableBuilder<List<CartItem>>(
      valueListenable: OrderStore.cartItems,
      builder: (context, cartItems, _) {
        return ValueListenableBuilder<List<OrderRecord>>(
          valueListenable: OrderStore.orders,
          builder: (context, orders, _) {
            final totalBadge = cartItems.length + orders.length;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SizeTransition(
                      sizeFactor: animation,
                      axis: Axis.horizontal,
                      child: child,
                    ),
                  ),
                  child: _showTopZalo
                      ? Container(
                          key: const ValueKey('zalo_visible'),
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6F4EA),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: const Color(0xFFB7DFC2),
                              width: 0.8,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.phone_android,
                                  color: Color(0xFF2E7D32), size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Zalo: 0888196789',
                                style: TextStyle(
                                  color: Color.fromARGB(255, 13, 31, 32),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox(key: ValueKey('zalo_hidden')),
                ),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.shopping_cart_outlined,
                          color: Colors.white),
                      onPressed: _openCart,
                    ),
                    if (totalBadge > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: cartItems.isNotEmpty
                                ? const Color(0xFFE65100)
                                : Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                              minWidth: 16, minHeight: 16),
                          child: Text(
                            totalBadge.toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildLogoutAction() {
    return IconButton(
      icon: const Icon(Icons.logout, color: Colors.white),
      tooltip: 'Đăng xuất',
      onPressed: () async {
        final confirmed = await showDialog<bool>(
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
                child: const Text(
                  'Đăng xuất',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await AuthService.signOut();
        }
      },
    );
  }

  Widget _buildGreetingBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.waving_hand_rounded,
              color: Color(0xFF2B678B), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Xin chào, $_displayName!',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1B4F6A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftBanner() {
    return GestureDetector(
      onTap: widget.onGiftTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF6B6B), Color(0xFFFF4081)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B6B).withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quà tặng hấp dẫn 🎁',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Tặng bộ dụng cụ dán\n'
                    '• Sticker cảnh báo không trêu cá\n'
                    '• Móc chìa khóa mica cá koi may mắn\n'
                    '• Ưu đãi lên đến 10% khi đặt cả bộ lưng + đáy\n'
                    '• Miễn phí vận chuyển',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Xem ngay',
                      style: TextStyle(
                        color: Color(0xFFFF4081),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.card_giftcard_rounded,
              size: 68,
              color: Colors.white38,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => searchQuery = value),
            onSubmitted: _navigateToMatch,
            decoration: InputDecoration(
              hintText: "Tìm mã tranh hoặc chủ đề...",
              prefixIcon: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2B678B),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  icon: const Icon(Icons.search, color: Colors.white, size: 20),
                  onPressed: () => _navigateToMatch(searchQuery),
                ),
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Nút xóa text tìm kiếm
                  if (searchQuery.isNotEmpty)
                    IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => searchQuery = '');
                      },
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ),
        if (searchQuery.isNotEmpty && _filteredCategories.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(15)),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 4)
              ],
            ),
            child: Column(
              children: _filteredCategories
                  .take(3)
                  .map(
                    (cat) => ListTile(
                      dense: true,
                      leading: cat.thumbnailUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: CachedNetworkImage(
                                imageUrl: cat.thumbnailUrl!,
                                width: 32,
                                height: 32,
                                fit: BoxFit.cover,
                                errorWidget: (ctx, url, err) =>
                                    const Icon(Icons.image, size: 20),
                              ),
                            )
                          : const Icon(Icons.image,
                              size: 20, color: Color(0xFF2B678B)),
                      title: Text(cat.name),
                      onTap: () => _navigateToMatch(cat.name),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }

  void _navigateToMatch(String query) {
    if (query.isEmpty) return;
    final match = _categories.firstWhere(
      (c) => c.name.toLowerCase().contains(query.toLowerCase()),
      orElse: () => const _FbCategory(name: '', folderPath: ''),
    );
    if (match.name.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GalleryPage(
            categoryName: match.name,
            folderPath: match.folderPath,
            selectedSize: selectedSize,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không tìm thấy chủ đề phù hợp, hãy xem gợi ý bên dưới.'),
        ),
      );
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Text(
        title,
        style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }

  Widget _buildNewArrivalsSlider() {
    final count = _sliderUrls.isEmpty ? 1 : _sliderUrls.length;
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (page) => setState(() => _currentPage = page),
            itemCount: count,
            itemBuilder: (context, index) {
              final url = _sliderUrls.isEmpty ? null : _sliderUrls[index];
              return InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const NewPaintingsPage()),
                ),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B4F6A),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (url != null)
                          CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            errorWidget: (ctx, url, err) =>
                                const SizedBox.shrink(),
                          ),
                        // Gradient overlay
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.55),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 12,
                          left: 14,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'MỚI',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Mẫu Tranh Mới Nhất',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  shadows: [
                                    Shadow(blurRadius: 4, color: Colors.black)
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            count,
            (index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentPage == index ? 12 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: _currentPage == index
                    ? const Color(0xFF2B678B)
                    : Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSizeChips() {
    const sizes = [
      "60x30",
      "90x45",
      "100x50",
      "120x50",
      "120x60",
      "150x60",
      "Custom",
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        children: sizes.map((size) {
          final isSelected = selectedSize == size;
          return ChoiceChip(
            label: Text(size),
            selected: isSelected,
            onSelected: (_) => setState(() => selectedSize = size),
            selectedColor: const Color(0xFF2B678B),
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
            ),
            backgroundColor: Colors.white,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryCard(_FbCategory cat) {
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GalleryPage(
            categoryName: cat.name,
            folderPath: cat.folderPath,
            selectedSize: selectedSize,
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail image hoặc màu nền
            cat.thumbnailUrl != null
                ? CachedNetworkImage(
                    imageUrl: cat.thumbnailUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (ctx, url, err) =>
                        Container(color: const Color(0xFF2B678B)),
                  )
                : Container(color: const Color(0xFF2B678B)),

            // Gradient để chữ dễ đọc
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.65),
                  ],
                ),
              ),
            ),

            // Tên chủ đề
            Positioned(
              bottom: 10,
              left: 10,
              right: 10,
              child: Text(
                cat.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  shadows: [
                    Shadow(blurRadius: 4, color: Colors.black)
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/painting_search_service.dart';
import '../../services/storage_rest.dart';
import '../../widgets/app_ui.dart';
import '../gallery/gallery_page.dart';
import '../order/order_history_page.dart';
import '../order/order_store.dart';
import '../product_detail/widgets/new_paintings_page.dart';
import '../search/search_suggestions.dart';

// Màu dùng chung (lib/widgets/app_ui.dart)
const _kBlue = AppColors.blue;
const _kSky = AppColors.sky;
const _kCoral = AppColors.coral;
const _kCoralDark = AppColors.coralDark;
const _kInk = AppColors.ink;
const _kMuted = AppColors.muted;

class _FbCategory {
  final String name; // Tên hiển thị (vd: "DEMO")
  final String folderPath; // Đường dẫn Firebase (vd: "images/DEMO")
  final String? thumbnailUrl;
  const _FbCategory({
    required this.name,
    required this.folderPath,
    this.thumbnailUrl,
  });
}

class HomePage extends StatefulWidget {
  final VoidCallback? onGiftTap;
  final VoidCallback? onAvatarTap;
  const HomePage({super.key, this.onGiftTap, this.onAvatarTap});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<_FbCategory> _categories = [];
  List<String> _sliderUrls = [];
  // Toàn bộ tranh + từ khóa, tải nền để gợi ý ngay khi khách gõ tìm kiếm
  List<PaintingEntry> _searchCatalog = const [];
  bool _loadingData = true;

  String selectedSize = "60x30";
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final PageController _pageController = PageController(viewportFraction: 0.86);
  Timer? _timer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _loadFirebaseData();
    PaintingSearchService.catalog().then((list) {
      if (mounted) setState(() => _searchCatalog = list);
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _timer?.cancel();
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
      final cats = await Future.wait(
        categoryFolders.map((folderPath) async {
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
        }),
      );
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

  List<_FbCategory> get _filteredCategories {
    final query = PaintingSearchService.normalize(searchQuery);
    if (query.isEmpty) return _categories;
    return _categories
        .where((c) => PaintingSearchService.normalize(c.name).contains(query))
        .toList();
  }

  void _openCart() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OrderHistoryPage()),
    );
  }

  void _openNewPaintings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NewPaintingsPage()),
    );
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _textColor => _isDark ? Colors.white : _kInk;
  Color get _mutedColor => _isDark ? Colors.white60 : _kMuted;

  // Bóng đổ nhẹ ánh xanh teal (Level 1 trong design system)
  List<BoxShadow> get _softShadow => _isDark
      ? const []
      : [
          BoxShadow(
            color: _kBlue.withValues(alpha: 0.07),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildHeader(),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                _buildSearchBar(),
                _buildSectionTitle(
                  'Tranh mới nổi bật',
                  badge: 'HOT',
                  trailing: _buildSeeAll(),
                ),
                _buildNewArrivalsSlider(),
                _buildGiftBanner(),
                _buildSectionTitle(
                  'Kích thước tranh',
                  trailing: _buildHint('Chuẩn bể kính VN'),
                ),
                _buildSizeChips(),
                _buildSectionTitle(
                  'Tất cả chủ đề',
                  trailing: _loadingData || _categories.isEmpty
                      ? null
                      : _buildHint('${_categories.length} chủ đề'),
                ),
                if (searchQuery.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text(
                      'Kết quả cho: "$searchQuery"',
                      style: TextStyle(color: _mutedColor),
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
              ? SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        searchQuery.trim().isEmpty
                            ? 'Không tìm thấy chủ đề phù hợp.'
                            : 'Không có chủ đề trùng tên — xem tranh gợi ý '
                                  'ở ô tìm kiếm phía trên.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _mutedColor),
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
                          childAspectRatio: 1.2,
                        ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          _buildCategoryCard(_filteredCategories[index]),
                      childCount: _filteredCategories.length,
                    ),
                  ),
                ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildHeader() {
    final theme = Theme.of(context);
    return SliverAppBar(
      pinned: true,
      floating: true,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      toolbarHeight: 64,
      backgroundColor: theme.cardColor,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: _kBlue.withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/icons/trung_logo.png',
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'Tranh Bể Cá Trung 3D',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: _buildAvatar(),
        ),
      ],
    );
  }

  // Avatar tròn của khách: ảnh đại diện nếu có, không thì chữ cái đầu tên
  Widget _buildAvatar() {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data;
        final name = user?.displayName?.trim() ?? '';
        final photoUrl = user?.photoURL;
        return Tooltip(
          message: name.isNotEmpty ? name : 'Tài khoản',
          child: GestureDetector(
            onTap: widget.onAvatarTap,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_kSky, _kBlue],
                ),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: _kBlue.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              child: photoUrl != null && photoUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: photoUrl,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => _buildInitials(name),
                    )
                  : _buildInitials(name),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInitials(String name) {
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final initials = parts.isEmpty
        ? ''
        : parts.length >= 2
        ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
        : parts.first[0].toUpperCase();
    if (initials.isEmpty) {
      return const Icon(
        PhosphorIconsRegular.user,
        color: Colors.white,
        size: 22,
      );
    }
    return Text(
      initials,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 15,
      ),
    );
  }

  // Nút giỏ hàng tròn, nằm cùng hàng với ô tìm kiếm
  Widget _buildCartButton() {
    final theme = Theme.of(context);
    return ValueListenableBuilder<List<CartItem>>(
      valueListenable: OrderStore.cartItems,
      builder: (context, cartItems, _) {
        return ValueListenableBuilder<List<OrderRecord>>(
          valueListenable: OrderStore.orders,
          builder: (context, orders, _) {
            final totalBadge = cartItems.length + orders.length;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: _softShadow,
                  ),
                  child: Material(
                    color: theme.cardColor,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: _openCart,
                      child: SizedBox(
                        width: 50,
                        height: 50,
                        child: Tooltip(
                          message: 'Giỏ hàng',
                          child: Icon(
                            PhosphorIconsRegular.shoppingBag,
                            color: _isDark ? _kSky : _kBlue,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (totalBadge > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).cardColor,
                          width: 1.5,
                        ),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        totalBadge.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSearchBar() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: _softShadow,
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => searchQuery = value),
                    onSubmitted: _navigateToMatch,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Tìm tranh: hoa sen, mặt trăng, mã tranh...',
                      hintStyle: TextStyle(color: _mutedColor, fontSize: 14),
                      prefixIcon: IconButton(
                        icon: Icon(
                          PhosphorIconsRegular.magnifyingGlass,
                          color: _isDark ? _kSky : _kBlue,
                        ),
                        onPressed: () => _navigateToMatch(searchQuery),
                      ),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() => searchQuery = '');
                              },
                              icon: Icon(
                                PhosphorIconsRegular.x,
                                color: _mutedColor,
                              ),
                            )
                          : null,
                      filled: true,
                      fillColor: theme.cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: const BorderSide(color: _kSky, width: 1.2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _buildCartButton(),
            ],
          ),
        ),
        if (searchQuery.trim().isNotEmpty)
          SearchSuggestionsPanel(
            query: searchQuery,
            catalog: _searchCatalog,
            selectedSize: selectedSize,
            leading: [
              for (final cat in _filteredCategories.take(2))
                ListTile(
                  dense: true,
                  leading: SizedBox(
                    width: 36,
                    height: 36,
                    child: cat.thumbnailUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: cat.thumbnailUrl!,
                              fit: BoxFit.cover,
                              errorWidget: (ctx, url, err) => const Icon(
                                PhosphorIconsRegular.image,
                                size: 20,
                              ),
                            ),
                          )
                        : const Icon(
                            PhosphorIconsRegular.image,
                            size: 20,
                            color: _kBlue,
                          ),
                  ),
                  title: Text(cat.name),
                  subtitle: Text(
                    'Chủ đề',
                    style: TextStyle(fontSize: 12, color: _mutedColor),
                  ),
                  trailing: Icon(
                    PhosphorIconsRegular.arrowUpLeft,
                    size: 16,
                    color: _mutedColor,
                  ),
                  onTap: () => _openCategory(cat),
                ),
            ],
          ),
      ],
    );
  }

  void _openCategory(_FbCategory cat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GalleryPage(
          categoryName: cat.name,
          folderPath: cat.folderPath,
          selectedSize: selectedSize,
        ),
      ),
    );
  }

  // Bấm tìm: trùng hẳn tên chủ đề thì mở chủ đề, còn lại mở trang kết quả
  // tìm tranh theo từ khóa/mã tranh.
  void _navigateToMatch(String query) {
    final q = PaintingSearchService.normalize(query);
    if (q.isEmpty) return;
    for (final c in _categories) {
      if (PaintingSearchService.normalize(c.name) == q) {
        _openCategory(c);
        return;
      }
    }
    openSearchResults(context, query, selectedSize: selectedSize);
  }

  Widget _buildSectionTitle(String title, {String? badge, Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
      child: Row(
        children: [
          // Luôn 1 dòng: màn hình hẹp thì thu nhỏ chữ thay vì xuống dòng
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: _textColor,
                ),
              ),
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _kCoral,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }

  Widget _buildSeeAll() {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: _openNewPaintings,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Xem tất cả',
              style: TextStyle(
                color: _isDark ? _kSky : _kBlue,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            Icon(
              PhosphorIconsRegular.caretRight,
              size: 18,
              color: _isDark ? _kSky : _kBlue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHint(String text) {
    return Text(text, style: TextStyle(fontSize: 12, color: _mutedColor));
  }

  Widget _buildNewArrivalsSlider() {
    final count = _sliderUrls.isEmpty ? 1 : _sliderUrls.length;
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Vùng của thẻ ảnh đang hiển thị (thẻ đầu lệch trái 16px)
              final cardWidth =
                  constraints.maxWidth * _pageController.viewportFraction - 22;
              return Stack(
                children: [
                  PageView.builder(
                    controller: _pageController,
                    padEnds: false,
                    onPageChanged: (page) =>
                        setState(() => _currentPage = page),
                    itemCount: count,
                    itemBuilder: (context, index) {
                      final url = _sliderUrls.isEmpty
                          ? null
                          : _sliderUrls[index];
                      return Padding(
                        padding: EdgeInsets.only(
                          left: index == 0 ? 16 : 6,
                          right: 6,
                        ),
                        child: GestureDetector(
                          onTap: _openNewPaintings,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E3A8A),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: _softShadow,
                            ),
                            clipBehavior: Clip.antiAlias,
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
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      stops: const [0.45, 1.0],
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withValues(alpha: 0.6),
                                      ],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 12,
                                  left: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _kCoral,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      'MỚI',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  if (count > 1)
                    Positioned(
                      left: 16,
                      width: cardWidth,
                      bottom: 12,
                      child: IgnorePointer(
                        child: Center(child: _buildSliderDots(count)),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // Thanh chỉ trang nằm trong ảnh (chấm trắng trên nền tối mờ)
  Widget _buildSliderDots(int count) {
    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, _) {
        final page =
            _pageController.hasClients &&
                _pageController.position.hasContentDimensions
            ? (_pageController.page ?? _currentPage.toDouble())
            : _currentPage.toDouble();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(count, (index) {
              // t = 1 khi đang ở đúng ảnh, giảm dần khi vuốt sang ảnh khác
              final t = (1 - (page - index).abs()).clamp(0.0, 1.0);
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 5 + 11 * t,
                height: 5,
                decoration: BoxDecoration(
                  color: Color.lerp(
                    Colors.white.withValues(alpha: 0.5),
                    Colors.white,
                    t,
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildGiftBanner() {
    const perks = [
      'Tặng bộ dụng cụ dán',
      'Sticker cảnh báo không trêu cá',
      'Móc chìa khóa mica cá koi may mắn',
      'Ưu đãi đến 10% khi đặt cả bộ lưng + đáy',
      'Miễn phí vận chuyển',
    ];
    final bg = _isDark ? const Color(0xFF3A2420) : const Color(0xFFFFF3EF);
    final titleColor = _isDark ? const Color(0xFFFFB4A3) : _kCoralDark;
    return GestureDetector(
      onTap: widget.onGiftTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 28, 16, 0),
        padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kCoral.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quà tặng hấp dẫn 🎁',
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...perks.map(
                        (p) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 1),
                                child: Icon(
                                  PhosphorIconsRegular.checkCircle,
                                  size: 16,
                                  color: Color(0xFF22C55E),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  p,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.35,
                                    color: _textColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: _kCoral.withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Xem ngay',
                              style: TextStyle(
                                color: _kCoralDark,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              PhosphorIconsRegular.arrowRight,
                              size: 16,
                              color: _kCoralDark,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    PhosphorIconsRegular.gift,
                    size: 32,
                    color: _kCoral,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTrustBadges(),
          ],
        ),
      ),
    );
  }

  Widget _buildSizeChips() {
    final theme = Theme.of(context);
    const sizes = [
      "60x30",
      "90x45",
      "100x50",
      "120x50",
      "120x60",
      "150x60",
      "Custom",
    ];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: sizes.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final size = sizes[index];
          final isSelected = selectedSize == size;
          final label = size == 'Custom'
              ? 'Tùy chỉnh'
              : '${size.replaceAll('x', '×')} cm';
          return GestureDetector(
            onTap: () => setState(() => selectedSize = size),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? _kBlue : theme.cardColor,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isSelected
                      ? _kBlue
                      : (_isDark
                            ? Colors.white24
                            : _kBlue.withValues(alpha: 0.15)),
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.white : _textColor,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryCard(_FbCategory cat) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
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
        child: Stack(
          fit: StackFit.expand,
          children: [
            cat.thumbnailUrl != null
                ? CachedNetworkImage(
                    imageUrl: cat.thumbnailUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (ctx, url, err) => Container(color: _kBlue),
                  )
                : Container(color: _kBlue),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.4, 1.0],
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Text(
                cat.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
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

  Widget _buildTrustBadges() {
    const badges = [
      (
        PhosphorIconsRegular.shieldCheck,
        'Decal 4 lớp 3M',
        'Chống trầy, bay màu',
      ),
      (PhosphorIconsRegular.ruler, 'Đo cắt chuẩn', 'Vừa khít từng milimet'),
      (PhosphorIconsRegular.truck, 'Đóng gói trong ống PVC', 'Không gãy nếp'),
    ];
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Row(
        children: [
          for (var i = 0; i < badges.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Icon(
                      badges[i].$1,
                      size: 22,
                      color: _isDark ? _kSky : _kBlue,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      badges[i].$2,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      badges[i].$3,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10.5, color: _mutedColor),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

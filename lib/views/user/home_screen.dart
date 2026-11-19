
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/book_model.dart';
import '../../controllers/auth_controller.dart';
import '../book/book_detail_screen.dart';
import '../../controllers/book_controller.dart';
import '../../controllers/chat_controller.dart';
import '../book/sell_book_screen.dart';
import '../widgets/cart_screen.dart';
import 'chat_inbox_screen.dart';
import 'notification_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color green = Color(0xFF087F3E);
  static const Color blue = Color(0xFF092B8F);

  final TextEditingController _searchController =
      TextEditingController();

  // Index halaman pada IndexedStack: Home, Chat, Notifikasi, Profil.
  int _selectedPageIndex = 0;

  int get _selectedNavigationIndex =>
      _selectedPageIndex < 2 ? _selectedPageIndex : _selectedPageIndex + 1;

  String _homeSearchQuery = '';
  int? _selectedHomeCategoryId;

  static const Map<int, String> _homeCategories = {
    1: 'Fiksi',
    2: 'Non Fiksi',
    3: 'Pelajaran',
    4: 'Komik',
    5: 'Self Help',
    6: 'Teknologi',
    7: 'Bisnis',
  };


  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      context.read<BookController>().fetchAllBooks();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _searchBooks(String query) {
    setState(() {
      _homeSearchQuery = query.trim().toLowerCase();
    });
  }

  void _openBookList({required bool forSale}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => BookController()..fetchAllBooks(),
          child: BookListScreen(forSale: forSale),
        ),
      ),
    );
  }

  // Halaman unggah dipakai untuk mode Jual maupun Tukar.
  void _openUploadBook({required bool isExchange}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SellBookScreen(initialIsExchange: isExchange),
      ),
    );
  }

  void _openSellBook() => _openUploadBook(isExchange: false);

  void _showCreateOptions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Tambah Aktivitas',
                  style: TextStyle(
                    color: blue,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Pilih jenis buku yang ingin kamu unggah.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE4F3E9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.sell_outlined, color: green),
                  ),
                  title: const Text(
                    'Jual Buku',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text('Unggah buku dengan harga jual.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openUploadBook(isExchange: false);
                  },
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8F2FC),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.swap_horiz_rounded, color: blue),
                  ),
                  title: const Text(
                    'Tukar Buku',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text('Unggah buku dan tulis buku yang dicari.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openUploadBook(isExchange: true);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onBottomNavTap(int index) {
    // Tombol Plus berada di posisi ketiga dan tidak mengganti halaman aktif.
    if (index == 2) {
      _showCreateOptions();
      return;
    }

    setState(() {
      _selectedPageIndex = index < 2 ? index : index - 1;
    });
  }

  Widget _chatNavigationIcon(int unreadCount) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.chat_bubble_outline_rounded),
        if (unreadCount > 0)
          Positioned(
            right: -9,
            top: -7,
            child: Container(
              constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDF8F0),
      body: SafeArea(
        child: IndexedStack(
          index: _selectedPageIndex,
          children: [
            _buildHomeContent(),
            const ChatInboxScreen(),
            const NotificationScreen(),
            const ProfileScreen(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedNavigationIndex,
        onTap: _onBottomNavTap,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: green,
        unselectedItemColor: Colors.grey,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Consumer<ChatController>(
              builder: (context, controller, child) =>
                  _chatNavigationIcon(controller.totalUnreadCount),
            ),
            label: 'Chat',
          ),
          const BottomNavigationBarItem(
            icon: SizedBox(
              width: 38,
              height: 38,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: green,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add_rounded, color: Colors.white, size: 25),
              ),
            ),
            label: 'Tambah',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.notifications_none_rounded),
            label: 'Notifikasi',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  // =========================================================
  // KONTEN HOME
  // =========================================================

  Widget _buildHomeContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SEARCH BAR
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _searchBooks,
                    decoration: InputDecoration(
                      hintText:
                          'Cari buku, judul, penulis, atau kategori...',
                      hintStyle: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: blue,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFEEF4FD),
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF4FD),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: IconButton(
                    tooltip: 'Keranjang',
                    icon: const Icon(
                      Icons.shopping_cart_outlined,
                      color: green,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CartScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // BANNER BOOKCYCLE
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              height: 150,
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF087F3E),
                    Color(0xFF079B70),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(
                      14,
                      12,
                      130,
                      12,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Buku baru,\ncerita baru!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            height: 1.15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Temukan buku favoritmu '
                          'dengan harga terbaik.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    bottom: 8,
                    width: 125,
                    child: Center(
                      child: Image.asset(
                        'assets/images/book_bunner.jpeg',
                        width: 120,
                        height: 120,
                        fit: BoxFit.contain,
                        errorBuilder: (
                          context,
                          error,
                          stackTrace,
                        ) {
                          return const Icon(
                            Icons.menu_book_rounded,
                            color: Colors.white,
                            size: 65,
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 22),

          // MENU BELI, JUAL, TUKAR
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _menuItem(
                  icon: Icons.shopping_bag_outlined,
                  label: 'Beli',
                  color: const Color(0xFF087F3E),
                  onTap: () => _openBookList(forSale: true),
                ),
                _menuItem(
                  icon: Icons.sell_outlined,
                  label: 'Jual',
                  color: const Color(0xFFFFC329),
                  onTap: _openSellBook,
                ),
                _menuItem(
                  icon: Icons.swap_horiz_rounded,
                  label: 'Tukar',
                  color: const Color(0xFF13A4E0),
                  onTap: () => _openBookList(forSale: false),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // FILTER KATEGORI DAN DAFTAR BUKU LANGSUNG DI HOME.
          _buildHomeBookSection(),

          const SizedBox(height: 18),
        ],
      ),
    );
  }

  // =========================================================
  // FILTER DAN DAFTAR BUKU DI HOME
  // =========================================================

  List<BookModel> _filterHomeBooks(
    List<BookModel> source,
    int? currentUserId,
  ) {
    return source.where((book) {
      final status = book.statusBuku.trim().toLowerCase();
      final isAvailable = status == 'tersedia';
      final isOwnBook = currentUserId != null &&
          book.userId != null &&
          book.userId == currentUserId;
      final categoryMatches = _selectedHomeCategoryId == null ||
          book.kategoriId == _selectedHomeCategoryId;

      final query = _homeSearchQuery;
      final title = book.judulBuku.toLowerCase();
      final author = (book.penulis ?? '').toLowerCase();
      final category =
          (_homeCategories[book.kategoriId] ?? 'Lainnya').toLowerCase();
      final searchMatches = query.isEmpty ||
          title.contains(query) ||
          author.contains(query) ||
          category.contains(query);

      // Keputusan produk: buku milik pengguna yang sedang login
      // tidak ditampilkan pada daftar Home.
      return isAvailable &&
          !isOwnBook &&
          categoryMatches &&
          searchMatches;
    }).toList();
  }

  Widget _buildHomeBookSection() {
    return Consumer2<BookController, AuthController>(
      builder: (context, bookController, authController, child) {
        final books = _filterHomeBooks(
          bookController.books,
          authController.currentUser?.userId,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHomeCategoryFilter(),
            const SizedBox(height: 14),
            if (bookController.isLoading && bookController.books.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 34),
                child: Center(
                  child: CircularProgressIndicator(color: green),
                ),
              )
            else if (bookController.errorMessage != null &&
                bookController.books.isEmpty)
              _buildHomeErrorState(bookController)
            else if (books.isEmpty)
              _buildHomeEmptyState()
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: books.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) =>
                    _buildHomeBookItem(books[index]),
              ),
          ],
        );
      },
    );
  }

  Widget _buildHomeCategoryFilter() {
    return SizedBox(
      height: 42,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _homeCategoryChip(
              label: 'Semua',
              selected: _selectedHomeCategoryId == null,
              onTap: () {
                setState(() => _selectedHomeCategoryId = null);
              },
            ),
            ..._homeCategories.entries.map((entry) {
              return _homeCategoryChip(
                label: entry.value,
                selected: _selectedHomeCategoryId == entry.key,
                onTap: () {
                  setState(() => _selectedHomeCategoryId = entry.key);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _homeCategoryChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        selectedColor: green,
        backgroundColor: const Color(0xFFEEF5F1),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        labelStyle: TextStyle(
          color: selected ? Colors.white : green,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      ),
    );
  }

  Widget _buildHomeBookItem(BookModel book) {
    final transactionType = book.jenisTransaksi
        .trim()
        .toLowerCase()
        .replaceAll(' ', '_');
    final transactionLabel = transactionType == 'tukar'
        ? 'Tukar'
        : _formatHomePrice(book.harga);

    return InkWell(
      onTap: () => _openHomeBookDetail(book),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE1ECE7)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 7,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 82,
                height: 116,
                child: book.fotoBuku != null && book.fotoBuku!.isNotEmpty
                    ? Image.network(
                        book.fotoBuku!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _homeBookPlaceholder(),
                      )
                    : _homeBookPlaceholder(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    book.judulBuku,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: blue,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    book.penulis?.trim().isNotEmpty == true
                        ? book.penulis!.trim()
                        : '-',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF78909C),
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _homeCategories[book.kategoriId] ?? 'Lainnya',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF78909C),
                      fontSize: 9,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 8,
                    runSpacing: 5,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        transactionLabel,
                        style: const TextStyle(
                          color: green,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE9F6EF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _formatHomeCondition(book.kondisiBuku),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: green,
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 62,
              height: 34,
              child: ElevatedButton(
                onPressed: () => _openHomeBookDetail(book),
                style: ElevatedButton.styleFrom(
                  backgroundColor: green,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Pilih',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _homeBookPlaceholder() {
    return Container(
      color: const Color(0xFFEAF4EE),
      alignment: Alignment.center,
      child: const Icon(
        Icons.menu_book_rounded,
        color: green,
        size: 34,
      ),
    );
  }

  String _formatHomePrice(int? price) {
    if (price == null || price == 0) return 'Rp0';

    final value = price.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < value.length; i++) {
      if (i > 0 && (value.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(value[i]);
    }
    return 'Rp${buffer.toString()}';
  }

  String _formatHomeCondition(String condition) {
    switch (condition) {
      case 'Bekas_Layak':
        return 'Bekas Layak';
      case 'Bekas_Cukup':
        return 'Bekas Cukup';
      default:
        return condition.replaceAll('_', ' ');
    }
  }

  void _openHomeBookDetail(BookModel book) {
    if (book.bukuId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID buku tidak ditemukan.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookDetailScreen(bookId: book.bukuId!),
      ),
    );
  }

  Widget _buildHomeEmptyState() {
    final hasFilter = _homeSearchQuery.isNotEmpty ||
        _selectedHomeCategoryId != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 34, 24, 42),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 58,
              color: green.withValues(alpha: 0.55),
            ),
            const SizedBox(height: 12),
            Text(
              hasFilter ? 'Buku tidak ditemukan' : 'Belum ada buku tersedia',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: blue,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasFilter
                  ? 'Coba kata pencarian atau kategori lain.'
                  : 'Buku yang tersedia akan muncul di sini.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeErrorState(BookController controller) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
      child: Column(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.grey, size: 42),
          const SizedBox(height: 10),
          const Text(
            'Buku gagal dimuat',
            style: TextStyle(
              color: blue,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            controller.errorMessage ?? 'Periksa koneksi internet Anda.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 11),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: controller.fetchAllBooks,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // MENU ITEM: BELI, JUAL, TUKAR
  // =========================================================

  Widget _menuItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 80,
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 25,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: blue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================
// HALAMAN DAFTAR BUKU UNTUK BELI DAN TUKAR
// =========================================================

class BookListScreen extends StatefulWidget {
  final bool forSale;

  const BookListScreen({
    super.key,
    required this.forSale,
  });

  @override
  State<BookListScreen> createState() => _BookListScreenState();
}

class _BookListScreenState extends State<BookListScreen> {
  static const Color green = Color(0xFF087F3E);
  static const Color blue = Color(0xFF092B8F);

  final TextEditingController _searchController =
      TextEditingController();

  String _searchQuery = '';
  int? _selectedCategoryId;

  // ID kategori mengikuti daftar kategori HomeScreen.
  static const Map<int, String> _categories = {
    1: 'Fiksi',
    2: 'Non Fiksi',
    3: 'Pelajaran',
    4: 'Komik',
    5: 'Self Help',
    6: 'Teknologi',
    7: 'Bisnis',
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getCategoryName(int? kategoriId) {
    return _categories[kategoriId] ?? 'Lainnya';
  }

  String _formatCondition(String condition) {
    switch (condition) {
      case 'Bekas_Layak':
        return 'Bekas Layak';
      case 'Bekas_Cukup':
        return 'Bekas Cukup';
      default:
        return condition.replaceAll('_', ' ');
    }
  }

  String _formatPrice(int? price) {
    if (price == null || price == 0) {
      return 'Rp0';
    }

    final value = price.toString();
    final buffer = StringBuffer();

    for (int i = 0; i < value.length; i++) {
      if (i > 0 && (value.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(value[i]);
    }

    return 'Rp${buffer.toString()}';
  }

  // FILTER BERDASARKAN TRANSAKSI, KATEGORI, DAN PENCARIAN.
  List<BookModel> _filterBooks(List<BookModel> source) {
    return source.where((book) {
      final jenis = book.jenisTransaksi
          .trim()
          .toLowerCase()
          .replaceAll(' ', '_');

      final status = book.statusBuku.trim().toLowerCase();

      final tersedia = status == 'tersedia';

      final bisaDibeli =
          jenis == 'jual' || jenis == 'jual_tukar';

      final bisaDitukar =
          jenis == 'tukar' || jenis == 'jual_tukar';

      final transaksiSesuai =
          widget.forSale ? bisaDibeli : bisaDitukar;

      final kategoriSesuai = _selectedCategoryId == null ||
          book.kategoriId == _selectedCategoryId;

      final query = _searchQuery.trim().toLowerCase();
      final judul = book.judulBuku.toLowerCase();
      final penulis = (book.penulis ?? '').toLowerCase();
      final kategori =
          _getCategoryName(book.kategoriId).toLowerCase();

      final pencarianSesuai = query.isEmpty ||
          judul.contains(query) ||
          penulis.contains(query) ||
          kategori.contains(query);

      return tersedia &&
          transaksiSesuai &&
          kategoriSesuai &&
          pencarianSesuai;
    }).toList();
  }

  // BUKA DETAIL BUKU.
  void _openBookDetail(BookModel book) {
    if (book.bukuId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ID buku tidak ditemukan.'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookDetailScreen(
          bookId: book.bukuId!,
        ),
      ),
    );
  }

  // SEARCH FIELD.
  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: 'Cari judul, penulis, atau kategori...',
          hintStyle: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: blue,
            size: 21,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.close,
                    size: 18,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: const Color(0xFFEEF4FD),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // FILTER KATEGORI HORIZONTAL.
  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 40,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            _categoryChip(
              label: 'Semua',
              selected: _selectedCategoryId == null,
              onTap: () {
                setState(() {
                  _selectedCategoryId = null;
                });
              },
            ),
            ..._categories.entries.map((entry) {
              return _categoryChip(
                label: entry.value,
                selected: _selectedCategoryId == entry.key,
                onTap: () {
                  setState(() {
                    _selectedCategoryId = entry.key;
                  });
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  // TOMBOL KATEGORI.
  Widget _categoryChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        selectedColor: green,
        backgroundColor: const Color(0xFFEEF5F1),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        labelStyle: TextStyle(
          color: selected ? Colors.white : green,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(
          horizontal: 5,
          vertical: 2,
        ),
      ),
    );
  }

  // ITEM BUKU DALAM BENTUK LIST VERTIKAL.
  Widget _buildBookItem(BookModel book) {
    return InkWell(
      onTap: () => _openBookDetail(book),
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: const Color(0xFFE1ECE7),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 7,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // FOTO BUKU.
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: SizedBox(
                width: 76,
                height: 105,
                child: book.fotoBuku != null &&
                        book.fotoBuku!.isNotEmpty
                    ? Image.network(
                        book.fotoBuku!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _bookImagePlaceholder();
                        },
                      )
                    : _bookImagePlaceholder(),
              ),
            ),

            const SizedBox(width: 12),

            // INFORMASI BUKU.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    book.judulBuku,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: blue,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    book.penulis ?? '-',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF78909C),
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _getCategoryName(book.kategoriId),
                    style: const TextStyle(
                      color: Color(0xFF78909C),
                      fontSize: 9,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.forSale
                              ? _formatPrice(book.harga)
                              : 'Tukar',
                          style: const TextStyle(
                            color: green,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE9F6EF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _formatCondition(book.kondisiBuku),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: green,
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // TOMBOL PILIH.
            SizedBox(
              width: 60,
              height: 32,
              child: ElevatedButton(
                onPressed: () => _openBookDetail(book),
                style: ElevatedButton.styleFrom(
                  backgroundColor: green,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text(
                  'Pilih',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // PLACEHOLDER FOTO.
  Widget _bookImagePlaceholder() {
    return Container(
      color: const Color(0xFFEAF4EE),
      child: const Center(
        child: Icon(
          Icons.menu_book_rounded,
          color: green,
          size: 35,
        ),
      ),
    );
  }

  // TAMPILAN KETIKA BUKU TIDAK DITEMUKAN.
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_rounded,
              size: 65,
              color: green.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 14),
            const Text(
              'Buku tidak ditemukan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: blue,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Coba gunakan kata pencarian atau kategori lain.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // BUILD HALAMAN DAFTAR BUKU
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: blue,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        title: Text(
          widget.forSale
              ? 'Pilih Buku untuk Dibeli'
              : 'Pilih Buku untuk Ditukar',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: blue,
          ),
        ),
      ),
      body: Consumer<BookController>(
        builder: (context, controller, child) {
          if (controller.isLoading) {
            return const Center(
              child: CircularProgressIndicator(
                color: green,
              ),
            );
          }

          final books = _filterBooks(controller.books);

          return Column(
            children: [
              _buildSearchField(),
              _buildCategoryFilter(),
              const SizedBox(height: 12),
              Expanded(
                child: books.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          12,
                          0,
                          12,
                          20,
                        ),
                        itemCount: books.length,
                        separatorBuilder: (context, index) {
                          return const SizedBox(height: 11);
                        },
                        itemBuilder: (context, index) {
                          return _buildBookItem(books[index]);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

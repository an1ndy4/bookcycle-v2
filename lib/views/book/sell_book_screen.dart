import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SellBookScreen extends StatefulWidget {
  final bool initialIsExchange;

  const SellBookScreen({
    super.key,
    this.initialIsExchange = false,
  });

  @override
  State<SellBookScreen> createState() => _SellBookScreenState();
}

class _SellBookScreenState extends State<SellBookScreen> {
  static const Color _green = Color(0xFF087F3E);
  static const Color _navy = Color(0xFF092B8F);
  static const Color _fieldBorder = Color(0xFFE1E7E9);

  final SupabaseClient _supabase = Supabase.instance.client;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();

  // Input yang digunakan bersama oleh tab Jual dan Tukar.
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _authorController = TextEditingController();
  final TextEditingController _descriptionController =
      TextEditingController();

  // Input khusus masing-masing tab.
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _wantedBookController = TextEditingController();

  String? _selectedCategory;
  String? _selectedCondition;

  XFile? _bookImage;
  Uint8List? _bookImageBytes;

  bool _isExchange = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _isExchange = widget.initialIsExchange;
  }

  final List<String> _categories = const [
    'Fiksi',
    'Non Fiksi',
    'Pelajaran',
    'Komik',
    'Self Help',
    'Teknologi',
    'Bisnis',
    'Lainnya',
  ];

  final List<String> _conditions = const [
    'Baru',
    'Bekas Layak',
    'Bekas Cukup',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _wantedBookController.dispose();
    super.dispose();
  }

  // =========================================================
  // PILIH FOTO BUKU
  // =========================================================
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image == null) return;

      final Uint8List bytes = await image.readAsBytes();
      if (!mounted) return;

      setState(() {
        _bookImage = image;
        _bookImageBytes = bytes;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memilih foto: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 18, 18, 8),
              child: Text(
                'Pilih Sumber Foto',
                style: TextStyle(
                  color: _navy,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: _green),
              title: const Text('Ambil dari Kamera'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: _green),
              title: const Text('Pilih dari Galeri'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // UPLOAD FOTO KE SUPABASE STORAGE
  // Mengembalikan path dan URL agar file dapat dibersihkan jika
  // penyimpanan data buku ke database gagal.
  // =========================================================
  Future<Map<String, String>> _uploadImageToSupabase(
    XFile imageFile,
  ) async {
    final authUser = _supabase.auth.currentUser;
    if (authUser == null) {
      throw Exception('Silakan login terlebih dahulu.');
    }

    final String extension = imageFile.name.contains('.')
        ? imageFile.name.split('.').last.toLowerCase()
        : 'jpg';

    final String fileName =
        'book_${authUser.id}_${DateTime.now().microsecondsSinceEpoch}.$extension';
    final String filePath = 'books/$fileName';
    final Uint8List bytes = await imageFile.readAsBytes();

    await _supabase.storage.from('book-images').uploadBinary(
          filePath,
          bytes,
          fileOptions: FileOptions(
            contentType: imageFile.mimeType ?? 'image/jpeg',
            upsert: false,
          ),
        );

    return {
      'path': filePath,
      'url': _supabase.storage.from('book-images').getPublicUrl(filePath),
    };
  }

  // =========================================================
  // SIMPAN BUKU
  // =========================================================
  Future<void> _submitBook() async {
    if (_isUploading) return;

    final formIsValid = _formKey.currentState?.validate() ?? false;
    if (!formIsValid) return;

    if (_bookImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto buku wajib diunggah.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    int? price;
    if (!_isExchange) {
      final String rawPrice = _priceController.text.replaceAll(
        RegExp(r'[^0-9]'),
        '',
      );
      price = int.tryParse(rawPrice);

      if (price == null || price <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Masukkan harga lebih dari Rp 0.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    setState(() => _isUploading = true);

    String? uploadedImagePath;

    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) {
        throw Exception('Silakan login terlebih dahulu.');
      }

      // Ambil user_id integer dari tabel users.
      final userData = await _supabase
          .from('users')
          .select('user_id')
          .eq('auth_id', authUser.id)
          .maybeSingle();

      if (userData == null) {
        throw Exception('Profil pengguna tidak ditemukan di database.');
      }

      final int userId = (userData['user_id'] as num).toInt();

      // Ambil kategori_id berdasarkan nama kategori yang dipilih.
      final String? categoryName = _selectedCategory;
      if (categoryName == null) {
        throw Exception('Silakan pilih kategori buku.');
      }

      final categoryData = await _supabase
          .from('kategori')
          .select('kategori_id')
          .ilike('nama_kategori', categoryName)
          .maybeSingle();

      if (categoryData == null) {
        throw Exception(
          'Kategori "$categoryName" belum ditemukan di database Supabase.',
        );
      }

      final int kategoriId = (categoryData['kategori_id'] as num).toInt();

      const Map<String, String> conditionMap = {
        'Baru': 'Baru',
        'Bekas Layak': 'Bekas_Layak',
        'Bekas Cukup': 'Bekas_Cukup',
      };

      final String? kondisiBuku = conditionMap[_selectedCondition];
      if (kondisiBuku == null) {
        throw Exception('Kondisi buku tidak valid.');
      }

      // Upload foto setelah validasi data selesai.
      final uploadedImage = await _uploadImageToSupabase(_bookImage!);
      uploadedImagePath = uploadedImage['path'];
      final String imageUrl = uploadedImage['url']!;

      final Map<String, dynamic> bookData = {
        'user_id': userId,
        'kategori_id': kategoriId,
        'judul_buku': _titleController.text.trim(),
        'penulis': _authorController.text.trim(),
        'kondisi_buku': kondisiBuku,
        // Harga tidak digunakan pada tab Tukar.
        'harga': _isExchange ? null : price,
        'deskripsi': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'foto_buku': imageUrl,
        'jenis_transaksi': _isExchange ? 'Tukar' : 'Jual',
        'status_buku': 'Tersedia',
      };

      // Kolom buku_dicari hanya dikirim pada tab Tukar.
      // Kolom ini perlu ditambahkan ke public.buku melalui SQL
      // yang disertakan bersama file ini.
      if (_isExchange) {
        bookData['buku_dicari'] = _wantedBookController.text.trim();
      }

      await _supabase.from('buku').insert(bookData);

      // Insert berhasil, foto tidak perlu dibersihkan.
      uploadedImagePath = null;

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isExchange
                ? 'Buku berhasil diunggah untuk ditukar.'
                : 'Buku berhasil diunggah untuk dijual.',
          ),
          backgroundColor: _green,
        ),
      );
    } catch (e) {
      // Hapus foto dari Storage jika insert database gagal.
      if (uploadedImagePath != null) {
        try {
          await _supabase.storage
              .from('book-images')
              .remove([uploadedImagePath]);
        } catch (cleanupError) {
          debugPrint('Gagal membersihkan foto: $cleanupError');
        }
      }

      if (!mounted) return;

      debugPrint('Gagal mengunggah buku: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengunggah buku: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  // =========================================================
  // GANTI TAB JUAL / TUKAR
  // Data umum dan foto tetap dipertahankan ketika berpindah tab.
  // =========================================================
  void _changeTab(bool isExchange) {
    if (_isUploading || _isExchange == isExchange) return;

    setState(() {
      _isExchange = isExchange;
    });
  }

  // =========================================================
  // BUILD
  // =========================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _navy,
            size: 19,
          ),
          onPressed: _isUploading ? null : () => Navigator.pop(context),
        ),
        title: const Text(
          'Unggah Buku',
          style: TextStyle(
            color: _navy,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTransactionTabs(),
                const SizedBox(height: 12),
                _buildImagePicker(),
                const SizedBox(height: 12),
                _buildTextField(
                  label: 'Judul Buku',
                  controller: _titleController,
                  hint: 'Masukkan judul buku',
                ),
                const SizedBox(height: 9),
                _buildTextField(
                  label: 'Penulis',
                  controller: _authorController,
                  hint: 'Masukkan nama penulis',
                ),
                const SizedBox(height: 9),
                _buildDropdown(
                  label: 'Kategori',
                  value: _selectedCategory,
                  items: _categories,
                  hint: 'Pilih kategori',
                  onChanged: (value) {
                    setState(() => _selectedCategory = value);
                  },
                ),
                const SizedBox(height: 9),
                _buildDropdown(
                  label: 'Kondisi Buku',
                  value: _selectedCondition,
                  items: _conditions,
                  hint: 'Pilih kondisi',
                  onChanged: (value) {
                    setState(() => _selectedCondition = value);
                  },
                ),
                const SizedBox(height: 9),
                if (_isExchange)
                  _buildTextField(
                    label: 'Jenis Buku yang Dicari',
                    controller: _wantedBookController,
                    hint: 'Contoh: Novel, buku pendidikan...',
                  )
                else
                  _buildTextField(
                    label: 'Harga',
                    controller: _priceController,
                    hint: '0',
                    prefixText: 'Rp ',
                    isNumber: true,
                  ),
                const SizedBox(height: 9),
                _buildDescriptionField(),
                const SizedBox(height: 16),
                SizedBox(
                  height: 42,
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : _submitBook,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      disabledBackgroundColor: _green.withValues(alpha: 0.6),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: _isUploading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Unggah'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // TAB SELECTOR
  // =========================================================
  Widget _buildTransactionTabs() {
    return Container(
      height: 34,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF4F3),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              label: 'Jual Buku',
              selected: !_isExchange,
              onTap: () => _changeTab(false),
            ),
          ),
          Expanded(
            child: _buildTabButton(
              label: 'Tukar Buku',
              selected: _isExchange,
              onTap: () => _changeTab(true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isUploading ? null : onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? _green : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : _navy,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // IMAGE PICKER CARD
  // =========================================================
  Widget _buildImagePicker() {
    final bool hasImage = _bookImageBytes != null;

    return GestureDetector(
      onTap: _isUploading ? null : _showImageSourceDialog,
      child: Container(
        height: hasImage ? 132 : 80,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFFAFCFB),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: const Color(0xFFC8DED4)),
        ),
        clipBehavior: Clip.antiAlias,
        child: hasImage
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(
                    _bookImageBytes!,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.58),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.camera_alt, color: Colors.white, size: 13),
                          SizedBox(width: 5),
                          Text(
                            'Ganti Foto',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.camera_alt_rounded,
                    color: _green,
                    size: 25,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tambah Foto Buku',
                    style: TextStyle(
                      color: _green,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Unggah foto sampul buku',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 8,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // =========================================================
  // FIELD LABEL
  // =========================================================
  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(
        label,
        style: const TextStyle(
          color: _navy,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    String? prefixText,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixText: prefixText,
      hintStyle: const TextStyle(
        color: Color(0xFFA6B0BC),
        fontSize: 10,
      ),
      prefixStyle: const TextStyle(
        color: Color(0xFF6F7B87),
        fontSize: 10,
      ),
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 10,
      ),
      errorStyle: const TextStyle(fontSize: 9, height: 1.1),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _fieldBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _fieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _green, width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
      ),
    );
  }

  // =========================================================
  // TEXT FIELD
  // =========================================================
  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    String? prefixText,
    bool isNumber = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label),
        TextFormField(
          controller: controller,
          enabled: !_isUploading,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: const TextStyle(
            color: Color(0xFF344054),
            fontSize: 10,
          ),
          decoration: _inputDecoration(
            hint: hint,
            prefixText: prefixText,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '$label wajib diisi';
            }
            return null;
          },
        ),
      ],
    );
  }

  // =========================================================
  // DROPDOWN
  // =========================================================
  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required String hint,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label),
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: _navy,
            size: 18,
          ),
          style: const TextStyle(
            color: Color(0xFF344054),
            fontSize: 10,
          ),
          decoration: _inputDecoration(hint: hint),
          items: items
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(item),
                ),
              )
              .toList(),
          onChanged: _isUploading ? null : onChanged,
          validator: (selectedValue) {
            if (selectedValue == null || selectedValue.isEmpty) {
              return '$label wajib dipilih';
            }
            return null;
          },
        ),
      ],
    );
  }

  // =========================================================
  // DESCRIPTION
  // =========================================================
  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Deskripsi'),
        TextFormField(
          controller: _descriptionController,
          enabled: !_isUploading,
          minLines: 2,
          maxLines: 3,
          style: const TextStyle(
            color: Color(0xFF344054),
            fontSize: 10,
          ),
          decoration: _inputDecoration(
            hint: 'Tambahkan deskripsi buku',
          ).copyWith(
            alignLabelWithHint: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 11,
              vertical: 9,
            ),
          ),
        ),
      ],
    );
  }
}

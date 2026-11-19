
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;

  const ResetPasswordScreen({
    super.key,
    required this.email,
  });

  @override
  State<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState
    extends State<ResetPasswordScreen> {

  static const Color _green = Color(0xFF1D6B3C);
  static const Color _textDark = Color(0xFF1A1A1A);
  static const Color _textGrey = Color(0xFF5F6B76);

  final TextEditingController _passwordController =
      TextEditingController();

  final TextEditingController _confirmController =
      TextEditingController();

  bool _hidePassword = true;
  bool _hideConfirm = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // ==================== HELPERS ====================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: _green,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  String _cleanError(String? error) {
    if (error == null || error.isEmpty) {
      return 'Gagal mengubah kata sandi. Silakan coba kembali.';
    }

    return error.replaceFirst('Exception: ', '');
  }

  // ==================== PASSWORD STRENGTH ====================

  int _strength(String password) {
    if (password.isEmpty) return 0;

    int points = 0;

    if (password.length >= 8) points++;

    if (RegExp(r'[a-z]').hasMatch(password) &&
        RegExp(r'[A-Z]').hasMatch(password)) {
      points++;
    }

    if (RegExp(r'[0-9]').hasMatch(password)) {
      points++;
    }

    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      points++;
    }

    if (points <= 1) return 1;
    if (points == 2) return 2;

    return 3;
  }

  String _strengthLabel(int level) {
    switch (level) {
      case 1:
        return 'Lemah';
      case 2:
        return 'Sedang';
      case 3:
        return 'Kuat';
      default:
        return 'Belum Diisi';
    }
  }

  Color _strengthColor(int level) {
    switch (level) {
      case 1:
        return Colors.redAccent;
      case 2:
        return Colors.orange;
      case 3:
        return _green;
      default:
        return Colors.grey;
    }
  }

  // ==================== SAVE PASSWORD ====================

  Future<void> _save() async {
    if (_isSaving) return;

    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (password.length < 8) {
      _showMessage(
        'Kata sandi minimal 8 karakter.',
      );
      return;
    }

    if (password != confirm) {
      _showMessage(
        'Konfirmasi kata sandi tidak sama.',
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final authController = context.read<AuthController>();

    try {
      // Kirim kata sandi baru ke Supabase
      // menggunakan sesi recovery yang dibuat saat tautan email dibuka.
      final success =
          await authController.updatePassword(password);

      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      if (success) {
        _showMessage(
          'Kata sandi berhasil diubah. Silakan login kembali.',
        );

        // Kembali ke halaman login dan bersihkan route recovery.
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
      } else {
        _showMessage(
          _cleanError(authController.errorMessage),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      _showMessage(
        _cleanError(authController.errorMessage),
      );
    }
  }

  // ==================== MAIN UI ====================

  @override
  Widget build(BuildContext context) {
    final level = _strength(_passwordController.text);

    final passwordsMismatch =
        _confirmController.text.isNotEmpty &&
        _confirmController.text != _passwordController.text;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 16,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 420,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Tombol kembali
                  IconButton(
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                    icon: const Icon(
                      Icons.arrow_back,
                      color: _green,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Judul
                  Text(
                    'Atur Ulang Kata Sandi',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: _textDark,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Silakan masukkan kata sandi baru '
                    'untuk akun Anda.',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      height: 1.5,
                      color: _textGrey,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Email akun
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F8F4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.email_outlined,
                          color: _green,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.email.isNotEmpty
                                ? widget.email
                                : 'Akun BookCycle',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: _textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Kata sandi baru
                  _label('Kata Sandi Baru'),

                  const SizedBox(height: 8),

                  _buildPasswordField(
                    controller: _passwordController,
                    hint: 'Minimal 8 karakter',
                    icon: Icons.lock_outline,
                    hidden: _hidePassword,
                    onToggle: () {
                      setState(() {
                        _hidePassword = !_hidePassword;
                      });
                    },
                    onChanged: (_) {
                      setState(() {});
                    },
                  ),

                  const SizedBox(height: 10),

                  // Indikator kekuatan sandi
                  Row(
                    children: List.generate(3, (i) {
                      final active = i < level;

                      return Expanded(
                        child: Container(
                          height: 4,
                          margin: EdgeInsets.only(
                            right: i < 2 ? 6 : 0,
                          ),
                          decoration: BoxDecoration(
                            color: active
                                ? _strengthColor(level)
                                : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 6),

                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Kekuatan Sandi:',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: _textGrey,
                        ),
                      ),
                      Text(
                        _strengthLabel(level),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _strengthColor(level),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Konfirmasi kata sandi
                  _label('Konfirmasi Kata Sandi Baru'),

                  const SizedBox(height: 8),

                  _buildPasswordField(
                    controller: _confirmController,
                    hint: 'Ulangi kata sandi baru',
                    icon: Icons.lock_reset_outlined,
                    hidden: _hideConfirm,
                    onToggle: () {
                      setState(() {
                        _hideConfirm = !_hideConfirm;
                      });
                    },
                    onChanged: (_) {
                      setState(() {});
                    },
                    errorText: passwordsMismatch
                        ? 'Kata sandi tidak sama'
                        : null,
                  ),

                  const SizedBox(height: 24),

                  // Tombol simpan
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(
                              height: 19,
                              width: 19,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.lock_outline,
                              size: 20,
                            ),
                      label: Text(
                        _isSaving
                            ? 'MENYIMPAN...'
                            : 'SIMPAN KATA SANDI BARU',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            Colors.grey.shade400,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== LABEL ====================

  Widget _label(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: _textDark,
      ),
    );
  }

  // ==================== PASSWORD FIELD ====================

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool hidden,
    required VoidCallback onToggle,
    required ValueChanged<String> onChanged,
    String? errorText,
  }) {
    return TextField(
      controller: controller,
      obscureText: hidden,
      enabled: !_isSaving,
      onChanged: onChanged,
      style: GoogleFonts.poppins(
        fontSize: 13,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(
          fontSize: 13,
          color: Colors.grey,
        ),
        errorText: errorText,
        prefixIcon: Icon(
          icon,
          color: _green,
          size: 20,
        ),
        suffixIcon: IconButton(
          onPressed: _isSaving ? null : onToggle,
          icon: Icon(
            hidden
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: _green,
            size: 20,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: Colors.grey.shade300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: _green,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: Colors.redAccent,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: Colors.redAccent,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

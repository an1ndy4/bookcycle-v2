import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const Color _green = Color(0xFF1D6B3C);
  static const Color _darkGreen = Color(0xFF15552F);
  static const Color _lightGreen = Color(0xFFF0F7F2);
  static const Color _border = Color(0xFFE1E8E3);
  static const Color _textDark = Color(0xFF202522);
  static const Color _textGrey = Color(0xFF68756D);

  final TextEditingController _emailController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();

  bool _isSending = false;
  bool _emailSent = false;
  String _sentEmail = '';

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  String? _validateEmail(String value) {
    final email = value.trim();
    if (email.isEmpty) return 'Alamat email wajib diisi.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Masukkan alamat email yang valid.';
    }
    return null;
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? const Color(0xFFB3261E) : _darkGreen,
        ),
      );
  }

  Future<void> _sendResetLink() async {
    if (_isSending) return;

    final email = _emailController.text.trim();
    final validationMessage = _validateEmail(email);
    if (validationMessage != null) {
      _showMessage(validationMessage, isError: true);
      _emailFocusNode.requestFocus();
      return;
    }

    setState(() => _isSending = true);

    final authController = context.read<AuthController>();
    final success = await authController.forgotPassword(email);

    if (!mounted) return;
    setState(() => _isSending = false);

    if (success) {
      setState(() {
        _emailSent = true;
        _sentEmail = email;
      });
      _showMessage(
        'Jika email tersebut terdaftar, tautan pemulihan akan dikirim.',
      );
    } else {
      final error = authController.errorMessage
          ?.replaceFirst('Exception: ', '')
          .trim();
      _showMessage(
        (error == null || error.isEmpty)
            ? 'Tautan reset belum dapat dikirim. Silakan coba lagi.'
            : error,
        isError: true,
      );
    }
  }

  void _useAnotherEmail() {
    setState(() {
      _emailSent = false;
      _sentEmail = '';
      _emailController.clear();
    });
    _emailFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBackButton(),
                  const SizedBox(height: 30),
                  Center(
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: const BoxDecoration(
                        color: _lightGreen,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _emailSent
                            ? Icons.mark_email_read_outlined
                            : Icons.lock_reset_rounded,
                        color: _green,
                        size: 36,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      _emailSent ? 'Periksa Email Anda' : 'Lupa Kata Sandi?',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: _textDark,
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Center(
                    child: Text(
                      _emailSent
                          ? 'Kami telah memproses permintaan reset kata sandi Anda.'
                          : 'Tidak masalah. Masukkan email akun BookCycle Anda dan kami akan mengirimkan tautan untuk membuat kata sandi baru.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: _textGrey,
                        fontSize: 13,
                        height: 1.65,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _emailSent
                        ? _buildSuccessCard()
                        : _buildRequestCard(),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Ingat kata sandi Anda? ',
                          style: GoogleFonts.poppins(
                            color: _textGrey,
                            fontSize: 13,
                          ),
                        ),
                        GestureDetector(
                          onTap: _isSending ? null : () => Navigator.pop(context),
                          child: Text(
                            'Masuk ke sistem',
                            style: GoogleFonts.poppins(
                              color: _green,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildBackButton() {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _isSending ? null : () => Navigator.pop(context),
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Icon(Icons.arrow_back_rounded, color: _green, size: 23),
        ),
      ),
    );
  }

  Widget _buildRequestCard() {
    return Container(
      key: const ValueKey('request-card'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Alamat Email',
            style: GoogleFonts.poppins(
              color: _textDark,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 9),
          TextField(
            controller: _emailController,
            focusNode: _emailFocusNode,
            enabled: !_isSending,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            onSubmitted: (_) => _sendResetLink(),
            style: GoogleFonts.poppins(fontSize: 14, color: _textDark),
            decoration: InputDecoration(
              hintText: 'nama@email.com',
              hintStyle: GoogleFonts.poppins(
                color: Colors.grey.shade400,
                fontSize: 13,
              ),
              prefixIcon: const Icon(Icons.mail_outline_rounded, color: _green),
              filled: true,
              fillColor: const Color(0xFFFCFDFC),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: _border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: _green, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isSending ? null : _sendResetLink,
              icon: _isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                _isSending ? 'MENGIRIM TAUTAN...' : 'KIRIM LINK RESET',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _green.withValues(alpha: 0.55),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, color: _textGrey, size: 16),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Pastikan email yang dimasukkan sama dengan email akun BookCycle Anda.',
                  style: GoogleFonts.poppins(
                    color: _textGrey,
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessCard() {
    return Container(
      key: const ValueKey('success-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: _lightGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: _green, size: 30),
          ),
          const SizedBox(height: 15),
          Text(
            'Permintaan Berhasil Diproses',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: _textDark,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Jika akun dengan email ini terdaftar, tautan untuk mengatur ulang kata sandi akan dikirim ke:',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: _textGrey,
              fontSize: 12,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 13),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            decoration: BoxDecoration(
              color: _lightGreen,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              children: [
                const Icon(Icons.email_outlined, color: _green, size: 19),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    _sentEmail,
                    style: GoogleFonts.poppins(
                      color: _darkGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Buka email Anda, lalu klik tombol atau tautan “Reset Password”. Periksa juga folder Spam atau Promosi jika email belum terlihat.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: _textGrey,
              fontSize: 11,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _isSending ? null : _sendResetLink,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                _isSending ? 'MENGIRIM ULANG...' : 'KIRIM ULANG LINK',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _green,
                side: const BorderSide(color: _green),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _isSending ? null : _useAnotherEmail,
            child: Text(
              'Gunakan email lain',
              style: GoogleFonts.poppins(
                color: _textGrey,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

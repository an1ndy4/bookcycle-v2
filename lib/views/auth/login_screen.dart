
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../controllers/auth_controller.dart';
import '../user/home_screen.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailC = TextEditingController();
  final _passC = TextEditingController();

  final SupabaseClient _supabase = Supabase.instance.client;

  StreamSubscription<AuthState>? _authSubscription;

  bool _hidePass = true;
  bool _isGoogleLoading = false;
  bool _isCheckingSession = false;
  bool _hasNavigated = false;

  static const Color _green = Color(0xFF1B6B3A);
  static const Color _darkGreen = Color(0xFF1B5E20);

  static final RegExp _emailRegex = RegExp(
    r'^[\w\.\-]+@([\w\-]+\.)+[a-zA-Z]{2,}$',
  );

  // ==================== INIT STATE ====================
  @override
  void initState() {
    super.initState();

    // Mendengarkan perubahan sesi Supabase.
    // Diperlukan saat kembali dari halaman login Google.
    _authSubscription = _supabase.auth.onAuthStateChange.listen(
      (data) {
        if (data.event == AuthChangeEvent.signedIn &&
            data.session != null) {
          _handleAuthenticatedSession();
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!mounted) return;

        _showMessage('Gagal memeriksa sesi login: $error');
      },
    );

    // Jika browser kembali dari Google dan sesi
    // sudah tersimpan, langsung periksa pengguna.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (_supabase.auth.currentSession != null) {
        _handleAuthenticatedSession();
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _emailC.dispose();
    _passC.dispose();
    super.dispose();
  }

  // ==================== HELPERS ====================
  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _goToHome() {
    if (!mounted || _hasNavigated) return;

    _hasNavigated = true;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const HomeScreen(),
      ),
    );
  }

  // ==================== CHECK LOGIN SESSION ====================
  Future<void> _handleAuthenticatedSession() async {
    if (!mounted || _isCheckingSession || _hasNavigated) {
      return;
    }

    if (_supabase.auth.currentUser == null) {
      return;
    }

    _isCheckingSession = true;

    try {
      // Sinkronkan profil dengan AuthController.
      final controller = context.read<AuthController>();

      await controller.loadCurrentUser();

      if (!mounted || _hasNavigated) return;

      if (controller.currentUser == null) {
        _showMessage(
          'Login berhasil, tetapi profil BookCycle '
          'belum ditemukan di database.',
        );
        return;
      }

      _goToHome();
    } catch (e) {
      _showMessage('Gagal memuat profil setelah login: $e');
    } finally {
      _isCheckingSession = false;
    }
  }

  // ==================== VALIDASI ====================
  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) {
      return 'Email wajib diisi';
    }

    if (!_emailRegex.hasMatch(v.trim())) {
      return 'Format email tidak valid';
    }

    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) {
      return 'Password wajib diisi';
    }

    if (v.length < 6) {
      return 'Password minimal 6 karakter';
    }

    return null;
  }

  // ==================== LOGIN EMAIL ====================
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final controller = context.read<AuthController>();

    final success = await controller.login(
      email: _emailC.text.trim(),
      password: _passC.text,
    );

    if (!mounted || _hasNavigated) return;

    if (success) {
      _goToHome();
    } else {
      _showMessage(
        controller.errorMessage ?? 'Login gagal',
      );
    }
  }

  // ==================== LOGIN GOOGLE ====================
  Future<void> _handleGoogleLogin() async {
    if (_isGoogleLoading) return;

    setState(() {
      _isGoogleLoading = true;
    });

    try {
      // Untuk Flutter Web, pengguna akan kembali
      // ke alamat localhost yang sedang digunakan.
      final String? redirectUrl =
          kIsWeb ? '${Uri.base.origin}/' : null;

      final success = await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectUrl,
      );

      if (!success) {
        throw Exception(
          'Tidak dapat membuka halaman login Google',
        );
      }

      // Di Flutter Web, browser dialihkan ke Google.
      // Setelah kembali ke BookCycle, sesi login
      // diproses oleh _handleAuthenticatedSession().
    } catch (e) {
      _showMessage('Login Google gagal: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
    }
  }

  // ==================== REGISTER ====================
  void _goToRegister() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const RegisterScreen(),
      ),
    );
  }

  // ==================== INPUT DECORATION ====================
  InputDecoration _decoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(
        fontSize: 13,
        color: Colors.grey,
      ),
      prefixIcon: Icon(
        icon,
        color: _green,
        size: 22,
      ),
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(
        vertical: 12,
      ),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(
          color: Color(0xFFBDBDBD),
        ),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(
          color: _green,
          width: 1.5,
        ),
      ),
      errorBorder: const UnderlineInputBorder(
        borderSide: BorderSide(
          color: Colors.red,
        ),
      ),
      focusedErrorBorder: const UnderlineInputBorder(
        borderSide: BorderSide(
          color: Colors.red,
          width: 1.5,
        ),
      ),
      errorStyle: GoogleFonts.poppins(
        fontSize: 11,
      ),
    );
  }

  // ==================== UI ====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 430,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 28,
                vertical: 20,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ==================== LOGO ====================
                    Center(
                      child: Column(
                        children: [
                          Image.asset(
                            'assets/images/logo.jpg.jpeg',
                            width: 80,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                const Icon(
                              Icons.auto_stories,
                              color: _green,
                              size: 80,
                            ),
                          ),
                          Text(
                            'BookCycle',
                            style: GoogleFonts.poppins(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: _darkGreen,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // ==================== JUDUL ====================
                    Text(
                      'Selamat datang kembali!',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      'Login untuk melanjutkan.',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFF1F3A5F),
                      ),
                    ),

                    const SizedBox(height: 22),

                    // ==================== EMAIL ====================
                    TextFormField(
                      controller: _emailC,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: _validateEmail,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                      ),
                      decoration: _decoration(
                        hint: 'Email',
                        icon: Icons.mail_outline,
                      ),
                    ),

                    const SizedBox(height: 6),

                    // ==================== PASSWORD ====================
                    TextFormField(
                      controller: _passC,
                      obscureText: _hidePass,
                      textInputAction: TextInputAction.done,
                      validator: _validatePassword,
                      onFieldSubmitted: (_) => _handleLogin(),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                      ),
                      decoration: _decoration(
                        hint: 'Password',
                        icon: Icons.lock_outline,
                        suffix: IconButton(
                          icon: Icon(
                            _hidePass
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: _green,
                            size: 22,
                          ),
                          onPressed: () {
                            setState(() {
                              _hidePass = !_hidePass;
                            });
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ==================== FORGOT PASSWORD ====================
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ForgotPasswordScreen(),
                            ),
                          );
                        },
                        child: Text(
                          'Lupa Password?',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _green,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ==================== LOGIN BUTTON ====================
                    Consumer<AuthController>(
                      builder: (context, controller, _) {
                        return SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: controller.isLoading
                                ? null
                                : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(8),
                              ),
                            ),
                            child: controller.isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child:
                                        CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(
                                    'Login',
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight:
                                          FontWeight.w600,
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 18),

                    // ==================== SOCIAL LOGIN ====================
                    Center(
                      child: Text(
                        'atau masuk dengan',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFF444444),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // LOGIN SOSIAL HANYA MENGGUNAKAN GOOGLE.
                        _socialButton(
                          label: _isGoogleLoading ? 'Memuat...' : 'Google',
                          icon: _isGoogleLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _green,
                                  ),
                                )
                              : const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CustomPaint(
                                    painter: GoogleLogoPainter(),
                                  ),
                                ),
                          onTap: _handleGoogleLogin,
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    // ==================== REGISTER ====================
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Belum punya akun? ',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                            ),
                          ),
                          GestureDetector(
                            onTap: _goToRegister,
                            child: Text(
                              'Daftar sekarang',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _green,
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
      ),
    );
  }

  // ==================== SOCIAL BUTTON ====================
  Widget _socialButton({
    required String label,
    required Widget icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 6,
          vertical: 4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

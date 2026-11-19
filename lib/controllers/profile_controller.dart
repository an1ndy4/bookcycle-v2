
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class ProfileController extends ChangeNotifier {
  final AuthService _authService = AuthService();

  // ==================== STATE ====================
  UserModel? _profile;
  bool _isLoading = false;
  bool _isUpdating = false;
  String? _errorMessage;

  // ==================== GETTERS ====================
  UserModel? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isUpdating => _isUpdating;
  String? get errorMessage => _errorMessage;

  bool get hasProfile => _profile != null;

  // ==================== LOAD PROFILE ====================
  Future<void> loadProfile() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = _authService.currentUser;

      if (user == null) {
        _profile = null;
        throw Exception('Pengguna belum login');
      }

      final result = await _authService.getUserProfile();

      if (result == null) {
        _profile = null;
        throw Exception(
          'Profil pengguna tidak ditemukan',
        );
      }

      _profile = result;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==================== UPDATE PROFILE ====================
  Future<bool> updateProfile({
    String? namaLengkap,
    String? nomorHp,
    String? alamat,
  }) async {
    if (_isUpdating) return false;

    _isUpdating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_authService.currentUser == null) {
        throw Exception('Pengguna belum login');
      }

      if (namaLengkap != null &&
          namaLengkap.trim().isEmpty) {
        throw Exception('Nama lengkap tidak boleh kosong');
      }

      await _authService.updateProfile(
        namaLengkap: namaLengkap?.trim(),
        nomorHp: nomorHp?.trim(),
        alamat: alamat?.trim(),
      );

      // Ambil ulang profil terbaru dari database.
      final updatedProfile =
          await _authService.getUserProfile();

      if (updatedProfile == null) {
        throw Exception(
          'Gagal memuat profil setelah diperbarui',
        );
      }

      _profile = updatedProfile;

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  // ==================== REFRESH PROFILE ====================
  Future<void> refreshProfile() async {
    await loadProfile();
  }

  // ==================== CLEAR ERROR ====================
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ==================== RESET PROFILE ====================
  void reset() {
    _profile = null;
    _isLoading = false;
    _isUpdating = false;
    _errorMessage = null;

    notifyListeners();
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class AuthProvider extends ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService.instance;
  
  User? _user;
  bool _isLoading = false;
  String? _errorMessage;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _user = _supabaseService.currentUser;
    _supabaseService.client.auth.onAuthStateChange.listen((data) {
      _user = data.session?.user;
      notifyListeners();
    });
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _supabaseService.signIn(email: email, password: password);
      _user = _supabaseService.currentUser;
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      if (e.message.toLowerCase().contains('confirm') || e.message.toLowerCase().contains('verified')) {
        _errorMessage = 'Email not confirmed yet. Please verify your email via the link sent to your inbox, or disable email confirmation in your Supabase Auth dashboard.';
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String whatsapp,
    required String companyName,
    required String gstNumber,
    required String companyAddress,
    String? logoBase64,
    String? signatureBase64,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _supabaseService.signUp(
        email: email,
        password: password,
        userMetadata: {
          'first_name': firstName,
          'last_name': lastName,
          'whatsapp_number': whatsapp,
          'company_name': companyName,
          'gst_number': gstNumber,
          'company_address': companyAddress,
          'logo_url': ?logoBase64,
          'signature_url': ?signatureBase64,
        },
      );

      _isLoading = false;
      
      // If session is null, email confirmation is required.
      if (response.session == null) {
        _errorMessage = 'CONFIRMATION_REQUIRED';
        notifyListeners();
        return false;
      }

      _user = response.user;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _supabaseService.signOut();
    _user = null;
    notifyListeners();
  }
}

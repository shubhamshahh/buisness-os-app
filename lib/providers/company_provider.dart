import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class CompanyProvider extends ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService.instance;

  int? _companyId;
  String _companyName = '';
  String _role = 'owner';
  bool _isLoading = false;

  int? get companyId => _companyId;
  String get companyName => _companyName;
  String get role => _role;
  bool get isLoading => _isLoading;

  CompanyProvider() {
    _supabaseService.client.auth.onAuthStateChange.listen((data) {
      if (data.session?.user != null) {
        fetchCompany(data.session!.user.id);
      } else {
        clear();
      }
    });
    if (_supabaseService.currentUser != null) {
      fetchCompany(_supabaseService.currentUser!.id);
    }
  }

  Future<void> fetchCompany(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _supabaseService.client
          .from('user_companies')
          .select('company_id, role, companies(name)')
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        _companyId = response['company_id'] as int?;
        _role = (response['role'] as String?) ?? 'owner';
        
        final companiesObj = response['companies'];
        if (companiesObj != null && companiesObj is Map) {
          _companyName = (companiesObj['name'] as String?) ?? 'BusinessOS';
        } else {
          _companyName = 'BusinessOS';
        }
      } else {
        // Fallback: If no company mapping exists, check if there is any company in the database
        final List<dynamic> companiesList = await _supabaseService.client
            .from('companies')
            .select('id, name')
            .limit(1);

        if (companiesList.isNotEmpty) {
          final firstCompany = companiesList.first;
          final int cid = firstCompany['id'] as int;
          
          await _supabaseService.client.from('user_companies').insert({
            'user_id': userId,
            'company_id': cid,
            'role': 'owner'
          });
          
          _companyId = cid;
          _companyName = (firstCompany['name'] as String?) ?? 'BusinessOS';
          _role = 'owner';
        } else {
          // If no company exists at all, create a default one
          final List<dynamic> newCompanyList = await _supabaseService.client.from('companies').insert({
            'name': 'My Business',
          }).select('id, name');

          if (newCompanyList.isNotEmpty) {
            final newCompany = newCompanyList.first;
            final int cid = newCompany['id'] as int;
            
            await _supabaseService.client.from('user_companies').insert({
              'user_id': userId,
              'company_id': cid,
              'role': 'owner'
            });
            
            _companyId = cid;
            _companyName = 'My Business';
            _role = 'owner';
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching user company: $e');
      clear();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _companyId = null;
    _companyName = '';
    _role = 'owner';
    notifyListeners();
  }
}

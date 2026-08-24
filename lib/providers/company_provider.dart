import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class CompanyProvider extends ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService.instance;

  int? _companyId;
  String _companyName = '';
  String _logoUrl = '';
  String _role = 'owner';
  bool _isLoading = false;
  String _debugMessage = '';

  int? get companyId => _companyId;
  String get companyName => _companyName;
  String get logoUrl => _logoUrl;
  String get role => _role;
  bool get isLoading => _isLoading;
  String get debugMessage => _debugMessage;

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
      bool loaded = false;
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
            _companyName = (companiesObj['name'] as String?) ?? 'MK Polymers';
          } else {
            _companyName = 'MK Polymers';
          }
          loaded = true;
        }
      } catch (joinedError) {
        debugPrint('Joined company select query failed, trying sequential query: $joinedError');
      }

      if (!loaded) {
        final response = await _supabaseService.client
            .from('user_companies')
            .select('company_id, role')
            .eq('user_id', userId)
            .maybeSingle();

        if (response != null) {
          _companyId = response['company_id'] as int?;
          _role = (response['role'] as String?) ?? 'owner';
          
          if (_companyId != null) {
            final compRes = await _supabaseService.client
                .from('companies')
                .select('name')
                .eq('id', _companyId!)
                .maybeSingle();
                
            if (compRes != null) {
              _companyName = (compRes['name'] as String?) ?? 'MK Polymers';
            } else {
              _companyName = 'MK Polymers';
            }
          }
          loaded = true;
        } else {
          // User has no company mapping yet. Check signup metadata
          final metadata = _supabaseService.currentUser?.userMetadata ?? {};
          final userCompanyName = metadata['company_name'] as String?;
          final userAddress = metadata['company_address'] as String?;
          final userGstin = metadata['gst_number'] as String?;
          final userSig = metadata['signature_url'] as String?;

          if (userCompanyName != null && userCompanyName.trim().isNotEmpty) {
            final List<dynamic> newCompanyList = await _supabaseService.client.from('companies').insert({
              'name': userCompanyName.trim(),
              'address': userAddress ?? '',
              'gst_number': userGstin ?? '',
              'signatory_name': userSig ?? '',
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
              _companyName = (newCompany['name'] as String?) ?? userCompanyName;
              _role = 'owner';
            }
          } else {
            // Fallback to first existing company
            final List<dynamic> companiesList = await _supabaseService.client
                .from('companies')
                .select('id, name')
                .order('id', ascending: true)
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
              _companyName = (firstCompany['name'] as String?) ?? 'MK Polymers';
              _role = 'owner';
            }
          }
        }
      }

      // Auto-repair placeholders
      if (_companyId != null) {
        final metadata = _supabaseService.currentUser?.userMetadata ?? {};
        final userCompanyName = metadata['company_name'] as String?;
        final userLogo = metadata['logo_url'] as String?;
        if (userLogo != null && userLogo.isNotEmpty) {
          _logoUrl = userLogo;
        }

        if (_companyName == 'BusinessOS' || _companyName == 'My Business' || _companyName == 'Business OS') {
          if (userCompanyName != null && userCompanyName.trim().isNotEmpty) {
            _companyName = userCompanyName.trim();
            try {
              await _supabaseService.client
                  .from('companies')
                  .update({'name': _companyName})
                  .eq('id', _companyId!);
            } catch (_) {}
          } else {
            _companyName = 'MK Polymers';
          }
        }
      }
    } catch (e, stackTrace) {
      _debugMessage = 'Error: $e\n$stackTrace';
      debugPrint('Error fetching user company: $e\n$stackTrace');
      clear();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _companyId = null;
    _companyName = '';
    _logoUrl = '';
    _role = 'owner';
    _debugMessage = '';
    notifyListeners();
  }
}

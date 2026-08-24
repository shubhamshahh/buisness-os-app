import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService instance = SupabaseService._internal();
  SupabaseService._internal();

  SupabaseClient get client => Supabase.instance.client;

  // Authentication Methods
  Future<AuthResponse> signIn({required String email, required String password}) async {
    return await client.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> userMetadata,
  }) async {
    return await client.auth.signUp(
      email: email,
      password: password,
      data: userMetadata,
    );
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }

  Session? get currentSession => client.auth.currentSession;
  User? get currentUser => client.auth.currentUser;

  // Generic DB Methods
  Future<List<Map<String, dynamic>>> getTableData({
    required String table,
    required int companyId,
    String? eqColumn,
    dynamic eqValue,
    String? orderBy,
    bool ascending = true,
  }) async {
    dynamic query = client.from(table).select().eq('company_id', companyId);
    if (eqColumn != null && eqValue != null) {
      query = query.eq(eqColumn, eqValue);
    }
    if (orderBy != null) {
      query = query.order(orderBy, ascending: ascending);
    }
    final List<dynamic> response = await query;
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>?> getSingle({
    required String table,
    required int companyId,
    required String eqColumn,
    required dynamic eqValue,
  }) async {
    try {
      final response = await client
          .from(table)
          .select()
          .eq('company_id', companyId)
          .eq(eqColumn, eqValue)
          .maybeSingle();
      return response;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> insert({
    required String table,
    required Map<String, dynamic> row,
  }) async {
    final response = await client.from(table).insert(row).select().single();
    return response;
  }

  Future<List<Map<String, dynamic>>> insertBatch({
    required String table,
    required List<Map<String, dynamic>> rows,
  }) async {
    final response = await client.from(table).insert(rows).select();
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> update({
    required String table,
    required dynamic id,
    required Map<String, dynamic> values,
  }) async {
    await client.from(table).update(values).eq('id', id);
  }
}

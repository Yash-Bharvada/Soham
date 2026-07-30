import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';

// ── Current user profile ─────────────────────────────────────────────────────
final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return null;

  try {
    final data = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    return data != null ? Profile.fromJson(data) : null;
  } catch (e) {
    if (e.toString().contains('JWT issued at future') ||
        e.toString().contains('PGRST303')) {
      await Supabase.instance.client.auth.signOut();
    }
    return null;
  }
});

// ── Auth service actions ──────────────────────────────────────────────────────
class AuthService {
  final _supabase = Supabase.instance.client;

  Future<AuthResponse> signIn(String email, String password) async {
    try {
      return await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } catch (e) {
      if (e.toString().contains('JWT issued at future') ||
          e.toString().contains('PGRST303')) {
        await _supabase.auth.signOut();
        return await _supabase.auth.signInWithPassword(
          email: email.trim(),
          password: password,
        );
      }
      rethrow;
    }
  }

  Future<AuthResponse> signUp({
    required String name,
    required String email,
    required String password,
    required String phone,
  }) async {
    final res = await _supabase.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'name': name.trim(),
        'role': 'tenant',
        'phone': phone.trim(),
      },
    );

    if (res.user != null) {
      try {
        // Update phone in profile (trigger handles name/role)
        await _supabase
            .from('profiles')
            .update({'phone': phone.trim(), 'name': name.trim()})
            .eq('id', res.user!.id);

        // Create 3 document rows
        await _supabase.from('documents').upsert([
          {'tenant_id': res.user!.id, 'type': 'self', 'status': 'pending'},
          {'tenant_id': res.user!.id, 'type': 'father', 'status': 'pending'},
          {'tenant_id': res.user!.id, 'type': 'mother', 'status': 'pending'},
        ]);
      } catch (_) {
        // Table or trigger might not be populated yet, ignore post-signup DB step
      }
    }

    return res;
  }

  Future<void> signOut() => _supabase.auth.signOut();

  User? get currentUser => _supabase.auth.currentUser;

  String get currentRole =>
      currentUser?.userMetadata?['role'] as String? ?? 'tenant';

  bool get isOwner => currentRole == 'owner';
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

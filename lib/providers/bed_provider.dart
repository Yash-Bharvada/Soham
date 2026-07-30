import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/bed.dart';
import '../models/profile.dart';

// ── All beds (streamed, real-time) ───────────────────────────────────────────
final bedsStreamProvider = StreamProvider<List<Bed>>((ref) {
  // Auto-sync rent_amount to 2500 in Supabase database
  Supabase.instance.client
      .from('beds')
      .update({'rent_amount': 2500})
      .neq('rent_amount', 2500)
      .then((_) {})
      .catchError((_) {});
  Supabase.instance.client
      .from('payments')
      .update({'amount': 2500})
      .eq('status', 'pending')
      .then((_) {})
      .catchError((_) {});

  return Supabase.instance.client
      .from('beds')
      .stream(primaryKey: ['id'])
      .order('id')
      .map((rows) => rows.map(Bed.fromJson).toList());
});

// ── All tenant profiles (direct query, reliable) ──────────────────────────────
final allTenantsStreamProvider = FutureProvider<List<Profile>>((ref) async {
  final data = await Supabase.instance.client
      .from('profiles')
      .select()
      .eq('role', 'tenant')
      .order('created_at', ascending: false);

  return data.map((row) => Profile.fromJson(row)).toList();
});

// ── Beds with tenant profiles joined ─────────────────────────────────────────
final bedsWithTenantsProvider = FutureProvider<List<Bed>>((ref) async {
  final supabase = Supabase.instance.client;

  final bedsData = await supabase
      .from('beds')
      .select('*, tenant:profiles(id, name, email, avatar_url, phone)')
      .order('id');

  return bedsData.map((row) {
    final bed = Bed.fromJson(row);
    final tenantJson = row['tenant'] as Map<String, dynamic>?;
    if (tenantJson != null) {
      return bed.copyWith(
        tenant: Profile.fromJson({
          ...tenantJson,
          'role': 'tenant',
          'created_at': DateTime.now().toIso8601String(),
        }),
      );
    }
    return bed;
  }).toList();
});

// ── Tenant's own bed ──────────────────────────────────────────────────────────
final myBedProvider = FutureProvider<Bed?>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return null;

  final data = await Supabase.instance.client
      .from('beds')
      .select()
      .eq('tenant_id', user.id)
      .maybeSingle();

  return data != null ? Bed.fromJson(data) : null;
});

// ── Occupancy stats ───────────────────────────────────────────────────────────
final occupancyProvider = Provider<AsyncValue<({int occupied, int total})>>(
  (ref) {
    return ref.watch(bedsStreamProvider).when(
          data: (beds) => AsyncData((
            occupied: beds.where((b) => b.isOccupied).length,
            total: beds.length,
          )),
          loading: () => const AsyncLoading(),
          error: (e, s) => AsyncError(e, s),
        );
  },
);

// ── Assign tenant to bed ──────────────────────────────────────────────────────
Future<void> assignTenantToBed(String tenantId, int bedId) async {
  await Supabase.instance.client
      .from('beds')
      .update({'tenant_id': tenantId, 'move_in_date': DateTime.now().toIso8601String().split('T').first})
      .eq('id', bedId);
}

// ── Unassign tenant from bed ──────────────────────────────────────────────────
Future<void> unassignTenantFromBed(int bedId) async {
  await Supabase.instance.client
      .from('beds')
      .update({'tenant_id': null, 'move_in_date': null})
      .eq('id', bedId);
}

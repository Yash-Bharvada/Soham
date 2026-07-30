import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/bed.dart';
import '../../models/payment.dart';
import '../../models/profile.dart';
import '../../providers/bed_provider.dart';
import '../../providers/payment_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/tenant_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bedsAsync = ref.watch(bedsStreamProvider);
    final paymentsAsync = ref.watch(allPaymentsStreamProvider);
    final collectedAsync = ref.watch(collectedThisMonthProvider);
    final occupancyAsync = ref.watch(occupancyProvider);

    final user = Supabase.instance.client.auth.currentUser;
    final ownerName = user?.userMetadata?['name'] as String? ?? 'Owner';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Navy header ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 20,
                left: AppDimensions.screenPadding,
                right: AppDimensions.screenPadding,
                bottom: 24,
              ),
              decoration: AppDecorations.navyGradient,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Soham', style: AppTextStyles.headerTitle),
                        Text('Owner dashboard',
                            style: AppTextStyles.headerSubtitle),
                      ],
                    ),
                  ),
                  _OwnerAvatar(name: ownerName),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(AppDimensions.screenPadding),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Stat cards ────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: collectedAsync.when(
                        data: (amount) => StatCard(
                          label: 'Collected this month',
                          value:
                              '₹${NumberFormat('#,##,###').format(amount.toInt())}',
                          subtitle: _paidCountSubtitle(paymentsAsync, ref),
                          icon: Icons.currency_rupee,
                          iconBg: const Color(0xFFE8F5E9),
                        ),
                        loading: () => const StatCard(
                          label: 'Collected this month',
                          value: '...',
                          icon: Icons.currency_rupee,
                        ),
                        error: (_, __) => const StatCard(
                          label: 'Collected this month',
                          value: '—',
                          icon: Icons.currency_rupee,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: occupancyAsync.when(
                        data: (occ) => StatCard(
                          label: 'Occupancy',
                          value: '${((occ.occupied / occ.total) * 100).toInt()}%',
                          subtitle: '${occ.occupied} / ${occ.total} beds filled',
                          icon: Icons.bed_outlined,
                          iconBg: const Color(0xFFE3F2FD),
                        ),
                        loading: () => const StatCard(
                          label: 'Occupancy',
                          value: '...',
                          icon: Icons.bed_outlined,
                        ),
                        error: (_, __) => const StatCard(
                          label: 'Occupancy',
                          value: '—',
                          icon: Icons.bed_outlined,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Tenants section ────────────────────────────────────
                Text('Tenants', style: AppTextStyles.screenTitle),
                const SizedBox(height: 12),

                bedsAsync.when(
                  data: (beds) => _TenantsList(
                    beds: beds,
                    paymentsAsync: paymentsAsync,
                  ),
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (e, _) => Center(
                    child: Text('Error: $e',
                        style: AppTextStyles.bodyMedium),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  String? _paidCountSubtitle(
      AsyncValue<List<Payment>> paymentsAsync, WidgetRef ref) {
    final allTenants = ref.watch(allTenantsStreamProvider).valueOrNull ?? [];
    final totalTenants = allTenants.isNotEmpty ? allTenants.length : 1;

    return paymentsAsync.whenOrNull(data: (payments) {
      final now = DateTime.now();
      final paidTenantsCount = payments
          .where((p) =>
              p.isPaid &&
              p.paidDate != null &&
              p.paidDate!.month == now.month &&
              p.paidDate!.year == now.year)
          .map((p) => p.tenantId)
          .toSet()
          .length;
      final tenantWord = totalTenants == 1 ? 'tenant' : 'tenants';
      return '$paidTenantsCount of $totalTenants $tenantWord paid';
    });
  }
}

class _TenantsList extends ConsumerWidget {
  final List<Bed> beds;
  final AsyncValue<List<Payment>> paymentsAsync;

  const _TenantsList({required this.beds, required this.paymentsAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latestPaymentsAsync = ref.watch(latestPaymentPerTenantProvider);
    final allTenantsAsync = ref.watch(allTenantsStreamProvider);

    final assignedIds =
        beds.where((b) => b.isOccupied).map((b) => b.tenantId!).toSet();
    final vacantBeds = beds.where((b) => !b.isOccupied).toList();

    final unassignedTenants = allTenantsAsync.whenOrNull(
          data: (tenants) =>
              tenants.where((t) => !assignedIds.contains(t.id)).toList(),
        ) ??
        [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (unassignedTenants.isNotEmpty) ...[
          Row(
            children: [
              Text('Unassigned Registered Tenants',
                  style: AppTextStyles.cardTitle),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.amberBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${unassignedTenants.length} pending',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.amber,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...unassignedTenants.map((tenant) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: AppDecorations.card.copyWith(
                  border: Border.all(color: AppColors.amber.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    InitialsAvatar(
                      name: tenant.name,
                      avatarUrl: tenant.avatarUrl,
                      size: 44,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tenant.name, style: AppTextStyles.cardTitle),
                          const SizedBox(height: 2),
                          Text(
                            tenant.phone?.isNotEmpty == true
                                ? tenant.phone!
                                : tenant.email,
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () =>
                          _showAssignBedModal(context, tenant, vacantBeds),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.coral,
                        minimumSize: const Size(90, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('Assign Bed',
                          style:
                              AppTextStyles.labelLarge.copyWith(fontSize: 12)),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 16),
          Text('Bed Allocation', style: AppTextStyles.cardTitle),
          const SizedBox(height: 10),
        ],
        ...beds.map((bed) {
          if (!bed.isOccupied) {
            return _EmptyBedCard(
                bed: bed, unassignedTenants: unassignedTenants);
          }

          return FutureBuilder<Profile?>(
            future: _fetchProfile(bed.tenantId!),
            builder: (context, snap) {
              final tenant = snap.data;
              if (tenant == null) {
                return _LoadingBedCard(bedNumber: bed.bedNumber);
              }

              final latestPayment = latestPaymentsAsync.whenOrNull(
                data: (map) => map[bed.tenantId],
              );

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TenantCard(
                  tenant: tenant,
                  bedNumber: bed.bedNumber,
                  rentAmount: bed.rentAmount,
                  latestPayment: latestPayment,
                  onTap: () => context.push('/owner/tenants/${tenant.id}'),
                ),
              );
            },
          );
        }),
      ],
    );
  }

  Future<Profile?> _fetchProfile(String id) async {
    final data = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', id)
        .maybeSingle();
    return data != null ? Profile.fromJson(data) : null;
  }
}

class _EmptyBedCard extends StatelessWidget {
  final Bed bed;
  final List<Profile> unassignedTenants;

  const _EmptyBedCard(
      {required this.bed, this.unassignedTenants = const []});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: AppDecorations.card,
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.border,
              child: const Icon(Icons.bed_outlined,
                  color: AppColors.textSecondary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(bed.bedNumber, style: AppTextStyles.cardTitle),
                  Text('Vacant', style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            if (unassignedTenants.isNotEmpty)
              OutlinedButton(
                onPressed: () =>
                    _showTenantPickerForBed(context, bed, unassignedTenants),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.navy),
                  minimumSize: const Size(100, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('+ Assign',
                    style: AppTextStyles.caption.copyWith(
                        color: AppColors.navy, fontWeight: FontWeight.w600)),
              )
            else
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'Empty',
                  style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

void _showAssignBedModal(
    BuildContext context, Profile tenant, List<Bed> vacantBeds) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Assign ${tenant.name} to a Bed',
                style: AppTextStyles.cardTitle),
          ),
          if (vacantBeds.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No vacant beds available right now.'),
            )
          else
            ...vacantBeds.map((bed) => ListTile(
                  leading:
                      const Icon(Icons.bed_outlined, color: AppColors.navy),
                  title: Text(bed.bedNumber),
                  subtitle: Text('₹${bed.rentAmount.toInt()} / month'),
                  trailing: const Icon(Icons.add_circle_outline,
                      color: AppColors.coral),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await assignTenantToBed(tenant.id, bed.id);
                    await createPayment(
                      tenantId: tenant.id,
                      amount: bed.rentAmount,
                      dueDate: DateTime.now().add(const Duration(days: 5)),
                    );
                  },
                )),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
}

void _showTenantPickerForBed(
    BuildContext context, Bed bed, List<Profile> unassignedTenants) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Assign to ${bed.bedNumber}',
                style: AppTextStyles.cardTitle),
          ),
          ...unassignedTenants.map((tenant) => ListTile(
                leading: InitialsAvatar(
                  name: tenant.name,
                  avatarUrl: tenant.avatarUrl,
                  size: 36,
                ),
                title: Text(tenant.name),
                subtitle: Text(tenant.email),
                trailing: const Icon(Icons.check_circle_outline,
                    color: AppColors.green),
                onTap: () async {
                  Navigator.pop(ctx);
                  await assignTenantToBed(tenant.id, bed.id);
                  await createPayment(
                    tenantId: tenant.id,
                    amount: bed.rentAmount,
                    dueDate: DateTime.now().add(const Duration(days: 5)),
                  );
                },
              )),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
}

class _LoadingBedCard extends StatelessWidget {
  final String bedNumber;
  const _LoadingBedCard({required this.bedNumber});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: AppDecorations.card,
        child: Row(
          children: [
            const CircleAvatar(radius: 22, backgroundColor: AppColors.border),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bedNumber, style: AppTextStyles.cardTitle),
                Text('Loading...', style: AppTextStyles.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnerAvatar extends StatelessWidget {
  final String name;
  const _OwnerAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 22,
      backgroundColor: Colors.white.withOpacity(0.2),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'O',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
    );
  }
}

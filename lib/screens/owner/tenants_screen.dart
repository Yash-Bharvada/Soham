import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/bed.dart';
import '../../models/payment.dart';
import '../../models/profile.dart';
import '../../providers/bed_provider.dart';
import '../../providers/payment_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/tenant_card.dart';

class TenantsScreen extends ConsumerWidget {
  const TenantsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bedsAsync = ref.watch(bedsStreamProvider);
    final allTenantsAsync = ref.watch(allTenantsStreamProvider);
    final latestPaymentsAsync = ref.watch(latestPaymentPerTenantProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 20,
                left: AppDimensions.screenPadding,
                right: AppDimensions.screenPadding,
                bottom: 24,
              ),
              decoration: AppDecorations.navyGradient,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tenants', style: AppTextStyles.headerTitle),
                  Text('Soham · 4 beds & registered tenants',
                      style: AppTextStyles.headerSubtitle),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(AppDimensions.screenPadding),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Unassigned / New Registered Tenants Section ──────────
                allTenantsAsync.when(
                  data: (tenants) {
                    final beds = bedsAsync.valueOrNull ?? [];
                    final assignedIds = beds
                        .where((b) => b.isOccupied)
                        .map((b) => b.tenantId!)
                        .toSet();
                    final unassigned =
                        tenants.where((t) => !assignedIds.contains(t.id)).toList();

                    if (unassigned.isEmpty) return const SizedBox.shrink();

                    final vacantBeds = beds.where((b) => !b.isOccupied).toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('New / Unassigned Tenants',
                                style: AppTextStyles.cardTitle),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.amberBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${unassigned.length} pending',
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
                        ...unassigned.map((tenant) => _UnassignedTenantCard(
                              tenant: tenant,
                              vacantBeds: vacantBeds,
                              onTap: () =>
                                  context.push('/owner/tenants/${tenant.id}'),
                            )),
                        const SizedBox(height: 20),
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                // ── Beds List ─────────────────────────────────────────
                Text('Bed Allocation', style: AppTextStyles.cardTitle),
                const SizedBox(height: 10),

                bedsAsync.when(
                  data: (beds) {
                    final tenants = allTenantsAsync.valueOrNull ?? [];
                    final assignedIds = beds
                        .where((b) => b.isOccupied)
                        .map((b) => b.tenantId!)
                        .toSet();
                    final unassigned =
                        tenants.where((t) => !assignedIds.contains(t.id)).toList();

                    return Column(
                      children: beds.map((bed) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _BedTenantCard(
                            bed: bed,
                            unassignedTenants: unassigned,
                            latestPaymentsAsync: latestPaymentsAsync,
                            onTap: bed.tenantId != null
                                ? () => context
                                    .push('/owner/tenants/${bed.tenantId}')
                                : null,
                          ),
                        );
                      }).toList(),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Unassigned tenant card widget ─────────────────────────────────────────────
class _UnassignedTenantCard extends StatelessWidget {
  final Profile tenant;
  final List<Bed> vacantBeds;
  final VoidCallback onTap;

  const _UnassignedTenantCard({
    required this.tenant,
    required this.vacantBeds,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            onPressed: () => _showAssignBedModal(context, tenant, vacantBeds),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.coral,
              minimumSize: const Size(90, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Assign Bed',
                style: AppTextStyles.labelLarge.copyWith(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _BedTenantCard extends StatefulWidget {
  final Bed bed;
  final List<Profile> unassignedTenants;
  final AsyncValue<Map<String, Payment?>> latestPaymentsAsync;
  final VoidCallback? onTap;

  const _BedTenantCard({
    required this.bed,
    required this.unassignedTenants,
    required this.latestPaymentsAsync,
    this.onTap,
  });

  @override
  State<_BedTenantCard> createState() => _BedTenantCardState();
}

class _BedTenantCardState extends State<_BedTenantCard> {
  Profile? _tenant;

  @override
  void initState() {
    super.initState();
    if (widget.bed.tenantId != null) _loadTenant();
  }

  @override
  void didUpdateWidget(covariant _BedTenantCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.bed.tenantId != oldWidget.bed.tenantId) {
      if (widget.bed.tenantId != null) {
        _loadTenant();
      } else {
        setState(() => _tenant = null);
      }
    }
  }

  Future<void> _loadTenant() async {
    final data = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', widget.bed.tenantId!)
        .maybeSingle();
    if (mounted && data != null) {
      setState(() => _tenant = Profile.fromJson(data));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bed = widget.bed;

    if (!bed.isOccupied) {
      return _vacantCard(context, bed, widget.unassignedTenants);
    }

    if (_tenant == null) {
      return _loadingCard(bed.bedNumber);
    }

    final status = widget.latestPaymentsAsync.whenOrNull(
          data: (map) => map[bed.tenantId]?.status,
        ) ??
        'pending';

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: AppDecorations.card,
        child: Row(
          children: [
            InitialsAvatar(
              name: _tenant!.name,
              avatarUrl: _tenant!.avatarUrl,
              size: 44,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_tenant!.name, style: AppTextStyles.cardTitle),
                  const SizedBox(height: 2),
                  Text('${bed.bedNumber} · Soham',
                      style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            StatusBadge(status),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right,
                color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _vacantCard(
      BuildContext context, Bed bed, List<Profile> unassignedTenants) {
    return Container(
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
    );
  }

  Widget _loadingCard(String bedNumber) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card,
      child: Row(
        children: [
          const CircleAvatar(radius: 22, backgroundColor: AppColors.border),
          const SizedBox(width: 12),
          Text(bedNumber, style: AppTextStyles.cardTitle),
        ],
      ),
    );
  }
}

// ── Modal helpers ─────────────────────────────────────────────────────────────
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
                    // Also create an initial payment record for the new tenant
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

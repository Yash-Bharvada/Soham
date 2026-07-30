import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/payment.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bed_provider.dart';
import '../../providers/payment_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/tenant_card.dart';

import '../../providers/document_provider.dart';
import '../../services/notification_service.dart';

class TenantHomeScreen extends ConsumerStatefulWidget {
  const TenantHomeScreen({super.key});

  @override
  ConsumerState<TenantHomeScreen> createState() => _TenantHomeScreenState();
}

class _TenantHomeScreenState extends ConsumerState<TenantHomeScreen> {
  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      ensureTenantHasPendingPayment(user.id);
    }
    NotificationService.checkAndTriggerDueReminders();
  }

  @override
  Widget build(BuildContext context) {
    final bedAsync = ref.watch(myBedProvider);
    final currentPaymentAsync = ref.watch(currentPaymentProvider);

    final profileAsync = ref.watch(currentProfileProvider);
    final user = Supabase.instance.client.auth.currentUser;
    final name = user?.userMetadata?['name'] as String? ?? 'Tenant';
    final firstName = name.split(' ').first;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Navy header ───────────────────────────────────────────────
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
                        Text(
                          'Good ${_greeting()}, $firstName 👋',
                          style: AppTextStyles.headerTitle,
                        ),
                        Text(
                          'Welcome to Soham',
                          style: AppTextStyles.headerSubtitle,
                        ),
                      ],
                    ),
                  ),
                  profileAsync.when(
                    data: (p) => InitialsAvatar(
                      name: p?.name.isNotEmpty == true ? p!.name : name,
                      avatarUrl: p?.avatarUrl,
                      size: 44,
                    ),
                    loading: () => InitialsAvatar(name: name, size: 44),
                    error: (_, __) => InitialsAvatar(name: name, size: 44),
                  ),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(AppDimensions.screenPadding),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Hero rent card ────────────────────────────────────
                currentPaymentAsync.when(
                  data: (payment) => payment != null
                      ? _RentHeroCard(payment: payment)
                      : _AllPaidCard(),
                  loading: () => _ShimmerCard(),
                  error: (_, __) => _AllPaidCard(),
                ),
                const SizedBox(height: 14),

                // ── Your bed card ─────────────────────────────────────
                bedAsync.when(
                  data: (bed) => bed != null
                      ? _BedInfoCard(
                          bedNumber: bed.bedNumber,
                          moveInDate: bed.moveInDate,
                        )
                      : _NoBedCard(),
                  loading: () => _ShimmerCard(height: 90),
                  error: (_, __) => _NoBedCard(),
                ),
                const SizedBox(height: 14),

                // ── Quick actions ─────────────────────────────────────
                Text('Quick actions', style: AppTextStyles.cardTitle),
                const SizedBox(height: 10),
                ref.watch(myDocumentsStreamProvider).when(
                      data: (docs) {
                        String docBadgeLabel = 'Pending';
                        Color docBadgeBg = AppColors.amberBg;
                        Color docBadgeFg = AppColors.amber;

                        if (docs.length >= 3 && docs.every((d) => d.isVerified)) {
                          docBadgeLabel = 'Approved ✓';
                          docBadgeBg = AppColors.greenBg;
                          docBadgeFg = AppColors.green;
                        } else if (docs.any((d) => d.isRejected)) {
                          docBadgeLabel = 'Rejected ⚠️';
                          docBadgeBg = AppColors.redBg;
                          docBadgeFg = AppColors.red;
                        } else if (docs.length >= 3 && docs.every((d) => d.hasFile)) {
                          docBadgeLabel = 'Under Review';
                          docBadgeBg = AppColors.amberBg;
                          docBadgeFg = AppColors.amber;
                        }

                        return Row(
                          children: [
                            Expanded(
                              child: _QuickActionCard(
                                icon: Icons.upload_file_outlined,
                                label: 'KYC\ndocuments',
                                badge: docBadgeLabel,
                                badgeBg: docBadgeBg,
                                badgeFg: docBadgeFg,
                                onTap: () => context.go('/tenant/documents'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _QuickActionCard(
                                icon: Icons.history,
                                label: 'Payment\nhistory',
                                onTap: () => context.go('/tenant/payment'),
                              ),
                            ),
                          ],
                        );
                      },
                      loading: () => Row(
                        children: [
                          Expanded(
                            child: _QuickActionCard(
                              icon: Icons.upload_file_outlined,
                              label: 'KYC\ndocuments',
                              badge: '...',
                              onTap: () => context.go('/tenant/documents'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _QuickActionCard(
                              icon: Icons.history,
                              label: 'Payment\nhistory',
                              onTap: () => context.go('/tenant/payment'),
                            ),
                          ),
                        ],
                      ),
                      error: (_, __) => Row(
                        children: [
                          Expanded(
                            child: _QuickActionCard(
                              icon: Icons.upload_file_outlined,
                              label: 'KYC\ndocuments',
                              badge: 'Pending',
                              onTap: () => context.go('/tenant/documents'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _QuickActionCard(
                              icon: Icons.history,
                              label: 'Payment\nhistory',
                              onTap: () => context.go('/tenant/payment'),
                            ),
                          ),
                        ],
                      ),
                    ),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }
}

// ── Hero rent card ────────────────────────────────────────────────────────────
class _RentHeroCard extends StatelessWidget {
  final Payment payment;
  const _RentHeroCard({required this.payment});

  String get _dueLabel {
    if (payment.isOverdue) return 'Rent overdue!';
    if (payment.isDueToday) return 'Rent due today';
    final days = payment.dueDate.difference(DateTime.now()).inDays;
    if (days == 1) return 'Rent due tomorrow';
    return 'Rent due in $days days';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.navy,
            payment.isOverdue ? AppColors.red.withOpacity(0.8) : AppColors.navyLight,
          ],
        ),
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_dueLabel, style: AppTextStyles.headerSubtitle),
          const SizedBox(height: 6),
          Text(
            '₹${NumberFormat('#,##,###').format(payment.amount.toInt())}',
            style: AppTextStyles.amountWhite,
          ),
          const SizedBox(height: 4),
          Text(
            'Due ${DateFormat('d MMM yyyy').format(payment.dueDate)}',
            style: AppTextStyles.headerSubtitle,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.go('/tenant/payment'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.coral,
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Pay now', style: AppTextStyles.labelLarge),
            ),
          ),
        ],
      ),
    );
  }
}

class _AllPaidCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.green, Color(0xFF388E3C)],
        ),
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 32),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('All paid up! ✓',
                  style: AppTextStyles.headerTitle.copyWith(fontSize: 20)),
              Text('No pending payments',
                  style: AppTextStyles.headerSubtitle),
            ],
          ),
        ],
      ),
    );
  }
}

class _BedInfoCard extends StatelessWidget {
  final String bedNumber;
  final DateTime? moveInDate;
  const _BedInfoCard({required this.bedNumber, this.moveInDate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.bed_outlined,
                color: AppColors.navy, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your bed', style: AppTextStyles.caption),
              Text('$bedNumber, Soham',
                  style: AppTextStyles.cardTitle),
              if (moveInDate != null)
                Text(
                  'Since ${DateFormat('d MMM yyyy').format(moveInDate!)}',
                  style: AppTextStyles.bodySmall,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoBedCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card,
      child: Row(
        children: [
          const Icon(Icons.bed_outlined, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Text('No bed assigned yet — contact your owner.',
              style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final Color? badgeBg;
  final Color? badgeFg;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    this.badge,
    this.badgeBg,
    this.badgeFg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppDecorations.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.navy, size: 22),
                if (badge != null) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeBg ?? AppColors.amberBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge!,
                      style: AppTextStyles.caption.copyWith(
                        color: badgeFg ?? AppColors.amber,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text(label,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                )),
          ],
        ),
      ),
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  final double? height;
  const _ShimmerCard({this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height ?? 160,
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
      ),
    );
  }
}

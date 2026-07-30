import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/tenant_card.dart';

class TenantProfileScreen extends ConsumerWidget {
  const TenantProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    Future<void> signOut() async {
      await ref.read(authServiceProvider).signOut();
      if (context.mounted) context.go('/login');
    }

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
                bottom: 28,
              ),
              decoration: AppDecorations.navyGradient,
              child: profileAsync.when(
                data: (profile) => Row(
                  children: [
                    InitialsAvatar(
                      name: profile?.name ?? 'Tenant',
                      avatarUrl: profile?.avatarUrl,
                      size: 56,
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?.name ?? 'Tenant',
                          style: AppTextStyles.headerTitle,
                        ),
                        Text(
                          profile?.email ?? '',
                          style: AppTextStyles.headerSubtitle,
                        ),
                        if (profile?.phone != null)
                          Text(
                            profile!.phone!,
                            style: AppTextStyles.headerSubtitle,
                          ),
                      ],
                    ),
                  ],
                ),
                loading: () =>
                    const CircularProgressIndicator(color: Colors.white),
                error: (_, __) =>
                    Text('Tenant', style: AppTextStyles.headerTitle),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(AppDimensions.screenPadding),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 4),
                _SettingsGroup(children: [
                  _SettingsTile(
                    icon: Icons.person_outline,
                    label: 'Personal details',
                    onTap: () => context.push('/profile/personal-details'),
                  ),
                  _SettingsTile(
                    icon: Icons.notifications_outlined,
                    label: 'Notification preferences',
                    onTap: () => context.push('/profile/notifications'),
                  ),
                  _SettingsTile(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Payment methods',
                    onTap: () => context.push('/profile/payment-methods'),
                  ),
                  _SettingsTile(
                    icon: Icons.help_outline,
                    label: 'Help & support',
                    onTap: () => context.push('/profile/help-support'),
                  ),
                ]),
                const SizedBox(height: 12),
                _SettingsGroup(children: [
                  _SettingsTile(
                    icon: Icons.logout,
                    label: 'Log out',
                    labelColor: AppColors.red,
                    iconColor: AppColors.red,
                    onTap: signOut,
                    showChevron: false,
                  ),
                ]),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared settings widgets ───────────────────────────────────────────────────
class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecorations.card,
      child: Column(
        children: children
            .asMap()
            .entries
            .map((entry) => Column(
                  children: [
                    entry.value,
                    if (entry.key < children.length - 1)
                      const Divider(height: 1, indent: 52),
                  ],
                ))
            .toList(),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? labelColor;
  final Color? iconColor;
  final VoidCallback? onTap;
  final bool showChevron;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.labelColor,
    this.iconColor,
    this.onTap,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: iconColor ?? AppColors.navy, size: 20),
      title: Text(
        label,
        style: AppTextStyles.cardTitle.copyWith(
          fontSize: 14,
          color: labelColor ?? AppColors.textPrimary,
        ),
      ),
      trailing: showChevron
          ? const Icon(Icons.chevron_right,
              color: AppColors.textSecondary, size: 20)
          : null,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}

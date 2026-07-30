import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/tenant_card.dart';

class OwnerProfileScreen extends ConsumerStatefulWidget {
  const OwnerProfileScreen({super.key});

  @override
  ConsumerState<OwnerProfileScreen> createState() =>
      _OwnerProfileScreenState();
}

class _OwnerProfileScreenState extends ConsumerState<OwnerProfileScreen> {
  bool _uploadingQr = false;

  Future<void> _uploadQrCode() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null) return;

    setState(() => _uploadingQr = true);
    try {
      final bytes = await picked.readAsBytes();
      await Supabase.instance.client.storage
          .from('payments')
          .uploadBinary('owner/upi_qr.png', bytes,
              fileOptions: const FileOptions(upsert: true, contentType: 'image/png'));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR code updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Upload failed: $e'),
              backgroundColor: AppColors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingQr = false);
    }
  }

  Future<void> _signOut() async {
    await ref.read(authServiceProvider).signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);

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
                      name: profile?.name ?? 'Owner',
                      avatarUrl: profile?.avatarUrl,
                      size: 56,
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?.name ?? 'Owner',
                          style: AppTextStyles.headerTitle,
                        ),
                        Text(
                          profile?.email ?? '',
                          style: AppTextStyles.headerSubtitle,
                        ),
                      ],
                    ),
                  ],
                ),
                loading: () => const CircularProgressIndicator(
                    color: Colors.white),
                error: (_, __) =>
                    Text('Owner', style: AppTextStyles.headerTitle),
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
                    icon: Icons.qr_code,
                    label: _uploadingQr ? 'Uploading...' : 'Update UPI QR code',
                    onTap: _uploadingQr ? null : _uploadQrCode,
                    trailing: _uploadingQr
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : null,
                  ),
                  _SettingsTile(
                    icon: Icons.notifications_outlined,
                    label: 'Notification settings',
                    onTap: () => context.push('/profile/notifications'),
                  ),
                  _SettingsTile(
                    icon: Icons.help_outline,
                    label: 'Help & support',
                    onTap: () => context.push('/profile/help-support'),
                  ),
                  _SettingsTile(
                    icon: Icons.info_outline,
                    label: 'Payment methods & info',
                    onTap: () => context.push('/profile/payment-methods'),
                  ),
                ]),
                const SizedBox(height: 12),
                _SettingsGroup(children: [
                  _SettingsTile(
                    icon: Icons.logout,
                    label: 'Log out',
                    labelColor: AppColors.red,
                    iconColor: AppColors.red,
                    onTap: _signOut,
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

// ── Shared profile widgets ────────────────────────────────────────────────────
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
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.labelColor,
    this.iconColor,
    this.onTap,
    this.showChevron = true,
    this.trailing,
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
      trailing: trailing ??
          (showChevron
              ? const Icon(Icons.chevron_right,
                  color: AppColors.textSecondary, size: 20)
              : null),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}

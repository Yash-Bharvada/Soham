import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final config = _resolve(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: config.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        config.label,
        style: AppTextStyles.caption.copyWith(
          color: config.fg,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  _BadgeConfig _resolve(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return const _BadgeConfig(AppColors.greenBg, AppColors.green, 'Paid');
      case 'due_today':
        return const _BadgeConfig(AppColors.amberBg, AppColors.amber, 'Due today');
      case 'overdue':
        return const _BadgeConfig(AppColors.redBg, AppColors.red, 'Overdue');
      case 'verified':
      case 'approved':
        return const _BadgeConfig(AppColors.greenBg, AppColors.green, 'Approved');
      case 'rejected':
        return const _BadgeConfig(AppColors.redBg, AppColors.red, 'Rejected');
      case 'approval pending':
        return const _BadgeConfig(AppColors.amberBg, AppColors.amber, 'Approval Pending');
      case 'upload remaining':
        return const _BadgeConfig(Color(0xFFF3F4F6), AppColors.textSecondary, 'Upload Remaining');
      case 'pending':
      default:
        return const _BadgeConfig(AppColors.amberBg, AppColors.amber, 'Pending');
    }
  }
}

class _BadgeConfig {
  final Color bg;
  final Color fg;
  final String label;
  const _BadgeConfig(this.bg, this.fg, this.label);
}

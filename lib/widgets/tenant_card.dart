import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/profile.dart';
import '../models/payment.dart';
import '../theme/app_theme.dart';
import 'status_badge.dart';

class TenantCard extends StatelessWidget {
  final Profile tenant;
  final String bedNumber;
  final double rentAmount;
  final Payment? latestPayment;
  final VoidCallback? onTap;

  const TenantCard({
    super.key,
    required this.tenant,
    required this.bedNumber,
    required this.rentAmount,
    this.latestPayment,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = latestPayment?.status ?? 'pending';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: AppDecorations.card,
        child: Row(
          children: [
            // Avatar
            _Avatar(name: tenant.name, avatarUrl: tenant.avatarUrl, size: 44),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tenant.name, style: AppTextStyles.cardTitle),
                  const SizedBox(height: 2),
                  Text(
                    '$bedNumber · ₹${NumberFormat('#,##,###').format(rentAmount.toInt())}',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
            // Status badge + chevron
            StatusBadge(status),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right,
                  color: AppColors.textSecondary, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final double size;

  const _Avatar({required this.name, this.avatarUrl, required this.size});

  Color _colorFromName(String name) {
    const colors = [
      Color(0xFF1E3A5F),
      Color(0xFF3B6EA5),
      Color(0xFF2E7D32),
      Color(0xFF6A1B9A),
      Color(0xFF00695C),
      Color(0xFFBF360C),
    ];
    final index = name.isEmpty ? 0 : name.codeUnitAt(0) % colors.length;
    return colors[index];
  }

  String get _initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: _colorFromName(name),
        backgroundImage: NetworkImage(avatarUrl!),
        onBackgroundImageError: (_, __) {},
        child: null,
      );
    }

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: _colorFromName(name),
      child: Text(
        _initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.35,
        ),
      ),
    );
  }
}

// ── Re-usable avatar widget ───────────────────────────────────────────────────
class InitialsAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final double size;

  const InitialsAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    required this.size,
  });

  @override
  Widget build(BuildContext context) =>
      _Avatar(name: name, avatarUrl: avatarUrl, size: size);
}

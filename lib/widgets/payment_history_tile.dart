import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/payment.dart';
import '../theme/app_theme.dart';

class PaymentHistoryTile extends StatelessWidget {
  final Payment payment;
  const PaymentHistoryTile({super.key, required this.payment});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: AppDecorations.card,
      child: Row(
        children: [
          // Month icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.receipt_long_outlined,
                size: 20, color: AppColors.navy),
          ),
          const SizedBox(width: 12),
          // Month & date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.monthYear.isNotEmpty
                      ? payment.monthYear
                      : DateFormat('MMM yyyy').format(payment.dueDate),
                  style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  payment.isPaid && payment.paidDate != null
                      ? 'Paid on ${DateFormat('d MMM yyyy').format(payment.paidDate!)}'
                      : 'Due ${DateFormat('d MMM yyyy').format(payment.dueDate)}',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          // Amount + status
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${NumberFormat('#,##,###').format(payment.amount.toInt())}',
                style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
              ),
              const SizedBox(height: 4),
              _statusChip(payment.status),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    Color color;
    String label;
    switch (status) {
      case 'paid':
        color = AppColors.green;
        label = 'Paid';
        break;
      case 'overdue':
        color = AppColors.red;
        label = 'Overdue';
        break;
      case 'due_today':
        color = AppColors.amber;
        label = 'Due today';
        break;
      default:
        color = AppColors.textSecondary;
        label = 'Pending';
    }
    return Text(
      label,
      style: AppTextStyles.caption.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

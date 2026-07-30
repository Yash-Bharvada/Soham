import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/payment.dart';
import '../../providers/payment_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/payment_history_tile.dart';
import '../../services/notification_service.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  bool _uploadingScreenshot = false;

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      ensureTenantHasPendingPayment(user.id);
    }
  }

  Future<void> _openGPay(Payment payment) async {
    final upiId = dotenv.env['UPI_ID'] ?? '';
    final amount = payment.amount.toStringAsFixed(0);
    final uri = Uri.parse(
        'upi://pay?pa=$upiId&pn=Soham+PG&am=$amount&cu=INR&tn=Rent+${payment.monthYear}');
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await launchUrl(uri);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Opening UPI app... If not opening, copy the UPI ID below to pay in any app.'),
          ),
        );
      }
    }
  }

  Future<void> _openPhonePe(Payment payment) async {
    final upiId = dotenv.env['UPI_ID'] ?? '';
    final amount = payment.amount.toStringAsFixed(0);
    final phonePeUri = Uri.parse(
        'phonepe://pay?pa=$upiId&pn=Soham+PG&am=$amount&cu=INR');
    final upiUri = Uri.parse(
        'upi://pay?pa=$upiId&pn=Soham+PG&am=$amount&cu=INR&tn=Rent+${payment.monthYear}');

    try {
      final launched = await launchUrl(
        phonePeUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await launchUrl(upiUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      try {
        await launchUrl(upiUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Opening PhonePe/UPI... If not opening, copy the UPI ID below.')),
          );
        }
      }
    }
  }

  Future<void> _uploadScreenshot(Payment payment) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;

    setState(() => _uploadingScreenshot = true);
    try {
      final user = Supabase.instance.client.auth.currentUser!;
      final bytes = await picked.readAsBytes();
      final path = '${user.id}/screenshots/${payment.id}.jpg';

      await Supabase.instance.client.storage
          .from('payments')
          .uploadBinary(path, bytes,
              fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'));

      final url = await Supabase.instance.client.storage
          .from('payments')
          .createSignedUrl(path, 86400);

      await uploadPaymentScreenshot(payment.id, url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Screenshot uploaded. Owner will confirm payment.')),
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
      if (mounted) setState(() => _uploadingScreenshot = false);
    }
  }

  void _copyUpiId() {
    final upiId = dotenv.env['UPI_ID'] ?? '';
    Clipboard.setData(ClipboardData(text: upiId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('UPI ID copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paymentsAsync = ref.watch(myPaymentsStreamProvider);
    final currentPaymentAsync = ref.watch(currentPaymentProvider);
    final upiId = dotenv.env['UPI_ID'] ?? '';

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
                  Text('Pay rent', style: AppTextStyles.headerTitle),
                  Text('Scan or tap to pay',
                      style: AppTextStyles.headerSubtitle),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(AppDimensions.screenPadding),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Payment card ─────────────────────────────────────
                currentPaymentAsync.when(
                  data: (payment) => payment != null
                      ? _PaymentCard(
                          payment: payment,
                          upiId: upiId,
                          onGPay: () => _openGPay(payment),
                          onPhonePe: () => _openPhonePe(payment),
                          onUploadScreenshot: () =>
                              _uploadScreenshot(payment),
                          onCopyUpi: _copyUpiId,
                          uploadingScreenshot: _uploadingScreenshot,
                        )
                      : _NoPendingCard(
                          onCreatePending: () async {
                            final u = Supabase.instance.client.auth.currentUser;
                            if (u != null) {
                              await ensureTenantHasPendingPayment(u.id);
                            }
                          },
                        ),
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (_, __) => _NoPendingCard(
                    onCreatePending: () async {
                      final u = Supabase.instance.client.auth.currentUser;
                      if (u != null) {
                        await ensureTenantHasPendingPayment(u.id);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // ── Payment history ───────────────────────────────────
                Text('Payment history', style: AppTextStyles.screenTitle),
                const SizedBox(height: 12),

                paymentsAsync.when(
                  data: (payments) {
                    if (payments.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'No payment history yet.',
                            style: AppTextStyles.bodyMedium,
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: payments
                          .map((p) => PaymentHistoryTile(payment: p))
                          .toList(),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) =>
                      Text('Error loading history', style: AppTextStyles.bodyMedium),
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

// ── Payment card ──────────────────────────────────────────────────────────────
class _PaymentCard extends StatelessWidget {
  final Payment payment;
  final String upiId;
  final VoidCallback onGPay;
  final VoidCallback onPhonePe;
  final VoidCallback onUploadScreenshot;
  final VoidCallback onCopyUpi;
  final bool uploadingScreenshot;

  const _PaymentCard({
    required this.payment,
    required this.upiId,
    required this.onGPay,
    required this.onPhonePe,
    required this.onUploadScreenshot,
    required this.onCopyUpi,
    required this.uploadingScreenshot,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.card,
      child: Column(
        children: [
          // QR code
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/images/qr.jpeg',
              width: 180,
              height: 180,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code_2, size: 80, color: AppColors.navy),
                    SizedBox(height: 8),
                    Text('Scan to pay',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Amount
          Text(
            '₹${NumberFormat('#,##,###').format(payment.amount.toInt())}',
            style: AppTextStyles.heroTitle.copyWith(color: AppColors.textPrimary),
          ),
          Text(
            'Due ${DateFormat('d MMM yyyy').format(payment.dueDate)}',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 16),

          // UPI ID row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined,
                    size: 16, color: AppColors.navy),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    upiId,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onCopyUpi,
                  child: const Icon(Icons.copy_outlined,
                      size: 16, color: AppColors.lightBlue),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // GPay button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onGPay,
              icon: const Icon(Icons.payment, size: 18),
              label: Text('Open in GPay', style: AppTextStyles.labelLarge),
            ),
          ),
          const SizedBox(height: 8),

          // PhonePe button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onPhonePe,
              icon: const Icon(Icons.phone_android_outlined,
                  size: 18, color: AppColors.navy),
              label: Text('Open in PhonePe',
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.navy)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.navy),
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.buttonRadius)),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Paid in Cash button
          if (payment.isCash)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.amberBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.amber.withOpacity(0.4)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.payments_outlined, color: AppColors.amber, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '💵 Paid in Cash — Awaiting Owner Confirmation',
                      style: TextStyle(
                        color: AppColors.amber,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      title: const Text('Mark as Paid in Cash?'),
                      content: const Text(
                          'Owner will be notified that you paid ₹2,500 in cash and will confirm your payment.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.amber),
                          child: const Text('Confirm Cash Payment'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await markPaymentAsCash(payment.id);
                    await NotificationService.logNotification(
                      tenantId: payment.tenantId,
                      title: '💵 Cash Payment Submitted',
                      body:
                          'You marked ₹2,500 rent for ${payment.monthYear} as paid in cash.',
                      type: 'cash_payment',
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Marked as paid in cash. Awaiting owner confirmation.')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.payments_outlined,
                    size: 18, color: AppColors.amber),
                label: Text('Mark as Paid in Cash',
                    style: AppTextStyles.labelLarge
                        .copyWith(color: AppColors.amber)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.amber),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimensions.buttonRadius)),
                ),
              ),
            ),
          const SizedBox(height: 12),

          // Upload screenshot
          payment.hasScreenshot
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle,
                        color: AppColors.green, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Screenshot uploaded — awaiting confirmation',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                )
              : TextButton.icon(
                  onPressed: uploadingScreenshot ? null : onUploadScreenshot,
                  icon: uploadingScreenshot
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.upload_outlined, size: 16),
                  label: Text(
                    uploadingScreenshot
                        ? 'Uploading...'
                        : 'Upload payment screenshot',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.lightBlue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _NoPendingCard extends StatelessWidget {
  final VoidCallback? onCreatePending;
  const _NoPendingCard({this.onCreatePending});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: AppDecorations.card,
      child: Column(
        children: [
          const Icon(Icons.check_circle_outline,
              color: AppColors.green, size: 44),
          const SizedBox(height: 12),
          Text('No active payment due',
              style: AppTextStyles.cardTitle.copyWith(fontSize: 16)),
          Text('You\'re all caught up for this month!',
              style: AppTextStyles.bodyMedium),
          if (onCreatePending != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onCreatePending,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy),
              child: const Text('Generate ₹2,500 Rent Payment',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ],
      ),
    );
  }
}

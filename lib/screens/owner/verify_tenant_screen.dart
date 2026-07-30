import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/bed.dart';
import '../../models/document.dart';
import '../../models/payment.dart';
import '../../models/profile.dart';
import '../../providers/document_provider.dart';
import '../../providers/payment_provider.dart';
import '../../providers/bed_provider.dart';
import '../../services/email_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/tenant_card.dart';

class VerifyTenantScreen extends ConsumerStatefulWidget {
  final String tenantId;
  const VerifyTenantScreen({super.key, required this.tenantId});

  @override
  ConsumerState<VerifyTenantScreen> createState() =>
      _VerifyTenantScreenState();
}

class _VerifyTenantScreenState extends ConsumerState<VerifyTenantScreen> {
  Profile? _tenant;
  Bed? _bed;
  bool _approving = false;
  bool _rejecting = false;
  bool _markingPaid = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final supabase = Supabase.instance.client;

    final profileData = await supabase
        .from('profiles')
        .select()
        .eq('id', widget.tenantId)
        .maybeSingle();
    if (profileData != null) {
      setState(() => _tenant = Profile.fromJson(profileData));
    }

    final bedData = await supabase
        .from('beds')
        .select()
        .eq('tenant_id', widget.tenantId)
        .maybeSingle();
    if (bedData != null) setState(() => _bed = Bed.fromJson(bedData));
  }

  Future<void> _approveAll(List<Document> docs) async {
    setState(() => _approving = true);
    try {
      await approveAllDocuments(widget.tenantId);
      if (_tenant != null) {
        for (final doc in docs) {
          await EmailService.sendDocumentVerifiedEmail(
            tenantEmail: _tenant!.email,
            tenantName: _tenant!.name,
            docType: doc.displayName,
          );
        }
        await NotificationService.showNotification(
          id: 100,
          title: 'Documents Approved ✓',
          body: 'All documents for ${_tenant!.name} have been approved.',
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All documents approved')),
        );
      }
    } finally {
      if (mounted) setState(() => _approving = false);
    }
  }

  Future<void> _promptRejectDialog({Document? singleDoc}) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          singleDoc != null
              ? 'Reject ${singleDoc.displayName}'
              : 'Reject Documents',
          style: AppTextStyles.cardTitle,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Write feedback for the tenant explaining what needs to be fixed:',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText:
                    'e.g. Photo is blurry. Please upload a clear photo of front & back side.',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text('Confirm Rejection'),
          ),
        ],
      ),
    );

    if (reason == null) return;

    setState(() => _rejecting = true);
    try {
      if (singleDoc != null) {
        await rejectDocumentWithReason(singleDoc.id, reason);
      } else {
        await rejectAllDocuments(widget.tenantId, reason: reason);
      }

      if (_tenant != null) {
        await EmailService.sendDocumentRejectedEmail(
          tenantEmail: _tenant!.email,
          tenantName: _tenant!.name,
          docType: singleDoc?.displayName ?? 'documents',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rejection feedback sent to tenant')),
        );
      }
    } finally {
      if (mounted) setState(() => _rejecting = false);
    }
  }

  void _viewPaymentScreenshot(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Payment Screenshot'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(dialogCtx).pop(),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('Error loading screenshot'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _promptRequestScreenshotDialog(Payment payment) async {
    final controller = TextEditingController(
      text:
          'Please upload your payment screenshot for ${payment.monthYear} so I can confirm and mark your rent as paid.',
    );

    final feedback = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Request Payment Screenshot'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tenant has not uploaded a payment screenshot yet. Send feedback to request the screenshot:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Feedback for tenant...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy),
            child: const Text('Send Feedback'),
          ),
        ],
      ),
    );

    if (feedback == null || feedback.isEmpty) return;

    await NotificationService.logNotification(
      tenantId: widget.tenantId,
      title: '📷 Upload Payment Screenshot Required',
      body: feedback,
      type: 'screenshot_required',
    );

    if (_tenant != null) {
      await EmailService.sendRentDueEmail(
        tenantEmail: _tenant!.email,
        tenantName: _tenant!.name,
        amount: payment.amount,
        dueDate: 'immediately (screenshot requested)',
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Feedback & screenshot request sent to tenant')),
      );
    }
  }

  Future<void> _markPaid(Payment payment) async {
    setState(() => _markingPaid = true);
    try {
      await markPaymentPaid(payment.id);
      if (_tenant != null) {
        await EmailService.sendPaymentConfirmedEmail(
          tenantEmail: _tenant!.email,
          tenantName: _tenant!.name,
          amount: payment.amount,
          monthYear: payment.monthYear,
        );
        await NotificationService.showNotification(
          id: 101,
          title: '₹${payment.amount.toInt()} payment confirmed',
          body: '${_tenant!.name}\'s payment has been marked as paid.',
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment marked as paid')),
        );
      }
    } finally {
      if (mounted) setState(() => _markingPaid = false);
    }
  }

  Future<void> _sendReminder() async {
    if (_tenant == null) return;
    final paymentsAsync =
        ref.read(tenantPaymentsStreamProvider(widget.tenantId));
    final payments = paymentsAsync.valueOrNull ?? [];
    final overdue = payments.where((p) => !p.isPaid).toList();
    final total = overdue.fold<double>(0, (s, p) => s + p.amount);
    final amountFormatted = (total > 0 ? total : 2500).toInt();

    // 1. Trigger mobile / device push notification
    await NotificationService.showNotification(
      id: widget.tenantId.hashCode,
      title: '⏳ Rent Payment Due Reminder',
      body:
          'Owner sent you a rent reminder for ₹$amountFormatted. Please pay via GPay/PhonePe or Cash in Soham app.',
    );

    // 2. Log in-app notification entry for tenant
    await NotificationService.logNotification(
      tenantId: widget.tenantId,
      title: '⏳ Rent Payment Due Reminder',
      body:
          'Owner sent you a rent reminder for ₹$amountFormatted. Please pay via GPay/PhonePe or Cash in Soham app.',
      type: 'reminder',
    );

    // 3. Send email reminder
    final sent = await EmailService.sendRentDueEmail(
      tenantEmail: _tenant!.email,
      tenantName: _tenant!.name,
      amount: total > 0 ? total : 2500,
      dueDate: 'immediately',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(sent
              ? 'Reminder mobile notification & email sent to ${_tenant!.email}'
              : 'Reminder mobile notification & email sent to owner (chetnabharvada1234@gmail.com)'),
        ),
      );
    }
  }

  Future<void> _assignBed(int bedId) async {
    await assignTenantToBed(widget.tenantId, bedId);
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Bed assigned')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final docsAsync =
        ref.watch(tenantDocumentsStreamProvider(widget.tenantId));
    final paymentsAsync =
        ref.watch(tenantPaymentsStreamProvider(widget.tenantId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Header ───────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                left: AppDimensions.screenPadding,
                right: AppDimensions.screenPadding,
                bottom: 24,
              ),
              decoration: AppDecorations.navyGradient,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Padding(
                      padding: EdgeInsets.only(right: 16),
                      child: Icon(Icons.arrow_back, color: Colors.white),
                    ),
                  ),
                  if (_tenant != null)
                    InitialsAvatar(
                      name: _tenant!.name,
                      avatarUrl: _tenant!.avatarUrl,
                      size: 48,
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _tenant?.name ?? '...',
                          style: AppTextStyles.headerTitle,
                        ),
                        Text(
                          _bed != null
                              ? '${_bed!.bedNumber} · Soham'
                              : 'No bed assigned',
                          style: AppTextStyles.headerSubtitle,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(AppDimensions.screenPadding),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Assign bed (if no bed) ────────────────────────────
                if (_bed == null && _tenant != null)
                  _AssignBedCard(onAssign: _assignBed),

                // ── Overdue / pending payments ────────────────────────
                paymentsAsync.when(
                  data: (payments) {
                    final unpaid = payments.where((p) => !p.isPaid).toList();
                    if (unpaid.isEmpty) return const SizedBox.shrink();
                    final totalOwed =
                        unpaid.fold<double>(0, (s, p) => s + p.amount);
                    final hasOverdue =
                        unpaid.any((p) => p.isOverdue || p.isDueToday);
                    final activePayment = unpaid.first;

                    return Column(
                      children: [
                        // Payment screenshot preview if uploaded
                        if (activePayment.hasScreenshot)
                          _ScreenshotCard(
                            screenshotUrl: activePayment.screenshotUrl!,
                            onTap: () => _viewPaymentScreenshot(
                                context, activePayment.screenshotUrl!),
                          )
                        else if (activePayment.isCash)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.greenBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: AppColors.green.withOpacity(0.4)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.payments_outlined,
                                    color: AppColors.green, size: 22),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '💵 Cash Payment Submitted by Tenant',
                                        style: TextStyle(
                                          color: AppColors.green,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Tenant marked rent as paid in cash. Tap "Mark as Paid" to confirm receipt.',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textPrimary),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.amberBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: AppColors.amber.withOpacity(0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.add_a_photo_outlined,
                                    color: AppColors.amber, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Payment screenshot missing',
                                        style: AppTextStyles.caption.copyWith(
                                          color: AppColors.amber,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Request screenshot from tenant to confirm before marking paid.',
                                        style: AppTextStyles.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                        _OverdueAlertCard(
                          totalOwed: totalOwed,
                          hasOverdue: hasOverdue,
                          payments: unpaid,
                          hasScreenshot: activePayment.hasScreenshot || activePayment.isCash,
                          onSendReminder: _sendReminder,
                          onMarkPaid: unpaid.isNotEmpty
                              ? () {
                                  if (!activePayment.hasScreenshot && !activePayment.isCash) {
                                    _promptRequestScreenshotDialog(activePayment);
                                  } else {
                                    _markPaid(activePayment);
                                  }
                                }
                              : null,
                          onRequestScreenshot: () =>
                              _promptRequestScreenshotDialog(activePayment),
                          markingPaid: _markingPaid,
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                // ── KYC Documents Section ─────────────────────────────
                Text('KYC Documents', style: AppTextStyles.screenTitle),
                const SizedBox(height: 12),

                docsAsync.when(
                  data: (docs) => Column(
                    children: [
                      ...docs.map((doc) => _OwnerDocCard(
                            doc: doc,
                            onApprove: () async {
                              await updateDocumentStatus(doc.id, 'verified');
                              if (_tenant != null) {
                                await EmailService.sendDocumentVerifiedEmail(
                                  tenantEmail: _tenant!.email,
                                  tenantName: _tenant!.name,
                                  docType: doc.displayName,
                                );
                              }
                            },
                            onReject: () => _promptRejectDialog(singleDoc: doc),
                          )),
                      const SizedBox(height: 16),

                      // Bulk Action Buttons (only if any uploaded doc is pending review)
                      if (docs.any((d) => d.hasFile && d.status == 'pending')) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _approving
                                    ? null
                                    : () => _approveAll(docs),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.green,
                                ),
                                child: _approving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2))
                                    : Text('Approve all',
                                        style: AppTextStyles.labelLarge),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _rejecting
                                    ? null
                                    : () => _promptRejectDialog(),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppColors.red),
                                  minimumSize: const Size.fromHeight(54),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppDimensions.buttonRadius),
                                  ),
                                ),
                                child: _rejecting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            color: AppColors.red,
                                            strokeWidth: 2))
                                    : Text('Reject all with feedback',
                                        style: AppTextStyles.labelLarge
                                            .copyWith(color: AppColors.red)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Error: $e'),
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

// ── Owner Document Card with Thumbnail & Actions ──────────────────────────────
class _OwnerDocCard extends StatelessWidget {
  final Document doc;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _OwnerDocCard({
    required this.doc,
    required this.onApprove,
    required this.onReject,
  });

  void _viewFullImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(doc.displayName),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(dialogCtx).pop(),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('Error loading image'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.badge_outlined,
                    size: 18, color: AppColors.navy),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(doc.displayName, style: AppTextStyles.cardTitle),
              ),
              StatusBadge(doc.displayStatus),
            ],
          ),
          const SizedBox(height: 12),

          // Uploaded File Thumbnail / Preview Area
          if (doc.hasFile) ...[
            GestureDetector(
              onTap: () => _viewFullImage(context, doc.fileUrl!),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Image.network(
                      doc.fileUrl!,
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 100,
                        color: AppColors.background,
                        child: const Center(
                          child: Icon(Icons.image_not_supported_outlined,
                              color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.zoom_in, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text('Tap to inspect',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Actions per document (only if pending review)
            if (doc.status == 'pending')
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close, size: 16, color: AppColors.red),
                      label: Text('Reject with Feedback',
                          style: AppTextStyles.caption.copyWith(
                              color: AppColors.red, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.red),
                        minimumSize: const Size(0, 42),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check, size: 16, color: Colors.white),
                      label: Text('Approve',
                          style: AppTextStyles.caption.copyWith(
                              color: Colors.white, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.green,
                        minimumSize: const Size(0, 42),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.hourglass_empty,
                      color: AppColors.textSecondary, size: 18),
                  SizedBox(width: 8),
                  Text('No document uploaded yet by tenant',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
            ),
          ],

          // Display existing rejection reason if rejected
          if (doc.isRejected &&
              doc.rejectionReason != null &&
              doc.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Feedback given: "${doc.rejectionReason}"',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.red,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _OverdueAlertCard extends StatelessWidget {
  final double totalOwed;
  final bool hasOverdue;
  final List<Payment> payments;
  final bool hasScreenshot;
  final VoidCallback onSendReminder;
  final VoidCallback? onMarkPaid;
  final VoidCallback? onRequestScreenshot;
  final bool markingPaid;

  const _OverdueAlertCard({
    required this.totalOwed,
    required this.hasOverdue,
    required this.payments,
    this.hasScreenshot = false,
    required this.onSendReminder,
    this.onMarkPaid,
    this.onRequestScreenshot,
    required this.markingPaid,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.redCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: AppColors.red, size: 18),
              const SizedBox(width: 6),
              Text(
                hasOverdue ? 'Overdue rent' : 'Rent due',
                style: AppTextStyles.cardTitle
                    .copyWith(color: AppColors.red, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Amount owed', style: AppTextStyles.caption),
                    Text(
                      '₹${NumberFormat('#,##,###').format(totalOwed.toInt())}',
                      style: AppTextStyles.amount,
                    ),
                    Text(
                      payments.map((p) => p.monthYear).join(' + '),
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: onSendReminder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      minimumSize: const Size(130, 42),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text('Send reminder',
                        style:
                            AppTextStyles.labelLarge.copyWith(fontSize: 13)),
                  ),
                  const SizedBox(height: 6),
                  ElevatedButton(
                    onPressed: markingPaid ? null : onMarkPaid,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasScreenshot
                          ? AppColors.green
                          : AppColors.amber,
                      minimumSize: const Size(130, 38),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: markingPaid
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(
                            hasScreenshot ? 'Mark as Paid' : 'Request SS',
                            style: AppTextStyles.labelLarge.copyWith(
                                color: Colors.white, fontSize: 13),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScreenshotCard extends StatelessWidget {
  final String screenshotUrl;
  final VoidCallback? onTap;

  const _ScreenshotCard({required this.screenshotUrl, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: AppDecorations.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long_outlined,
                    color: AppColors.navy, size: 18),
                const SizedBox(width: 6),
                Text('Payment Screenshot Uploaded',
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Image.network(
                    screenshotUrl,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(
                      height: 60,
                      child: Center(child: Text('Could not load screenshot')),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.zoom_in, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text('Tap to inspect screenshot',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssignBedCard extends StatefulWidget {
  final Future<void> Function(int bedId) onAssign;
  const _AssignBedCard({required this.onAssign});

  @override
  State<_AssignBedCard> createState() => _AssignBedCardState();
}

class _AssignBedCardState extends State<_AssignBedCard> {
  int? _selectedBed;
  bool _assigning = false;
  List<Map<String, dynamic>> _availableBeds = [];

  @override
  void initState() {
    super.initState();
    _loadAvailableBeds();
  }

  Future<void> _loadAvailableBeds() async {
    final beds = await Supabase.instance.client
        .from('beds')
        .select()
        .isFilter('tenant_id', null)
        .order('id');
    if (mounted) {
      setState(() => _availableBeds = List<Map<String, dynamic>>.from(beds));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_availableBeds.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Assign a bed', style: AppTextStyles.cardTitle),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: _selectedBed,
            decoration: const InputDecoration(hintText: 'Select bed'),
            items: _availableBeds
                .map((b) => DropdownMenuItem<int>(
                      value: b['id'] as int,
                      child: Text(b['bed_number'] as String),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _selectedBed = v),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: (_selectedBed == null || _assigning)
                ? null
                : () async {
                    setState(() => _assigning = true);
                    await widget.onAssign(_selectedBed!);
                    if (mounted) setState(() => _assigning = false);
                  },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy),
            child: _assigning
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Text('Assign bed', style: AppTextStyles.labelLarge),
          ),
        ],
      ),
    );
  }
}

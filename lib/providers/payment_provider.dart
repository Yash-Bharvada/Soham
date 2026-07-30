import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/payment.dart';
import '../services/notification_service.dart';

// ── Tenant's own payments (real-time stream) ──────────────────────────────────
final myPaymentsStreamProvider = StreamProvider<List<Payment>>((ref) {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return const Stream.empty();

  return Supabase.instance.client
      .from('payments')
      .stream(primaryKey: ['id'])
      .eq('tenant_id', user.id)
      .order('created_at', ascending: false)
      .map((rows) => rows.map(Payment.fromJson).toList());
});

// ── Tenant's current (latest unpaid) payment ─────────────────────────────────
final currentPaymentProvider = Provider<AsyncValue<Payment?>>((ref) {
  return ref.watch(myPaymentsStreamProvider).when(
        data: (payments) {
          final unpaid = payments.where((p) => !p.isPaid).toList();
          if (unpaid.isEmpty) return const AsyncData(null);
          unpaid.sort((a, b) => a.dueDate.compareTo(b.dueDate));
          return AsyncData(unpaid.first);
        },
        loading: () => const AsyncLoading(),
        error: (e, s) => AsyncError(e, s),
      );
});

// ── All payments (owner view, real-time) ─────────────────────────────────────
final allPaymentsStreamProvider = StreamProvider<List<Payment>>((ref) {
  return Supabase.instance.client
      .from('payments')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .map((rows) => rows.map(Payment.fromJson).toList());
});

// ── Payments for a specific tenant ───────────────────────────────────────────
final tenantPaymentsStreamProvider =
    StreamProvider.family<List<Payment>, String>((ref, tenantId) {
  return Supabase.instance.client
      .from('payments')
      .stream(primaryKey: ['id'])
      .eq('tenant_id', tenantId)
      .order('created_at', ascending: false)
      .map((rows) => rows.map(Payment.fromJson).toList());
});

// ── Collected this month (owner) ──────────────────────────────────────────────
final collectedThisMonthProvider = Provider<AsyncValue<double>>((ref) {
  return ref.watch(allPaymentsStreamProvider).when(
        data: (payments) {
          final now = DateTime.now();
          final total = payments
              .where((p) =>
                  p.isPaid &&
                  p.paidDate != null &&
                  p.paidDate!.month == now.month &&
                  p.paidDate!.year == now.year)
              .fold<double>(0, (sum, p) => sum + p.amount);
          return AsyncData(total);
        },
        loading: () => const AsyncLoading(),
        error: (e, s) => AsyncError(e, s),
      );
});

// ── Latest payment status per tenant (map tenantId → payment) ────────────────
final latestPaymentPerTenantProvider =
    Provider<AsyncValue<Map<String, Payment?>>>((ref) {
  return ref.watch(allPaymentsStreamProvider).when(
        data: (payments) {
          final map = <String, Payment?>{};
          for (final p in payments) {
            final existing = map[p.tenantId];
            if (existing == null || p.createdAt.isAfter(existing.createdAt)) {
              map[p.tenantId] = p;
            }
          }
          return AsyncData(map);
        },
        loading: () => const AsyncLoading(),
        error: (e, s) => AsyncError(e, s),
      );
});

// ── Ensure tenant has an active pending payment row ────────────────────────────
Future<void> ensureTenantHasPendingPayment(String tenantId,
    {double amount = 2500.0}) async {
  final supabase = Supabase.instance.client;

  // Fetch all payments for this tenant ordered by due_date desc
  final payments = await supabase
      .from('payments')
      .select()
      .eq('tenant_id', tenantId)
      .order('due_date', ascending: false);

  if (payments.isEmpty) {
    final now = DateTime.now();
    final dueDate = now.day > 15
        ? DateTime(now.year, now.month + 1, 1)
        : DateTime(now.year, now.month, 1);
    final monthYear = '${_monthName(dueDate.month)} ${dueDate.year}';

    await supabase.from('payments').insert({
      'tenant_id': tenantId,
      'amount': amount,
      'due_date': dueDate.toIso8601String().split('T').first,
      'status': 'pending',
      'month_year': monthYear,
    });
    return;
  }

  // Check if any payment is currently unpaid
  final hasUnpaid =
      payments.any((p) => (p['status'] as String? ?? '') != 'paid');
  if (!hasUnpaid) {
    // All existing payments are paid! Create next cycle payment based on latest paid payment's due_date
    final latestPaid = payments.first;
    final latestDueDate = DateTime.parse(latestPaid['due_date'] as String);
    final nextDueDate =
        DateTime(latestDueDate.year, latestDueDate.month + 1, 1);
    final monthYear = '${_monthName(nextDueDate.month)} ${nextDueDate.year}';

    await supabase.from('payments').insert({
      'tenant_id': tenantId,
      'amount': amount,
      'due_date': nextDueDate.toIso8601String().split('T').first,
      'status': 'pending',
      'month_year': monthYear,
    });
  }
}

// ── Create a new payment row ──────────────────────────────────────────────────
Future<void> createPayment({
  required String tenantId,
  required double amount,
  required DateTime dueDate,
}) async {
  final monthYear = '${_monthName(dueDate.month)} ${dueDate.year}';

  await Supabase.instance.client.from('payments').insert({
    'tenant_id': tenantId,
    'amount': amount,
    'due_date': dueDate.toIso8601String().split('T').first,
    'status': _computeStatus(dueDate),
    'month_year': monthYear,
  });
}

// ── Mark payment as paid & reset trigger for 1st of next month (₹2500) ────────
Future<void> markPaymentPaid(String paymentId) async {
  final supabase = Supabase.instance.client;

  // 1. Fetch current payment details
  final current = await supabase
      .from('payments')
      .select()
      .eq('id', paymentId)
      .maybeSingle();

  if (current == null) return;
  final tenantId = current['tenant_id'] as String;
  final currentDueDate = DateTime.parse(current['due_date'] as String);

  // 2. Update payment status to paid
  await supabase.from('payments').update({
    'status': 'paid',
    'paid_date': DateTime.now().toIso8601String(),
  }).eq('id', paymentId);

  // 3. Automatically generate next month's payment due on 1st of next month relative to paid payment's due_date
  final nextMonthFirstDay =
      DateTime(currentDueDate.year, currentDueDate.month + 1, 1);
  final nextMonthYearStr =
      '${_monthName(nextMonthFirstDay.month)} ${nextMonthFirstDay.year}';

  // Check if next month's payment already exists for this tenant
  final existingNext = await supabase
      .from('payments')
      .select()
      .eq('tenant_id', tenantId)
      .eq('month_year', nextMonthYearStr)
      .maybeSingle();

  if (existingNext == null) {
    await supabase.from('payments').insert({
      'tenant_id': tenantId,
      'amount': 2500.0,
      'due_date': nextMonthFirstDay.toIso8601String().split('T').first,
      'status': 'pending',
      'month_year': nextMonthYearStr,
    });
  }

  // 4. Send in-app notification informing tenant that payment was confirmed
  await NotificationService.logNotification(
    tenantId: tenantId,
    title: 'Payment Confirmed ✓',
    body:
        'Owner confirmed your payment for ${current['month_year']}. Next cycle (₹2,500) is due on 1 ${_monthName(nextMonthFirstDay.month)} ${nextMonthFirstDay.year}.',
    type: 'payment_confirmed',
  );
}

// ── Mark payment as requested in cash ───────────────────────────────────────
Future<void> markPaymentAsCash(String paymentId) async {
  await Supabase.instance.client.from('payments').update({
    'payment_method': 'cash',
    'status': 'pending',
  }).eq('id', paymentId);
}

// ── Upload screenshot and set pending ────────────────────────────────────────
Future<void> uploadPaymentScreenshot(
    String paymentId, String screenshotUrl) async {
  await Supabase.instance.client.from('payments').update({
    'screenshot_url': screenshotUrl,
    'status': 'pending',
  }).eq('id', paymentId);
}

String _computeStatus(DateTime dueDate) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
  if (due.isBefore(today)) return 'overdue';
  if (due == today) return 'due_today';
  return 'pending';
}

String _monthName(int month) {
  const names = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return names[month];
}

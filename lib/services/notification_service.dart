import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import '../main.dart';

class NotificationService {
  static const _channelId = 'soham_rent';
  static const _channelName = 'Rent Reminders';
  static const _channelDesc = 'Notifications for rent due dates and updates';

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    _channelId,
    _channelName,
    channelDescription: _channelDesc,
    importance: Importance.high,
    priority: Priority.high,
    icon: '@mipmap/ic_launcher',
  );

  static const DarwinNotificationDetails _iosDetails =
      DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  static const NotificationDetails _details =
      NotificationDetails(android: _androidDetails, iOS: _iosDetails);

  // ── Show immediate notification ────────────────────────────────────────────
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      await flutterLocalNotificationsPlugin.show(id, title, body, _details);
    } catch (_) {}
  }

  // ── Schedule notification ──────────────────────────────────────────────────
  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    try {
      final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);
      if (tzDate.isBefore(tz.TZDateTime.now(tz.local))) return;

      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzDate,
        _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {}
  }

  // ── Cancel all notifications ───────────────────────────────────────────────
  static Future<void> cancelAll() async {
    try {
      await flutterLocalNotificationsPlugin.cancelAll();
    } catch (_) {}
  }

  // ── Check approaching payment dates (2 days, 1 day, today) & log in-app ────
  static Future<void> checkAndTriggerDueReminders() async {
    try {
      final supabase = Supabase.instance.client;
      final payments = await supabase
          .from('payments')
          .select()
          .neq('status', 'paid');

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      for (final p in payments) {
        final tenantId = p['tenant_id'] as String;
        final dueDateStr = p['due_date'] as String?;
        if (dueDateStr == null) continue;

        final dueDate = DateTime.parse(dueDateStr);
        final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
        final diffDays = dueDay.difference(today).inDays;
        final amount = (p['amount'] as num).toDouble();
        final amountStr = '₹${amount.toInt()}';
        final monthYear = p['month_year'] ?? '';

        String? title;
        String? body;
        String? typeKey;

        if (diffDays == 2) {
          title = '⏳ Rent Due in 2 Days';
          body =
              'Your rent of $amountStr for $monthYear is due in 2 days on ${_formatDate(dueDate)}.';
          typeKey = 'due_2_days';
        } else if (diffDays == 1) {
          title = '⚠️ Rent Due Tomorrow';
          body =
              'Reminder: Your rent of $amountStr for $monthYear is due tomorrow (${_formatDate(dueDate)}).';
          typeKey = 'due_1_day';
        } else if (diffDays == 0) {
          title = '📌 Rent Due Today';
          body = 'Your rent payment of $amountStr for $monthYear is due today.';
          typeKey = 'due_today';
        }

        if (title != null && body != null && typeKey != null) {
          final existingLog = await supabase
              .from('notifications')
              .select()
              .eq('tenant_id', tenantId)
              .eq('title', title)
              .maybeSingle();

          if (existingLog == null) {
            await logNotification(
              tenantId: tenantId,
              title: title,
              body: body,
              type: typeKey,
            );
            await showNotification(
              id: tenantId.hashCode + diffDays,
              title: title,
              body: body,
            );
          }
        }
      }
    } catch (_) {}
  }

  static Future<void> scheduleRentReminders() async {
    await checkAndTriggerDueReminders();
  }

  // ── Insert notification log to Supabase ───────────────────────────────────
  static Future<void> logNotification({
    required String tenantId,
    required String title,
    required String body,
    required String type,
  }) async {
    try {
      await Supabase.instance.client.from('notifications').insert({
        'tenant_id': tenantId,
        'title': title,
        'body': body,
        'type': type,
      });
    } catch (_) {}
  }

  static String _formatDate(DateTime date) {
    const months = [
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
    return '${date.day} ${months[date.month]}';
  }
}

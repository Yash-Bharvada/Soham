import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class EmailService {
  static String get _resendKey =>
      dotenv.env['RESEND_API_KEY'] ?? '';
  static const String _from = 'Soham PG <onboarding@resend.dev>';

  static Future<bool> sendEmail({
    required String to,
    required String subject,
    required String htmlBody,
  }) async {
    final key = _resendKey;
    if (key.isEmpty) {
      print('EmailService Error: RESEND_API_KEY is empty');
      return false;
    }

    final targetUrl = kIsWeb
        ? 'https://corsproxy.io/?https://api.resend.com/emails'
        : 'https://api.resend.com/emails';
    try {
      final res = await http.post(
        Uri.parse(targetUrl),
        headers: {
          'Authorization': 'Bearer $key',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'from': _from,
          'to': [to],
          'subject': subject,
          'html': htmlBody,
        }),
      );

      print('Resend API Response Status: ${res.statusCode}');
      print('Resend API Response Body: ${res.body}');

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return true;
      }

      // If Resend free tier restricts to owner account email
      if (res.body.contains('validation_error') ||
          res.statusCode == 403 ||
          res.body.contains('testing emails')) {
        print(
            'Resend test mode detected: redirecting email to account email chetnabharvada1234@gmail.com');
        final fallbackRes = await http.post(
          Uri.parse(targetUrl),
          headers: {
            'Authorization': 'Bearer $key',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'from': _from,
            'to': ['chetnabharvada1234@gmail.com'],
            'subject': '[$to] $subject',
            'html': htmlBody,
          }),
        );
        print('Fallback Email Status: ${fallbackRes.statusCode}');
        print('Fallback Email Body: ${fallbackRes.body}');
        return fallbackRes.statusCode >= 200 && fallbackRes.statusCode < 300;
      }
      return false;
    } catch (e) {
      print('EmailService Exception: $e');
      return false;
    }
  }

  // ── Send rent due reminder ─────────────────────────────────────────────────
  static Future<bool> sendRentDueEmail({
    required String tenantEmail,
    required String tenantName,
    required double amount,
    required String dueDate,
  }) async {
    return sendEmail(
      to: tenantEmail,
      subject: 'Rent Due Reminder — Soham PG',
      htmlBody: '''
        <div style="font-family:sans-serif;max-width:480px;margin:auto;">
          <div style="background:#1E3A5F;padding:24px;border-radius:12px 12px 0 0;text-align:center;">
            <h1 style="color:white;margin:0;font-size:24px;">Soham PG</h1>
            <p style="color:rgba(255,255,255,0.7);margin:4px 0 0;">Rent Reminder</p>
          </div>
          <div style="background:#fff;padding:24px;border-radius:0 0 12px 12px;border:1px solid #E5E7EB;">
            <p style="color:#1A1A2E;">Hi <strong>$tenantName</strong>,</p>
            <p style="color:#6B7280;">Your rent payment of <strong style="color:#1A1A2E;font-size:20px;">₹${amount.toStringAsFixed(0)}</strong> is due on <strong>$dueDate</strong>.</p>
            <p style="color:#6B7280;">Please use the GPay QR or UPI ID in the Soham app to make the payment.</p>
            <p style="color:#6B7280;font-size:12px;margin-top:32px;">— Soham PG Management</p>
          </div>
        </div>
      ''',
    );
  }

  // ── Send overdue alert ─────────────────────────────────────────────────────
  static Future<bool> sendOverdueEmail({
    required String tenantEmail,
    required String tenantName,
    required double amount,
  }) async {
    return sendEmail(
      to: tenantEmail,
      subject: '⚠️ Rent Overdue — Soham PG',
      htmlBody: '''
        <div style="font-family:sans-serif;max-width:480px;margin:auto;">
          <div style="background:#1E3A5F;padding:24px;border-radius:12px 12px 0 0;text-align:center;">
            <h1 style="color:white;margin:0;font-size:24px;">Soham PG</h1>
            <p style="color:rgba(255,255,255,0.7);margin:4px 0 0;">Overdue Alert</p>
          </div>
          <div style="background:#fff;padding:24px;border-radius:0 0 12px 12px;border:1px solid #E5E7EB;">
            <p style="color:#1A1A2E;">Hi <strong>$tenantName</strong>,</p>
            <p style="color:#D32F2F;font-weight:bold;">Your rent of ₹${amount.toStringAsFixed(0)} is OVERDUE.</p>
            <p style="color:#6B7280;">Please make the payment immediately through the Soham app to avoid further notices.</p>
            <p style="color:#6B7280;font-size:12px;margin-top:32px;">— Soham PG Management</p>
          </div>
        </div>
      ''',
    );
  }

  // ── Send document verified email ───────────────────────────────────────────
  static Future<void> sendDocumentVerifiedEmail({
    required String tenantEmail,
    required String tenantName,
    required String docType,
  }) async {
    await sendEmail(
      to: tenantEmail,
      subject: 'Document Verified ✓ — Soham PG',
      htmlBody: '''
        <div style="font-family:sans-serif;max-width:480px;margin:auto;">
          <div style="background:#1E3A5F;padding:24px;border-radius:12px 12px 0 0;text-align:center;">
            <h1 style="color:white;margin:0;font-size:24px;">Soham PG</h1>
          </div>
          <div style="background:#fff;padding:24px;border-radius:0 0 12px 12px;border:1px solid #E5E7EB;">
            <p style="color:#1A1A2E;">Hi <strong>$tenantName</strong>,</p>
            <p style="color:#2E7D32;font-weight:bold;">✓ Your <em>$docType</em> has been verified by the owner.</p>
            <p style="color:#6B7280;font-size:12px;margin-top:32px;">— Soham PG Management</p>
          </div>
        </div>
      ''',
    );
  }

  // ── Send document rejected email ───────────────────────────────────────────
  static Future<void> sendDocumentRejectedEmail({
    required String tenantEmail,
    required String tenantName,
    required String docType,
  }) async {
    await sendEmail(
      to: tenantEmail,
      subject: 'Document Rejected — Soham PG',
      htmlBody: '''
        <div style="font-family:sans-serif;max-width:480px;margin:auto;">
          <div style="background:#1E3A5F;padding:24px;border-radius:12px 12px 0 0;text-align:center;">
            <h1 style="color:white;margin:0;font-size:24px;">Soham PG</h1>
          </div>
          <div style="background:#fff;padding:24px;border-radius:0 0 12px 12px;border:1px solid #E5E7EB;">
            <p style="color:#1A1A2E;">Hi <strong>$tenantName</strong>,</p>
            <p style="color:#D32F2F;font-weight:bold;">✗ Your <em>$docType</em> was rejected.</p>
            <p style="color:#6B7280;">Please re-upload a clearer copy through the Soham app.</p>
            <p style="color:#6B7280;font-size:12px;margin-top:32px;">— Soham PG Management</p>
          </div>
        </div>
      ''',
    );
  }

  // ── Send payment confirmed email ───────────────────────────────────────────
  static Future<void> sendPaymentConfirmedEmail({
    required String tenantEmail,
    required String tenantName,
    required double amount,
    required String monthYear,
  }) async {
    await sendEmail(
      to: tenantEmail,
      subject: 'Payment Confirmed ✓ — Soham PG',
      htmlBody: '''
        <div style="font-family:sans-serif;max-width:480px;margin:auto;">
          <div style="background:#1E3A5F;padding:24px;border-radius:12px 12px 0 0;text-align:center;">
            <h1 style="color:white;margin:0;font-size:24px;">Soham PG</h1>
          </div>
          <div style="background:#fff;padding:24px;border-radius:0 0 12px 12px;border:1px solid #E5E7EB;">
            <p style="color:#1A1A2E;">Hi <strong>$tenantName</strong>,</p>
            <p style="color:#2E7D32;font-weight:bold;">✓ Payment of ₹${amount.toStringAsFixed(0)} for $monthYear has been confirmed.</p>
            <p style="color:#6B7280;">Thank you for your payment!</p>
            <p style="color:#6B7280;font-size:12px;margin-top:32px;">— Soham PG Management</p>
          </div>
        </div>
      ''',
    );
  }

  // ── Send owner reminder via Supabase Edge Function ────────────────────────
  static Future<void> triggerOwnerReminder(String tenantId) async {
    try {
      await Supabase.instance.client.functions.invoke(
        'send-owner-reminder',
        body: {'tenant_id': tenantId},
      );
    } catch (_) {}
  }
}

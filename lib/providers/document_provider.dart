import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/document.dart';

// ── Tenant's own documents (real-time stream) ─────────────────────────────────
final myDocumentsStreamProvider = StreamProvider<List<Document>>((ref) {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return const Stream.empty();

  return Supabase.instance.client
      .from('documents')
      .stream(primaryKey: ['id'])
      .eq('tenant_id', user.id)
      .order('type')
      .map((rows) => rows.map(Document.fromJson).toList());
});

// ── Documents for a specific tenant (owner view) ──────────────────────────────
final tenantDocumentsStreamProvider =
    StreamProvider.family<List<Document>, String>((ref, tenantId) {
  return Supabase.instance.client
      .from('documents')
      .stream(primaryKey: ['id'])
      .eq('tenant_id', tenantId)
      .order('type')
      .map((rows) => rows.map(Document.fromJson).toList());
});

// ── Upload document file bytes (cross-platform: Web, Mobile, Desktop) ──────────
Future<String> uploadDocument({
  required String tenantId,
  required String docType, // 'self', 'father', 'mother'
  required Uint8List bytes,
}) async {
  final supabase = Supabase.instance.client;
  final path = '$tenantId/$docType.jpg';

  await supabase.storage.from('documents').uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
      );

  final signedUrl = await supabase.storage
      .from('documents')
      .createSignedUrl(path, 86400);

  // Update documents table
  await supabase.from('documents').upsert({
    'tenant_id': tenantId,
    'type': docType,
    'file_url': signedUrl,
    'status': 'pending',
    'uploaded_at': DateTime.now().toIso8601String(),
  }, onConflict: 'tenant_id, type');

  return signedUrl;
}

// ── Update document status (owner action) ─────────────────────────────────────
Future<void> updateDocumentStatus(String documentId, String status) async {
  await Supabase.instance.client.from('documents').update({
    'status': status,
    'reviewed_at': DateTime.now().toIso8601String(),
  }).eq('id', documentId);
}

// ── Approve all documents for a tenant ───────────────────────────────────────
Future<void> approveAllDocuments(String tenantId) async {
  await Supabase.instance.client.from('documents').update({
    'status': 'verified',
    'reviewed_at': DateTime.now().toIso8601String(),
  }).eq('tenant_id', tenantId);
}

// ── Reject a specific document with feedback reason ────────────────────────────
Future<void> rejectDocumentWithReason(String documentId, String reason) async {
  await Supabase.instance.client.from('documents').update({
    'status': 'rejected',
    'rejection_reason': reason.trim(),
    'reviewed_at': DateTime.now().toIso8601String(),
  }).eq('id', documentId);
}

// ── Reject all pending documents for a tenant ────────────────────────────────
Future<void> rejectAllDocuments(String tenantId, {String? reason}) async {
  await Supabase.instance.client
      .from('documents')
      .update({
        'status': 'rejected',
        'rejection_reason': reason?.trim(),
        'reviewed_at': DateTime.now().toIso8601String(),
      })
      .eq('tenant_id', tenantId)
      .neq('status', 'verified');
}

// ── Get signed URL for viewing a document ────────────────────────────────────
Future<String?> getDocumentSignedUrl(String tenantId, String docType) async {
  try {
    return await Supabase.instance.client.storage
        .from('documents')
        .createSignedUrl('$tenantId/$docType.jpg', 3600);
  } catch (_) {
    return null;
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/document.dart';
import '../../providers/document_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/document_card.dart';

class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(myDocumentsStreamProvider);
    final user = Supabase.instance.client.auth.currentUser;

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
                  Text('Documents', style: AppTextStyles.headerTitle),
                  Text('Upload your KYC documents',
                      style: AppTextStyles.headerSubtitle),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(AppDimensions.screenPadding),
            sliver: docsAsync.when(
              data: (docs) {
                // Ensure all 3 doc types are present
                const types = ['self', 'father', 'mother'];
                final sortedDocs = types.map((type) {
                  return docs.firstWhere(
                    (d) => d.type == type,
                    orElse: () => _placeholderDoc(type, user?.id ?? ''),
                  );
                }).toList();

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final doc = sortedDocs[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: DocumentCard(
                          document: doc,
                          onUpload: (Uint8List bytes) async {
                            if (user == null) return;
                            try {
                              await uploadDocument(
                                tenantId: user.id,
                                docType: doc.type,
                                bytes: bytes,
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Document uploaded successfully')),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Upload failed: $e'),
                                    backgroundColor: AppColors.red,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      );
                    },
                    childCount: sortedDocs.length,
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SliverFillRemaining(
                child: Center(
                    child: Text('Error: $e',
                        style: AppTextStyles.bodyMedium)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Create placeholder document for types not yet in DB ──────────────────────
Document _placeholderDoc(String type, String tenantId) => Document(
      id: type,
      tenantId: tenantId,
      type: type,
      fileUrl: null,
      status: 'pending',
    );

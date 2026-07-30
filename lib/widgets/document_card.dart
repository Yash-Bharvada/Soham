import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/document.dart';
import '../theme/app_theme.dart';
import 'status_badge.dart';

class DocumentCard extends StatefulWidget {
  final Document document;
  final Future<void> Function(Uint8List bytes) onUpload;

  const DocumentCard({
    super.key,
    required this.document,
    required this.onUpload,
  });

  @override
  State<DocumentCard> createState() => _DocumentCardState();
}

class _DocumentCardState extends State<DocumentCard> {
  bool _uploading = false;

  Future<void> _pick() async {
    final picker = ImagePicker();
    final result = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            if (!kIsWeb)
              ListTile(
                leading:
                    const Icon(Icons.camera_alt_outlined, color: AppColors.navy),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppColors.navy),
              title: const Text('Choose file / photo'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (result == null) return;
    final picked = await picker.pickImage(
      source: result,
      maxWidth: 1920,
      imageQuality: 85,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();

    setState(() => _uploading = true);
    try {
      await widget.onUpload(bytes);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.document;
    Color dashColor;
    Color iconColor;
    Widget innerContent;

    if (doc.isVerified) {
      dashColor = AppColors.green;
      iconColor = AppColors.green;
      innerContent = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.greenBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: AppColors.green, size: 20),
          ),
          const SizedBox(height: 8),
          Text('Document approved ✓',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.green, fontWeight: FontWeight.w600)),
        ],
      );
    } else if (doc.isRejected) {
      dashColor = AppColors.red;
      iconColor = AppColors.red;
      innerContent = _UploadArea(
          color: AppColors.red, label: 'Tap to re-upload document', uploading: _uploading);
    } else if (doc.hasFile) {
      dashColor = AppColors.amber;
      iconColor = AppColors.amber;
      innerContent = _UploadArea(
          color: AppColors.amber,
          label: 'Uploaded — Approval Pending',
          uploading: _uploading);
    } else {
      dashColor = AppColors.border;
      iconColor = AppColors.lightBlue;
      innerContent = _UploadArea(
          color: iconColor, label: 'Tap to upload', uploading: _uploading);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with displayStatus badge
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.badge_outlined, size: 18, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(doc.displayName, style: AppTextStyles.cardTitle),
              ),
              StatusBadge(doc.displayStatus),
            ],
          ),
          const SizedBox(height: 12),

          // Upload area
          GestureDetector(
            onTap: doc.isVerified ? null : _pick,
            child: _DashedBox(
              color: dashColor,
              child: innerContent,
            ),
          ),

          // Owner Rejection Feedback Banner
          if (doc.isRejected &&
              doc.rejectionReason != null &&
              doc.rejectionReason!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.redBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.red.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.feedback_outlined,
                      color: AppColors.red, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Owner Feedback:',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.red,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          doc.rejectionReason!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textPrimary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UploadArea extends StatelessWidget {
  final Color color;
  final String label;
  final bool uploading;
  const _UploadArea(
      {required this.color, required this.label, required this.uploading});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (uploading)
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Icon(Icons.upload_outlined, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          uploading ? 'Uploading...' : label,
          style: AppTextStyles.caption.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _DashedBox extends StatelessWidget {
  final Color color;
  final Widget child;
  const _DashedBox({required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(color: color),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
        ),
        child: child,
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    const radius = 10.0;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          const Radius.circular(radius)));

    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end.toDouble()), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

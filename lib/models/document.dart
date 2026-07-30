class Document {
  final String id;
  final String tenantId;
  final String type; // 'self' | 'father' | 'mother'
  final String? fileUrl;
  final String status; // 'pending' | 'verified' | 'rejected'
  final String? rejectionReason;
  final DateTime? uploadedAt;
  final DateTime? reviewedAt;

  const Document({
    required this.id,
    required this.tenantId,
    required this.type,
    this.fileUrl,
    required this.status,
    this.rejectionReason,
    this.uploadedAt,
    this.reviewedAt,
  });

  factory Document.fromJson(Map<String, dynamic> json) => Document(
        id: json['id'] as String,
        tenantId: json['tenant_id'] as String,
        type: json['type'] as String,
        fileUrl: json['file_url'] as String?,
        status: json['status'] as String? ?? 'pending',
        rejectionReason: json['rejection_reason'] as String?,
        uploadedAt: json['uploaded_at'] != null
            ? DateTime.tryParse(json['uploaded_at'] as String)
            : null,
        reviewedAt: json['reviewed_at'] != null
            ? DateTime.tryParse(json['reviewed_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenant_id': tenantId,
        'type': type,
        'file_url': fileUrl,
        'status': status,
        'rejection_reason': rejectionReason,
        'uploaded_at': uploadedAt?.toIso8601String(),
        'reviewed_at': reviewedAt?.toIso8601String(),
      };

  String get displayName {
    switch (type) {
      case 'self':
        return 'Your Aadhaar card';
      case 'father':
        return "Father's Aadhaar card";
      case 'mother':
        return "Mother's Aadhaar card";
      default:
        return 'Document';
    }
  }

  bool get hasFile => fileUrl != null && fileUrl!.isNotEmpty;
  bool get isVerified => status == 'verified';
  bool get isRejected => status == 'rejected';
  bool get isPendingApproval => hasFile && status == 'pending';
  bool get isUploadRemaining => !hasFile;

  String get displayStatus {
    if (isVerified) return 'Approved';
    if (isRejected) return 'Rejected';
    if (hasFile) return 'Approval Pending';
    return 'Upload Remaining';
  }
}

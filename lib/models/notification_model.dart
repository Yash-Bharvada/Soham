class AppNotification {
  final String id;
  final String tenantId;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final DateTime sentAt;

  const AppNotification({
    required this.id,
    required this.tenantId,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.sentAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String,
        tenantId: json['tenant_id'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        type: json['type'] as String,
        isRead: json['is_read'] as bool? ?? false,
        sentAt: DateTime.tryParse(json['sent_at'] as String? ?? '') ?? DateTime.now(),
      );
}

class Payment {
  final String id;
  final String tenantId;
  final double amount;
  final DateTime dueDate;
  final DateTime? paidDate;
  final String status; // 'paid' | 'due_today' | 'overdue' | 'pending'
  final String? screenshotUrl;
  final String? paymentMethod; // 'online' | 'cash'
  final String monthYear;
  final DateTime createdAt;

  const Payment({
    required this.id,
    required this.tenantId,
    required this.amount,
    required this.dueDate,
    this.paidDate,
    required this.status,
    this.screenshotUrl,
    this.paymentMethod,
    required this.monthYear,
    required this.createdAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
        id: json['id'] as String,
        tenantId: json['tenant_id'] as String,
        amount: (json['amount'] as num).toDouble(),
        dueDate: DateTime.parse(json['due_date'] as String),
        paidDate: json['paid_date'] != null
            ? DateTime.tryParse(json['paid_date'] as String)
            : null,
        status: json['status'] as String? ?? 'pending',
        screenshotUrl: json['screenshot_url'] as String?,
        paymentMethod: json['payment_method'] as String? ?? 'online',
        monthYear: json['month_year'] as String? ?? '',
        createdAt:
            DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenant_id': tenantId,
        'amount': amount,
        'due_date': dueDate.toIso8601String().split('T').first,
        'paid_date': paidDate?.toIso8601String(),
        'status': status,
        'screenshot_url': screenshotUrl,
        'payment_method': paymentMethod,
        'month_year': monthYear,
        'created_at': createdAt.toIso8601String(),
      };

  bool get isPaid => status == 'paid';
  bool get isOverdue => status == 'overdue';
  bool get isDueToday => status == 'due_today';
  bool get isPending => status == 'pending';
  bool get hasScreenshot => screenshotUrl != null && screenshotUrl!.isNotEmpty;
  bool get isCash => paymentMethod == 'cash';
}

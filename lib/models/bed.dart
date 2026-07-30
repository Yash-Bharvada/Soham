import 'profile.dart';

class Bed {
  final int id;
  final String bedNumber;
  final String? tenantId;
  final DateTime? moveInDate;
  final double rentAmount;

  // Joined/populated separately
  final Profile? tenant;

  const Bed({
    required this.id,
    required this.bedNumber,
    this.tenantId,
    this.moveInDate,
    required this.rentAmount,
    this.tenant,
  });

  factory Bed.fromJson(Map<String, dynamic> json) => Bed(
        id: json['id'] as int,
        bedNumber: json['bed_number'] as String,
        tenantId: json['tenant_id'] as String?,
        moveInDate: json['move_in_date'] != null
            ? DateTime.tryParse(json['move_in_date'] as String)
            : null,
        rentAmount: (json['rent_amount'] as num).toDouble(),
      );

  bool get isOccupied => tenantId != null;

  Bed copyWith({Profile? tenant}) => Bed(
        id: id,
        bedNumber: bedNumber,
        tenantId: tenantId,
        moveInDate: moveInDate,
        rentAmount: rentAmount,
        tenant: tenant ?? this.tenant,
      );
}

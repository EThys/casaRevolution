import 'package:casa/models/PropertyModel.dart';
import 'package:casa/models/UserModel.dart';

class PropertyVisitModel {
  final int propertyVisitId;
  final int propertyId;
  final int? userId;
  final String name;
  final String? secondName;
  final String email;
  final String phone;
  final String message;
  final String? address;
  final DateTime visitDate;
  final String visitHour;
  final String status;
  final String ipAddress;
  final String? cancellationReason;
  final PropertyModel property;
  final UserModel? user;

  PropertyVisitModel({
    required this.propertyVisitId,
    required this.propertyId,
    this.userId,
    required this.name,
    this.secondName,
    required this.email,
    required this.phone,
    required this.message,
    this.address,
    required this.visitDate,
    required this.visitHour,
    required this.status,
    required this.ipAddress,
    this.cancellationReason,
    required this.property,
    this.user,
  });

  factory PropertyVisitModel.fromJson(Map<String, dynamic> json) {
    return PropertyVisitModel(
      propertyVisitId: json['PropertyVisitId'],
      propertyId: json['PropertyId'],
      userId: json['UserId'],
      name: json['name'],
      secondName: json['secondName'],
      email: json['email'],
      phone: json['phone'],
      message: json['message'],
      address: json['address'],
      visitDate: DateTime.parse(json['visitDate']),
      visitHour: json['visitHour'],
      status: json['status'],
      ipAddress: json['ipAddress'],
      cancellationReason: json['cancellation_reason'],
      property: PropertyModel.fromJson(json['property']),
      user: json['user'] != null ? UserModel.fromJson(json['user']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'PropertyVisitId': propertyVisitId,
      'PropertyId': propertyId,
      'UserId': userId,
      'name': name,
      'secondName': secondName,
      'email': email,
      'phone': phone,
      'message': message,
      'address': address,
      'visitDate': visitDate.toIso8601String(),
      'visitHour': visitHour,
      'status': status,
      'ipAddress': ipAddress,
      'cancellation_reason': cancellationReason,
      'property': property.toJson(),
      'user': user?.toJson(),
    };
  }
}

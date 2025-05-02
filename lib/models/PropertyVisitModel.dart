// To parse this JSON data, do
//
//     final propertyVisit = propertyVisitFromJson(jsonString);

import 'dart:convert';

PropertyVisitModel propertyVisitFromJson(String str) => PropertyVisitModel.fromJson(json.decode(str));

String propertyVisitToJson(PropertyVisitModel data) => json.encode(data.toJson());

class PropertyVisitModel {
  int? propertyId;
  int? userId;
  String? name;
  String? secondName;
  String? email;
  String? phone;
  String? message;
  String? address;
  DateTime? visitDate;
  String? visitHour;
  String? status;
  String? ipAddress;
  String? cancellationReason;

  PropertyVisitModel({
    this.propertyId,
    this.userId,
    this.name,
    this.secondName,
    this.email,
    this.phone,
    this.message,
    this.address,
    this.visitDate,
    this.visitHour,
    this.status,
    this.ipAddress,
    this.cancellationReason,
  });

  factory PropertyVisitModel.fromJson(Map<String, dynamic> json) => PropertyVisitModel(
    propertyId: json["PropertyId"],
    userId: json["UserId"],
    name: json["name"],
    secondName: json["secondName"],
    email: json["email"],
    phone: json["phone"],
    message: json["message"],
    address: json["address"],
    visitDate: json["visitDate"] == null ? null : DateTime.parse(json["visitDate"]),
    visitHour: json["visitHour"],
    status: json["status"],
    ipAddress: json["ipAddress"],
    cancellationReason: json["cancellation_reason"],
  );

  Map<String, dynamic> toJson() => {
    "PropertyId": propertyId,
    "UserId": userId,
    "name": name,
    "secondName": secondName,
    "email": email,
    "phone": phone,
    "message": message,
    "address": address,
    "visitDate": visitDate?.toIso8601String(),
    "visitHour": visitHour,
    "status": status,
    "ipAddress": ipAddress,
    "cancellation_reason": cancellationReason,
  };
}
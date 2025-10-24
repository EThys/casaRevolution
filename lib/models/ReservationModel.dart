import 'dart:convert';
import 'UserModel.dart';
import 'PropertyModel.dart';

ReservationModel reservationModelFromJson(String str) => ReservationModel.fromJson(json.decode(str));
String reservationModelToJson(ReservationModel data) => json.encode(data.toJson());

class ReservationModel {
  int? reservationId;
  UserModel? user;
  PropertyModel? property;
  String? message;
  String? status;
  String? type;
  String? reservationHeure;
  String? cancellationReason;
  String? startDate;
  String? endDate;
  String? createdAt;
  bool? active;

  ReservationModel({
    this.reservationId,
    this.user,
    this.property,
    this.message,
    this.status,
    this.type,
    this.reservationHeure,
    this.cancellationReason,
    this.startDate,
    this.endDate,
    this.createdAt,
    this.active,
  });

  factory ReservationModel.fromJson(Map<String, dynamic> json) => ReservationModel(
    reservationId: json["reservationId"] ?? json["id"],
    user: json["user"] == null
        ? null
        : UserModel.fromJson(json["user"]),
    property: json["property"] == null
        ? null
        : PropertyModel.fromJson(json["property"]),
    message: json["message"],
    status: json["status"],
    type: json["type"],
    reservationHeure: json["reservationHeure"],
    cancellationReason: json["cancellationReason"],
    startDate: json["startDate"],
    endDate: json["endDate"],
    createdAt: json["createdAt"],
    active: json["active"] ?? false,
  );

  Map<String, dynamic> toJson() => {
    "reservationId": reservationId,
    "user": user?.toJson(),
    "property": property?.toJson(),
    "message": message,
    "status": status,
    "type": type,
    "reservationHeure": reservationHeure,
    "cancellationReason": cancellationReason,
    "startDate": startDate,
    "endDate": endDate,
    "createdAt": createdAt,
    "active": active,
  };

  @override
  String toString() {
    return 'ReservationModel(reservationId: $reservationId, status: $status, type: $type, startDate: $startDate, endDate: $endDate)';
  }
}
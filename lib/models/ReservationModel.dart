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

  factory ReservationModel.fromJson(Map<String, dynamic> json) {
    // Gérer la structure imbriquée : l'API retourne {"reservation": {...}, "property": {...}}
    Map<String, dynamic>? reservationData;
    Map<String, dynamic>? propertyData;
    
    // Si la clé "reservation" existe et contient un objet, c'est la structure imbriquée
    if (json.containsKey("reservation") && json["reservation"] is Map) {
      reservationData = json["reservation"] as Map<String, dynamic>;
      propertyData = json["property"] as Map<String, dynamic>?;
      print("📋 [ReservationModel] Structure imbriquée détectée - reservation.id: ${reservationData?["id"]}, userId: ${reservationData?["userId"]}");
    } else {
      // Sinon, c'est la structure plate (données directement dans json)
      reservationData = json;
      propertyData = json["property"] as Map<String, dynamic>?;
      print("📋 [ReservationModel] Structure plate détectée - id: ${reservationData?["id"]}");
    }
    
    return ReservationModel(
      reservationId: reservationData?["reservationId"] ?? reservationData?["id"],
      user: json["user"] == null
          ? null
          : UserModel.fromJson(json["user"]),
      property: propertyData == null
          ? null
          : PropertyModel.fromJson(propertyData),
      message: reservationData?["message"],
      status: reservationData?["status"],
      type: reservationData?["type"],
      reservationHeure: reservationData?["reservationHeure"],
      cancellationReason: reservationData?["cancellationReason"],
      startDate: reservationData?["startDate"],
      endDate: reservationData?["endDate"],
      createdAt: reservationData?["createdAt"],
      active: reservationData?["active"] ?? false,
    );
  }

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
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

  // Champs pour propriétés spéciales
  int? terrainId;
  int? bureauId;
  int? vacanceId;
  int? festiveId;
  int? funeraireId;
  int? hotelId;

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
    this.terrainId,
    this.bureauId,
    this.vacanceId,
    this.festiveId,
    this.funeraireId,
    this.hotelId,
  });

  factory ReservationModel.fromJson(Map<String, dynamic> json) {
    // Gérer la structure imbriquée : l'API retourne {"reservation": {...}, "property": {...}}
    Map<String, dynamic>? reservationData;
    
    // Si la clé "reservation" existe et contient un objet, c'est la structure imbriquée
    if (json.containsKey("reservation") && json["reservation"] is Map) {
      reservationData = Map<String, dynamic>.from(json["reservation"]);
      print("📋 [ReservationModel] Structure imbriquée détectée - reservation.id: ${reservationData["id"] ?? reservationData["reservationId"]}");
    } else {
      // Sinon, c'est la structure plate
      reservationData = json;
      print("📋 [ReservationModel] Structure plate détectée - id: ${reservationData["id"] ?? reservationData["reservationId"]}");
    }
    
    // Extraire et convertir l'ID de manière robuste
    dynamic rawId = reservationData["reservationId"] ?? reservationData["id"];
    int? parsedId;
    if (rawId != null) {
      if (rawId is int) {
        parsedId = rawId;
      } else if (rawId is String) {
        parsedId = int.tryParse(rawId);
      }
    }

    return ReservationModel(
      reservationId: parsedId,
      user: json["user"] == null
          ? null
          : UserModel.fromJson(json["user"]),
      property: PropertyModel.fromJson(json),
      message: reservationData["message"]?.toString(),
      status: reservationData["status"]?.toString(),
      type: reservationData["type"]?.toString(),
      reservationHeure: reservationData["reservationHeure"]?.toString(),
      cancellationReason: reservationData["cancellationReason"]?.toString(),
      startDate: reservationData["startDate"]?.toString(),
      endDate: reservationData["endDate"]?.toString(),
      createdAt: reservationData["createdAt"]?.toString(),
      active: reservationData["active"] == true,
      terrainId: reservationData["terrainId"],
      bureauId: reservationData["bureauId"],
      vacanceId: reservationData["vacanceId"],
      festiveId: reservationData["festiveId"],
      funeraireId: reservationData["funeraireId"],
      hotelId: reservationData["hotelId"],
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
    "terrainId": terrainId,
    "bureauId": bureauId,
    "vacanceId": vacanceId,
    "festiveId": festiveId,
    "funeraireId": funeraireId,
    "hotelId": hotelId,
  };

  @override
  String toString() {
    return 'ReservationModel(reservationId: $reservationId, status: $status, type: $type, startDate: $startDate, endDate: $endDate)';
  }
}
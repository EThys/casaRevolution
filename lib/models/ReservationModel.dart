import 'dart:convert';
import 'UserModel.dart';
import 'PropertyModel.dart';
import 'PropertyImageModel.dart';

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
  int? chambreId;

  String? userImage;

  /// Téléphone annonceur renvoyé par l’API sur la réponse réservation réussie (`postByTel`).
  String? postByTel;

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
    this.chambreId,
    this.userImage,
    this.postByTel,
  });

  static String? _parsePostByTel(
    Map<String, dynamic> json,
    Map<String, dynamic>? reservationData,
  ) {
    String? pick(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      if (s.isEmpty || s == 'null') return null;
      return s;
    }

    final prop = json['property'];
    return pick(json['postByTel']) ??
        pick(reservationData?['postByTel']) ??
        (prop is Map ? pick(prop['postByTel']) : null);
  }

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

    List<PropertyImageModel> parseImages(dynamic imagesRaw) {
      final List<PropertyImageModel> imgs = [];
      if (imagesRaw is List) {
        for (final it in imagesRaw) {
          if (it is Map) {
            final m = Map<String, dynamic>.from(it);
            final p = m["path"]?.toString();
            if (p != null && p.trim().isNotEmpty) {
              imgs.add(PropertyImageModel(path: p.trim()));
            }
          } else if (it is String) {
            final p = it.trim();
            if (p.isNotEmpty) imgs.add(PropertyImageModel(path: p));
          }
        }
      }
      return imgs;
    }

    // Réservations chambre: structure spéciale
    // { reservation: {...}, chambre: {...}, user: {...}, imageChambre: [...] }
    PropertyModel? parsedProperty;
    if (json["chambre"] is Map) {
      final chambre = Map<String, dynamic>.from(json["chambre"] as Map);
      parsedProperty = PropertyModel(
        propertyId: chambre["hotelId"] is int ? chambre["hotelId"] as int : null,
        propertyTypeId: 5,
        title: chambre["title"]?.toString(),
        description: chambre["description"]?.toString(),
        price: (chambre["price"] is num) ? (chambre["price"] as num).toDouble() : null,
        deviseId: chambre["deviseId"] is int ? chambre["deviseId"] as int : null,
        propertyImage: parseImages(json["imageChambre"]),
      );
    } else if (json["terrain"] is Map) {
      // Réservations terrains
      // { reservation: {...}, terrain: {...}, user: {...}, imageTerrain: [...] }
      final t = Map<String, dynamic>.from(json["terrain"] as Map);
      parsedProperty = PropertyModel(
        propertyId: t["id"] is int ? t["id"] as int : null,
        propertyTypeId: 9,
        userId: t["userId"] is int ? t["userId"] as int : null,
        title: t["title"]?.toString(),
        description: t["description"]?.toString(),
        price: (t["price"] is num) ? (t["price"] as num).toDouble() : null,
        deviseId: t["deviseId"] is int ? t["deviseId"] as int : null,
        quartierValue: t["quartierValue"]?.toString(),
        communeValue: t["communeValue"]?.toString(),
        cityValue: t["cityValue"]?.toString(),
        countryValue: t["countryValue"]?.toString(),
        surface: (t["surface"] is num) ? (t["surface"] as num).toDouble() : null,
        propertyImage: parseImages(json["imageTerrain"]),
      );
    } else if (json["vacance"] is Map) {
      // Réservations agences / tourisme (vacance)
      // { reservation: {...}, vacance: {...}, user: {...}, imageVacance: [...] }
      final v = Map<String, dynamic>.from(json["vacance"] as Map);
      parsedProperty = PropertyModel(
        propertyId: v["id"] is int ? v["id"] as int : null,
        propertyTypeId: 6, // Tourisme (Vacances)
        agenceId: v["agenceId"] is int ? v["agenceId"] as int : null,
        userId: v["userId"] is int ? v["userId"] as int : null,
        title: v["title"]?.toString(),
        description: v["description"]?.toString(),
        price: (v["price"] is num) ? (v["price"] as num).toDouble() : null,
        address: v["address"]?.toString(),
        cityValue: v["cityValue"]?.toString(),
        countryValue: v["countryValue"]?.toString(),
        propertyImage: parseImages(json["imageVacance"]),
      );
    } else {
      // Structure habituelle: PropertyModel sait extraire les champs depuis json / reservation.
      parsedProperty = PropertyModel.fromJson(json);
    }

    return ReservationModel(
      reservationId: parsedId,
      user: json["user"] == null ? null : UserModel.fromJson(json["user"]),
      property: parsedProperty,
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
      chambreId: reservationData["chambreId"],
      userImage: json["userImage"]?.toString(),
      postByTel: _parsePostByTel(json, reservationData),
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
    "chambreId": chambreId,
    "postByTel": postByTel,
  };

  @override
  String toString() {
    return 'ReservationModel(reservationId: $reservationId, status: $status, type: $type, startDate: $startDate, endDate: $endDate)';
  }
}
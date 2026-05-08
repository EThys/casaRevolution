import 'dart:convert';
import 'UserModel.dart';
import 'PropertyModel.dart';
import 'PropertyImageModel.dart';

ReservationModel reservationModelFromJson(String str) => ReservationModel.fromJson(json.decode(str));
String reservationModelToJson(ReservationModel data) => json.encode(data.toJson());

class ReservationModel {
  int? reservationId;
  UserModel? user;
  /// Propriétaire / annonceur renvoyé par certaines réponses API (ex: réservation chambre).
  UserModel? proprietaire;
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
    this.proprietaire,
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
    
    // Certaines réponses ont une double structure: { reservation: { reservation: {...}, ... } }
    final Map<String, dynamic> reservationCore =
        (reservationData["reservation"] is Map)
            ? Map<String, dynamic>.from(reservationData["reservation"] as Map)
            : reservationData;

    // Extraire et convertir l'ID de manière robuste
    dynamic rawId = reservationCore["reservationId"] ??
        reservationCore["id"] ??
        reservationData["reservationId"] ??
        reservationData["id"];
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

    String? _pickUserImage() {
      // 1) Champs possibles au niveau racine
      final direct = (json["userImage"] ??
          json["imageUser"] ??
          json["clientImage"] ??
          json["avatar"]);
      final directStr = direct?.toString().trim();
      if (directStr != null &&
          directStr.isNotEmpty &&
          directStr.toLowerCase() != 'null') {
        return directStr;
      }

      // 2) Champs sur l'objet user/client (nouveau: `avatar`)
      final dynamic rawUser = json["user"] ?? json["client"] ?? reservationData?["user"];
      if (rawUser is Map) {
        final m = Map<String, dynamic>.from(rawUser);
        final v = (m["avatar"] ??
            m["profilePicture"] ??
            m["profile_picture"] ??
            m["image"]);
        final s = v?.toString().trim();
        if (s != null && s.isNotEmpty && s.toLowerCase() != 'null') {
          return s;
        }
      }
      return null;
    }

    return ReservationModel(
      reservationId: parsedId,
      user: (() {
        final dynamic raw = json["user"] ?? json["client"] ?? reservationData?["user"];
        if (raw is Map) return UserModel.fromJson(Map<String, dynamic>.from(raw));
        return null;
      })(),
      proprietaire: json["proprietaire"] == null ? null : UserModel.fromJson(json["proprietaire"]),
      property: parsedProperty,
      message: reservationCore["message"]?.toString(),
      status: reservationCore["status"]?.toString(),
      type: reservationCore["type"]?.toString(),
      reservationHeure: reservationCore["reservationHeure"]?.toString(),
      cancellationReason: reservationCore["cancellationReason"]?.toString(),
      startDate: reservationCore["startDate"]?.toString(),
      endDate: reservationCore["endDate"]?.toString(),
      createdAt: reservationCore["createdAt"]?.toString(),
      active: reservationCore["active"] == true,
      terrainId: reservationCore["terrainId"],
      bureauId: reservationCore["bureauId"],
      vacanceId: reservationCore["vacanceId"],
      festiveId: reservationCore["festiveId"],
      funeraireId: reservationCore["funeraireId"],
      hotelId: reservationCore["hotelId"],
      chambreId: reservationCore["chambreId"],
      userImage: _pickUserImage(),
      postByTel: _parsePostByTel(json, reservationData),
    );
  }

  Map<String, dynamic> toJson() => {
    "reservationId": reservationId,
    "user": user?.toJson(),
    "proprietaire": proprietaire?.toJson(),
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
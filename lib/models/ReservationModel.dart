import 'dart:convert';
import 'UserModel.dart';
import 'PropertyModel.dart';
import 'PropertyTypeModel.dart';
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

  /// Photo de la personne qui réserve, si l’API l’a envoyée.
  String? get requesterPhoto {
    final direct = profileImageUrlFrom(userImage);
    if (direct != null) return direct;
    return profileImageUrlFrom(user?.profilePicture);
  }

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

    String? fromNode(dynamic node) {
      if (node is! Map) return null;
      return pick(node['postByTel']) ?? pick(node['phone']) ?? pick(node['telephone']);
    }

    final prop = json['property'];
    return pick(json['postByTel']) ??
        pick(reservationData?['postByTel']) ??
        (prop is Map ? pick(prop['postByTel']) : null) ??
        fromNode(json['hotel']) ??
        fromNode(json['bureau']) ??
        fromNode(json['terrain']) ??
        fromNode(json['vacance']) ??
        fromNode(json['salle']) ??
        fromNode(json['festive']) ??
        fromNode(json['funeraire']) ??
        fromNode(json['proprietaire']);
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

    PropertyModel listingFrom(
      Map<String, dynamic> node, {
      Map<String, dynamic>? placeSource,
      required int typeId,
      required String typeName,
      String? title,
      List<PropertyImageModel>? images,
      int? agenceId,
      double? surface,
      int? capacity,
      int? pieces,
    }) {
      String? text(dynamic value) {
        if (value == null) return null;
        if (value is Map) {
          final inner = value["address"] ??
              value["adresse"] ??
              value["name"] ??
              value["value"];
          if (inner == null || inner is Map) return null;
          final nested = inner.toString().trim();
          if (nested.isEmpty || nested.toLowerCase() == 'null') return null;
          return nested;
        }
        final raw = value.toString().trim();
        if (raw.isEmpty || raw.toLowerCase() == 'null') return null;
        return raw;
      }

      String? place(dynamic value) => text(value);
      final where = placeSource ?? node;
      final amount = node["price"];
      return PropertyModel(
        propertyId: node["hotelId"] is int
            ? node["hotelId"] as int
            : (where["id"] is int
                ? where["id"] as int
                : (node["id"] is int ? node["id"] as int : null)),
        propertyTypeId: typeId,
        propertyType: PropertyTypeModel(propertyTypeId: typeId, name: typeName),
        userId: node["userId"] is int
            ? node["userId"] as int
            : (where["userId"] is int ? where["userId"] as int : null),
        agenceId: agenceId,
        title: title ?? text(node["title"]),
        description: text(node["description"] ?? where["description"]),
        price: amount is num ? amount.toDouble() : double.tryParse('${amount ?? ''}'),
        deviseId: node["deviseId"] is int ? node["deviseId"] as int : null,
        address: text(where["address"] ?? where["adresse"] ?? node["address"] ?? node["adresse"]),
        communeValue: place(where["communeValue"] ?? where["commune"] ?? node["communeValue"]),
        quartierValue: place(where["quartierValue"] ?? where["quartier"] ?? node["quartierValue"]),
        cityValue: place(where["cityValue"] ?? where["city"] ?? node["cityValue"]),
        countryValue: place(where["countryValue"] ?? where["country"] ?? node["countryValue"]),
        postalCode: text(where["postalCode"] ?? node["postalCode"]),
        surface: surface,
        capacityPeople: capacity ?? int.tryParse('${node["capacityPeople"] ?? node["capacity"] ?? ''}'),
        numberPiece: pieces ?? int.tryParse('${node["numberPiece"] ?? ''}'),
        transactionType: text(node["transactionType"] ?? where["transactionType"]),
        postBy: text(where["postBy"] ?? node["postBy"]),
        propertyImage: images,
      );
    }

    PropertyModel? parsedProperty;
    final chambreNode = json["chambre"] ?? reservationData?["chambre"];
    final terrainNode = json["terrain"] ?? reservationData?["terrain"];
    final vacanceNode = json["vacance"] ?? reservationData?["vacance"];
    final bureauNode = json["bureau"] ?? json["bureaux"] ?? reservationData?["bureau"];
    final salleNode = json["salle"] ??
        json["festive"] ??
        json["funeraire"] ??
        reservationData?["salle"];
    if (chambreNode is Map) {
      final chambre = Map<String, dynamic>.from(chambreNode);
      final hotelNode = json["hotel"] ?? reservationData?["hotel"];
      final hotel = hotelNode is Map ? Map<String, dynamic>.from(hotelNode) : null;
      final roomTitle = chambre["title"]?.toString().trim() ?? '';
      final hotelTitle = hotel?["title"]?.toString().trim() ?? '';
      final title = roomTitle.isEmpty
          ? hotelTitle
          : (hotelTitle.isEmpty ? roomTitle : '$roomTitle — $hotelTitle');
      final roomListing = listingFrom(
        chambre,
        placeSource: hotel,
        typeId: 5,
        typeName: 'Hôtel',
        title: title.isEmpty ? null : title,
        images: parseImages(json["imageChambre"] ?? reservationData?["imageChambre"]),
        pieces: chambre["numberPiece"] is int
            ? chambre["numberPiece"] as int
            : int.tryParse('${chambre["numberPiece"]}'),
      );
      if (hotel != null && hotel["id"] is int) {
        roomListing.propertyId = hotel["id"] as int;
      }
      parsedProperty = roomListing;
    } else if (terrainNode is Map) {
      final t = Map<String, dynamic>.from(terrainNode);
      final surface = t["surface"];
      parsedProperty = listingFrom(
        t,
        typeId: 9,
        typeName: 'Terrain',
        images: parseImages(json["imageTerrain"] ?? reservationData?["imageTerrain"]),
        surface: surface is num ? surface.toDouble() : double.tryParse('${surface ?? ''}'),
      );
    } else if (vacanceNode is Map) {
      final v = Map<String, dynamic>.from(vacanceNode);
      parsedProperty = listingFrom(
        v,
        typeId: 6,
        typeName: 'Tourisme',
        agenceId: v["agenceId"] is int ? v["agenceId"] as int : null,
        images: parseImages(json["imageVacance"] ?? reservationData?["imageVacance"]),
        capacity: int.tryParse('${v["capacity"] ?? ''}'),
      );
    } else if (bureauNode is Map) {
      final b = Map<String, dynamic>.from(bureauNode);
      parsedProperty = listingFrom(
        b,
        typeId: 4,
        typeName: 'Bureau',
        images: parseImages(json["bureauImage"] ?? reservationData?["bureauImage"]),
      );
    } else if (salleNode is Map) {
      final salle = Map<String, dynamic>.from(salleNode);
      final funeral = reservationCore["funeraireId"] != null ||
          json["funeraire"] is Map ||
          (reservationCore["type"]?.toString().toLowerCase().contains('funer') ?? false);
      parsedProperty = listingFrom(
        salle,
        typeId: funeral ? 7 : 8,
        typeName: funeral ? 'Funéraire' : 'Salle de fête',
        images: parseImages(json["imagSalle"] ?? reservationData?["imagSalle"]),
        capacity: int.tryParse('${salle["capacityPeople"] ?? ''}'),
      );
    } else {
      parsedProperty = PropertyModel.fromJson(json);
    }

    String? _pickUserImage() {
      final direct = profileImageUrlFrom(json["userImage"] ??
          json["imageUser"] ??
          json["clientImage"] ??
          json["avatar"] ??
          reservationData?["userImage"] ??
          reservationData?["imageUser"]);
      if (direct != null) return direct;

      final dynamic rawUser =
          json["user"] ?? json["client"] ?? reservationData?["user"];
      if (rawUser is Map) {
        final m = Map<String, dynamic>.from(rawUser);
        final fromUser = profileImageUrlFrom(m["avatar"] ??
            m["profilePicture"] ??
            m["profile_picture"] ??
            m["image"] ??
            m["photo"] ??
            m["picture"] ??
            m["images"]);
        if (fromUser != null) return fromUser;
        final fromProfile = profileImageUrlFrom(m["profile"]);
        if (fromProfile != null) return fromProfile;
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
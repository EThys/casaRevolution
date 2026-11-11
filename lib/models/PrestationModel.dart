import 'dart:convert';
import 'CotationModel.dart';
import 'UserModel.dart';

PrestationModel prestationModelFromJson(String str) => PrestationModel.fromJson(json.decode(str));
String prestationModelToJson(PrestationModel data) => json.encode(data.toJson());

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  if (value is double) return value.toInt();
  return null;
}

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

bool _parseBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is String) return value.toLowerCase() == 'true';
  if (value is int) return value == 1;
  return false;
}

class PrestationModel {
  int? id;
  int? userId;
  int? serviceId;
  int? deviseId;
  String? title;
  String? profile; // Photo de profil du prestataire (base64)
  String? description;
  String? experience;
  String? plageJourPrestation;
  String? plageHeurePrestation;
  double? minPrice;
  double? maxPrice;
  String? address;
  String? communeValue;
  String? quartierValue;
  String? cityValue;
  String? countryValue;
  int? cityId;
  int? communeId;
  int? quartierId;
  bool? isCertified;
  bool? isActive;
  DateTime? dateCreated;
  String? username; // Nom du publicateur
  String? postBy; // Champ explicite pour postBy
  List<String>? images; // Pour stocker les images
  String? phone;
  String? email;
  String? whatsapp;
  UserModel? user;
  /// Avis clients (`cotation` dans la réponse API détail prestation).
  List<CotationModel>? cotations;

  PrestationModel({
    this.id,
    this.userId,
    this.serviceId,
    this.deviseId,
    this.title,
    this.profile,
    this.description,
    this.experience,
    this.plageJourPrestation,
    this.plageHeurePrestation,
    this.minPrice,
    this.maxPrice,
    this.address,
    this.communeValue,
    this.quartierValue,
    this.cityValue,
    this.countryValue,
    this.cityId,
    this.communeId,
    this.quartierId,
    this.isCertified,
    this.isActive,
    this.dateCreated,
    this.username,
    this.postBy,
    this.images,
    this.phone,
    this.email,
    this.whatsapp,
    this.user,
    this.cotations,
  });

  /// Nom, téléphone et e-mail du prestataire quand l’API les met à côté de la prestation (`postBy`, `actor`).
  void absorbPublisher(Map<String, dynamic> envelope) {
    String? text(dynamic value) {
      if (value == null) return null;
      final raw = value.toString().trim();
      if (raw.isEmpty || raw.toLowerCase() == 'null') return null;
      return raw;
    }

    Map<String, dynamic>? asMap(dynamic value) {
      if (value is Map) return Map<String, dynamic>.from(value);
      return null;
    }

    final actor = asMap(envelope['actor']);
    final person = asMap(actor?['user']) ?? asMap(actor?['member']) ?? actor;
    final profile = asMap(person?['profile']);

    postBy ??= text(envelope['postBy']) ??
        text(person?['fullName']) ??
        text(person?['fullname']) ??
        text(person?['username']) ??
        text(profile?['fullName']) ??
        text(profile?['fullname']);
    username ??= postBy ?? text(person?['username']);
    phone ??= text(envelope['postByTel']) ??
        text(person?['phone']) ??
        text(person?['telephone']) ??
        text(profile?['phone']) ??
        text(profile?['telephone']);
    email ??= text(person?['email']) ?? text(profile?['email']);
    if (user == null && person != null) {
      user = UserModel.fromJson(person);
    }
  }

  void mergePublisherFrom(PrestationModel? other) {
    if (other == null) return;
    String? keep(String? current, String? incoming) {
      final text = current?.trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') return current;
      final next = incoming?.trim() ?? '';
      if (next.isEmpty || next.toLowerCase() == 'null') return current;
      return incoming;
    }

    postBy = keep(postBy, other.postBy ?? other.username);
    username = keep(username, other.username ?? other.postBy);
    phone = keep(phone, other.phone ?? other.user?.phone);
    email = keep(email, other.email ?? other.user?.email);
    user ??= other.user;
  }

  static String? _placeText(dynamic value) {
    if (value == null) return null;
    if (value is Map) {
      final inner = value["address"] ?? value["adresse"] ?? value["name"];
      if (inner == null || inner is Map) return null;
      return _placeText(inner);
    }
    final text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return null;
    return text;
  }

  static List<CotationModel>? _parseCotations(Map<String, dynamic> json) {
    dynamic raw = json['cotation'] ?? json['cotations'];
    if (raw == null) return null;

    // Certains endpoints renvoient { cotation: { cotation: [ ... ] } } ou { cotations: { cotation: [...] } }
    if (raw is Map) {
      final m = Map<String, dynamic>.from(raw);
      raw = m['cotation'] ?? m['cotations'] ?? m['data'];
    }

    if (raw is! List) return null;
    return raw
        .whereType<Map>()
        .map((e) => CotationModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  factory PrestationModel.fromJson(Map<String, dynamic> json) => PrestationModel(
    id: _parseInt(json["id"]),
    userId: _parseInt(json["userId"]),
    serviceId: _parseInt(json["serviceId"]),
    deviseId: _parseInt(json["deviseId"]),
    title: json["title"] ?? "",
    profile: json["profile"],
    description: json["description"] ?? "",
    experience: json["experience"] ?? "",
    plageJourPrestation: json["plageJourPrestation"] ?? "",
    plageHeurePrestation: json["plageHeurePrestation"] ?? "",
    minPrice: _parseDouble(json["minPrice"]) ?? 0.0,
    maxPrice: _parseDouble(json["maxPrice"]) ?? 0.0,
    address: _placeText(json["address"] is Map
        ? (json["address"] as Map)["address"] ?? (json["address"] as Map)["adresse"]
        : json["address"]),
    communeValue: _placeText(json["communeValue"] ??
            (json["address"] is Map ? (json["address"] as Map)["communeValue"] : null) ??
            (json["commune"] is Map ? (json["commune"] as Map)["name"] : json["commune"])) ??
        "",
    quartierValue: _placeText(json["quartierValue"] ??
            (json["address"] is Map ? (json["address"] as Map)["quartierValue"] : null) ??
            (json["quartier"] is Map ? (json["quartier"] as Map)["name"] : json["quartier"])) ??
        "",
    cityValue: _placeText(json["cityValue"] ??
            (json["address"] is Map ? (json["address"] as Map)["cityValue"] : null) ??
            (json["city"] is Map ? (json["city"] as Map)["name"] : json["city"])) ??
        "",
    countryValue: _placeText(json["countryValue"] ??
            (json["address"] is Map ? (json["address"] as Map)["countryValue"] : null) ??
            (json["country"] is Map ? (json["country"] as Map)["name"] : json["country"])) ??
        "",
    cityId: _parseInt(json["cityId"]),
    communeId: _parseInt(json["communeId"]),
    quartierId: _parseInt(json["quartierId"]),
    isCertified: json["certified"] == null ? (json["isCertified"] == null ? true : _parseBool(json["isCertified"])) : _parseBool(json["certified"]),
    isActive: json["active"] == null ? (json["isActive"] == null ? true : _parseBool(json["isActive"])) : _parseBool(json["active"]),
    dateCreated: json["dateCreated"] != null ? DateTime.tryParse(json["dateCreated"]) : DateTime.now(),
    username: (json["username"] != null && json["username"].toString().isNotEmpty) ? json["username"] : json["postBy"],
    postBy: json["postBy"],
    images: json["images"] != null 
        ? (json["images"] is List 
            ? List<String>.from(json["images"].map((img) => img is String ? img : (img["path"] ?? img["url"] ?? "")))
            : [])
        : null,
    phone: json["phone"],
    email: json["email"],
    whatsapp: json["whatsapp"],
    user: json["user"] != null ? UserModel.fromJson(json["user"]) : null,
    cotations: _parseCotations(json),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "userId": userId,
    "serviceId": serviceId,
    "deviseId": deviseId,
    "title": title,
    "profile": profile,
    "description": description,
    "experience": experience,
    "plageJourPrestation": plageJourPrestation,
    "plageHeurePrestation": plageHeurePrestation,
    "minPrice": minPrice,
    "maxPrice": maxPrice,
    "address": address,
    "communeValue": communeValue,
    "quartierValue": quartierValue,
    "cityValue": cityValue,
    "countryValue": countryValue,
    "cityId": cityId,
    "communeId": communeId,
    "quartierId": quartierId,
    "isCertified": isCertified,
    "isActive": isActive,
    "dateCreated": dateCreated?.toIso8601String(),
    "username": username,
    "postBy": postBy,
    "images": images,
    "phone": phone,
    "email": email,
    "whatsapp": whatsapp,
    "user": user?.toJson(),
    "cotation": cotations?.map((e) => {
          "id": e.id,
          "userId": e.userId,
          "sollicitationId": e.sollicitationId,
          "commentaire": e.commentaire,
          "cote": e.cote,
          "createdAt": e.createdAt,
        }).toList(),
  };

  // Compatibility getter
  String? get createdAt => dateCreated?.toIso8601String();
  
  // Currency getter similar to PropertyModel and ServiceModel
  String get currency => (deviseId == 1) ? "FC" : "\$";
}

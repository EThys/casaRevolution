import 'dart:convert';
import 'CommuneModel.dart';
import 'PropertyTypeModel.dart';
import 'PropertyFeatureModel.dart';
import 'PropertyImageModel.dart';
import 'PropertyImageRoomModel.dart';
import 'PropertyImageLivingRoomModel.dart';
import 'PropertyImageKitchenModel.dart';
import 'UserModel.dart';

PropertyModel propertyModelFromJson(String str) => PropertyModel.fromJson(json.decode(str));
String propertyModelToJson(PropertyModel data) => json.encode(data.toJson());

// Méthodes helpers pour le parsing sécurisé
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

String? _parseString(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  return value.toString();
}

bool _parseBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is String) return value.toLowerCase() == 'true';
  if (value is int) return value == 1;
  return false;
}

class PropertyModel {
  int? propertyId;
  String? title;
  String? username;
  String? description;
  double? price;
  double? surface;
  int? rooms;
  int? bedrooms;
  int? kitchen;
  int? livingRoom;
  int? bathroom;
  int? floor;
  String? address;

  // NOUVELLES PROPRIÉTES AJOUTÉES
  String? guarantee;
  String? communeValue;
  String? cityValue;
  String? countryValue;
  String? districtValue;
  String? quartierValue;

  int? cityId;
  int? communeId;
  int? quartierId;
  int? districtId;
  String? postalCode;
  String? quartier;
  bool? sold;
  String? transactionType;
  int? propertyTypeId;
  PropertyTypeModel? propertyType;
  int? userId;
  UserModel? user;
  double? latitude;
  double? longitude;
  String? createdStart;
  String? updatedAt;
  String? createdAt;
  int? electric;
  int? water;

  // NOUVELLES PROPRIÉTES STATISTIQUES
  int? viewCount;
  int? favoriteCount;
  bool? isFavorite;
  double? rating;
  int? reviewCount;

  // NOUVELLES PROPRIÉTES MÉTADONNÉES
  bool? isActive;
  bool? isVerified;
  bool? isFeatured;
  String? status;
  String? rejectionReason;

  List<PropertyFeatureModel>? features;
  List<PropertyImageModel>? propertyImage;
  List<PropertyImageRoomModel>? propertyImageRoom;
  List<PropertyImageLivingRoomModel>? propertyImageLivingRoom;
  List<PropertyImageKitchenModel>? propertyImageKitchen;

  PropertyModel({
    this.propertyId,
    this.title,
    this.description,
    this.username,
    this.price,
    this.surface,
    this.rooms,
    this.bedrooms,
    this.kitchen,
    this.livingRoom,
    this.bathroom,
    this.floor,
    this.address,

    // NOUVELLES PROPRIÉTES
    this.guarantee,
    this.communeValue,
    this.cityValue,
    this.countryValue,
    this.districtValue,
    this.quartierValue,

    this.cityId,
    this.communeId,
    this.quartierId,
    this.districtId,
    this.postalCode,
    this.quartier,
    this.sold,
    this.transactionType,
    this.propertyTypeId,
    this.propertyType,
    this.userId,
    this.user,
    this.latitude,
    this.longitude,
    this.createdStart,
    this.updatedAt,
    this.createdAt,
    this.electric,
    this.water,

    // NOUVELLES PROPRIÉTES STATISTIQUES
    this.viewCount,
    this.favoriteCount,
    this.isFavorite,
    this.rating,
    this.reviewCount,

    // NOUVELLES PROPRIÉTES MÉTADONNÉES
    this.isActive,
    this.isVerified,
    this.isFeatured,
    this.status,
    this.rejectionReason,

    this.features,
    this.propertyImage,
    this.propertyImageRoom,
    this.propertyImageLivingRoom,
    this.propertyImageKitchen,
  });

  factory PropertyModel.fromJson(Map<String, dynamic> json) {
    // Debug logging
    print('🔍 Parsing PropertyModel from JSON:');
    json.forEach((key, value) {
      if (value != null) {
        print('   $key: $value (${value.runtimeType})');
      }
    });

    return PropertyModel(
      propertyId: _parseInt(json["propertyId"]) ?? _parseInt(json["id"]),
      title: _parseString(json["title"]),
      description: _parseString(json["description"]),
      username: _parseString(json["username"]),
      price: _parseDouble(json["price"]) ?? 0.0,
      surface: _parseDouble(json["surface"]) ?? 0.0,
      rooms: _parseInt(json["rooms"]) ?? 0,
      bedrooms: _parseInt(json["bedrooms"]) ?? 0,
      kitchen: _parseInt(json["kitchen"]) ?? 0,
      livingRoom: _parseInt(json["livingRoom"]) ?? 0,
      bathroom: _parseInt(json["bathroom"]) ?? 0,
      floor: _parseInt(json["floor"]) ?? 0,
      address: _parseString(json["address"]),

      // NOUVELLES PROPRIÉTES
      guarantee: _parseString(json["guarantee"]),
      communeValue: _parseString(json["communeValue"]),
      cityValue: _parseString(json["cityValue"]),
      countryValue: _parseString(json["countryValue"]),
      districtValue: _parseString(json["districtValue"]),
      quartierValue: _parseString(json["quartierValue"]),

      cityId: _parseInt(json["cityId"]) ?? 0,
      communeId: _parseInt(json["communeId"]) ?? 0,
      quartierId: _parseInt(json["quartierId"]) ?? 0,
      districtId: _parseInt(json["districtId"]) ?? 0,
      postalCode: _parseString(json["postalCode"]),
      quartier: _parseString(json["quartier"]),
      sold: _parseBool(json["sold"]),
      transactionType: _parseString(json["transactionType"]),
      propertyTypeId: _parseInt(json["propertyTypeId"]) ?? 0,
      propertyType: json["propertyType"] is Map<String, dynamic>
          ? PropertyTypeModel.fromJson(json["propertyType"])
          : null,
      // Extraire userId depuis json["userId"] ou depuis json["user"]["userId"]
      userId: _parseInt(json["userId"]) ?? 
              (json["user"] is Map && json["user"]["userId"] != null 
                ? _parseInt(json["user"]["userId"]) 
                : 0),
      user: json["user"] is Map<String, dynamic>
          ? UserModel.fromJson(json["user"])
          : null,
      latitude: _parseDouble(json["latitude"]) ?? 0.0,
      longitude: _parseDouble(json["longitude"]) ?? 0.0,
      createdStart: _parseString(json["createdStart"]) ?? _parseString(json["createdAt"]),
      updatedAt: _parseString(json["updatedAt"]),
      createdAt: _parseString(json["createdAt"]),
      electric: _parseInt(json["electric"]) ?? 0,
      water: _parseInt(json["water"]) ?? 0,

      // NOUVELLES PROPRIÉTES STATISTIQUES
      viewCount: _parseInt(json["viewCount"]) ?? 0,
      favoriteCount: _parseInt(json["favoriteCount"]) ?? 0,
      isFavorite: _parseBool(json["isFavorite"]),
      rating: _parseDouble(json["rating"]) ?? 0.0,
      reviewCount: _parseInt(json["reviewCount"]) ?? 0,

      // NOUVELLES PROPRIÉTES MÉTADONNÉES
      isActive: _parseBool(json["isActive"]) ?? true,
      isVerified: _parseBool(json["isVerified"]) ?? false,
      isFeatured: _parseBool(json["isFeatured"]) ?? false,
      status: _parseString(json["status"]) ?? "active",
      rejectionReason: _parseString(json["rejectionReason"]),

      features: json["features"] is List
          ? List<PropertyFeatureModel>.from(
          (json["features"] as List).where((x) => x != null).map((x) => PropertyFeatureModel.fromJson(x)))
          : <PropertyFeatureModel>[],
      propertyImage: json["propertyImage"] is List
          ? List<PropertyImageModel>.from(
          (json["propertyImage"] as List).where((x) => x != null).map((x) => PropertyImageModel.fromJson(x)))
          : <PropertyImageModel>[],
      propertyImageRoom: json["propertyImageRoom"] is List
          ? List<PropertyImageRoomModel>.from(
          (json["propertyImageRoom"] as List).where((x) => x != null).map((x) => PropertyImageRoomModel.fromJson(x)))
          : <PropertyImageRoomModel>[],
      propertyImageLivingRoom: json["propertyImageLivingRoom"] is List
          ? List<PropertyImageLivingRoomModel>.from(
          (json["propertyImageLivingRoom"] as List).where((x) => x != null).map((x) => PropertyImageLivingRoomModel.fromJson(x)))
          : <PropertyImageLivingRoomModel>[],
      propertyImageKitchen: json["propertyImageKitchen"] is List
          ? List<PropertyImageKitchenModel>.from(
          (json["propertyImageKitchen"] as List).where((x) => x != null).map((x) => PropertyImageKitchenModel.fromJson(x)))
          : <PropertyImageKitchenModel>[],
    );
  }

  Map<String, dynamic> toJson() => {
    "propertyId": propertyId,
    "title": title,
    "description": description,
    "username": username,
    "price": price,
    "surface": surface,
    "rooms": rooms,
    "bedrooms": bedrooms,
    "kitchen": kitchen,
    "livingRoom": livingRoom,
    "bathroom": bathroom,
    "floor": floor,
    "address": address,

    // NOUVELLES PROPRIÉTES
    "guarantee": guarantee,
    "communeValue": communeValue,
    "cityValue": cityValue,
    "countryValue": countryValue,
    "districtValue": districtValue,
    "quartierValue": quartierValue,

    "cityId": cityId,
    "communeId": communeId,
    "quartierId": quartierId,
    "districtId": districtId,
    "postalCode": postalCode,
    "quartier": quartier,
    "sold": sold,
    "transactionType": transactionType,
    "propertyTypeId": propertyTypeId,
    "propertyType": propertyType?.toJson(),
    "userId": userId,
    "user": user?.toJson(),
    "latitude": latitude,
    "longitude": longitude,
    "createdStart": createdStart,
    "updatedAt": updatedAt,
    "createdAt": createdAt,
    "electric": electric,
    "water": water,

    // NOUVELLES PROPRIÉTES STATISTIQUES
    "viewCount": viewCount,
    "favoriteCount": favoriteCount,
    "isFavorite": isFavorite,
    "rating": rating,
    "reviewCount": reviewCount,

    // NOUVELLES PROPRIÉTES MÉTADONNÉES
    "isActive": isActive,
    "isVerified": isVerified,
    "isFeatured": isFeatured,
    "status": status,
    "rejectionReason": rejectionReason,

    "features": features == null
        ? []
        : List<dynamic>.from(features!.map((x) => x.toJson())),
    "propertyImage": propertyImage == null
        ? []
        : List<dynamic>.from(propertyImage!.map((x) => x.toJson())),
    "propertyImageRoom": propertyImageRoom == null
        ? []
        : List<dynamic>.from(propertyImageRoom!.map((x) => x.toJson())),
    "propertyImageLivingRoom": propertyImageLivingRoom == null
        ? []
        : List<dynamic>.from(propertyImageLivingRoom!.map((x) => x.toJson())),
    "propertyImageKitchen": propertyImageKitchen == null
        ? []
        : List<dynamic>.from(propertyImageKitchen!.map((x) => x.toJson())),
  };

  // Méthodes utilitaires
  String get formattedPrice {
    if (price == null) return "0";
    if (transactionType == "vente") {
      return "${price!.toStringAsFixed(0)}\$";
    } else {
      return "${price!.toStringAsFixed(0)}\$/mois";
    }
  }

  String get formattedSurface {
    if (surface == null) return "0";
    return "${surface!.toStringAsFixed(0)} m²";
  }

  String get fullAddress {
    List<String> parts = [];
    if (address != null && address!.isNotEmpty) parts.add(address!);
    if (quartier != null && quartier!.isNotEmpty) parts.add(quartier!);
    if (communeValue != null && communeValue!.isNotEmpty) parts.add(communeValue!);
    if (cityValue != null && cityValue!.isNotEmpty) parts.add(cityValue!);
    return parts.join(", ");
  }

  String get electricStatus {
    switch (electric) {
      case 80:
        return "Élevée";
      case 60:
        return "Bonne";
      case 40:
        return "Moyenne";
      case 20:
        return "Faible";
      default:
        return "Non spécifié";
    }
  }

  String get waterStatus {
    switch (water) {
      case 80:
        return "Excellente";
      case 60:
        return "Bonne";
      case 40:
        return "Moyenne";
      case 20:
        return "Faible";
      default:
        return "Non spécifié";
    }
  }

  bool get hasImages {
    return (propertyImage?.isNotEmpty == true) ||
        (propertyImageRoom?.isNotEmpty == true) ||
        (propertyImageLivingRoom?.isNotEmpty == true) ||
        (propertyImageKitchen?.isNotEmpty == true);
  }

  List<String> get allImageUrls {
    List<String> urls = [];

    if (propertyImage != null) {
      urls.addAll(propertyImage!.map((img) => img.path ?? "").where((url) => url.isNotEmpty));
    }
    if (propertyImageRoom != null) {
      urls.addAll(propertyImageRoom!.map((img) => img.path ?? "").where((url) => url.isNotEmpty));
    }
    if (propertyImageLivingRoom != null) {
      urls.addAll(propertyImageLivingRoom!.map((img) => img.path ?? "").where((url) => url.isNotEmpty));
    }
    if (propertyImageKitchen != null) {
      urls.addAll(propertyImageKitchen!.map((img) => img.path ?? "").where((url) => url.isNotEmpty));
    }

    return urls;
  }

  List<String> get amenities {
    if (features == null) return [];
    return features!.map((feature) => feature.name ?? "").where((name) => name.isNotEmpty).toList();
  }

  @override
  String toString() {
    return 'PropertyModel('
        'propertyId: $propertyId, '
        'title: $title, '
        'username: $username, '
        'price: $price, '
        'surface: $surface, '
        'cityId: $cityId, '
        'propertyType: ${propertyType?.name}, '
        'user: ${user?.email}, '
        'createdStart: $createdStart, '
        'electric: $electric, '
        'water: $water, '
        'transactionType: $transactionType, '
        'isActive: $isActive, '
        'isVerified: $isVerified'
        ')';
  }

  // Méthode pour créer une copie du modèle
  PropertyModel copyWith({
    int? propertyId,
    String? title,
    String? username,
    String? description,
    double? price,
    double? surface,
    int? rooms,
    int? bedrooms,
    int? kitchen,
    int? livingRoom,
    int? bathroom,
    int? floor,
    String? address,
    String? guarantee,
    String? communeValue,
    String? cityValue,
    String? countryValue,
    String? districtValue,
    String? quartierValue,
    int? cityId,
    int? communeId,
    int? quartierId,
    int? districtId,
    String? postalCode,
    String? quartier,
    bool? sold,
    String? transactionType,
    int? propertyTypeId,
    PropertyTypeModel? propertyType,
    int? userId,
    UserModel? user,
    double? latitude,
    double? longitude,
    String? createdStart,
    String? updatedAt,
    String? createdAt,
    int? electric,
    int? water,
    int? viewCount,
    int? favoriteCount,
    bool? isFavorite,
    double? rating,
    int? reviewCount,
    bool? isActive,
    bool? isVerified,
    bool? isFeatured,
    String? status,
    String? rejectionReason,
    List<PropertyFeatureModel>? features,
    List<PropertyImageModel>? propertyImage,
    List<PropertyImageRoomModel>? propertyImageRoom,
    List<PropertyImageLivingRoomModel>? propertyImageLivingRoom,
    List<PropertyImageKitchenModel>? propertyImageKitchen,
  }) {
    return PropertyModel(
      propertyId: propertyId ?? this.propertyId,
      title: title ?? this.title,
      username: username ?? this.username,
      description: description ?? this.description,
      price: price ?? this.price,
      surface: surface ?? this.surface,
      rooms: rooms ?? this.rooms,
      bedrooms: bedrooms ?? this.bedrooms,
      kitchen: kitchen ?? this.kitchen,
      livingRoom: livingRoom ?? this.livingRoom,
      bathroom: bathroom ?? this.bathroom,
      floor: floor ?? this.floor,
      address: address ?? this.address,
      guarantee: guarantee ?? this.guarantee,
      communeValue: communeValue ?? this.communeValue,
      cityValue: cityValue ?? this.cityValue,
      countryValue: countryValue ?? this.countryValue,
      districtValue: districtValue ?? this.districtValue,
      quartierValue: quartierValue ?? this.quartierValue,
      cityId: cityId ?? this.cityId,
      communeId: communeId ?? this.communeId,
      quartierId: quartierId ?? this.quartierId,
      districtId: districtId ?? this.districtId,
      postalCode: postalCode ?? this.postalCode,
      quartier: quartier ?? this.quartier,
      sold: sold ?? this.sold,
      transactionType: transactionType ?? this.transactionType,
      propertyTypeId: propertyTypeId ?? this.propertyTypeId,
      propertyType: propertyType ?? this.propertyType,
      userId: userId ?? this.userId,
      user: user ?? this.user,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdStart: createdStart ?? this.createdStart,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
      electric: electric ?? this.electric,
      water: water ?? this.water,
      viewCount: viewCount ?? this.viewCount,
      favoriteCount: favoriteCount ?? this.favoriteCount,
      isFavorite: isFavorite ?? this.isFavorite,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      isActive: isActive ?? this.isActive,
      isVerified: isVerified ?? this.isVerified,
      isFeatured: isFeatured ?? this.isFeatured,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      features: features ?? this.features,
      propertyImage: propertyImage ?? this.propertyImage,
      propertyImageRoom: propertyImageRoom ?? this.propertyImageRoom,
      propertyImageLivingRoom: propertyImageLivingRoom ?? this.propertyImageLivingRoom,
      propertyImageKitchen: propertyImageKitchen ?? this.propertyImageKitchen,
    );
  }
}
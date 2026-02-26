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
  String? postBy; // Publisher name from API
  String? image; // Profile picture from API
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

  // CHAMPS SPÉCIFIQUES (Bureau, Festive, Funéraire)
  int? roomMeet;
  int? numberPiece;
  bool? isEquip;
  int? capacityPeople;
  bool? isDecore;
  bool? pisteDanse;
  
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
  bool? available;
  String? status;
  String? rejectionReason;
  int? deviseId; // 1 for FC, 2 for USD

  List<PropertyFeatureModel>? features;
  List<PropertyImageModel>? propertyImage;
  List<PropertyImageRoomModel>? propertyImageRoom;
  List<PropertyImageLivingRoomModel>? propertyImageLivingRoom;
  List<PropertyImageKitchenModel>? propertyImageKitchen;
  List<HotelRoomStructure>? hotelStructure;

  PropertyModel({
    this.propertyId,
    this.title,
    this.description,
    this.username,
    this.postBy,
    this.image,
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
    
    // CHAMPS SPÉCIFIQUES
    this.roomMeet,
    this.numberPiece,
    this.isEquip,
    this.capacityPeople,
    this.isDecore,
    this.pisteDanse,
    
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
    this.available,
    this.status,
    this.rejectionReason,

    this.features,
    this.propertyImage,
    this.propertyImageRoom,
    this.propertyImageLivingRoom,
    this.propertyImageKitchen,
    this.deviseId,
    this.hotelStructure,
  });

  factory PropertyModel.fromJson(Map<String, dynamic> json) {
    // 1. Identifier le conteneur principal (qui contient images, address, etc.)
    Map<String, dynamic> container = json;
    if (json["property"] is Map) {
      container = json["property"];
    } else {
      final specializedKeys = [
        "terrain", "bureau", "bureaux", "vacance", "vacances", 
        "festive", "festives", "funeraire", "funeraires", "hotel", "salle"
      ];
      for (final key in specializedKeys) {
        if (json[key] is Map) {
          container = json[key];
          break;
        }
      }
    }
    
    // Support pour la structure d'hôtel (chambres)
    List<HotelRoomStructure>? parsedStructure;
    if (json["structure"] is List) {
      parsedStructure = (json["structure"] as List)
          .map((s) => HotelRoomStructure.fromJson(s))
          .toList();
    }

    // 2. Identifier le noeud de données plates (title, price, price, etc.)
    Map<String, dynamic> dataNode = container;
    if (container["property"] is Map) {
      dataNode = container["property"];
    }

    // Debug logging pour le support technique
    print('🔍 Parsing PropertyModel [ID: ${dataNode["propertyId"] ?? dataNode["id"]}] - Structure: ${json["property"] != null ? (container["property"] != null ? 'DOUBLE_NESTED' : 'NESTED') : 'FLAT'}');
                
    final dynamic imagesNode = container["images"] ?? json["images"] ?? container["propertyImage"];
    final Map<String, dynamic> addressNode = container["address"] is Map ? container["address"] : (json["address"] is Map ? json["address"] : dataNode);
    final Map<String, dynamic> geoNode = container["geoZone"] is Map ? container["geoZone"] : (json["geoZone"] is Map ? json["geoZone"] : dataNode);
    final Map<String, dynamic> typeNode = container["typeProperty"] is Map ? container["typeProperty"] : (json["typeProperty"] is Map ? json["typeProperty"] : dataNode);
    
    // Helper pour chercher dans les différentes couches de données
    dynamic _getVal(String key) {
       return dataNode[key] ?? container[key] ?? json[key];
    }
    
    return PropertyModel(
      propertyId: _parseInt(dataNode["propertyId"]) ?? _parseInt(dataNode["id"]),
      title: _parseString(dataNode["title"]),
      description: _parseString(dataNode["description"]),
      postBy: _parseString(container["postBy"]) ?? _parseString(json["postBy"]),
      image: _parseString(container["image"]) ?? _parseString(json["image"]),
      username: _parseString(container["postBy"]) ?? _parseString(dataNode["username"]) ?? _parseString(json["username"]),
      price: _parseDouble(dataNode["price"]) ?? 0.0,
      surface: _parseDouble(dataNode["surface"]) ?? 0.0,
      rooms: _parseInt(dataNode["rooms"]) ?? 0,
      bedrooms: _parseInt(dataNode["bedrooms"]) ?? 0,
      kitchen: _parseInt(dataNode["kitchen"]) ?? 0,
      livingRoom: _parseInt(dataNode["livingRoom"]) ?? 0,
      bathroom: _parseInt(dataNode["bathroom"]) ?? 0,
      floor: _parseInt(dataNode["floor"]) ?? 0,
      address: _parseString(addressNode["address"]) ?? _parseString(dataNode["address"]),

      // NOUVELLES PROPRIÉTES
      guarantee: _parseString(dataNode["guarantee"]),
      communeValue: _parseString(addressNode["communeValue"]) ?? _parseString(dataNode["communeValue"]),
      cityValue: _parseString(addressNode["cityValue"]) ?? _parseString(dataNode["cityValue"]),
      countryValue: _parseString(addressNode["countryValue"]) ?? _parseString(dataNode["countryValue"]),
      districtValue: _parseString(addressNode["districtValue"]) ?? _parseString(dataNode["districtValue"]),
      quartierValue: _parseString(addressNode["quartierValue"]) ?? _parseString(dataNode["quartierValue"]),

      cityId: _parseInt(addressNode["cityId"]) ?? _parseInt(dataNode["cityId"]) ?? 0,
      communeId: _parseInt(addressNode["communeId"]) ?? _parseInt(dataNode["communeId"]) ?? 0,
      quartierId: _parseInt(addressNode["quartierId"]) ?? _parseInt(dataNode["quartierId"]) ?? 0,
      districtId: _parseInt(addressNode["districtId"]) ?? _parseInt(dataNode["districtId"]) ?? 0,
      postalCode: _parseString(addressNode["postalCode"]) ?? _parseString(dataNode["postalCode"]),
      quartier: _parseString(addressNode["quartier"]) ?? _parseString(dataNode["quartier"]),
      sold: _parseBool(dataNode["sold"]),
      transactionType: _parseString(dataNode["transactionType"]),
      propertyTypeId: _parseInt(typeNode["propertyTypeId"]) ?? _parseInt(dataNode["propertyTypeId"]) ?? 0,
      
      propertyType: typeNode.isNotEmpty && typeNode["propertyTypeId"] != null
          ? PropertyTypeModel.fromJson(typeNode)
          : (dataNode["propertyType"] is Map<String, dynamic>
              ? PropertyTypeModel.fromJson(dataNode["propertyType"])
              : null),

      userId: _parseInt(dataNode["userId"]) ?? 
              _parseInt(json["userId"]) ?? 
              (json["user"] is Map && json["user"]["userId"] != null 
                ? _parseInt(json["user"]["userId"]) 
                : 0),
      user: json["user"] is Map<String, dynamic>
          ? UserModel.fromJson(json["user"])
          : null,
      latitude: _parseDouble(geoNode["lat"]) ?? _parseDouble(dataNode["latitude"]) ?? 0.0,
      longitude: _parseDouble(geoNode["lng"]) ?? _parseDouble(dataNode["longitude"]) ?? 0.0,
      createdStart: _parseString(dataNode["createdStart"]) ?? _parseString(_getVal("createdAt")) ?? _parseString(json["createdAt"]),
      updatedAt: _parseString(dataNode["updatedAt"]) ?? _parseString(json["updatedAt"]),
      createdAt: _parseString(_getVal("createdAt")) ?? _parseString(json["createdAt"]),
      electric: _parseInt(dataNode["electric"]) ?? 0,
      water: _parseInt(dataNode["water"]) ?? 0,

      // CHAMPS SPÉCIFIQUES
      roomMeet: _parseInt(_getVal("roomMeet")),
      numberPiece: _parseInt(_getVal("numberPiece")),
      isEquip: _parseBool(_getVal("isEquip")) || _parseBool(_getVal("equipped")),
      capacityPeople: _parseInt(_getVal("capacityPeople")),
      isDecore: _parseBool(_getVal("isDecore")) || _parseBool(_getVal("decore")),
      pisteDanse: _parseBool(_getVal("pisteDanse")),

      // NOUVELLES PROPRIÉTES STATISTIQUES
      viewCount: _parseInt(json["viewCount"]) ?? _parseInt(container["viewCount"]) ?? 0,
      favoriteCount: _parseInt(json["favoriteCount"]) ?? _parseInt(container["favoriteCount"]) ?? 0,
      isFavorite: _parseBool(json["isFavorite"]) || _parseBool(container["isFavorite"]),
      rating: _parseDouble(json["rating"]) ?? _parseDouble(container["rating"]) ?? 0.0,
      reviewCount: _parseInt(json["reviewCount"]) ?? _parseInt(container["reviewCount"]) ?? 0,

      // NOUVELLES PROPRIÉTES MÉTADONNÉES
      isActive: _parseBool(dataNode["isActive"]) ?? _parseBool(container["isActive"]) ?? true,
      isVerified: _parseBool(dataNode["isVerified"]) ?? _parseBool(container["isVerified"]) ?? false,
      isFeatured: _parseBool(dataNode["isFeatured"]) ?? _parseBool(container["isFeatured"]) ?? false,
      available: _parseBool(dataNode["available"]) ?? _parseBool(container["available"]) ?? _parseBool(json["available"]) ?? true,
      status: _parseString(dataNode["status"]) ?? "active",
      rejectionReason: _parseString(dataNode["rejectionReason"]),
      deviseId: _parseInt(dataNode["deviseId"]) ?? _parseInt(json["deviseId"]) ?? _parseInt(json["devise"]?["id"]),
      hotelStructure: parsedStructure,

      features: (json["features"] ?? json["feature"] ?? dataNode["features"]) is List
          ? List<PropertyFeatureModel>.from(
          ((json["features"] ?? json["feature"] ?? dataNode["features"]) as List).where((x) => x != null).map((x) => PropertyFeatureModel.fromJson(x)))
          : <PropertyFeatureModel>[],
          
      propertyImage: _parseImages(imagesNode),
      
      propertyImageRoom: _parseRoomImages(imagesNode),
      
      propertyImageLivingRoom: _parseLivingRoomImages(imagesNode),
      
      propertyImageKitchen: _parseKitchenImages(imagesNode),

    );
  }

  Map<String, dynamic> toJson() => {
    "propertyId": propertyId,
    "title": title,
    "description": description,
    "username": username,
    "postBy": postBy,
    "image": image,
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
    "transactionType": transactionType,
    "deviseId": deviseId,
    "devise_id": deviseId, // Helper for API consistency
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

    // CHAMPS SPÉCIFIQUES
    "roomMeet": roomMeet,
    "numberPiece": numberPiece,
    "isEquip": isEquip,
    "capacityPeople": capacityPeople,
    "isDecore": isDecore,
    "pisteDanse": pisteDanse,

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
    "available": available,
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
    "hotelStructure": hotelStructure == null
        ? []
        : List<dynamic>.from(hotelStructure!.map((x) => x.toJson())),
  };

  // Méthodes utilitaires
  String get formattedPrice {
    if (price == null) return "0";
    String symbol = (deviseId == 1) ? "FC" : "\$";
    if (transactionType == "vente") {
      return "${price!.toStringAsFixed(0)} $symbol";
    } else {
      return "${price!.toStringAsFixed(0)} $symbol/mois";
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

  String get currency => (deviseId == 1) ? "FC" : "\$";

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
        'roomMeet: $roomMeet, '
        'capacityPeople: $capacityPeople, '
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
    int? roomMeet,
    int? numberPiece,
    bool? isEquip,
    int? capacityPeople,
    bool? isDecore,
    bool? pisteDanse,
    int? viewCount,
    int? favoriteCount,
    bool? isFavorite,
    double? rating,
    int? reviewCount,
    bool? isActive,
    bool? isVerified,
    bool? isFeatured,
    bool? available,
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
      
      roomMeet: roomMeet ?? this.roomMeet,
      numberPiece: numberPiece ?? this.numberPiece,
      isEquip: isEquip ?? this.isEquip,
      capacityPeople: capacityPeople ?? this.capacityPeople,
      isDecore: isDecore ?? this.isDecore,
      pisteDanse: pisteDanse ?? this.pisteDanse,
      
      viewCount: viewCount ?? this.viewCount,
      favoriteCount: favoriteCount ?? this.favoriteCount,
      isFavorite: isFavorite ?? this.isFavorite,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      isActive: isActive ?? this.isActive,
      isVerified: isVerified ?? this.isVerified,
      isFeatured: isFeatured ?? this.isFeatured,
      available: available ?? this.available,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      features: features ?? this.features,
      propertyImage: propertyImage ?? this.propertyImage,
      propertyImageRoom: propertyImageRoom ?? this.propertyImageRoom,
      propertyImageLivingRoom: propertyImageLivingRoom ?? this.propertyImageLivingRoom,
      propertyImageKitchen: propertyImageKitchen ?? this.propertyImageKitchen,
    );
  }

  static List<PropertyImageModel> _parseImages(dynamic data) {
    if (data == null) return [];
    try {
      if (data is List) {
        return List<PropertyImageModel>.from(data.where((x) => x != null).map((x) {
             if (x is String) return PropertyImageModel(path: x);
             return PropertyImageModel.fromJson(x);
        }));
      }
      if (data is Map && data['main'] is List) {
        return List<PropertyImageModel>.from((data['main'] as List).where((x) => x != null).map((x) => PropertyImageModel.fromJson(x)));
      }
    } catch (e) {
      print("⚠️ Error parsing images: $e");
    }
    return [];
  }

  static List<PropertyImageRoomModel> _parseRoomImages(dynamic data) {
    if (data == null) return [];
    try {
      if (data is List) {
        return List<PropertyImageRoomModel>.from(data.where((x) => x != null).map((x) => PropertyImageRoomModel.fromJson(x)));
      }
      if (data is Map && data['room'] is List) {
         return List<PropertyImageRoomModel>.from((data['room'] as List).where((x) => x != null).map((x) => PropertyImageRoomModel.fromJson(x)));
      }
    } catch (e) {
      print("⚠️ Error parsing room images: $e");
    }
    return [];
  }

  static List<PropertyImageLivingRoomModel> _parseLivingRoomImages(dynamic data) {
     if (data == null) return [];
    try {
      if (data is List) {
        return List<PropertyImageLivingRoomModel>.from(data.where((x) => x != null).map((x) => PropertyImageLivingRoomModel.fromJson(x)));
      }
      if (data is Map && data['living'] is List) {
         return List<PropertyImageLivingRoomModel>.from((data['living'] as List).where((x) => x != null).map((x) => PropertyImageLivingRoomModel.fromJson(x)));
      }
    } catch (e) {
      print("⚠️ Error parsing living room images: $e");
    }
    return [];
  }

  static List<PropertyImageKitchenModel> _parseKitchenImages(dynamic data) {
    if (data == null) return [];
    try {
      if (data is List) {
        return List<PropertyImageKitchenModel>.from(data.where((x) => x != null).map((x) => PropertyImageKitchenModel.fromJson(x)));
      }
      if (data is Map && data['kitchen'] is List) {
         return List<PropertyImageKitchenModel>.from((data['kitchen'] as List).where((x) => x != null).map((x) => PropertyImageKitchenModel.fromJson(x)));
      }
    } catch (e) {
      print("⚠️ Error parsing kitchen images: $e");
    }
    return [];
  }
}

class HotelRoomStructure {
  final HotelRoomModel? chambre;
  final List<PropertyImageModel>? images;

  HotelRoomStructure({this.chambre, this.images});

  factory HotelRoomStructure.fromJson(Map<String, dynamic> json) {
    return HotelRoomStructure(
      chambre: json["chambre"] != null ? HotelRoomModel.fromJson(json["chambre"]) : null,
      images: (json["image"] ?? json["images"]) != null 
          ? ((json["image"] ?? json["images"]) as List).map((i) => PropertyImageModel.fromJson(Map<String, dynamic>.from(i))).toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() => {
    "chambre": chambre?.toJson(),
    "image": images == null ? [] : List<dynamic>.from(images!.map((x) => x.toJson())),
  };
}

class HotelRoomModel {
  final int? id;
  final int? hotelId;
  final int? deviseId;
  final String? title;
  final String? description;
  final int? numberPiece;
  final double? price;
  final String? priceHeure;
  final String? createdAt;
  final String? updatedAt;
  final bool? available;

  HotelRoomModel({
    this.id,
    this.hotelId,
    this.deviseId,
    this.title,
    this.description,
    this.numberPiece,
    this.price,
    this.priceHeure,
    this.createdAt,
    this.updatedAt,
    this.available,
  });

  factory HotelRoomModel.fromJson(Map<String, dynamic> json) {
    return HotelRoomModel(
      id: json["id"],
      hotelId: json["hotelId"],
      deviseId: json["deviseId"],
      title: json["title"],
      description: json["description"],
      numberPiece: json["numberPiece"],
      price: json["price"] != null ? (json["price"] as num).toDouble() : 0.0,
      priceHeure: json["priceHeure"],
      createdAt: json["createdAt"],
      updatedAt: json["updatedAt"],
      available: json["available"] == null ? true : (json["available"] is bool ? json["available"] : json["available"] == 1),
    );
  }

  Map<String, dynamic> toJson() => {
    "id": id,
    "hotelId": hotelId,
    "deviseId": deviseId,
    "title": title,
    "description": description,
    "numberPiece": numberPiece,
    "price": price,
    "priceHeure": priceHeure,
    "createdAt": createdAt,
    "updatedAt": updatedAt,
    "available": available,
  };
}
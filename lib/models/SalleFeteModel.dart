import 'dart:convert';

SalleFeteModel salleFeteModelFromJson(String str) => SalleFeteModel.fromJson(json.decode(str));

String salleFeteModelToJson(SalleFeteModel data) => json.encode(data.toJson());

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

class SalleFeteModel {
  int? id;
  int? userId;
  int? deviseId;
  String? title;
  String? description;
  String? usage;
  int? capacityPeople;
  int? electric;
  int? water;
  int? propertyTypeId;
  String? transactionType;
  double? price;
  bool? isAvailable;
  bool? isDecore;
  bool? pisteDanse;
  bool? sold;
  String? createdAt;
  String? updatedAt;
  
  // Location Fields (matching payload structure)
  String? address;
  String? communeValue;
  String? quartierValue;
  String? cityValue;
  String? countryValue;
  String? postalCode;
  int? cityId;
  int? communeId;
  int? quartierId;
  double? latitude;
  double? longitude;

  // Relations (for frontend handling)
  List<SalleFestiveImageModel>? images;
  List<FestiveFeatureModel>? feature;

  SalleFeteModel({
    this.id,
    this.userId,
    this.deviseId,
    this.title,
    this.description,
    this.usage,
    this.capacityPeople,
    this.electric,
    this.water,
    this.propertyTypeId,
    this.transactionType,
    this.price,
    this.isAvailable,
    this.isDecore,
    this.pisteDanse,
    this.sold,
    this.createdAt,
    this.updatedAt,
    this.address,
    this.communeValue,
    this.quartierValue,
    this.cityValue,
    this.countryValue,
    this.postalCode,
    this.cityId,
    this.communeId,
    this.quartierId,
    this.latitude,
    this.longitude,
    this.images,
    this.feature,
  });

  factory SalleFeteModel.fromJson(Map<String, dynamic> json) => SalleFeteModel(
    id: _parseInt(json["id"]),
    userId: _parseInt(json["userId"]),
    deviseId: _parseInt(json["deviseId"]),
    title: _parseString(json["title"]),
    description: _parseString(json["description"]),
    usage: _parseString(json["usage"]),
    capacityPeople: _parseInt(json["capacityPeople"]),
    electric: _parseInt(json["electric"]),
    water: _parseInt(json["water"]),
    propertyTypeId: _parseInt(json["propertyTypeId"]),
    transactionType: _parseString(json["transactionType"]),
    price: _parseDouble(json["price"]),
    isAvailable: _parseBool(json["isAvailable"]),
    isDecore: _parseBool(json["isDecore"]),
    pisteDanse: _parseBool(json["pisteDanse"]),
    sold: _parseBool(json["sold"]),
    createdAt: _parseString(json["createdAt"]),
    updatedAt: _parseString(json["updatedAt"]),
    address: _parseString(json["address"]),
    communeValue: _parseString(json["communeValue"]),
    quartierValue: _parseString(json["quartierValue"]),
    cityValue: _parseString(json["cityValue"]),
    countryValue: _parseString(json["countryValue"]),
    postalCode: _parseString(json["postalCode"]),
    cityId: _parseInt(json["cityId"]),
    communeId: _parseInt(json["communeId"]),
    quartierId: _parseInt(json["quartierId"]),
    latitude: _parseDouble(json["latitude"]),
    longitude: _parseDouble(json["longitude"]),
    images: json["images"] != null 
        ? List<SalleFestiveImageModel>.from(json["images"].map((x) => SalleFestiveImageModel.fromJson(x))) 
        : [],
    feature: json["feature"] != null 
        ? List<FestiveFeatureModel>.from(json["feature"].map((x) => FestiveFeatureModel.fromJson(x))) 
        : [],
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "userId": userId,
    "deviseId": deviseId,
    "title": title,
    "description": description,
    "usage": usage,
    "capacityPeople": capacityPeople,
    "electric": electric,
    "water": water,
    "propertyTypeId": propertyTypeId,
    "transactionType": transactionType,
    "price": price,
    "isAvailable": isAvailable,
    "isDecore": isDecore,
    "pisteDanse": pisteDanse,
    "sold": sold,
    "address": address,
    "communeValue": communeValue,
    "quartierValue": quartierValue,
    "cityValue": cityValue,
    "countryValue": countryValue,
    "postalCode": postalCode,
    "cityId": cityId,
    "communeId": communeId,
    "quartierId": quartierId,
    "latitude": latitude ?? 0.0,
    "longitude": longitude ?? 0.0,
    "createdAt": createdAt,
    "updatedAt": updatedAt,
    "images": images?.map((x) => x.toJson()).toList(),
    "feature": feature?.map((x) => x.toJson()).toList(),
  };
}

class SalleFestiveImageModel {
  int? id;
  int? salleFestiveId;
  String? name;
  String? path;
  bool? isAvailable;
  String? createdAt;

  SalleFestiveImageModel({
    this.id,
    this.salleFestiveId,
    this.name,
    this.path,
    this.isAvailable,
    this.createdAt,
  });

  factory SalleFestiveImageModel.fromJson(Map<String, dynamic> json) => SalleFestiveImageModel(
    id: _parseInt(json["id"]),
    salleFestiveId: _parseInt(json["salleFestiveId"]),
    name: _parseString(json["name"]),
    path: _parseString(json["path"]),
    isAvailable: _parseBool(json["isAvailable"]),
    createdAt: _parseString(json["createdAt"]),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "salleFestiveId": salleFestiveId,
    "name": name,
    "path": path,
    "isAvailable": isAvailable,
    "createdAt": createdAt,
  };
}

class FestiveFeatureModel {
  int? featureId;
  String? name;

  FestiveFeatureModel({
    this.featureId,
    this.name,
  });

  factory FestiveFeatureModel.fromJson(Map<String, dynamic> json) => FestiveFeatureModel(
    featureId: _parseInt(json["featureId"]),
    name: _parseString(json["name"]),
  );

  Map<String, dynamic> toJson() => {
    "featureId": featureId,
    "name": name,
  };
}

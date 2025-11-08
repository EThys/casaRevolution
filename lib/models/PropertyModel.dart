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
  int? cityId;
  int? communeId;
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
  int? electric;
  int? water;
  List<PropertyFeatureModel>? features;
  List<PropertyImageModel>? propertyImage;
  List<PropertyImageRoomModel>? propertyImageRoom;
  List<PropertyImageLivingRoomModel>? propertyImageLivingRoom;
  List<PropertyImageKitchenModel>? propertyImageKitchen;

  PropertyModel({
    this.propertyId,
    this.title,
    this.description,
    this.price,
    this.surface,
    this.rooms,
    this.bedrooms,
    this.kitchen,
    this.livingRoom,
    this.bathroom,
    this.floor,
    this.address,
    this.cityId,
    this.communeId,
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
    this.electric,
    this.water,
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
      price: _parseDouble(json["price"]) ?? 0.0,
      surface: _parseDouble(json["surface"]) ?? 0.0,
      rooms: _parseInt(json["rooms"]) ?? 0,
      bedrooms: _parseInt(json["bedrooms"]) ?? 0,
      kitchen: _parseInt(json["kitchen"]) ?? 0,
      livingRoom: _parseInt(json["livingRoom"]) ?? 0,
      bathroom: _parseInt(json["bathroom"]) ?? 0,
      floor: _parseInt(json["floor"]) ?? 0,
      address: _parseString(json["address"]),
      cityId: _parseInt(json["cityId"]) ?? 0,
      communeId: _parseInt(json["communeId"]) ?? 0,
      postalCode: _parseString(json["postalCode"]),
      quartier: _parseString(json["quartier"]),
      sold: _parseBool(json["sold"]),
      transactionType: _parseString(json["transactionType"]),
      propertyTypeId: _parseInt(json["propertyTypeId"]) ?? 0,
      propertyType: json["propertyType"] is Map<String, dynamic>
          ? PropertyTypeModel.fromJson(json["propertyType"])
          : null,
      userId: _parseInt(json["userId"]) ?? 0,
      user: json["user"] is Map<String, dynamic>
          ? UserModel.fromJson(json["user"])
          : null,
      latitude: _parseDouble(json["latitude"]) ?? 0.0,
      longitude: _parseDouble(json["longitude"]) ?? 0.0,
      createdStart: _parseString(json["createdStart"]) ?? _parseString(json["createdAt"]),
      electric: _parseInt(json["electric"]) ?? 0,
      water: _parseInt(json["water"]) ?? 0,
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
    "price": price,
    "surface": surface,
    "rooms": rooms,
    "bedrooms": bedrooms,
    "kitchen": kitchen,
    "livingRoom": livingRoom,
    "bathroom": bathroom,
    "floor": floor,
    "address": address,
    "cityId": cityId,
    "communeId": communeId,
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
    "electric": electric,
    "water": water,
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

  @override
  String toString() {
    return 'PropertyModel(propertyId: $propertyId, title: $title, price: $price, cityId: $cityId, propertyType: ${propertyType?.name}, user: ${user?.email}, createdStart: $createdStart, electric: $electric, water: $water)';
  }
}
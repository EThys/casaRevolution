// To parse this JSON data, do
//
//     final property = propertyFromJson(jsonString);

import 'dart:convert';

import 'package:casa/models/PropertyFeature.dart';
import 'package:casa/models/UserModel.dart';

import '../models/PropertyTypeModel.dart';
import '../models/PropertyVisitModel.dart';
import 'PropertyFavoriteModel.dart';
import 'PropertyImageModel.dart';

PropertyModel propertyFromJson(String str) => PropertyModel.fromJson(json.decode(str));

String propertyToJson(PropertyModel data) => json.encode(data.toJson());

class PropertyModel {
  int? propertyId;
  String? title;
  String? description;
  double? price;
  double? surface;
  int? rooms;
  int? bedrooms;
  int? floor;
  String? address;
  String? commune;
  String? city;
  String? postalCode;
  bool? sold;
  String? transactionType; // 'avendre' or 'location'
  int? propertyTypeId;
  int? userId;
  double? latitude;
  bool? isAvailable;
  double? longitude;
  int? propertyFeatureId;
  int? propertyImageId;
  UserModel? user;
  PropertyTypeModel? propertyType;
  List<PropertyFeatureModel>? features;
  List<PropertyImageModel>? images;
  List<PropertyFavoriteModel>? favorites;
  List<PropertyVisitModel>? visits;

  PropertyModel({
    this.propertyId,
    this.title,
    this.description,
    this.price,
    this.surface,
    this.rooms,
    this.bedrooms,
    this.floor,
    this.address,
    this.commune,
    this.city,
    this.postalCode,
    this.sold,
    this.transactionType,
    this.propertyTypeId,
    this.userId,
    this.latitude,
    this.isAvailable,
    this.longitude,
    this.propertyFeatureId,
    this.propertyImageId,
    this.user,
    this.propertyType,
    this.features,
    this.images,
    this.favorites,
    this.visits,
  });

  factory PropertyModel.fromJson(Map<String, dynamic> json) => PropertyModel(
    propertyId: json["PropertyId"],
    title: json["title"],
    description: json["description"],
    price: json["price"]?.toDouble(),
    surface: json["surface"]?.toDouble(),
    rooms: json["rooms"],
    bedrooms: json["bedrooms"],
    floor: json["floor"],
    address: json["address"],
    commune: json["commune"],
    city: json["city"],
    postalCode: json["postalCode"],
    sold: json["sold"],
    transactionType: json["transactionType"],
    propertyTypeId: json["PropertyTypeId"],
    userId: json["UserId"],
    latitude: json["latitude"]?.toDouble(),
    isAvailable: json["isAvailable"],
    longitude: json["longitude"]?.toDouble(),
    propertyFeatureId: json["PropertyFeatureId"],
    propertyImageId: json["PropertyImageId"],
    user: json["user"] == null ? null : UserModel.fromJson(json["user"]),
    propertyType: json["propertyType"] == null ? null : PropertyTypeModel.fromJson(json["propertyType"]),
    features: json["features"] == null ? [] : List<PropertyFeatureModel>.from(json["features"]!.map((x) => PropertyFeatureModel.fromJson(x))),
    images: json["images"] == null ? [] : List<PropertyImageModel>.from(json["images"]!.map((x) => PropertyImageModel.fromJson(x))),
    favorites: json["favorites"] == null ? [] : List<PropertyFavoriteModel>.from(json["favorites"]!.map((x) => PropertyFavoriteModel.fromJson(x))),
    visits: json["visits"] == null ? [] : List<PropertyVisitModel>.from(json["visits"]!.map((x) => PropertyVisitModel.fromJson(x))),
  );

  Map<String, dynamic> toJson() => {
    "PropertyId": propertyId,
    "title": title,
    "description": description,
    "price": price,
    "surface": surface,
    "rooms": rooms,
    "bedrooms": bedrooms,
    "floor": floor,
    "address": address,
    "commune": commune,
    "city": city,
    "postalCode": postalCode,
    "sold": sold,
    "transactionType": transactionType,
    "PropertyTypeId": propertyTypeId,
    "UserId": userId,
    "latitude": latitude,
    "isAvailable": isAvailable,
    "longitude": longitude,
    "PropertyFeatureId": propertyFeatureId,
    "PropertyImageId": propertyImageId,
    "user": user?.toJson(),
    "propertyType": propertyType?.toJson(),
    "features": features == null ? [] : List<dynamic>.from(features!.map((x) => x.toJson())),
    "images": images == null ? [] : List<dynamic>.from(images!.map((x) => x.toJson())),
    "favorites": favorites == null ? [] : List<dynamic>.from(favorites!.map((x) => x.toJson())),
    "visits": visits == null ? [] : List<dynamic>.from(visits!.map((x) => x.toJson())),
  };
}

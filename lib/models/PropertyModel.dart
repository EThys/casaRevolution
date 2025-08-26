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
  int? PropertyId;
  String? title;
  String? description;
  double? price;
  double? surface;
  int? rooms;
  int? bedrooms;
  int? kitchen;      // nombre de cuisines
  int? living_room;  // nombre de salons
  int? bathroom;     // nombre de salles de bain
  int? floor;
  String? address;
  String? commune;
  String? city;
  String? postalCode;
  bool? sold;
  String? transactionType; // 'avendre' or 'location'
  int? PropertyTypeId;
  int? UserId;
  double? latitude;
  bool? isAvailable;
  double? longitude;
  int? propertyFeatureId;
  int? propertyImageId;
  UserModel? user;
  PropertyTypeModel? property_type;
  List<PropertyFeatureModel>? features;
  List<PropertyImageModel>? images;
  List<PropertyFavoriteModel>? favorites;
  List<PropertyVisitModel>? visits;

  PropertyModel({
    this.PropertyId,
    this.title,
    this.description,
    this.price,
    this.surface,
    this.rooms,
    this.bedrooms,
    this.kitchen,
    this.living_room,
    this.bathroom,       
    this.floor,
    this.address,
    this.commune,
    this.city,
    this.postalCode,
    this.sold,
    this.transactionType,
    this.PropertyTypeId,
    this.UserId,
    this.latitude,
    this.isAvailable,
    this.longitude,
    this.propertyFeatureId,
    this.propertyImageId,
    this.user,
    this.property_type,
    this.features,
    this.images,
    this.favorites,
    this.visits,
  });

  factory PropertyModel.fromJson(Map<String, dynamic> json) => PropertyModel(
    PropertyId: json["PropertyId"],
    title: json["title"],
    description: json["description"],
    price: json["price"]?.toDouble(),
    surface: json["surface"]?.toDouble(),
    rooms: json["rooms"],
    bedrooms: json["bedrooms"],
    kitchen: json["kitchen"],         
    living_room: json["living_room"],  
    bathroom: json["bathroom"],         
    floor: json["floor"],
    address: json["address"],
    commune: json["commune"],
    city: json["city"],
    postalCode: json["postalCode"],
    // Correction pour les champs booléens
    sold: json["sold"] == 1 || json["sold"] == true, // Accepte 1/0 ou true/false
    transactionType: json["transactionType"],
    PropertyTypeId: json["PropertyTypeId"],
    UserId: json["UserId"],
    latitude: json["latitude"]?.toDouble(),
    // Correction pour isAvailable
    isAvailable: json["isAvailable"] == 1 || json["isAvailable"] == true,
    longitude: json["longitude"]?.toDouble(),
    propertyFeatureId: json["PropertyFeatureId"],
    propertyImageId: json["PropertyImageId"],
    user: json["user"] == null ? null : UserModel.fromJson(json["user"]),
    property_type: json["property_type"] == null ? null : PropertyTypeModel.fromJson(json["property_type"]),
    features: json["features"] == null ? [] : List<PropertyFeatureModel>.from(json["features"]!.map((x) => PropertyFeatureModel.fromJson(x))),
    images: json["images"] == null ? [] : List<PropertyImageModel>.from(json["images"]!.map((x) => PropertyImageModel.fromJson(x))),
    favorites: json["favorites"] == null ? [] : List<PropertyFavoriteModel>.from(json["favorites"]!.map((x) => PropertyFavoriteModel.fromJson(x))),
    visits: json["visits"] == null ? [] : List<PropertyVisitModel>.from(json["visits"]!.map((x) => PropertyVisitModel.fromJson(x))),
  );

  Map<String, dynamic> toJson() => {
    "PropertyId": PropertyId,
    "title": title,
    "description": description,
    "price": price,
    "surface": surface,
    "rooms": rooms,
    "bedrooms": bedrooms,
    "kitchen": kitchen,
    "living_room": living_room,
    "bathroom": bathroom,
    "floor": floor,
    "address": address,
    "commune": commune,
    "city": city,
    "postalCode": postalCode,
    "sold": sold == true ? 1 : 0,
    "transactionType": transactionType,
    "PropertyTypeId": PropertyTypeId,
    "UserId": UserId,
    "latitude": latitude,
    "isAvailable": isAvailable == true ? 1 : 0,
    "longitude": longitude,
    "PropertyFeatureId": propertyFeatureId,
    "PropertyImageId": propertyImageId,
    "user": user?.toJson(),
    "property_type": property_type?.toJson(),
    "features": features == null ? [] : List<dynamic>.from(features!.map((x) => x.toJson())),
    "images": images == null ? [] : List<dynamic>.from(images!.map((x) => x.toJson())),
    "favorites": favorites == null ? [] : List<dynamic>.from(favorites!.map((x) => x.toJson())),
    "visits": visits == null ? [] : List<dynamic>.from(visits!.map((x) => x.toJson())),
  };
  String toJsonString() {
    return jsonEncode(toJson());
  }

  factory PropertyModel.fromJsonString(String jsonString) {
    return PropertyModel.fromJson(jsonDecode(jsonString));
  }

  @override
  String toString() {
    return 'PropertyModel{\n'
        '  PropertyId: $PropertyId,\n'
        '  title: $title,\n'
        '  description: ${description != null ? description!.substring(0, description!.length < 20 ? description!.length : 20) + (description!.length > 20 ? "..." : "") : null},\n'
        '  price: $price,\n'
        '  surface: $surface,\n'
        '  rooms: $rooms,\n'
        '  bedrooms: $bedrooms,\n'
        '  kitchen": $kitchen,\n'
        '  living_room":  $living_room,\n'
        '  bathroom":  $bathroom,\n'
        '  floor: $floor,\n'
        '  address: $address,\n'
        '  commune: $commune,\n'
        '  city: $city,\n'
        '  postalCode: $postalCode,\n'
        '  sold: $sold,\n'
        '  transactionType: $transactionType,\n'
        '  PropertyTypeId: $PropertyTypeId,\n'
        '  UserId: $UserId,\n'
        '  latitude: $latitude,\n'
        '  isAvailable: $isAvailable,\n'
        '  longitude: $longitude,\n'
        '  propertyFeatureId: $propertyFeatureId,\n'
        '  propertyImageId: $propertyImageId,\n'
        '  user: ${user?.toString()},\n'
        '  property_type: ${property_type?.toString()},\n'
        '  features: ${features?.length} éléments,\n'
        '  images: ${images?.length} éléments,\n'
        '  favorites: ${favorites?.length} éléments,\n'
        '  visits: ${visits?.length} éléments\n'
        '}';
  }


}


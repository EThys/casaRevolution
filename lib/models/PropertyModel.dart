import 'dart:convert';
import 'CommuneModel.dart';
import 'PropertyTypeModel.dart';
import 'PropertyFeatureModel.dart';
import 'PropertyImageModel.dart';
import 'PropertyImageRoomModel.dart';
import 'PropertyImageLivingRoomModel.dart';
import 'PropertyImageKitchenModel.dart';

PropertyModel propertyModelFromJson(String str) => PropertyModel.fromJson(json.decode(str));
String propertyModelToJson(PropertyModel data) => json.encode(data.toJson());

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
  double? latitude;
  double? longitude;
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
    this.propertyType, // Ajout dans le constructeur
    this.userId,
    this.latitude,
    this.longitude,
    this.features,
    this.propertyImage,
    this.propertyImageRoom,
    this.propertyImageLivingRoom,
    this.propertyImageKitchen,
  });

  factory PropertyModel.fromJson(Map<String, dynamic> json) => PropertyModel(
    propertyId: json["propertyId"] ?? json["id"],
    title: json["title"],
    description: json["description"],
    price: json["price"] != null ? json["price"].toDouble() : 0.0,
    surface: json["surface"] != null ? json["surface"].toDouble() : 0.0,
    rooms: json["rooms"],
    bedrooms: json["bedrooms"],
    kitchen: json["kitchen"],
    livingRoom: json["livingRoom"],
    bathroom: json["bathroom"],
    floor: json["floor"],
    address: json["address"],
    cityId: json["cityId"],
    communeId: json["communeId"],
    postalCode: json["postalCode"],
    quartier: json["quartier"],
    sold: json["sold"] ?? false,
    transactionType: json["transactionType"],
    propertyTypeId: json["propertyTypeId"],
    propertyType: json["propertyType"] == null
        ? null
        : PropertyTypeModel.fromJson(json["propertyType"]), // Désérialisation du PropertyType
    userId: json["userId"],
    latitude: json["latitude"] != null ? json["latitude"].toDouble() : 0.0,
    longitude: json["longitude"] != null ? json["longitude"].toDouble() : 0.0,
    features: json["features"] == null
        ? []
        : List<PropertyFeatureModel>.from(json["features"]!.map((x) => PropertyFeatureModel.fromJson(x))),
    propertyImage: json["propertyImage"] == null
        ? []
        : List<PropertyImageModel>.from(json["propertyImage"]!.map((x) => PropertyImageModel.fromJson(x))),
    propertyImageRoom: json["propertyImageRoom"] == null
        ? []
        : List<PropertyImageRoomModel>.from(json["propertyImageRoom"]!.map((x) => PropertyImageRoomModel.fromJson(x))),
    propertyImageLivingRoom: json["propertyImageLivingRoom"] == null
        ? []
        : List<PropertyImageLivingRoomModel>.from(json["propertyImageLivingRoom"]!.map((x) => PropertyImageLivingRoomModel.fromJson(x))),
    propertyImageKitchen: json["propertyImageKitchen"] == null
        ? []
        : List<PropertyImageKitchenModel>.from(json["propertyImageKitchen"]!.map((x) => PropertyImageKitchenModel.fromJson(x))),
  );

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
    "propertyType": propertyType?.toJson(), // Sérialisation du PropertyType
    "userId": userId,
    "latitude": latitude,
    "longitude": longitude,
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
    return 'PropertyModel(propertyId: $propertyId, title: $title, price: $price, cityId: $cityId, propertyType: ${propertyType?.name})';
  }
}
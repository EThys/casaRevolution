// To parse this JSON data, do
//
//     final propertyFavorite = propertyFavoriteFromJson(jsonString);

import 'dart:convert';

import 'package:casa/models/PropertyModel.dart';
import 'package:casa/models/UserModel.dart';

PropertyFavoriteModel propertyFavoriteFromJson(String str) => PropertyFavoriteModel.fromJson(json.decode(str));

String propertyFavoriteToJson(PropertyFavoriteModel data) => json.encode(data.toJson());

class PropertyFavoriteModel {
  int? propertyFavoriteId;
  int? userId;
  int? propertyId;
  UserModel? user;
  PropertyModel? property;

  PropertyFavoriteModel({
    this.propertyFavoriteId,
    this.userId,
    this.propertyId,
    this.user,
    this.property,
  });

  factory PropertyFavoriteModel.fromJson(Map<String, dynamic> json) => PropertyFavoriteModel(
    propertyFavoriteId: json["PropertyFavoriteId"],
    userId: json["UserId"],
    propertyId: json["PropertyId"],
    user: json["user"] == null ? null : UserModel.fromJson(json["user"]),
    property: json["property"] == null ? null : PropertyModel.fromJson(json["property"]),
  );

  Map<String, dynamic> toJson() => {
    "PropertyFavoriteId": propertyFavoriteId,
    "UserId": userId,
    "PropertyId": propertyId,
    "user": user?.toJson(),
    "property": property?.toJson(),
  };
  String toJsonString() {
    return jsonEncode(toJson());
  }

  factory PropertyFavoriteModel.fromJsonString(String jsonString) {
    return PropertyFavoriteModel.fromJson(jsonDecode(jsonString));
  }
}
import 'dart:convert';

import 'PropertyModel.dart';
import 'UserModel.dart';

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
    propertyFavoriteId: json["favoriteId"] ?? json["PropertyFavoriteId"],
    userId: json["userId"] ?? json["UserId"],
    propertyId: json["propertyId"] ?? json["PropertyId"],
    user: json["user"] == null ? null : UserModel.fromJson(json["user"]),
    property: json["property"] == null ? null : PropertyModel.fromJson(json["property"]),
  );

  Map<String, dynamic> toJson() => {
    "favoriteId": propertyFavoriteId,
    "userId": userId,
    "propertyId": propertyId,
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
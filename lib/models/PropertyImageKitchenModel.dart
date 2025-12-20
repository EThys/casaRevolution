// To parse this JSON data, do
//
//     final propertyImageKitchenModel = propertyImageKitchenModelFromJson(jsonString);

import 'dart:convert';
import 'PropertyModel.dart';

PropertyImageKitchenModel propertyImageKitchenModelFromJson(String str) => PropertyImageKitchenModel.fromJson(json.decode(str));

String propertyImageKitchenModelToJson(PropertyImageKitchenModel data) => json.encode(data.toJson());

class PropertyImageKitchenModel {
  int? propertyImageId;
  PropertyModel? property;
  String? name;
  String? path;

  PropertyImageKitchenModel({
    this.propertyImageId,
    this.property,
    this.name,
    this.path,
  });

    factory PropertyImageKitchenModel.fromJson(Map<String, dynamic> json) => PropertyImageKitchenModel(
    propertyImageId: json["propertyImageId"],
    property: json["property"] == null ? null : PropertyModel.fromJson(json["property"]),
    name: json["name"],
    path: json["path"] ?? json["publicPath"],
  );

  Map<String, dynamic> toJson() => {
    "propertyImageId": propertyImageId,
    "property": property?.toJson(),
    "name": name,
    "path": path,
  };
}
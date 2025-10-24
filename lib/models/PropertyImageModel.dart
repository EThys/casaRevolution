// To parse this JSON data, do
//
//     final propertyImageModel = propertyImageModelFromJson(jsonString);

import 'dart:convert';
import 'PropertyModel.dart';

PropertyImageModel propertyImageModelFromJson(String str) => PropertyImageModel.fromJson(json.decode(str));

String propertyImageModelToJson(PropertyImageModel data) => json.encode(data.toJson());

class PropertyImageModel {
  int? propertyImageId;
  PropertyModel? property;
  String? name;
  String? path;

  PropertyImageModel({
    this.propertyImageId,
    this.property,
    this.name,
    this.path,
  });

  factory PropertyImageModel.fromJson(Map<String, dynamic> json) => PropertyImageModel(
    propertyImageId: json["propertyImageId"],
    property: json["property"] == null ? null : PropertyModel.fromJson(json["property"]),
    name: json["name"],
    path: json["path"],
  );

  Map<String, dynamic> toJson() => {
    "propertyImageId": propertyImageId,
    "property": property?.toJson(),
    "name": name,
    "path": path,
  };
}
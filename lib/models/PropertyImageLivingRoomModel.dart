// To parse this JSON data, do
//
//     final propertyImageLivingRoomModel = propertyImageLivingRoomModelFromJson(jsonString);

import 'dart:convert';
import 'PropertyModel.dart';

PropertyImageLivingRoomModel propertyImageLivingRoomModelFromJson(String str) => PropertyImageLivingRoomModel.fromJson(json.decode(str));

String propertyImageLivingRoomModelToJson(PropertyImageLivingRoomModel data) => json.encode(data.toJson());

class PropertyImageLivingRoomModel {
  int? propertyImageId;
  PropertyModel? property;
  String? name;
  String? path;

  PropertyImageLivingRoomModel({
    this.propertyImageId,
    this.property,
    this.name,
    this.path,
  });

  factory PropertyImageLivingRoomModel.fromJson(Map<String, dynamic> json) => PropertyImageLivingRoomModel(
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
// To parse this JSON data, do
//
//     final propertyImageRoomModel = propertyImageRoomModelFromJson(jsonString);

import 'dart:convert';
import 'PropertyModel.dart';

PropertyImageRoomModel propertyImageRoomModelFromJson(String str) => PropertyImageRoomModel.fromJson(json.decode(str));

String propertyImageRoomModelToJson(PropertyImageRoomModel data) => json.encode(data.toJson());

class PropertyImageRoomModel {
  int? propertyImageId;
  PropertyModel? property;
  String? name;
  String? path;

  PropertyImageRoomModel({
    this.propertyImageId,
    this.property,
    this.name,
    this.path,
  });

    factory PropertyImageRoomModel.fromJson(Map<String, dynamic> json) => PropertyImageRoomModel(
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
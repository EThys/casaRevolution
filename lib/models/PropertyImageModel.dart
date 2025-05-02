// To parse this JSON data, do
//
//     final propertyImage = propertyImageFromJson(jsonString);

import 'dart:convert';

PropertyImageModel propertyImageFromJson(String str) => PropertyImageModel.fromJson(json.decode(str));

String propertyImageToJson(PropertyImageModel data) => json.encode(data.toJson());

class PropertyImageModel {
  int? propertyId;
  String? path;
  bool? isMain;

  PropertyImageModel({
    this.propertyId,
    this.path,
    this.isMain,
  });

  factory PropertyImageModel.fromJson(Map<String, dynamic> json) => PropertyImageModel(
    propertyId: json["PropertyId"],
    path: json["path"],
    isMain: json["isMain"],
  );

  Map<String, dynamic> toJson() => {
    "PropertyId": propertyId,
    "path": path,
    "isMain": isMain,
  };
}
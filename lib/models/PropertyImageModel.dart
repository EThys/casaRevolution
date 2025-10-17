// To parse this JSON data, do
//
//     final propertyImage = propertyImageFromJson(jsonString);

import 'dart:convert';

import 'package:casa/utils/extensions/bool_int_converter.dart';

PropertyImageModel propertyImageFromJson(String str) => PropertyImageModel.fromJson(json.decode(str));

String propertyImageToJson(PropertyImageModel data) => json.encode(data.toJson());

class PropertyImageModel {
  int? PropertyId;
  bool? isMain;
  String? path;
  String? category; // Ajout du champ category

  PropertyImageModel({
    this.PropertyId,
    this.isMain,
    this.path,
    this.category

  });

  factory PropertyImageModel.fromJson(Map<String, dynamic> json) => PropertyImageModel(
    PropertyId: json["PropertyId"],
    isMain: json["isMain"] == 1 || json["isMain"] == true,
    path: json["path"],
    category: json["category"],
  );

  Map<String, dynamic> toJson() => {
    "PropertyId": PropertyId,
    "isMain": isMain == true ? 1 : 0,
    "path": path,
    "category": category,
  };
}
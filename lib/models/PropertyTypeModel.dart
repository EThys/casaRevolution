// To parse this JSON data, do
//
//     final propertyTypeModel = propertyTypeModelFromJson(jsonString);

import 'dart:convert';

PropertyTypeModel propertyTypeModelFromJson(String str) => PropertyTypeModel.fromJson(json.decode(str));

String propertyTypeModelToJson(PropertyTypeModel data) => json.encode(data.toJson());

class PropertyTypeModel {
  String? name;
  String? description;

  PropertyTypeModel({
    this.name,
    this.description,
  });

  factory PropertyTypeModel.fromJson(Map<String, dynamic> json) => PropertyTypeModel(
    name: json["name"],
    description: json["description"],
  );

  Map<String, dynamic> toJson() => {
    "name": name,
    "description": description,
  };
}

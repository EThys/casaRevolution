// To parse this JSON data, do
//
//     final propertyFeatureModel = propertyFeatureModelFromJson(jsonString);

import 'dart:convert';

PropertyFeatureModel propertyFeatureModelFromJson(String str) => PropertyFeatureModel.fromJson(json.decode(str));

String propertyFeatureModelToJson(PropertyFeatureModel data) => json.encode(data.toJson());

class PropertyFeatureModel {
  String? name;
  String? description;

  PropertyFeatureModel({
    this.name,
    this.description,
  });

  factory PropertyFeatureModel.fromJson(Map<String, dynamic> json) => PropertyFeatureModel(
    name: json["name"],
    description: json["description"],
  );

  Map<String, dynamic> toJson() => {
    "name": name,
    "description": description,
  };
}

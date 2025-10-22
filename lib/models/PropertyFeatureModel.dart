// To parse this JSON data, do
//
//     final propertyFeatureModel = propertyFeatureModelFromJson(jsonString);

import 'dart:convert';

PropertyFeatureModel propertyFeatureModelFromJson(String str) => PropertyFeatureModel.fromJson(json.decode(str));

String propertyFeatureModelToJson(PropertyFeatureModel data) => json.encode(data.toJson());

class PropertyFeatureModel {
  int? featureId;
  String? name;

  PropertyFeatureModel({
    this.featureId,
    this.name,
  });

  factory PropertyFeatureModel.fromJson(Map<String, dynamic> json) => PropertyFeatureModel(
    featureId: json["featureId"],
    name: json["name"],
  );

  Map<String, dynamic> toJson() => {
    "featureId": featureId,
    "name": name,
  };
}
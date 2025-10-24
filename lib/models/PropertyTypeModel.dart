// To parse this JSON data, do
//
//     final propertyTypeModel = propertyTypeModelFromJson(jsonString);

import 'dart:convert';

import 'package:casa/models/PropertyModel.dart';

PropertyTypeModel propertyTypeModelFromJson(String str) => PropertyTypeModel.fromJson(json.decode(str));

String propertyTypeModelToJson(PropertyTypeModel data) => json.encode(data.toJson());

class PropertyTypeModel {
  int? propertyTypeId;
  String? name;
  String? description;
  List<PropertyModel>? property;

  PropertyTypeModel({
    this.propertyTypeId,
    this.name,
    this.description,
    this.property,
  });

  factory PropertyTypeModel.fromJson(Map<String, dynamic> json) => PropertyTypeModel(
    propertyTypeId: json["propertyTypeId"],
    name: json["name"],
    description: json["description"],
    property: json["property"] == null ? [] : List<PropertyModel>.from(json["property"]!.map((x) => PropertyModel.fromJson(x))),
  );

  Map<String, dynamic> toJson() => {
    "propertyTypeId": propertyTypeId,
    "name": name,
    "description": description,
    "property": property == null ? [] : List<dynamic>.from(property!.map((x) => x.toJson())),
  };
}

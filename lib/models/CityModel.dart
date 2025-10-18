import 'dart:convert';

import 'CountryModel.dart';


CityModel cityModelFromJson(String str) => CityModel.fromJson(json.decode(str));
String cityModelToJson(CityModel data) => json.encode(data.toJson());

class CityModel {
  int? cityId;
  CountryModel? country;
  String? name;

  CityModel({
    this.cityId,
    this.country,
    this.name,
  });

  factory CityModel.fromJson(Map<String, dynamic> json) => CityModel(
    cityId: json["cityId"] ?? json["id"],
    country: json["country"] != null
        ? CountryModel.fromJson(json["country"])
        : null,
    name: json["name"] ?? json["cityName"],
  );

  Map<String, dynamic> toJson() => {
    "cityId": cityId,
    "country": country?.toJson(),
    "name": name,
  };

  @override
  String toString() {
    return name ?? '';
  }
}
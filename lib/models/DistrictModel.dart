import 'dart:convert';
import 'CityModel.dart';

DistrictModel districtModelFromJson(String str) => DistrictModel.fromJson(json.decode(str));
String districtModelToJson(DistrictModel data) => json.encode(data.toJson());

class DistrictModel {
  int? districtId;
  CityModel? city;
  String? name;

  DistrictModel({
    this.districtId,
    this.city,
    this.name,
  });

  factory DistrictModel.fromJson(Map<String, dynamic> json) => DistrictModel(
    districtId: json["districtId"] ?? json["id"],
    city: json["city"] == null
        ? null
        : CityModel.fromJson(json["city"]),
    name: json["name"] ?? json["districtName"],
  );

  Map<String, dynamic> toJson() => {
    "districtId": districtId,
    "city": city?.toJson(),
    "name": name,
  };

  @override
  String toString() {
    return name ?? '';
  }
}
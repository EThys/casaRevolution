import 'dart:convert';
import 'DistrictModel.dart';

CommuneModel communeModelFromJson(String str) => CommuneModel.fromJson(json.decode(str));
String communeModelToJson(CommuneModel data) => json.encode(data.toJson());

class CommuneModel {
  int? communeId;
  DistrictModel? district;
  String? name;

  CommuneModel({
    this.communeId,
    this.district,
    this.name,
  });

  factory CommuneModel.fromJson(Map<String, dynamic> json) => CommuneModel(
    communeId: json["communeId"] ?? json["id"],
    district: json["district"] == null
        ? null
        : json["district"] is int
            ? DistrictModel(districtId: json["district"])
            : DistrictModel.fromJson(json["district"]),
    name: json["name"] ?? json["communeName"],
  );

  Map<String, dynamic> toJson() => {
    "communeId": communeId,
    "district": district?.toJson(),
    "name": name,
  };

  @override
  String toString() {
    return name ?? '';
  }
}
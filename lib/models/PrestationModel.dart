import 'dart:convert';

PrestationModel prestationModelFromJson(String str) => PrestationModel.fromJson(json.decode(str));
String prestationModelToJson(PrestationModel data) => json.encode(data.toJson());

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  if (value is double) return value.toInt();
  return null;
}

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

bool _parseBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is String) return value.toLowerCase() == 'true';
  if (value is int) return value == 1;
  return false;
}

class PrestationModel {
  int? id;
  int? userId;
  int? serviceId;
  int? deviseId;
  String? title;
  String? description;
  String? experience;
  String? plageJourPrestation;
  String? plageHeurePrestation;
  double? minPrice;
  double? maxPrice;
  String? address;
  String? communeValue;
  String? quartierValue;
  String? cityValue;
  String? countryValue;
  int? cityId;
  int? communeId;
  int? quartierId;
  bool? isCertified;
  bool? isActive;
  DateTime? dateCreated;

  PrestationModel({
    this.id,
    this.userId,
    this.serviceId,
    this.deviseId,
    this.title,
    this.description,
    this.experience,
    this.plageJourPrestation,
    this.plageHeurePrestation,
    this.minPrice,
    this.maxPrice,
    this.address,
    this.communeValue,
    this.quartierValue,
    this.cityValue,
    this.countryValue,
    this.cityId,
    this.communeId,
    this.quartierId,
    this.isCertified,
    this.isActive,
    this.dateCreated,
  });

  factory PrestationModel.fromJson(Map<String, dynamic> json) => PrestationModel(
    id: _parseInt(json["id"]),
    userId: _parseInt(json["userId"]),
    serviceId: _parseInt(json["serviceId"]),
    deviseId: _parseInt(json["deviseId"]),
    title: json["title"] ?? "",
    description: json["description"] ?? "",
    experience: json["experience"] ?? "",
    plageJourPrestation: json["plageJourPrestation"] ?? "",
    plageHeurePrestation: json["plageHeurePrestation"] ?? "",
    minPrice: _parseDouble(json["minPrice"]) ?? 0.0,
    maxPrice: _parseDouble(json["maxPrice"]) ?? 0.0,
    address: json["address"],
    communeValue: json["communeValue"] ?? "",
    quartierValue: json["quartierValue"] ?? "",
    cityValue: json["cityValue"] ?? "",
    countryValue: json["countryValue"] ?? "",
    cityId: _parseInt(json["cityId"]),
    communeId: _parseInt(json["communeId"]),
    quartierId: _parseInt(json["quartierId"]),
    isCertified: json["isCertified"] == null ? true : _parseBool(json["isCertified"]),
    isActive: json["isActive"] == null ? true : _parseBool(json["isActive"]),
    dateCreated: json["dateCreated"] != null ? DateTime.tryParse(json["dateCreated"]) : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "userId": userId,
    "serviceId": serviceId,
    "deviseId": deviseId,
    "title": title,
    "description": description,
    "experience": experience,
    "plageJourPrestation": plageJourPrestation,
    "plageHeurePrestation": plageHeurePrestation,
    "minPrice": minPrice,
    "maxPrice": maxPrice,
    "address": address,
    "communeValue": communeValue,
    "quartierValue": quartierValue,
    "cityValue": cityValue,
    "countryValue": countryValue,
    "cityId": cityId,
    "communeId": communeId,
    "quartierId": quartierId,
    "isCertified": isCertified,
    "isActive": isActive,
    "dateCreated": dateCreated?.toIso8601String(),
  };
}

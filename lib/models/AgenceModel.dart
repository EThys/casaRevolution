import 'dart:convert';

AgenceModel agenceModelFromJson(String str) => AgenceModel.fromJson(json.decode(str));
String agenceModelToJson(AgenceModel data) => json.encode(data.toJson());

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  if (value is double) return value.toInt();
  return null;
}

class AgenceModel {
  int? id;
  int? userId;
  String? name;
  String? description;
  String? phone1;
  String? phone2;
  String? address;
  String? logo;

  AgenceModel({
    this.id,
    this.userId,
    this.name,
    this.description,
    this.phone1,
    this.phone2,
    this.address,
    this.logo,
  });

  factory AgenceModel.fromJson(Map<String, dynamic> json) => AgenceModel(
    id: _parseInt(json["id"]),
    userId: _parseInt(json["userId"]),
    name: json["name"],
    description: json["description"] ?? "",
    phone1: json["phone1"] ?? "",
    phone2: json["phone2"] ?? "",
    address: json["address"] ?? "",
    logo: json["logo"] ?? "",
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "userId": userId,
    "name": name,
    "description": description,
    "phone1": phone1,
    "phone2": phone2,
    "address": address,
    "logo": logo,
  };
}

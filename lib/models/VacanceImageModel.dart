import 'dart:convert';

VacanceImageModel vacanceImageModelFromJson(String str) => VacanceImageModel.fromJson(json.decode(str));
String vacanceImageModelToJson(VacanceImageModel data) => json.encode(data.toJson());

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  if (value is double) return value.toInt();
  return null;
}

bool _parseBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is String) return value.toLowerCase() == 'true';
  if (value is int) return value == 1;
  return false;
}

class VacanceImageModel {
  int? id;
  int? vacanceId;
  String? name;
  String? path;
  bool? isAvailable;
  DateTime? createdAt;

  VacanceImageModel({
    this.id,
    this.vacanceId,
    this.name,
    this.path,
    this.isAvailable,
    this.createdAt,
  });

  factory VacanceImageModel.fromJson(Map<String, dynamic> json) => VacanceImageModel(
    id: _parseInt(json["id"]),
    vacanceId: _parseInt(json["vacanceId"]),
    name: json["name"] ?? "",
    path: json["path"] ?? "",
    isAvailable: json["isAvailable"] == null ? true : _parseBool(json["isAvailable"]),
    createdAt: json["createdAt"] != null ? DateTime.tryParse(json["createdAt"]) : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "vacanceId": vacanceId,
    "name": name,
    "path": path,
    "isAvailable": isAvailable,
    "createdAt": createdAt?.toIso8601String(),
  };
}

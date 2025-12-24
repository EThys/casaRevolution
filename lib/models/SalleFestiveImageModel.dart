import 'dart:convert';

SalleFestiveImageModel salleFestiveImageModelFromJson(String str) => SalleFestiveImageModel.fromJson(json.decode(str));
String salleFestiveImageModelToJson(SalleFestiveImageModel data) => json.encode(data.toJson());

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

class SalleFestiveImageModel {
  int? id;
  int? salleFestiveId;
  String? name;
  String? path;
  bool? isAvailable;
  DateTime? createdAt;

  SalleFestiveImageModel({
    this.id,
    this.salleFestiveId,
    this.name,
    this.path,
    this.isAvailable,
    this.createdAt,
  });

  factory SalleFestiveImageModel.fromJson(Map<String, dynamic> json) => SalleFestiveImageModel(
    id: _parseInt(json["id"]),
    salleFestiveId: _parseInt(json["salleFestiveId"]),
    name: json["name"],
    path: json["path"],
    isAvailable: _parseBool(json["isAvailable"]) || json["isAvailable"] == null ? true : _parseBool(json["isAvailable"]), // Default to true if null as per image
    createdAt: json["createdAt"] != null ? DateTime.tryParse(json["createdAt"]) : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "salleFestiveId": salleFestiveId,
    "name": name,
    "path": path,
    "isAvailable": isAvailable,
    "createdAt": createdAt?.toIso8601String(),
  };
}

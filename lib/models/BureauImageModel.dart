import 'dart:convert';

BureauImageModel bureauImageModelFromJson(String str) => BureauImageModel.fromJson(json.decode(str));
String bureauImageModelToJson(BureauImageModel data) => json.encode(data.toJson());

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

class BureauImageModel {
  int? id;
  int? bureauId;
  String? name;
  String? path;
  bool? isAvailable;
  DateTime? createdAt;

  BureauImageModel({
    this.id,
    this.bureauId,
    this.name,
    this.path,
    this.isAvailable,
    this.createdAt,
  });

  factory BureauImageModel.fromJson(Map<String, dynamic> json) => BureauImageModel(
    id: _parseInt(json["id"]),
    bureauId: _parseInt(json["bureauId"]),
    name: json["name"] ?? "",
    path: json["path"] ?? "",
    isAvailable: _parseBool(json["isAvailable"]) || json["isAvailable"] == null ? true : _parseBool(json["isAvailable"]),
    createdAt: json["createdAt"] != null ? DateTime.tryParse(json["createdAt"]) : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "bureauId": bureauId,
    "name": name,
    "path": path,
    "isAvailable": isAvailable,
    "createdAt": createdAt?.toIso8601String(),
  };
}

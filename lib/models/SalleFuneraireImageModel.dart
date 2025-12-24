import 'dart:convert';

SalleFuneraireImageModel salleFuneraireImageModelFromJson(String str) => SalleFuneraireImageModel.fromJson(json.decode(str));
String salleFuneraireImageModelToJson(SalleFuneraireImageModel data) => json.encode(data.toJson());

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

class SalleFuneraireImageModel {
  int? id;
  int? salleFuneraireId;
  String? name;
  String? path;
  bool? isAvailable;
  DateTime? createdAt;

  SalleFuneraireImageModel({
    this.id,
    this.salleFuneraireId,
    this.name,
    this.path,
    this.isAvailable,
    this.createdAt,
  });

  factory SalleFuneraireImageModel.fromJson(Map<String, dynamic> json) => SalleFuneraireImageModel(
    id: _parseInt(json["id"]),
    salleFuneraireId: _parseInt(json["salleFuneraireId"]),
    name: json["name"],
    path: json["path"],
    isAvailable: _parseBool(json["isAvailable"]) || json["isAvailable"] == null ? true : _parseBool(json["isAvailable"]),
    createdAt: json["createdAt"] != null ? DateTime.tryParse(json["createdAt"]) : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "salleFuneraireId": salleFuneraireId,
    "name": name,
    "path": path,
    "isAvailable": isAvailable,
    "createdAt": createdAt?.toIso8601String(),
  };
}

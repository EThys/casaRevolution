import 'dart:convert';

HotelChambreImageModel hotelChambreImageModelFromJson(String str) => HotelChambreImageModel.fromJson(json.decode(str));
String hotelChambreImageModelToJson(HotelChambreImageModel data) => json.encode(data.toJson());

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

class HotelChambreImageModel {
  int? id;
  int? hotelChambreId;
  String? name;
  String? path;
  bool? isAvailable;
  DateTime? createdAt;

  HotelChambreImageModel({
    this.id,
    this.hotelChambreId,
    this.name,
    this.path,
    this.isAvailable,
    this.createdAt,
  });

  factory HotelChambreImageModel.fromJson(Map<String, dynamic> json) => HotelChambreImageModel(
    id: _parseInt(json["id"]),
    hotelChambreId: _parseInt(json["hotelChambreId"]),
    name: json["name"],
    path: json["path"],
    isAvailable: json["isAvailable"] == null ? true : _parseBool(json["isAvailable"]),
    createdAt: json["createdAt"] != null ? DateTime.tryParse(json["createdAt"]) : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "hotelChambreId": hotelChambreId,
    "name": name,
    "path": path,
    "isAvailable": isAvailable,
    "createdAt": createdAt?.toIso8601String(),
  };
}

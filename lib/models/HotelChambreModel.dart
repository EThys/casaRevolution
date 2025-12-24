import 'dart:convert';

HotelChambreModel hotelChambreModelFromJson(String str) => HotelChambreModel.fromJson(json.decode(str));
String hotelChambreModelToJson(HotelChambreModel data) => json.encode(data.toJson());

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

class HotelChambreModel {
  int? id;
  int? hotelId;
  String? title;
  String? description;
  int? numberPiece;
  double? price;
  String? priceHeure;
  bool? isAvailable;
  DateTime? createdAt;
  DateTime? updatedAt;

  HotelChambreModel({
    this.id,
    this.hotelId,
    this.title,
    this.description,
    this.numberPiece,
    this.price,
    this.priceHeure,
    this.isAvailable,
    this.createdAt,
    this.updatedAt,
  });

  factory HotelChambreModel.fromJson(Map<String, dynamic> json) => HotelChambreModel(
    id: _parseInt(json["id"]),
    hotelId: _parseInt(json["hotelId"]),
    title: json["title"],
    description: json["description"] ?? "",
    numberPiece: _parseInt(json["numberPiece"]),
    price: _parseDouble(json["price"]),
    priceHeure: json["priceHeure"] ?? "",
    isAvailable: json["isAvailable"] == null ? true : _parseBool(json["isAvailable"]),
    createdAt: json["createdAt"] != null ? DateTime.tryParse(json["createdAt"]) : DateTime.now(),
    updatedAt: json["updatedAt"] != null ? DateTime.tryParse(json["updatedAt"]) : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "hotelId": hotelId,
    "title": title,
    "description": description,
    "numberPiece": numberPiece,
    "price": price,
    "priceHeure": priceHeure,
    "isAvailable": isAvailable,
    "createdAt": createdAt?.toIso8601String(),
    "updatedAt": updatedAt?.toIso8601String(),
  };
}

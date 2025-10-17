import 'dart:convert';

import 'PropertyModel.dart';

enum ReservationStatus { pending, completed, cancelled }

ReservationModel reservationModelFromJson(String str) => ReservationModel.fromJson(json.decode(str));

String reservationModelToJson(ReservationModel data) => json.encode(data.toJson());

class ReservationModel {
  String? id;
  String? propertyId;
  List<PropertyModel>? property;
  String? propertyTitle;
  List<String>? propertyImages;
  String? address;
  DateTime? date;
  double? price;
  ReservationStatus? status;
  String? cancellationReason;
  int? bedrooms;
  int? bathrooms;
  int? area;
  int? floor;
  List<String>? amenities;
  String? description;
  String? agentName;
  String? agentContact;

  ReservationModel({
    this.id,
    this.propertyId,
    this.property,
    this.propertyTitle,
    this.propertyImages,
    this.address,
    this.date,
    this.price,
    this.status,
    this.cancellationReason,
    this.bedrooms,
    this.bathrooms,
    this.area,
    this.floor,
    this.amenities,
    this.description,
    this.agentName,
    this.agentContact,
  });

  factory ReservationModel.fromJson(Map<String, dynamic> json) => ReservationModel(
    id: json["id"],
    propertyId: json["propertyId"],
    property: json["property"] == null
        ? []
        : List<PropertyModel>.from(json["property"]!.map((x) => PropertyModel.fromJson(x))),
    propertyTitle: json["propertyTitle"],
    propertyImages: json["propertyImages"] == null
        ? []
        : List<String>.from(json["propertyImages"]!.map((x) => x)),
    address: json["address"],
    date: json["date"] == null ? null : DateTime.parse(json["date"]),
    price: json["price"]?.toDouble(),
    status: json["status"] == null
        ? null
        : ReservationStatus.values.firstWhere(
          (e) => e.toString().split('.').last == json["status"],
      orElse: () => ReservationStatus.pending,
    ),
    cancellationReason: json["cancellationReason"],
    bedrooms: json["bedrooms"],
    bathrooms: json["bathrooms"],
    area: json["area"],
    floor: json["floor"],
    amenities: json["amenities"] == null
        ? []
        : List<String>.from(json["amenities"]!.map((x) => x)),
    description: json["description"],
    agentName: json["agentName"],
    agentContact: json["agentContact"],
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "propertyId": propertyId,
    "property": property == null
        ? []
        : List<dynamic>.from(property!.map((x) => x.toJson())),
    "propertyTitle": propertyTitle,
    "propertyImages": propertyImages == null
        ? []
        : List<dynamic>.from(propertyImages!.map((x) => x)),
    "address": address,
    "date": date?.toIso8601String(),
    "price": price,
    "status": status?.toString().split('.').last,
    "cancellationReason": cancellationReason,
    "bedrooms": bedrooms,
    "bathrooms": bathrooms,
    "area": area,
    "floor": floor,
    "amenities": amenities == null
        ? []
        : List<dynamic>.from(amenities!.map((x) => x)),
    "description": description,
    "agentName": agentName,
    "agentContact": agentContact,
  };
}
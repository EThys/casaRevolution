import 'dart:convert';
import 'TypeCardModel.dart';
import 'UserModel.dart';

CarreleurModel carreleurModelFromJson(String str) => CarreleurModel.fromJson(json.decode(str));
String carreleurModelToJson(CarreleurModel data) => json.encode(data.toJson());

class CarreleurModel {
  int? carreleurId;
  String? firstName;
  String? lastName;
  String? fullName;
  String? address;
  dynamic images;
  dynamic cardFront;
  dynamic cardBack;
  UserModel? user;
  TypeCardModel? typeCard;
  String? numberCard;

  CarreleurModel({
    this.carreleurId,
    this.firstName,
    this.lastName,
    this.fullName,
    this.address,
    this.images,
    this.cardFront,
    this.cardBack,
    this.user,
    this.typeCard,
    this.numberCard,
  });

  factory CarreleurModel.fromJson(Map<String, dynamic> json) => CarreleurModel(
    carreleurId: json["carreleurId"] ?? json["id"],
    firstName: json["firstName"] ?? json["prenom"],
    lastName: json["lastName"] ?? json["nom"],
    fullName: json["fullName"] ?? json["nomComplet"],
    address: json["address"] ?? json["adresse"],
    images: json["images"],
    cardFront: json["cardFront"],
    cardBack: json["cardBack"],
    user: json["user"] == null
        ? null
        : UserModel.fromJson(json["user"]),
    typeCard: json["typeCard"] == null
        ? null
        : TypeCardModel.fromJson(json["typeCard"]),
    numberCard: json["numberCard"] ?? json["numeroCarte"],
  );

  Map<String, dynamic> toJson() => {
    "carreleurId": carreleurId,
    "firstName": firstName,
    "lastName": lastName,
    "fullName": fullName,
    "address": address,
    "images": images,
    "cardFront": cardFront,
    "cardBack": cardBack,
    "user": user?.toJson(),
    "typeCard": typeCard?.toJson(),
    "numberCard": numberCard,
  };
}


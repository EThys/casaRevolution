import 'dart:convert';
import 'TypeCardModel.dart';
import 'UserModel.dart';

ElectricienModel electricienModelFromJson(String str) => ElectricienModel.fromJson(json.decode(str));
String electricienModelToJson(ElectricienModel data) => json.encode(data.toJson());

class ElectricienModel {
  int? electricienId;
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

  ElectricienModel({
    this.electricienId,
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

  factory ElectricienModel.fromJson(Map<String, dynamic> json) => ElectricienModel(
    electricienId: json["electricienId"] ?? json["id"],
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
    "electricienId": electricienId,
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




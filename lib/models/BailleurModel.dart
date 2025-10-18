import 'dart:convert';
import 'TypeCardModel.dart';
import 'UserModel.dart';

BailleurModel bailleurModelFromJson(String str) => BailleurModel.fromJson(json.decode(str));
String bailleurModelToJson(BailleurModel data) => json.encode(data.toJson());

class BailleurModel {
  int? bailleurId;
  String? firstName;
  String? lastName;
  String? fullName;
  String? address;
  dynamic images;
  dynamic cardFront;
  dynamic cardBack;
  dynamic parrain;
  UserModel? user;
  TypeCardModel? typeCard;
  String? numberCard;
  String? note;

  BailleurModel({
    this.bailleurId,
    this.firstName,
    this.lastName,
    this.fullName,
    this.address,
    this.images,
    this.cardFront,
    this.cardBack,
    this.parrain,
    this.user,
    this.typeCard,
    this.numberCard,
    this.note,
  });

  factory BailleurModel.fromJson(Map<String, dynamic> json) => BailleurModel(
    bailleurId: json["bailleurId"] ?? json["id"],
    firstName: json["firstName"] ?? json["prenom"],
    lastName: json["lastName"] ?? json["nom"],
    fullName: json["fullName"] ?? json["nomComplet"],
    address: json["address"] ?? json["adresse"],
    images: json["images"],
    cardFront: json["cardFront"],
    cardBack: json["cardBack"],
    parrain: json["parrain"],
    user: json["user"] == null
        ? null
        : UserModel.fromJson(json["user"]),
    typeCard: json["typeCard"] == null
        ? null
        : TypeCardModel.fromJson(json["typeCard"]),
    numberCard: json["numberCard"] ?? json["numeroCarte"],
    note: json["note"],
  );

  Map<String, dynamic> toJson() => {
    "bailleurId": bailleurId,
    "firstName": firstName,
    "lastName": lastName,
    "fullName": fullName,
    "address": address,
    "images": images,
    "cardFront": cardFront,
    "cardBack": cardBack,
    "parrain": parrain,
    "user": user?.toJson(),
    "typeCard": typeCard?.toJson(),
    "numberCard": numberCard,
    "note": note,
  };
}
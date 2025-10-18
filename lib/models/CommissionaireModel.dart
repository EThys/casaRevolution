import 'dart:convert';
import 'TypeCardModel.dart';
import 'UserModel.dart';

CommissionnaireModel commissionnaireModelFromJson(String str) => CommissionnaireModel.fromJson(json.decode(str));
String commissionnaireModelToJson(CommissionnaireModel data) => json.encode(data.toJson());

class CommissionnaireModel {
  int? commissionnaireId;
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

  CommissionnaireModel({
    this.commissionnaireId,
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
  });

  factory CommissionnaireModel.fromJson(Map<String, dynamic> json) => CommissionnaireModel(
    commissionnaireId: json["commissionnaireId"] ?? json["id"],
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
  );

  Map<String, dynamic> toJson() => {
    "commissionnaireId": commissionnaireId,
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
  };
}
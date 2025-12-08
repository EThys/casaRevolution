import 'dart:convert';
import 'TypeCardModel.dart';
import 'UserModel.dart';

MajordomeModel majordomeModelFromJson(String str) => MajordomeModel.fromJson(json.decode(str));
String majordomeModelToJson(MajordomeModel data) => json.encode(data.toJson());

class MajordomeModel {
  int? majordomeId;
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

  MajordomeModel({
    this.majordomeId,
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

  factory MajordomeModel.fromJson(Map<String, dynamic> json) => MajordomeModel(
    majordomeId: json["majordomeId"] ?? json["majordhommeId"] ?? json["id"],
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
    "majordomeId": majordomeId,
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




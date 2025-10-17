import 'dart:convert';
import 'package:casa/models/PropertyImageModel.dart';

BailleurModel bailleurModelFromJson(String str) => BailleurModel.fromJson(json.decode(str));
String bailleurModelToJson(BailleurModel data) => json.encode(data.toJson());

class BailleurModel {
  String? prenom;
  String? nom;
  String? nomComplet;
  String? telephone;
  String? email;
  String? adresse;
  List<PropertyImageModel>? images;
  int? parrainId;
  int? bailleurId;
  int? typeCarteId;
  String? numeroCarte;
  String? note;

  BailleurModel({
    this.prenom,
    this.nom,
    this.nomComplet,
    this.telephone,
    this.email,
    this.adresse,
    this.images,
    this.parrainId,
    this.bailleurId,
    this.typeCarteId,
    this.numeroCarte,
    this.note,
  });

  factory BailleurModel.fromJson(Map<String, dynamic> json) => BailleurModel(
    prenom: json["prenom"] ?? json["first_name"],
    nom: json["nom"] ?? json["last_name"],
    nomComplet: json["nom_complet"] ?? json["fullname"],
    telephone: json["telephone"] ?? json["phone"],
    email: json["email"],
    adresse: json["adresse"] ?? json["address"],
    images: json["images"] == null
        ? null
        : List<PropertyImageModel>.from(
        json["images"].map((x) => PropertyImageModel.fromJson(x))),
    parrainId: json["parrainId"] ?? json["ParrainId"],
    bailleurId: json["bailleurId"] ?? json["UserId"],
    typeCarteId: json["typeCarteId"] ?? json["TypeCardId"],
    numeroCarte: json["numeroCarte"] ?? json["number_card"],
    note: json["note"],
  );

  Map<String, dynamic> toJson() => {
    "prenom": prenom,
    "nom": nom,
    "nom_complet": nomComplet,
    "telephone": telephone,
    "email": email,
    "adresse": adresse,
    "images": images == null
        ? null
        : List<dynamic>.from(images!.map((x) => x.toJson())),
    "parrainId": parrainId,
    "bailleurId": bailleurId,
    "typeCarteId": typeCarteId,
    "numeroCarte": numeroCarte,
    "note": note,
  };
}

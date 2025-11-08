import 'dart:convert';

TypeCardModel typeCardModelFromJson(String str) => TypeCardModel.fromJson(json.decode(str));
String typeCardModelToJson(TypeCardModel data) => json.encode(data.toJson());

class TypeCardModel {
  int? typeCardId;
  String? name;

  TypeCardModel({
    this.typeCardId,
    this.name,
  });

  factory TypeCardModel.fromJson(Map<String, dynamic> json) => TypeCardModel(
    typeCardId: json["typeCardId"] ?? json["id"],
    name: json["name"] ?? json["cardName"],
  );

  Map<String, dynamic> toJson() => {
    "typeCardId": typeCardId,
    "name": name,
  };

  @override
  String toString() {
    return name ?? '';
  }
}
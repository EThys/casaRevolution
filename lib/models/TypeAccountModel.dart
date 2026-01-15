import 'dart:convert';

TypeAccountModel typeAccountModelFromJson(String str) => TypeAccountModel.fromJson(json.decode(str));
String typeAccountModelToJson(TypeAccountModel data) => json.encode(data.toJson());

class TypeAccountModel {
  int? typeAccountId;
  String? name;
  int? categoryId; // Nouveau champ pour stocker la catégorie parent (1, 2, ou 3)

  TypeAccountModel({
    this.typeAccountId,
    this.name,
    this.categoryId,
  });

  factory TypeAccountModel.fromJson(Map<String, dynamic> json) => TypeAccountModel(
    typeAccountId: json["typeAccountId"],
    name: json["name"],
    categoryId: json["categoryId"],
  );

  Map<String, dynamic> toJson() => {
    "typeAccountId": typeAccountId,
    "name": name,
    "categoryId": categoryId,
  };

  @override
  String toString() {
    return name ?? '';
  }
}
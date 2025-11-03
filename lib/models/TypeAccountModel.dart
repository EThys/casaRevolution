import 'dart:convert';

TypeAccountModel typeAccountModelFromJson(String str) => TypeAccountModel.fromJson(json.decode(str));
String typeAccountModelToJson(TypeAccountModel data) => json.encode(data.toJson());

class TypeAccountModel {
  int? typeAccountId;
  String? name;

  TypeAccountModel({
    this.typeAccountId,
    this.name,
  });

  factory TypeAccountModel.fromJson(Map<String, dynamic> json) => TypeAccountModel(
    typeAccountId: json["typeAccountId"] ?? json["id"],
    name: json["name"] ?? json["typeName"],
  );

  Map<String, dynamic> toJson() => {
    "typeAccountId": typeAccountId,
    "name": name,
  };

  @override
  String toString() {
    return name ?? '';
  }
}
import 'dart:convert';
import 'CityModel.dart';
import 'TypeAccountModel.dart';

UserModel userModelFromJson(String str) => UserModel.fromJson(json.decode(str));
String userModelToJson(UserModel data) => json.encode(data.toJson());

class UserModel {
  int? userId;
  String? password;
  TypeAccountModel? typeAccount;
  String? email;
  String? phone;
  CityModel? city;
  String? createdStart;

  UserModel({
    this.userId,
    this.password,
    this.typeAccount,
    this.email,
    this.phone,
    this.city,
    this.createdStart,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    userId: json["userId"] ?? json["id"],
    password: json["password"],
    typeAccount: json["typeAccount"] == null
        ? null
        : TypeAccountModel.fromJson(json["typeAccount"]),
    email: json["email"],
    phone: json["phone"] ?? json["telephone"],
    city: json["city"] == null
        ? null
        : CityModel.fromJson(json["city"]),
    createdStart: json["createdStart"] ?? json["createdAt"],
  );

  Map<String, dynamic> toJson() => {
    "userId": userId,
    "password": password,
    "typeAccount": typeAccount?.toJson(),
    "email": email,
    "phone": phone,
    "city": city?.toJson(),
    "createdStart": createdStart,
  };
}
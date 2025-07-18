import 'dart:convert';
import 'package:casa/models/PropertyImageModel.dart';

UserModel userModelFromJson(String str) => UserModel.fromJson(json.decode(str));
String userModelToJson(UserModel data) => json.encode(data.toJson());

class UserModel {
  int? typeAccountId;
  String? username;
  String? firstName;
  String? lastName;
  String? fullname;
  String? email;
  String? phone;
  String? address;
  String? city;
  int? cityId;
  String? postalCode;
  String? country;
  DateTime? dateOfBirth;
  String? gender;
  String? profilePicture;
  String? bio;
  bool? isAgent;
  bool? isAdmin;
  DateTime? emailVerifiedAt;
  String? password;
  DateTime? lastLoginAt;
  String? lastLoginIp;
  List<PropertyImageModel>? images;
  int? parrainId;
  int? userId;
  int? typeCardId;
  String? numberCard;
  String? note;

  UserModel({
    this.typeAccountId,
    this.username,
    this.firstName,
    this.lastName,
    this.fullname,
    this.email,
    this.phone,
    this.address,
    this.city,
    this.cityId,
    this.postalCode,
    this.country,
    this.dateOfBirth,
    this.gender,
    this.profilePicture,
    this.bio,
    this.isAgent,
    this.isAdmin,
    this.emailVerifiedAt,
    this.password,
    this.lastLoginAt,
    this.lastLoginIp,
    this.images,
    this.parrainId,
    this.userId,
    this.typeCardId,
    this.numberCard,
    this.note,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    typeAccountId: json["TypeAccountId"],
    username: json["username"],
    firstName: json["first_name"],
    lastName: json["last_name"],
    fullname: json["fullname"],
    email: json["email"],
    phone: json["phone"],
    address: json["address"],
    city: json["city"],
    cityId: json["CityId"],
    postalCode: json["postal_code"],
    country: json["country"],
    dateOfBirth: json["date_of_birth"] == null
        ? null
        : DateTime.parse(json["date_of_birth"]),
    gender: json["gender"],
    profilePicture: json["profile_picture"],
    bio: json["bio"],
    isAgent: json["is_agent"],
    isAdmin: json["is_admin"],
    emailVerifiedAt: json["email_verified_at"] == null
        ? null
        : DateTime.parse(json["email_verified_at"]),
    password: json["password"],
    lastLoginAt: json["last_login_at"] == null
        ? null
        : DateTime.parse(json["last_login_at"]),
    lastLoginIp: json["last_login_ip"],
    images: json["images"] == null
        ? null
        : List<PropertyImageModel>.from(
        json["images"].map((x) => PropertyImageModel.fromJson(x))),
    parrainId: json["ParrainId"],
    userId: json["UserId"],
    typeCardId: json["TypeCardId"],
    numberCard: json["number_card"],
    note: json["note"],
  );

  Map<String, dynamic> toJson() => {
    "TypeAccountId": typeAccountId,
    "username": username,
    "first_name": firstName,
    "last_name": lastName,
    "fullname": fullname,
    "email": email,
    "phone": phone,
    "address": address,
    "city": city,
    "CityId": cityId,
    "postal_code": postalCode,
    "country": country,
    "date_of_birth": dateOfBirth == null
        ? null
        : "${dateOfBirth!.year.toString().padLeft(4, '0')}-${dateOfBirth!.month.toString().padLeft(2, '0')}-${dateOfBirth!.day.toString().padLeft(2, '0')}",
    "gender": gender,
    "profile_picture": profilePicture,
    "bio": bio,
    "is_agent": isAgent,
    "is_admin": isAdmin,
    "email_verified_at": emailVerifiedAt?.toIso8601String(),
    "password": password,
    "last_login_at": lastLoginAt?.toIso8601String(),
    "last_login_ip": lastLoginIp,
    "images": images == null
        ? null
        : List<dynamic>.from(images!.map((x) => x.toJson())),
    "ParrainId": parrainId,
    "UserId": userId,
    "TypeCardId": typeCardId,
    "number_card": numberCard,
    "note": note,
  };
}
import 'dart:convert';
import 'UserModel.dart';
import 'PrestationModel.dart';

SollicitationModel sollicitationModelFromJson(String str) => SollicitationModel.fromJson(json.decode(str));
String sollicitationModelToJson(SollicitationModel data) => json.encode(data.toJson());

class SollicitationModel {
  int? id;
  int? userId;
  int? prestationId;
  int? deviseId;
  double? budget;
  String? description;
  String? status;
  String? startDate;
  String? endDate;
  String? createdAt;
  UserModel? user;
  PrestationModel? prestation;

  SollicitationModel({
    this.id,
    this.userId,
    this.prestationId,
    this.deviseId,
    this.budget,
    this.description,
    this.status,
    this.startDate,
    this.endDate,
    this.createdAt,
    this.user,
    this.prestation,
  });

  factory SollicitationModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? sollicitationData;
    
    // Gérer la structure imbriquée : {"sollicitation": {...}, "user": {...}, ...}
    if (json.containsKey("sollicitation") && json["sollicitation"] is Map) {
      sollicitationData = json["sollicitation"] as Map<String, dynamic>;
    } else {
      sollicitationData = json;
    }

    return SollicitationModel(
      id: sollicitationData?["id"],
      userId: sollicitationData?["userId"],
      prestationId: sollicitationData?["prestationId"],
      deviseId: sollicitationData?["deviseId"],
      budget: (sollicitationData?["budget"] as num?)?.toDouble(),
      description: sollicitationData?["description"],
      status: sollicitationData?["status"],
      startDate: sollicitationData?["startDate"],
      endDate: sollicitationData?["endDate"],
      createdAt: sollicitationData?["createdAt"],
      user: json["user"] == null ? null : UserModel.fromJson(json["user"]),
      prestation: json["prestation"] == null ? null : PrestationModel.fromJson(json["prestation"]),
    );
  }

  Map<String, dynamic> toJson() => {
    "id": id,
    "userId": userId,
    "prestationId": prestationId,
    "deviseId": deviseId,
    "budget": budget,
    "description": description,
    "status": status,
    "startDate": startDate,
    "endDate": endDate,
    "createdAt": createdAt,
    "user": user?.toJson(),
    "prestation": prestation?.toJson(),
  };
}

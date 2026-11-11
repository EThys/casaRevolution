import 'dart:convert';
import 'UserModel.dart';
import 'PrestationModel.dart';

SollicitationModel sollicitationModelFromJson(String str) =>
    SollicitationModel.fromJson(json.decode(str));
String sollicitationModelToJson(SollicitationModel data) =>
    json.encode(data.toJson());

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

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

  /// Photo profil demandeur renvoyée par certains endpoints (ex: profile/reservation).
  String? userImage;

  /// Photo de la personne qui sollicite, si l’API l’a envoyée.
  String? get requesterPhoto {
    final direct = profileImageUrlFrom(userImage);
    if (direct != null) return direct;
    return profileImageUrlFrom(user?.profilePicture);
  }

  /// Téléphone annonceur / prestataire (`postByTel`) renvoyé par l’API sur création / liste.
  String? postByTel;

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
    this.postByTel,
    this.userImage,
  });

  static String? _pickUserImage(
    Map<String, dynamic> json,
    Map<String, dynamic>? sollicitationData,
    UserModel? user,
  ) {
    final direct = profileImageUrlFrom(json["userImage"] ??
        sollicitationData?["userImage"] ??
        json["imageUser"] ??
        json["avatar"] ??
        json["photo"]);
    if (direct != null) return direct;

    final raw = json["user"] ?? sollicitationData?["user"];
    if (raw is Map) {
      final m = Map<String, dynamic>.from(raw);
      final fromUser = profileImageUrlFrom(m["avatar"] ??
          m["profilePicture"] ??
          m["profile_picture"] ??
          m["image"] ??
          m["photo"] ??
          m["picture"] ??
          m["images"]);
      if (fromUser != null) return fromUser;
      final fromProfile = profileImageUrlFrom(m["profile"]);
      if (fromProfile != null) return fromProfile;
    }
    return profileImageUrlFrom(user?.profilePicture);
  }

  static String? _parsePostByTel(
    Map<String, dynamic> json,
    Map<String, dynamic>? sollicitationData,
  ) {
    String? pick(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      if (s.isEmpty || s == 'null') return null;
      return s;
    }

    final prest = json['prestation'];
    return pick(json['postByTel']) ??
        pick(sollicitationData?['postByTel']) ??
        (prest is Map ? pick(prest['postByTel']) : null);
  }

  factory SollicitationModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? sollicitationData;

    // Gérer la structure imbriquée : {"sollicitation": {...}, "user": {...}, ...}
    if (json.containsKey("sollicitation") && json["sollicitation"] is Map) {
      sollicitationData = json["sollicitation"] as Map<String, dynamic>;
    } else {
      sollicitationData = json;
    }

    final user = json["user"] == null
        ? null
        : UserModel.fromJson(
            json["user"] is Map<String, dynamic>
                ? json["user"] as Map<String, dynamic>
                : Map<String, dynamic>.from(json["user"] as Map),
          );
    PrestationModel? prestation;
    if (json["prestation"] is Map) {
      final wrapper = Map<String, dynamic>.from(json["prestation"] as Map);
      final inner = wrapper["prestation"] is Map
          ? Map<String, dynamic>.from(wrapper["prestation"] as Map)
          : wrapper;
      prestation = PrestationModel.fromJson(inner);
      String? text(dynamic value) {
        if (value == null) return null;
        final raw = value.toString().trim();
        if (raw.isEmpty || raw.toLowerCase() == 'null') return null;
        return raw;
      }

      Map<String, dynamic>? actorUser;
      final actor = wrapper["actor"] ?? json["actor"];
      if (actor is Map) {
        final person = actor["user"] ?? actor["member"] ?? actor;
        if (person is Map) actorUser = Map<String, dynamic>.from(person);
      }
      prestation.postBy ??= text(wrapper["postBy"]) ??
          text(json["postBy"]) ??
          text(actorUser?["username"]) ??
          text(actorUser?["fullName"]);
      prestation.phone ??= text(wrapper["postByTel"]) ??
          text(json["postByTel"]) ??
          text(actorUser?["phone"]);
      prestation.email ??= text(actorUser?["email"]);
      prestation.user ??=
          actorUser == null ? null : UserModel.fromJson(actorUser);
    }

    return SollicitationModel(
      id: _asInt(sollicitationData?["id"] ?? json["id"]),
      userId: _asInt(sollicitationData?["userId"] ?? json["userId"]) ??
          user?.userId,
      prestationId: _asInt(
            sollicitationData?["prestationId"] ?? json["prestationId"],
          ) ??
          prestation?.id,
      deviseId: sollicitationData?["deviseId"],
      budget: (sollicitationData?["budget"] as num?)?.toDouble(),
      description: sollicitationData?["description"],
      status: sollicitationData?["status"],
      startDate: sollicitationData?["startDate"],
      endDate: sollicitationData?["endDate"],
      createdAt: sollicitationData?["createdAt"],
      user: user,
      prestation: prestation,
      userImage: _pickUserImage(json, sollicitationData, user),
      postByTel: _parsePostByTel(json, sollicitationData),
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
        "postByTel": postByTel,
        "userImage": userImage,
      };
}

import 'dart:convert';

import 'PropertyModel.dart';
import 'UserModel.dart';
import 'PrestationModel.dart';

class PropertyFavoriteModel {
  int? propertyFavoriteId;
  int? userId;
  int? propertyId;
  UserModel? user;
  PropertyModel? property;
  PrestationModel? prestation;

  PropertyFavoriteModel({
    this.propertyFavoriteId,
    this.userId,
    this.propertyId,
    this.user,
    this.property,
    this.prestation,
  });

  factory PropertyFavoriteModel.fromJson(Map<String, dynamic> json) {
    PropertyModel? parsedProperty = 
              json["property"] != null ? PropertyModel.fromJson(json["property"]) :
              json["hotel"] != null ? PropertyModel.fromJson(json["hotel"]) :
              json["festive"] != null ? PropertyModel.fromJson(json["festive"]) :
              json["terrain"] != null ? PropertyModel.fromJson(json["terrain"]) :
              json["funeraire"] != null ? PropertyModel.fromJson(json["funeraire"]) :
              json["salle"] != null ? PropertyModel.fromJson(json["salle"]) :
              json["vacance"] != null ? PropertyModel.fromJson(json["vacance"]) :
              // json["prestation"] != null ? PropertyModel.fromJson(json["prestation"]) : // Ne plus convertir en property
              json["bureau"] != null ? PropertyModel.fromJson(json["bureau"]) :
              (json["title"] != null || json["propertyId"] != null || json["id"] != null) && json["prestation"] == null ? PropertyModel.fromJson(json) :
              null;

    PrestationModel? parsedPrestation = json["prestation"] != null ? PrestationModel.fromJson(json["prestation"]) : null;

    // Extraire les métadonnées du favori (peut être à la racine ou dans un objet "favorite")
    final Map<String, dynamic>? favoriteObj = json["favorite"] is Map ? Map<String, dynamic>.from(json["favorite"]) : null;
    
    final int? favId = json["favoriteId"] ?? json["PropertyFavoriteId"] ?? favoriteObj?["id"] ?? favoriteObj?["favoriteId"];
    final int? usrId = json["userId"] ?? json["UserId"] ?? favoriteObj?["userId"];
    
    // Extraire l'ID de la propriété si non direct
    int? pId = json["propertyId"] ?? json["PropertyId"] ?? parsedProperty?.propertyId;
    if (pId == null && favoriteObj != null) {
      pId = _parseInt(favoriteObj["propertyId"]) ?? 
            _parseInt(favoriteObj["hotelId"]) ?? 
            _parseInt(favoriteObj["funeraireId"]) ?? 
            _parseInt(favoriteObj["festId"]) ?? 
            _parseInt(favoriteObj["bureauId"]) ?? 
            _parseInt(favoriteObj["terrainId"]) ?? 
            _parseInt(favoriteObj["prestationId"]);
    }

    return PropertyFavoriteModel(
      propertyFavoriteId: favId,
      userId: usrId,
      propertyId: pId,
      user: json["user"] == null ? null : UserModel.fromJson(json["user"]),
      property: parsedProperty,
      prestation: parsedPrestation,
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  Map<String, dynamic> toJson() => {
    "favoriteId": propertyFavoriteId,
    "userId": userId,
    "propertyId": propertyId,
    "user": user?.toJson(),
    "property": property?.toJson(),
    "prestation": prestation?.toJson(),
  };

  String toJsonString() {
    return jsonEncode(toJson());
  }

  factory PropertyFavoriteModel.fromJsonString(String jsonString) {
    return PropertyFavoriteModel.fromJson(jsonDecode(jsonString));
  }
}
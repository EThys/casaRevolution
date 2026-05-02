import 'dart:convert';

import 'PropertyImageModel.dart';
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
              json["vacance"] != null ? PropertyModel.fromJson(json["vacance"]) :
              json["festive"] != null ? PropertyModel.fromJson(json["festive"]) :
              json["terrain"] != null ? PropertyModel.fromJson(json["terrain"]) :
              json["funeraire"] != null ? PropertyModel.fromJson(json["funeraire"]) :
              json["salle"] != null ? PropertyModel.fromJson(json["salle"]) :
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
            _parseInt(favoriteObj["vacanceId"]) ??
            _parseInt(favoriteObj["funeraireId"]) ??
            _parseInt(favoriteObj["festiveId"]) ??
            _parseInt(favoriteObj["festId"]) ??
            _parseInt(favoriteObj["bureauId"]) ??
            _parseInt(favoriteObj["terrainId"]) ??
            _parseInt(favoriteObj["prestationId"]);
    }

    if (parsedProperty != null) {
      // Enrichir images racine (favoris types spéciaux / vacance).
      parsedProperty = _mergeFavoriteRootImages(parsedProperty, json);

      // Enrichir agenceId pour vacance (utile pour router vers AgenceDetailsPage).
      int? agenceId;
      try {
        agenceId = _parseInt(json['agenceId']);
        if (agenceId == null && json['agence'] is Map) {
          final a = Map<String, dynamic>.from(json['agence'] as Map);
          agenceId = _parseInt(a['id']) ?? _parseInt(a['agenceId']);
        }
        if (agenceId == null && json['vacance'] is Map) {
          final v = Map<String, dynamic>.from(json['vacance'] as Map);
          agenceId = _parseInt(v['agenceId']);
          if (agenceId == null && v['agence'] is Map) {
            final a = Map<String, dynamic>.from(v['agence'] as Map);
            agenceId = _parseInt(a['id']) ?? _parseInt(a['agenceId']);
          }
        }
      } catch (_) {}

      // Forcer un typeId cohérent pour "vacance" si non présent/incorrect.
      final looksLikeVacance = json.containsKey('vacance') || (json['vacances'] != null);
      final nextTypeId = looksLikeVacance
          ? (parsedProperty.propertyTypeId == null || parsedProperty.propertyTypeId == 0
              ? 11
              : parsedProperty.propertyTypeId)
          : parsedProperty.propertyTypeId;

      parsedProperty = parsedProperty.copyWith(
        agenceId: agenceId ?? parsedProperty.agenceId,
        propertyTypeId: nextTypeId,
      );
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

  /// Favoris API : images des types spéciaux sont **à la racine** (`bureauImage`, `terrainImage`,
  /// `festiveImage`, `funeraireImage`), pas dans l’objet `bureau` / `salle` / `terrain`.
  static PropertyModel _mergeFavoriteRootImages(
    PropertyModel property,
    Map<String, dynamic> json,
  ) {
    final sidecar = _favoriteSidecarImageList(json);
    if (sidecar.isEmpty) return property;
    final existing = property.propertyImage ?? [];
    return property.copyWith(propertyImage: [...sidecar, ...existing]);
  }

  static List<PropertyImageModel> _favoriteSidecarImageList(
    Map<String, dynamic> json,
  ) {
    final out = <PropertyImageModel>[];

    void addFrom(dynamic v) {
      if (v == null) return;
      if (v is String) {
        final s = v.trim();
        if (s.isNotEmpty) out.add(PropertyImageModel(path: s));
        return;
      }
      if (v is! List) return;
      for (final x in v) {
        if (x is String) {
          final s = x.trim();
          if (s.isNotEmpty) out.add(PropertyImageModel(path: s));
          continue;
        }
        if (x is! Map) continue;
        final m = Map<String, dynamic>.from(x);
        out.add(PropertyImageModel(
          propertyImageId:
              _parseInt(m['propertyImageId']) ?? _parseInt(m['id']),
          name: m['name']?.toString(),
          path: m['path']?.toString() ?? m['publicPath']?.toString(),
        ));
      }
    }

    const keys = <String>[
      'bureauImage',
      'terrainImage',
      'festiveImage',
      'funeraireImage',
      // Vacance favorites: certaines réponses exposent les images via une liste racine dédiée.
      'vacanceImage',
      // Certaines réponses utilisent simplement "image" au niveau racine.
      'image',
    ];
    for (final key in keys) {
      addFrom(json[key]);
    }

    void addFromVacanceMap(Map<String, dynamic> v) {
      addFrom(v['vacanceImage']);
      addFrom(v['propertyImage']);
      addFrom(v['images']);
      addFrom(v['image']);
    }

    if (json['vacance'] is Map) {
      addFromVacanceMap(Map<String, dynamic>.from(json['vacance'] as Map));
    }
    if (json['vacances'] is Map) {
      addFromVacanceMap(Map<String, dynamic>.from(json['vacances'] as Map));
    }

    return out;
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
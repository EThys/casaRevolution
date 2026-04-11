import 'dart:convert';

import 'PropertyModel.dart';
import '../utils/listing_fields_parse.dart';

TerrainModel terrainModelFromJson(String str) => TerrainModel.fromJson(json.decode(str));

String terrainModelToJson(TerrainModel data) => json.encode(data.toJson());

class TerrainModel {
    final TerrainData? terrain;
    final Devise? devise;
    final String? postBy;
    final Address? address;
    final LocalAddress? localAddress;
    final GeoZone? geoZone;
    final List<TerrainImage>? images;
    final TypeProperty? typeProperty;
    final String? publisherImage;

    TerrainModel({
        this.terrain,
        this.devise,
        this.postBy,
        this.address,
        this.localAddress,
        this.geoZone,
        this.images,
        this.typeProperty,
        this.publisherImage,
    });

    factory TerrainModel.fromJson(Map<String, dynamic> json) => TerrainModel(
        terrain: json["terrain"] == null
            ? null
            : TerrainData.fromJson(
                Map<String, dynamic>.from(json["terrain"] as Map),
                root: json,
              ),
        devise: json["devise"] == null ? null : Devise.fromJson(json["devise"]),
        postBy: json["postBy"],
        address: json["address"] == null ? null : Address.fromJson(json["address"]),
        localAddress: json["localAddress"] == null ? null : LocalAddress.fromJson(json["localAddress"]),
        geoZone: json["geoZone"] == null ? null : GeoZone.fromJson(json["geoZone"]),
        images: json["images"] == null ? [] : List<TerrainImage>.from(json["images"]!.map((x) => TerrainImage.fromJson(x))),
        typeProperty: json["typeProperty"] == null ? null : TypeProperty.fromJson(json["typeProperty"]),
        publisherImage: json["image"],
    );

  static String? _publisherDisplayName(PropertyModel p) {
    String? clean(String? s) {
      if (s == null) return null;
      final t = s.trim();
      if (t.isEmpty) return null;
      return t.replaceAll('@', '').trim();
    }

    return clean(p.postBy) ??
        clean(p.username) ??
        clean(p.user?.fullName) ??
        clean(p.user?.username) ??
        clean(p.user?.email);
  }

  static String? _publisherPhoto(PropertyModel p) {
    final top = p.image?.trim();
    if (top != null && top.isNotEmpty) return top;
    final pp = p.user?.profilePicture?.trim();
    if (pp != null && pp.isNotEmpty) return pp;
    return null;
  }

  static String? _publishedAt(PropertyModel p) {
    String? u(String? s) {
      if (s == null) return null;
      final t = s.trim();
      return t.isEmpty ? null : t;
    }

    return u(p.createdAt) ?? u(p.createdStart) ?? u(p.updatedAt);
  }

  /// Pont recherche / listes unifiées → écran détail terrain (puis rechargement API).
  factory TerrainModel.fromPropertyListing(PropertyModel p) {
    String? surfaceStr;
    final s = p.surface;
    if (s != null) {
      surfaceStr = s == s.roundToDouble() ? '${s.toInt()}' : s.toString();
    }

    String? deviseCode;
    if (p.deviseId == 1) {
      deviseCode = 'CDF';
    } else if (p.deviseId == 2) {
      deviseCode = 'USD';
    }

    return TerrainModel(
      terrain: TerrainData(
        id: p.propertyId,
        userId: p.userId,
        title: p.title,
        description: p.description,
        price: p.price,
        surface: surfaceStr,
        transactionType: p.transactionType,
        isAvailable: p.available,
        sold: p.sold,
        createdAt: _publishedAt(p),
      ),
      devise: deviseCode != null ? Devise(id: p.deviseId, code: deviseCode) : null,
      postBy: _publisherDisplayName(p),
      publisherImage: _publisherPhoto(p),
      address: Address(
        address: p.address,
        communeValue: p.communeValue,
        quartierValue: p.quartierValue,
        cityValue: p.cityValue,
        countryValue: p.countryValue,
        postalCode: p.postalCode,
      ),
      images: p.allImageUrls.map((path) => TerrainImage(path: path)).toList(),
      typeProperty: TypeProperty(
        propertyTypeId: p.propertyTypeId ?? p.propertyType?.propertyTypeId,
        name: p.propertyType?.name,
      ),
    );
  }

    Map<String, dynamic> toJson() => {
        "terrain": terrain?.toJson(),
        "devise": devise?.toJson(),
        "postBy": postBy,
        "address": address?.toJson(),
        "localAddress": localAddress?.toJson(),
        "geoZone": geoZone?.toJson(),
        "images": images == null ? [] : List<dynamic>.from(images!.map((x) => x.toJson())),
        "typeProperty": typeProperty?.toJson(),
        "image": publisherImage,
    };
}

bool? _parseTerrainSold(dynamic v) {
  if (v == null) return null;
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.toLowerCase().trim();
    return s == '1' || s == 'true' || s == 'yes';
  }
  return null;
}

class TerrainData {
    final int? id;
    final int? userId;
    final String? title;
    final String? description;
    final double? price;
    final String? surface;
    final String? transactionType;
    final bool? isAvailable;
    final bool? sold;
    final String? createdAt;

    TerrainData({
        this.id,
        this.userId,
        this.title,
        this.description,
        this.price,
        this.surface,
        this.transactionType,
        this.isAvailable,
        this.sold,
        this.createdAt,
    });

    factory TerrainData.fromJson(Map<String, dynamic> json, {Map<String, dynamic>? root}) {
      final maps = <Map<String, dynamic>>[json];
      if (root != null) maps.add(root);
      return TerrainData(
        id: json["id"],
        userId: json["userId"],
        title: json["title"],
        description: json["description"],
        price: (json["price"] as num?)?.toDouble(),
        surface: json["surface"],
        transactionType: json["transactionType"],
        isAvailable: ListingFieldsParse.availableFromMaps(maps) ??
            _parseTerrainSold(json["available"]) ??
            _parseTerrainSold(json["isAvailable"]) ??
            _parseTerrainSold(json["is_available"]),
        sold: ListingFieldsParse.soldFromMaps(maps) ?? _parseTerrainSold(json["sold"]),
        createdAt: json["createdAt"],
      );
    }

    Map<String, dynamic> toJson() => {
        "id": id,
        "userId": userId,
        "title": title,
        "description": description,
        "price": price,
        "surface": surface,
        "transactionType": transactionType,
        "available": isAvailable,
        "sold": sold,
        "createdAt": createdAt,
    };
}

class Devise {
    final int? id;
    final String? name;
    final String? code;
    final double? tauxLocal;

    Devise({
        this.id,
        this.name,
        this.code,
        this.tauxLocal,
    });

    factory Devise.fromJson(Map<String, dynamic> json) => Devise(
        id: json["id"],
        name: json["name"],
        code: json["code"],
        tauxLocal: (json["tauxLocal"] as num?)?.toDouble(),
    );

    Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "code": code,
        "tauxLocal": tauxLocal,
    };
}

class Address {
    final String? address;
    final String? communeValue;
    final String? quartierValue;
    final String? cityValue;
    final String? countryValue;
    final String? postalCode;

    Address({
        this.address,
        this.communeValue,
        this.quartierValue,
        this.cityValue,
        this.countryValue,
        this.postalCode,
    });

    factory Address.fromJson(Map<String, dynamic> json) => Address(
        address: json["address"],
        communeValue: json["communeValue"],
        quartierValue: json["quartierValue"],
        cityValue: json["cityValue"],
        countryValue: json["countryValue"],
        postalCode: json["postalCode"],
    );

    Map<String, dynamic> toJson() => {
        "address": address,
        "communeValue": communeValue,
        "quartierValue": quartierValue,
        "cityValue": cityValue,
        "countryValue": countryValue,
        "postalCode": postalCode,
    };
}

class LocalAddress {
    final City? city;
    final Commune? commune;
    final Quartier? quartier;

    LocalAddress({
        this.city,
        this.commune,
        this.quartier,
    });

    factory LocalAddress.fromJson(Map<String, dynamic> json) => LocalAddress(
        city: json["city"] == null ? null : City.fromJson(json["city"]),
        commune: json["commune"] == null ? null : Commune.fromJson(json["commune"]),
        quartier: json["quartier"] == null ? null : Quartier.fromJson(json["quartier"]),
    );

    Map<String, dynamic> toJson() => {
        "city": city?.toJson(),
        "commune": commune?.toJson(),
        "quartier": quartier?.toJson(),
    };
}

class City {
    final int? cityId;
    final String? name;

    City({
        this.cityId,
        this.name,
    });

    factory City.fromJson(Map<String, dynamic> json) => City(
        cityId: json["cityId"],
        name: json["name"],
    );

    Map<String, dynamic> toJson() => {
        "cityId": cityId,
        "name": name,
    };
}

class Commune {
    final int? communeId;
    final int? district;
    final List<Quartier>? quartiers;
    final String? name;

    Commune({
        this.communeId,
        this.district,
        this.quartiers,
        this.name,
    });

    factory Commune.fromJson(Map<String, dynamic> json) => Commune(
        communeId: json["communeId"],
        district: json["district"],
        quartiers: json["quartiers"] == null ? [] : List<Quartier>.from(json["quartiers"]!.map((x) => Quartier.fromJson(x))),
        name: json["name"],
    );

    Map<String, dynamic> toJson() => {
        "communeId": communeId,
        "district": district,
        "quartiers": quartiers == null ? [] : List<dynamic>.from(quartiers!.map((x) => x.toJson())),
        "name": name,
    };
}

class Quartier {
    final int? quartierId;
    final String? name;

    Quartier({
        this.quartierId,
        this.name,
    });

    factory Quartier.fromJson(Map<String, dynamic> json) => Quartier(
        quartierId: json["quartierId"],
        name: json["name"],
    );

    Map<String, dynamic> toJson() => {
        "quartierId": quartierId,
        "name": name,
    };
}

class GeoZone {
    final double? lat;
    final double? lng;

    GeoZone({
        this.lat,
        this.lng,
    });

    factory GeoZone.fromJson(Map<String, dynamic> json) => GeoZone(
        lat: (json["lat"] as num?)?.toDouble(),
        lng: (json["lng"] as num?)?.toDouble(),
    );

    Map<String, dynamic> toJson() => {
        "lat": lat,
        "lng": lng,
    };
}

class TerrainImage {
    final int? id;
    final int? terrainId;
    final String? name;
    final String? path;
    final bool? isAvailable;
    final String? createdAt;

    TerrainImage({
        this.id,
        this.terrainId,
        this.name,
        this.path,
        this.isAvailable,
        this.createdAt,
    });

    factory TerrainImage.fromJson(Map<String, dynamic> json) => TerrainImage(
        id: json["id"],
        terrainId: json["terrainId"],
        name: json["name"],
        path: json["path"],
        isAvailable: json["available"] ?? json["isAvailable"],
        createdAt: json["createdAt"],
    );

    Map<String, dynamic> toJson() => {
        "id": id,
        "terrainId": terrainId,
        "name": name,
        "path": path,
        "available": isAvailable,
        "createdAt": createdAt,
    };
}

class TypeProperty {
    final int? propertyTypeId;
    final String? name;

    TypeProperty({
        this.propertyTypeId,
        this.name,
    });

    factory TypeProperty.fromJson(Map<String, dynamic> json) => TypeProperty(
        propertyTypeId: json["propertyTypeId"],
        name: json["name"],
    );

    Map<String, dynamic> toJson() => {
        "propertyTypeId": propertyTypeId,
        "name": name,
    };
}

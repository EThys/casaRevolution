import 'dart:convert';

BureauModel bureauModelFromJson(String str) => BureauModel.fromJson(json.decode(str));

String bureauModelToJson(BureauModel data) => json.encode(data.toJson());

class BureauModel {
    final BureauData? bureau;
    final Devise? devise;
    final String? postBy;
    final Address? address;
    final LocalAddress? localAddress;
    final GeoZone? geoZone;
    final List<BureauImage>? images;
    final List<Feature>? feature;
    final TypeProperty? typeProperty;

    BureauModel({
        this.bureau,
        this.devise,
        this.postBy,
        this.address,
        this.localAddress,
        this.geoZone,
        this.images,
        this.feature,
        this.typeProperty,
    });

    factory BureauModel.fromJson(Map<String, dynamic> json) => BureauModel(
        bureau: json["bureau"] == null ? null : BureauData.fromJson(json["bureau"]),
        devise: json["devise"] == null ? null : Devise.fromJson(json["devise"]),
        postBy: json["postBy"],
        address: json["address"] == null ? null : Address.fromJson(json["address"]),
        localAddress: json["localAddress"] == null ? null : LocalAddress.fromJson(json["localAddress"]),
        geoZone: json["geoZone"] == null ? null : GeoZone.fromJson(json["geoZone"]),
        images: json["images"] == null ? [] : List<BureauImage>.from(json["images"]!.map((x) => BureauImage.fromJson(x))),
        feature: json["feature"] == null ? [] : List<Feature>.from(json["feature"]!.map((x) => Feature.fromJson(x))),
        typeProperty: json["typeProperty"] == null ? null : TypeProperty.fromJson(json["typeProperty"]),
    );

    Map<String, dynamic> toJson() => {
        "bureau": bureau?.toJson(),
        "devise": devise?.toJson(),
        "postBy": postBy,
        "address": address?.toJson(),
        "localAddress": localAddress?.toJson(),
        "geoZone": geoZone?.toJson(),
        "images": images == null ? [] : List<dynamic>.from(images!.map((x) => x.toJson())),
        "feature": feature == null ? [] : List<dynamic>.from(feature!.map((x) => x.toJson())),
        "typeProperty": typeProperty?.toJson(),
    };
}

class BureauData {
    final int? id;
    final int? userId;
    final String? title;
    final String? description;
    final double? price;
    final int? electric;
    final int? water;
    final String? transactionType;
    final int? propertyTypeId;
    final int? roomMeet;
    final bool? isAvailable;
    final int? numberPiece;
    final bool? isEquip;
    final bool? sold;
    final String? createdAt;

    BureauData({
        this.id,
        this.userId,
        this.title,
        this.description,
        this.price,
        this.electric,
        this.water,
        this.transactionType,
        this.propertyTypeId,
        this.roomMeet,
        this.isAvailable,
        this.numberPiece,
        this.isEquip,
        this.sold,
        this.createdAt,
    });

    factory BureauData.fromJson(Map<String, dynamic> json) => BureauData(
        id: json["id"],
        userId: json["userId"],
        title: json["title"],
        description: json["description"],
        price: (json["price"] as num?)?.toDouble(),
        electric: json["electric"],
        water: json["water"],
        transactionType: json["transactionType"],
        propertyTypeId: json["propertyTypeId"],
        roomMeet: json["roomMeet"],
        isAvailable: json["isAvailable"],
        numberPiece: json["numberPiece"],
        isEquip: json["isEquip"],
        sold: json["sold"],
        createdAt: json["createdAt"],
    );

    Map<String, dynamic> toJson() => {
        "id": id,
        "userId": userId,
        "title": title,
        "description": description,
        "price": price,
        "electric": electric,
        "water": water,
        "transactionType": transactionType,
        "propertyTypeId": propertyTypeId,
        "roomMeet": roomMeet,
        "isAvailable": isAvailable,
        "numberPiece": numberPiece,
        "isEquip": isEquip,
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

class BureauImage {
    final String? name;
    final String? path;

    BureauImage({
        this.name,
        this.path,
    });

    factory BureauImage.fromJson(Map<String, dynamic> json) => BureauImage(
        name: json["name"],
        path: json["path"],
    );

    Map<String, dynamic> toJson() => {
        "name": name,
        "path": path,
    };
}

class Feature {
    final int? featureId;
    final String? name;

    Feature({
        this.featureId,
        this.name,
    });

    factory Feature.fromJson(Map<String, dynamic> json) => Feature(
        featureId: json["featureId"],
        name: json["name"],
    );

    Map<String, dynamic> toJson() => {
        "featureId": featureId,
        "name": name,
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

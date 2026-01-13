import 'dart:convert';

SalleFuneraireModel salleFuneraireModelFromJson(String str) => SalleFuneraireModel.fromJson(json.decode(str));

String salleFuneraireModelToJson(SalleFuneraireModel data) => json.encode(data.toJson());

class SalleFuneraireModel {
    int? id;
    int? userId;
    int? deviseId;
    String? title;
    String? description;
    String? capacityPeople;
    String? transactionType;
    int? propertyTypeId;
    double? price;
    bool? sold;
    String? address;
    String? communeValue;
    String? quartierValue;
    String? cityValue;
    int? electric;
    int? water;
    String? countryValue;
    int? cityId;
    String? postalCode;
    int? communeId;
    int? quartierId;
    double? latitude;
    double? longitude;
    bool? isAvailable;
    String? createdAt;
    String? updatedAt;
    List<FuneraireImage>? images;
    List<FuneraireFeature>? feature;

    SalleFuneraireModel({
        this.id,
        this.userId,
        this.deviseId,
        this.title,
        this.description,
        this.capacityPeople,
        this.transactionType,
        this.propertyTypeId,
        this.price,
        this.sold,
        this.address,
        this.communeValue,
        this.quartierValue,
        this.cityValue,
        this.electric,
        this.water,
        this.countryValue,
        this.cityId,
        this.postalCode,
        this.communeId,
        this.quartierId,
        this.latitude,
        this.longitude,
        this.isAvailable,
        this.createdAt,
        this.updatedAt,
        this.images,
        this.feature,
    });

    factory SalleFuneraireModel.fromJson(Map<String, dynamic> json) => SalleFuneraireModel(
        id: json["id"],
        userId: json["userId"],
        deviseId: json["deviseId"],
        title: json["title"],
        description: json["description"],
        capacityPeople: json["capacityPeople"],
        transactionType: json["transactionType"],
        propertyTypeId: json["propertyTypeId"],
        price: json["price"]?.toDouble(),
        sold: json["sold"],
        address: json["address"],
        communeValue: json["communeValue"],
        quartierValue: json["quartierValue"],
        cityValue: json["cityValue"],
        electric: json["electric"],
        water: json["water"],
        countryValue: json["countryValue"],
        cityId: json["cityId"],
        postalCode: json["postalCode"],
        communeId: json["communeId"],
        quartierId: json["quartierId"],
        latitude: json["latitude"]?.toDouble(),
        longitude: json["longitude"]?.toDouble(),
        isAvailable: json["isAvailable"],
        createdAt: json["createdAt"],
        updatedAt: json["updatedAt"],
        images: json["images"] == null ? [] : List<FuneraireImage>.from(json["images"]!.map((x) => FuneraireImage.fromJson(x))),
        feature: json["feature"] == null ? [] : List<FuneraireFeature>.from(json["feature"]!.map((x) => FuneraireFeature.fromJson(x))),
    );

    Map<String, dynamic> toJson() => {
        "id": id,
        "userId": userId,
        "deviseId": deviseId,
        "title": title,
        "description": description,
        "capacityPeople": capacityPeople,
        "transactionType": transactionType,
        "propertyTypeId": propertyTypeId,
        "price": price,
        "sold": sold,
        "address": address,
        "communeValue": communeValue,
        "quartierValue": quartierValue,
        "cityValue": cityValue,
        "electric": electric,
        "water": water,
        "countryValue": countryValue,
        "cityId": cityId,
        "postalCode": postalCode,
        "communeId": communeId,
        "quartierId": quartierId,
        "latitude": latitude,
        "longitude": longitude,
        "isAvailable": isAvailable,
        "createdAt": createdAt,
        "updatedAt": updatedAt,
        "images": images == null ? [] : List<dynamic>.from(images!.map((x) => x.toJson())),
        "feature": feature == null ? [] : List<dynamic>.from(feature!.map((x) => x.toJson())),
    };
}

class FuneraireImage {
    int? id;
    int? salleFuneraireId;
    String? name;
    String? path;
    bool? isAvailable;
    String? createdAt;

    FuneraireImage({
        this.id,
        this.salleFuneraireId,
        this.name,
        this.path,
        this.isAvailable,
        this.createdAt,
    });

    factory FuneraireImage.fromJson(Map<String, dynamic> json) => FuneraireImage(
        id: json["id"],
        salleFuneraireId: json["salleFuneraireId"],
        name: json["name"],
        path: json["path"],
        isAvailable: json["isAvailable"],
        createdAt: json["createdAt"],
    );

    Map<String, dynamic> toJson() => {
        "id": id,
        "salleFuneraireId": salleFuneraireId,
        "name": name,
        "path": path,
        "isAvailable": isAvailable,
        "createdAt": createdAt,
    };
}

class FuneraireFeature {
    int? featureId;
    String? name;

    FuneraireFeature({
        this.featureId,
        this.name,
    });

    factory FuneraireFeature.fromJson(Map<String, dynamic> json) => FuneraireFeature(
        featureId: json["featureId"],
        name: json["name"],
    );

    Map<String, dynamic> toJson() => {
        "featureId": featureId,
        "name": name,
    };
}

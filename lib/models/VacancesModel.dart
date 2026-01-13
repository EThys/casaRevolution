import 'dart:convert';

VacancesModel vacancesModelFromJson(String str) => VacancesModel.fromJson(json.decode(str));

String vacancesModelToJson(VacancesModel data) => json.encode(data.toJson());

class VacancesModel {
    int? agenceId;
    int? userId;
    String? title;
    String? description;
    String? note;
    String? dateVacance;
    String? heureVacance;
    double? price;
    String? priceCombo;
    String? offre;
    int? capacity;
    String? address;
    String? cityValue;
    String? countryValue;
    bool? isAvailable;
    bool? available;
    List<VacanceImage>? images;

    VacancesModel({
        this.agenceId,
        this.userId,
        this.title,
        this.description,
        this.note,
        this.dateVacance,
        this.heureVacance,
        this.price,
        this.priceCombo,
        this.offre,
        this.capacity,
        this.address,
        this.cityValue,
        this.countryValue,
        this.isAvailable,
        this.available,
        this.images,
    });

    factory VacancesModel.fromJson(Map<String, dynamic> json) => VacancesModel(
        agenceId: json["agenceId"],
        userId: json["userId"],
        title: json["title"],
        description: json["description"],
        note: json["note"],
        dateVacance: json["dateVacance"],
        heureVacance: json["heureVacance"],
        price: json["price"]?.toDouble(),
        priceCombo: json["priceCombo"],
        offre: json["offre"],
        capacity: json["capacity"],
        address: json["address"],
        cityValue: json["cityValue"],
        countryValue: json["countryValue"],
        isAvailable: json["isAvailable"],
        available: json["available"],
        images: json["images"] == null ? [] : List<VacanceImage>.from(json["images"]!.map((x) => VacanceImage.fromJson(x))),
    );

    Map<String, dynamic> toJson() => {
        "agenceId": agenceId,
        "userId": userId,
        "title": title,
        "description": description,
        "note": note,
        "dateVacance": dateVacance,
        "heureVacance": heureVacance,
        "price": price,
        "priceCombo": priceCombo,
        "offre": offre,
        "capacity": capacity,
        "address": address,
        "cityValue": cityValue,
        "countryValue": countryValue,
        "isAvailable": isAvailable,
        "available": available,
        "images": images == null ? [] : List<dynamic>.from(images!.map((x) => x.toJson())),
    };
}

class VacanceImage {
    String? image;
    String? name;

    VacanceImage({
        this.image,
        this.name,
    });

    factory VacanceImage.fromJson(Map<String, dynamic> json) => VacanceImage(
        image: json["image"],
        name: json["name"],
    );

    Map<String, dynamic> toJson() => {
        "image": image,
        "name": name,
    };
}

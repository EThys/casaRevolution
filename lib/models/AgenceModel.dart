import 'dart:convert';

AgenceModel agenceModelFromJson(String str) => AgenceModel.fromJson(json.decode(str));
String agenceModelToJson(AgenceModel data) => json.encode(data.toJson());

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  if (value is double) return value.toInt();
  return null;
}

class AgenceModel {
  int? id;
  int? userId;
  String? name;
  String? description;
  String? phone1;
  String? phone2;
  String? address;
  String? logo;

  List<AgenceSiteModel>? sites;

  AgenceModel({
    this.id,
    this.userId,
    this.name,
    this.description,
    this.phone1,
    this.phone2,
    this.address,
    this.logo,
    this.sites,
  });

  factory AgenceModel.fromJson(Map<String, dynamic> json) => AgenceModel(
    id: _parseInt(json["id"]) ?? _parseInt(json["agenceId"]),
    userId: _parseInt(json["userId"]),
    name: json["name"],
    description: json["description"] ?? "",
    phone1: json["phone1"] ?? "",
    phone2: json["phone2"] ?? "",
    address: json["address"] ?? "",
    logo: json["logo"] ?? "",
    // parsing of sites will be handled in controller or via a setter if needed, 
    // but here we can initialize it empty or optional.
    // The controller currently does the mapping manually.
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "userId": userId,
    "name": name,
    "description": description,
    "phone1": phone1,
    "phone2": phone2,
    "address": address,
    "logo": logo,
    "sites": sites?.map((x) => x.toJson()).toList(),
  };
}

class AgenceSiteModel {
  int? id;
  String? title;
  String? description;
  double? price;
  String? dateVacance;
  String? heureVacance;
  bool? available;
  List<String>? images;

  AgenceSiteModel({
    this.id,
    this.title,
    this.description,
    this.price,
    this.dateVacance,
    this.heureVacance,
    this.available,
    this.images,
  });

  factory AgenceSiteModel.fromJson(Map<String, dynamic> json) {
    // Handling nested "vacance" and "image" structure
    final vacance = json['vacance'] ?? {};
    final imageList = json['image'] as List?;

    return AgenceSiteModel(
      id: _parseInt(vacance["id"]),
      title: vacance["title"],
      description: vacance["description"],
      price: (vacance["price"] as num?)?.toDouble(),
      dateVacance: vacance["dateVacance"],
      heureVacance: vacance["heureVacance"],
      available: vacance["available"] as bool?,
      images: imageList?.map((img) => img['path'] as String).toList() ?? [],
    );
  }
  
  // Also allowing direct parsing if structure is flat (fallback)
  factory AgenceSiteModel.fromFlatJson(Map<String, dynamic> json) => AgenceSiteModel(
      id: _parseInt(json["id"]),
      title: json["title"],
      description: json["description"],
      price: (json["price"] as num?)?.toDouble(),
      dateVacance: json["dateVacance"],
      images: [], // or parse if available
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "title": title,
    "description": description,
    "price": price,
    "dateVacance": dateVacance,
    "heureVacance": heureVacance,
    "available": available,
    "images": images,
  };
}

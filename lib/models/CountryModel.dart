import 'dart:convert';

CountryModel countryModelFromJson(String str) => CountryModel.fromJson(json.decode(str));
String countryModelToJson(CountryModel data) => json.encode(data.toJson());

class CountryModel {
  int? countryId;
  String? name;

  CountryModel({
    this.countryId,
    this.name,
  });

  factory CountryModel.fromJson(Map<String, dynamic> json) => CountryModel(
    countryId: json["countryId"] ?? json["id"],
    name: json["name"] ?? json["countryName"],
  );

  Map<String, dynamic> toJson() => {
    "countryId": countryId,
    "name": name,
  };

  @override
  String toString() {
    return name ?? '';
  }
}
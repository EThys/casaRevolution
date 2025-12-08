import 'dart:convert';

SalleFuneraireModel salleFuneraireModelFromJson(String str) => SalleFuneraireModel.fromJson(json.decode(str));
String salleFuneraireModelToJson(SalleFuneraireModel data) => json.encode(data.toJson());

// Méthodes helpers pour le parsing sécurisé
int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  if (value is double) return value.toInt();
  return null;
}

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

String? _parseString(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  return value.toString();
}

bool _parseBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is String) return value.toLowerCase() == 'true';
  if (value is int) return value == 1;
  return false;
}

class SalleFuneraireModel {
  int? salleFuneraireId;
  int? propertyId;
  
  // Capacité et dimensions
  int? funeralCapacity;
  double? surfaceArea;
  bool? hasReceptionArea;
  
  // Services funéraires
  List<String>? funeralServices;
  int? numberOfRestrooms;
  
  // Parking et accessibilité
  int? parkingSpaces;
  bool? hasParking;
  
  // Prix et disponibilité
  double? rentalPrice;
  int? minimumRentalDays; // Jours minimum de location
  int? maximumRentalDays; // Jours maximum de location
  String? availabilityStatus; // "available", "booked", "maintenance"
  List<String>? availableDates;
  List<String>? bookedDates;
  
  // Règles et conditions
  String? cancellationPolicy;
  double? depositAmount;
  double? securityDeposit;
  int? advanceBookingDays;
  String? operatingHours;
  
  // Équipements et aménagements
  int? numberOfSeats;
  bool? providesChairs;
  int? numberOfChairs;
  bool? providesTables;
  int? numberOfTables;
  
  // Services supplémentaires
  List<String>? additionalServices;
  
  // Informations pratiques
  String? setupTime;
  String? breakdownTime;
  int? hearseParkingSpaces;
  
  // Liste de tous les équipements et services (amenities)
  List<String>? amenities;
  
  // Métadonnées
  String? createdAt;
  String? updatedAt;
  bool? isActive;
  bool? isVerified;

  SalleFuneraireModel({
    this.salleFuneraireId,
    this.propertyId,
    this.funeralCapacity,
    this.surfaceArea,
    this.hasReceptionArea,
    this.funeralServices,
    this.numberOfRestrooms,
    this.parkingSpaces,
    this.hasParking,
    this.rentalPrice,
    this.minimumRentalDays,
    this.maximumRentalDays,
    this.availabilityStatus,
    this.availableDates,
    this.bookedDates,
    this.cancellationPolicy,
    this.depositAmount,
    this.securityDeposit,
    this.advanceBookingDays,
    this.operatingHours,
    this.numberOfSeats,
    this.providesChairs,
    this.numberOfChairs,
    this.providesTables,
    this.numberOfTables,
    this.additionalServices,
    this.setupTime,
    this.breakdownTime,
    this.hearseParkingSpaces,
    this.amenities,
    this.createdAt,
    this.updatedAt,
    this.isActive,
    this.isVerified,
  });

  factory SalleFuneraireModel.fromJson(Map<String, dynamic> json) => SalleFuneraireModel(
    salleFuneraireId: _parseInt(json["salleFuneraireId"]) ?? _parseInt(json["id"]),
    propertyId: _parseInt(json["propertyId"]),
    funeralCapacity: _parseInt(json["funeralCapacity"]),
    surfaceArea: _parseDouble(json["surfaceArea"]),
    hasReceptionArea: _parseBool(json["hasReceptionArea"]),
    funeralServices: json["funeralServices"] is List
        ? List<String>.from(json["funeralServices"])
        : null,
    numberOfRestrooms: _parseInt(json["numberOfRestrooms"]),
    parkingSpaces: _parseInt(json["parkingSpaces"]),
    hasParking: _parseBool(json["hasParking"]),
    rentalPrice: _parseDouble(json["rentalPrice"]),
    minimumRentalDays: _parseInt(json["minimumRentalDays"]),
    maximumRentalDays: _parseInt(json["maximumRentalDays"]),
    availabilityStatus: _parseString(json["availabilityStatus"]) ?? "available",
    availableDates: json["availableDates"] is List
        ? List<String>.from(json["availableDates"])
        : null,
    bookedDates: json["bookedDates"] is List
        ? List<String>.from(json["bookedDates"])
        : null,
    cancellationPolicy: _parseString(json["cancellationPolicy"]),
    depositAmount: _parseDouble(json["depositAmount"]),
    securityDeposit: _parseDouble(json["securityDeposit"]),
    advanceBookingDays: _parseInt(json["advanceBookingDays"]),
    operatingHours: _parseString(json["operatingHours"]),
    numberOfSeats: _parseInt(json["numberOfSeats"]),
    providesChairs: _parseBool(json["providesChairs"]),
    numberOfChairs: _parseInt(json["numberOfChairs"]),
    providesTables: _parseBool(json["providesTables"]),
    numberOfTables: _parseInt(json["numberOfTables"]),
    additionalServices: json["additionalServices"] is List
        ? List<String>.from(json["additionalServices"])
        : null,
    setupTime: _parseString(json["setupTime"]),
    breakdownTime: _parseString(json["breakdownTime"]),
    hearseParkingSpaces: _parseInt(json["hearseParkingSpaces"]),
    amenities: json["amenities"] is List
        ? List<String>.from(json["amenities"])
        : (() {
            // Générer automatiquement amenities si non fourni à partir des champs JSON
            List<String> autoAmenities = [];
            if (_parseBool(json["hasReceptionArea"])) autoAmenities.add("Espace de réception");
            if (_parseBool(json["hasCoffinDisplay"])) autoAmenities.add("Présentation du cercueil");
            if (_parseBool(json["hasMusicSystem"])) autoAmenities.add("Système musical");
            if (_parseBool(json["hasVideoProjection"])) autoAmenities.add("Projection vidéo");
            if (_parseBool(json["hasPrayerRoom"])) autoAmenities.add("Salle de prière");
            if (_parseBool(json["hasRestroom"])) {
              autoAmenities.add("Toilettes");
              int? restrooms = _parseInt(json["numberOfRestrooms"]);
              if (restrooms != null && restrooms > 0) {
                autoAmenities.add("Toilettes ($restrooms)");
              }
            }
            if (_parseBool(json["hasParking"])) {
              autoAmenities.add("Parking");
              int? spaces = _parseInt(json["parkingSpaces"]);
              if (spaces != null && spaces > 0) {
                autoAmenities.add("Parking ($spaces places)");
              }
            }
            if (_parseBool(json["hasAirConditioning"])) autoAmenities.add("Climatisation");
            if (_parseBool(json["hasHeating"])) autoAmenities.add("Chauffage");
            if (_parseBool(json["hasRefrigeration"])) autoAmenities.add("Réfrigération");
            if (_parseBool(json["hasSoundSystem"])) autoAmenities.add("Système sonore");
            if (_parseBool(json["hasLighting"])) autoAmenities.add("Éclairage");
            if (_parseBool(json["providesChairs"])) {
              autoAmenities.add("Chaises");
              int? chairs = _parseInt(json["numberOfChairs"]);
              if (chairs != null && chairs > 0) {
                autoAmenities.add("Chaises ($chairs)");
              }
            }
            if (_parseBool(json["providesTables"])) {
              autoAmenities.add("Tables");
              int? tables = _parseInt(json["numberOfTables"]);
              if (tables != null && tables > 0) {
                autoAmenities.add("Tables ($tables)");
              }
            }
            if (_parseBool(json["hasCatering"])) autoAmenities.add("Service de traiteur");
            if (_parseBool(json["hasFloralServices"])) autoAmenities.add("Services floraux");
            if (_parseBool(json["hasTransportation"])) autoAmenities.add("Service de transport");
            if (_parseBool(json["hasObituaryServices"])) autoAmenities.add("Services de faire-part");
            if (_parseBool(json["hasMemorialServices"])) autoAmenities.add("Services mémoriaux");
            if (_parseBool(json["hasWiFi"])) autoAmenities.add("WiFi");
            if (_parseBool(json["hasParkingForHearse"])) {
              autoAmenities.add("Parking pour corbillard");
              int? hearseSpaces = _parseInt(json["hearseParkingSpaces"]);
              if (hearseSpaces != null && hearseSpaces > 0) {
                autoAmenities.add("Parking corbillard ($hearseSpaces places)");
              }
            }
            return autoAmenities.isNotEmpty ? autoAmenities : null;
          })(),
    createdAt: _parseString(json["createdAt"]),
    updatedAt: _parseString(json["updatedAt"]),
    isActive: _parseBool(json["isActive"]) ?? true,
    isVerified: _parseBool(json["isVerified"]) ?? false,
  );

  Map<String, dynamic> toJson() => {
    "salleFuneraireId": salleFuneraireId,
    "propertyId": propertyId,
    "funeralCapacity": funeralCapacity,
    "surfaceArea": surfaceArea,
    "hasReceptionArea": hasReceptionArea,
    "funeralServices": funeralServices,
    "numberOfRestrooms": numberOfRestrooms,
    "parkingSpaces": parkingSpaces,
    "hasParking": hasParking,
    "rentalPrice": rentalPrice,
    "minimumRentalDays": minimumRentalDays,
    "maximumRentalDays": maximumRentalDays,
    "availabilityStatus": availabilityStatus,
    "availableDates": availableDates,
    "bookedDates": bookedDates,
    "cancellationPolicy": cancellationPolicy,
    "depositAmount": depositAmount,
    "securityDeposit": securityDeposit,
    "advanceBookingDays": advanceBookingDays,
    "operatingHours": operatingHours,
    "numberOfSeats": numberOfSeats,
    "providesChairs": providesChairs,
    "numberOfChairs": numberOfChairs,
    "providesTables": providesTables,
    "numberOfTables": numberOfTables,
    "additionalServices": additionalServices,
    "setupTime": setupTime,
    "breakdownTime": breakdownTime,
    "hearseParkingSpaces": hearseParkingSpaces,
    "amenities": amenities,
    "createdAt": createdAt,
    "updatedAt": updatedAt,
    "isActive": isActive,
    "isVerified": isVerified,
  };

  // Méthodes utilitaires
  String get formattedRentalPrice {
    if (rentalPrice == null) return "Prix sur demande";
    return "${rentalPrice!.toStringAsFixed(0)}\$/jour";
  }

  bool get isAvailable {
    return availabilityStatus == "available" && (isActive ?? true);
  }

  // Génère automatiquement la liste des amenities à partir de la liste amenities et autres champs
  List<String> get generatedAmenities {
    List<String> amenitiesList = [];
    
    // Ajouter d'abord les amenities de la liste principale
    if (amenities != null && amenities!.isNotEmpty) {
      amenitiesList.addAll(amenities!);
    }
    
    // Parking
    if (hasParking == true) {
      amenitiesList.add("Parking");
      if (parkingSpaces != null && parkingSpaces! > 0) {
        amenitiesList.add("Parking ($parkingSpaces places)");
      }
    }
    
    // Espace de réception
    if (hasReceptionArea == true) amenitiesList.add("Espace de réception");
    
    // Mobilier
    if (providesChairs == true) {
      amenitiesList.add("Chaises");
      if (numberOfChairs != null && numberOfChairs! > 0) {
        amenitiesList.add("Chaises ($numberOfChairs)");
      }
    }
    if (providesTables == true) {
      amenitiesList.add("Tables");
      if (numberOfTables != null && numberOfTables! > 0) {
        amenitiesList.add("Tables ($numberOfTables)");
      }
    }
    
    // Services funéraires
    if (funeralServices != null && funeralServices!.isNotEmpty) {
      amenitiesList.addAll(funeralServices!);
    }
    
    // Services supplémentaires
    if (additionalServices != null && additionalServices!.isNotEmpty) {
      amenitiesList.addAll(additionalServices!);
    }
    
    // Retourner une liste unique (sans doublons)
    return amenitiesList.toSet().toList();
  }
}


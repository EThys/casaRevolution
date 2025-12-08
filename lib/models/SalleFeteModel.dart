import 'dart:convert';

SalleFeteModel salleFeteModelFromJson(String str) => SalleFeteModel.fromJson(json.decode(str));
String salleFeteModelToJson(SalleFeteModel data) => json.encode(data.toJson());

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

class SalleFeteModel {
  int? salleFeteId;
  int? propertyId;
  
  // Capacité et dimensions
  int? eventCapacity;
  double? surfaceArea;
  
  // Équipements et services
  List<String>? eventEquipment;
  List<String>? includedServices;
  List<String>? amenities; // Liste de tous les équipements et services (WiFi, climatisation, cuisine, bar, son, lumière, etc.)
  bool? hasCatering;
  bool? hasDecoration;
  bool? hasSoundSystem;
  bool? hasLighting;
  bool? hasProjector;
  bool? hasStage;
  bool? hasDanceFloor;
  
  // Parking et accessibilité
  int? parkingSpaces;
  bool? hasParking;
  bool? isAccessible;
  bool? hasElevator;
  
  // Prix et disponibilité
  double? rentalPrice;
  int? minimumRentalDays; // Jours minimum de location
  int? maximumRentalDays; // Jours maximum de location
  String? availabilityStatus; // "available", "booked", "maintenance"
  List<String>? availableDates;
  List<String>? bookedDates;
  
  // Règles et restrictions
  String? cancellationPolicy;
  double? depositAmount;
  double? securityDeposit;
  int? advanceBookingDays;
  String? eventTypes; // "wedding", "birthday", "corporate", "all"
  bool? allowsAlcohol;
  bool? allowsMusic;
  int? maxNoiseLevel;
  String? restrictions;
  
  // Informations pratiques
  String? setupTime;
  String? breakdownTime;
  bool? providesTables;
  bool? providesChairs;
  int? numberOfTables;
  int? numberOfChairs;
  
  // Métadonnées
  String? createdAt;
  String? updatedAt;
  bool? isActive;
  bool? isVerified;

  SalleFeteModel({
    this.salleFeteId,
    this.propertyId,
    this.eventCapacity,
    this.surfaceArea,
    this.eventEquipment,
    this.includedServices,
    this.amenities,
    this.hasCatering,
    this.hasDecoration,
    this.hasSoundSystem,
    this.hasLighting,
    this.hasProjector,
    this.hasStage,
    this.hasDanceFloor,
    this.parkingSpaces,
    this.hasParking,
    this.isAccessible,
    this.hasElevator,
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
    this.eventTypes,
    this.allowsAlcohol,
    this.allowsMusic,
    this.maxNoiseLevel,
    this.restrictions,
    this.setupTime,
    this.breakdownTime,
    this.providesTables,
    this.providesChairs,
    this.numberOfTables,
    this.numberOfChairs,
    this.createdAt,
    this.updatedAt,
    this.isActive,
    this.isVerified,
  });

  factory SalleFeteModel.fromJson(Map<String, dynamic> json) => SalleFeteModel(
    salleFeteId: _parseInt(json["salleFeteId"]) ?? _parseInt(json["id"]),
    propertyId: _parseInt(json["propertyId"]),
    eventCapacity: _parseInt(json["eventCapacity"]),
    surfaceArea: _parseDouble(json["surfaceArea"]),
    eventEquipment: json["eventEquipment"] is List
        ? List<String>.from(json["eventEquipment"])
        : null,
    includedServices: json["includedServices"] is List
        ? List<String>.from(json["includedServices"])
        : null,
    amenities: json["amenities"] is List
        ? List<String>.from(json["amenities"])
        : (() {
            // Générer automatiquement amenities si non fourni à partir des champs JSON
            List<String> autoAmenities = [];
            if (_parseBool(json["hasParking"])) {
              autoAmenities.add("Parking");
              int? spaces = _parseInt(json["parkingSpaces"]);
              if (spaces != null && spaces > 0) {
                autoAmenities.add("Parking ($spaces places)");
              }
            }
            if (_parseBool(json["hasKitchen"])) autoAmenities.add("Cuisine");
            if (_parseBool(json["hasBar"])) autoAmenities.add("Bar");
            if (_parseBool(json["hasRestrooms"])) {
              autoAmenities.add("Toilettes");
              int? restrooms = _parseInt(json["numberOfRestrooms"]);
              if (restrooms != null && restrooms > 0) {
                autoAmenities.add("Toilettes ($restrooms)");
              }
            }
            if (_parseBool(json["hasAirConditioning"])) autoAmenities.add("Climatisation");
            if (_parseBool(json["hasHeating"])) autoAmenities.add("Chauffage");
            if (_parseBool(json["hasWiFi"])) autoAmenities.add("WiFi");
            if (_parseBool(json["hasSoundSystem"])) autoAmenities.add("Système sonore");
            if (_parseBool(json["hasLighting"])) autoAmenities.add("Éclairage professionnel");
            if (_parseBool(json["hasProjector"])) autoAmenities.add("Projecteur");
            if (_parseBool(json["hasStage"])) autoAmenities.add("Scène");
            if (_parseBool(json["hasDanceFloor"])) autoAmenities.add("Piste de danse");
            if (_parseBool(json["hasCatering"])) autoAmenities.add("Service traiteur");
            if (_parseBool(json["hasDecoration"])) autoAmenities.add("Service décoration");
            if (_parseBool(json["hasElevator"])) autoAmenities.add("Ascenseur");
            if (_parseBool(json["isAccessible"])) autoAmenities.add("Accessible PMR");
            if (_parseBool(json["providesTables"])) {
              autoAmenities.add("Tables");
              int? tables = _parseInt(json["numberOfTables"]);
              if (tables != null && tables > 0) {
                autoAmenities.add("Tables ($tables)");
              }
            }
            if (_parseBool(json["providesChairs"])) {
              autoAmenities.add("Chaises");
              int? chairs = _parseInt(json["numberOfChairs"]);
              if (chairs != null && chairs > 0) {
                autoAmenities.add("Chaises ($chairs)");
              }
            }
            return autoAmenities.isNotEmpty ? autoAmenities : null;
          })(),
    hasCatering: _parseBool(json["hasCatering"]),
    hasDecoration: _parseBool(json["hasDecoration"]),
    hasSoundSystem: _parseBool(json["hasSoundSystem"]),
    hasLighting: _parseBool(json["hasLighting"]),
    hasProjector: _parseBool(json["hasProjector"]),
    hasStage: _parseBool(json["hasStage"]),
    hasDanceFloor: _parseBool(json["hasDanceFloor"]),
    parkingSpaces: _parseInt(json["parkingSpaces"]),
    hasParking: _parseBool(json["hasParking"]),
    isAccessible: _parseBool(json["isAccessible"]),
    hasElevator: _parseBool(json["hasElevator"]),
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
    eventTypes: _parseString(json["eventTypes"]),
    allowsAlcohol: _parseBool(json["allowsAlcohol"]),
    allowsMusic: _parseBool(json["allowsMusic"]),
    maxNoiseLevel: _parseInt(json["maxNoiseLevel"]),
    restrictions: _parseString(json["restrictions"]),
    setupTime: _parseString(json["setupTime"]),
    breakdownTime: _parseString(json["breakdownTime"]),
    providesTables: _parseBool(json["providesTables"]),
    providesChairs: _parseBool(json["providesChairs"]),
    numberOfTables: _parseInt(json["numberOfTables"]),
    numberOfChairs: _parseInt(json["numberOfChairs"]),
    createdAt: _parseString(json["createdAt"]),
    updatedAt: _parseString(json["updatedAt"]),
    isActive: _parseBool(json["isActive"]) ?? true,
    isVerified: _parseBool(json["isVerified"]) ?? false,
  );

  Map<String, dynamic> toJson() => {
    "salleFeteId": salleFeteId,
    "propertyId": propertyId,
    "eventCapacity": eventCapacity,
    "surfaceArea": surfaceArea,
    "eventEquipment": eventEquipment,
    "includedServices": includedServices,
    "amenities": amenities,
    "hasCatering": hasCatering,
    "hasDecoration": hasDecoration,
    "hasSoundSystem": hasSoundSystem,
    "hasLighting": hasLighting,
    "hasProjector": hasProjector,
    "hasStage": hasStage,
    "hasDanceFloor": hasDanceFloor,
    "parkingSpaces": parkingSpaces,
    "hasParking": hasParking,
    "isAccessible": isAccessible,
    "hasElevator": hasElevator,
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
    "eventTypes": eventTypes,
    "allowsAlcohol": allowsAlcohol,
    "allowsMusic": allowsMusic,
    "maxNoiseLevel": maxNoiseLevel,
    "restrictions": restrictions,
    "setupTime": setupTime,
    "breakdownTime": breakdownTime,
    "providesTables": providesTables,
    "providesChairs": providesChairs,
    "numberOfTables": numberOfTables,
    "numberOfChairs": numberOfChairs,
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

  // Génère automatiquement la liste des amenities à partir des booléens et de la liste amenities
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
    
    // Équipements événementiels
    if (hasSoundSystem == true) amenitiesList.add("Système sonore");
    if (hasLighting == true) amenitiesList.add("Éclairage professionnel");
    if (hasProjector == true) amenitiesList.add("Projecteur");
    if (hasStage == true) amenitiesList.add("Scène");
    if (hasDanceFloor == true) amenitiesList.add("Piste de danse");
    
    // Services
    if (hasCatering == true) amenitiesList.add("Service traiteur");
    if (hasDecoration == true) amenitiesList.add("Service décoration");
    
    // Accessibilité
    if (hasElevator == true) amenitiesList.add("Ascenseur");
    if (isAccessible == true) amenitiesList.add("Accessible PMR");
    
    // Mobilier
    if (providesTables == true) {
      amenitiesList.add("Tables");
      if (numberOfTables != null && numberOfTables! > 0) {
        amenitiesList.add("Tables ($numberOfTables)");
      }
    }
    if (providesChairs == true) {
      amenitiesList.add("Chaises");
      if (numberOfChairs != null && numberOfChairs! > 0) {
        amenitiesList.add("Chaises ($numberOfChairs)");
      }
    }
    
    // Ajouter les équipements de eventEquipment
    if (eventEquipment != null && eventEquipment!.isNotEmpty) {
      amenitiesList.addAll(eventEquipment!);
    }
    
    // Ajouter les services inclus
    if (includedServices != null && includedServices!.isNotEmpty) {
      amenitiesList.addAll(includedServices!);
    }
    
    // Retourner une liste unique (sans doublons)
    return amenitiesList.toSet().toList();
  }
}


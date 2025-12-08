import 'dart:convert';

TerrainModel terrainModelFromJson(String str) => TerrainModel.fromJson(json.decode(str));
String terrainModelToJson(TerrainModel data) => json.encode(data.toJson());

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

class TerrainModel {
  int? terrainId;
  int? propertyId;
  
  // Dimensions et superficie
  double? landArea;
  double? width;
  double? length;
  double? perimeter;
  String? shape; // "rectangular", "square", "irregular", etc.
  
  // Type et usage
  String? landType; // "residential", "commercial", "agricultural", "industrial", "mixed"
  String? zoning; // "R1", "R2", "C1", "A1", etc.
  String? permittedUse;
  bool? allowsConstruction;
  bool? allowsFarming;
  bool? allowsParking;
  bool? allowsEvents;
  
  // Caractéristiques du terrain
  List<String>? landFeatures;
  String? soilType; // "clay", "sandy", "loamy", "rocky"
  String? topography; // "flat", "sloping", "hilly", "mountainous"
  double? elevation;
  bool? hasTrees;
  bool? hasWaterAccess;
  bool? hasElectricity;
  bool? hasWaterSupply;
  bool? hasSewerConnection;
  bool? hasRoadAccess;
  String? roadType; // "paved", "gravel", "dirt"
  
  // Clôture et sécurité
  bool? isFenced;
  String? fenceType; // "chain-link", "wood", "concrete", "none"
  double? fenceHeight;
  bool? hasGate;
  bool? hasSecurity;
  
  // Prix et disponibilité
  double? rentalPrice;
  double? monthlyRate;
  double? annualRate;
  String? rentalUnit; // "month", "year", "day"
  int? minimumRentalMonths;
  int? maximumRentalMonths;
  String? availabilityStatus; // "available", "rented", "maintenance"
  String? availableFrom;
  String? availableUntil;
  
  // Conditions de location
  String? cancellationPolicy;
  double? depositAmount;
  double? securityDeposit;
  int? advanceBookingDays;
  String? restrictions;
  bool? requiresInsurance;
  String? insuranceRequirements;
  
  // Accès et infrastructure
  bool? hasParking;
  int? parkingSpaces;
  bool? hasLoadingDock;
  bool? hasStorage;
  double? storageArea;
  bool? hasBuildings;
  int? numberOfBuildings;
  double? buildingArea;
  List<String>? buildingTypes;
  
  // Services et utilitaires
  bool? hasInternet;
  bool? hasPhoneLine;
  bool? hasGasConnection;
  String? waterSource; // "municipal", "well", "none"
  String? electricitySource; // "grid", "generator", "solar", "none"
  
  // Environnement
  String? nearbyFacilities; // "schools", "hospitals", "shopping", etc.
  double? distanceToCity;
  double? distanceToHighway;
  String? environmentalFactors;
  bool? isFloodZone;
  bool? isProtectedArea;
  
  // Métadonnées
  String? createdAt;
  String? updatedAt;
  bool? isActive;
  bool? isVerified;
  String? notes;

  TerrainModel({
    this.terrainId,
    this.propertyId,
    this.landArea,
    this.width,
    this.length,
    this.perimeter,
    this.shape,
    this.landType,
    this.zoning,
    this.permittedUse,
    this.allowsConstruction,
    this.allowsFarming,
    this.allowsParking,
    this.allowsEvents,
    this.landFeatures,
    this.soilType,
    this.topography,
    this.elevation,
    this.hasTrees,
    this.hasWaterAccess,
    this.hasElectricity,
    this.hasWaterSupply,
    this.hasSewerConnection,
    this.hasRoadAccess,
    this.roadType,
    this.isFenced,
    this.fenceType,
    this.fenceHeight,
    this.hasGate,
    this.hasSecurity,
    this.rentalPrice,
    this.monthlyRate,
    this.annualRate,
    this.rentalUnit,
    this.minimumRentalMonths,
    this.maximumRentalMonths,
    this.availabilityStatus,
    this.availableFrom,
    this.availableUntil,
    this.cancellationPolicy,
    this.depositAmount,
    this.securityDeposit,
    this.advanceBookingDays,
    this.restrictions,
    this.requiresInsurance,
    this.insuranceRequirements,
    this.hasParking,
    this.parkingSpaces,
    this.hasLoadingDock,
    this.hasStorage,
    this.storageArea,
    this.hasBuildings,
    this.numberOfBuildings,
    this.buildingArea,
    this.buildingTypes,
    this.hasInternet,
    this.hasPhoneLine,
    this.hasGasConnection,
    this.waterSource,
    this.electricitySource,
    this.nearbyFacilities,
    this.distanceToCity,
    this.distanceToHighway,
    this.environmentalFactors,
    this.isFloodZone,
    this.isProtectedArea,
    this.createdAt,
    this.updatedAt,
    this.isActive,
    this.isVerified,
    this.notes,
  });

  factory TerrainModel.fromJson(Map<String, dynamic> json) => TerrainModel(
    terrainId: _parseInt(json["terrainId"]) ?? _parseInt(json["id"]),
    propertyId: _parseInt(json["propertyId"]),
    landArea: _parseDouble(json["landArea"]),
    width: _parseDouble(json["width"]),
    length: _parseDouble(json["length"]),
    perimeter: _parseDouble(json["perimeter"]),
    shape: _parseString(json["shape"]),
    landType: _parseString(json["landType"]),
    zoning: _parseString(json["zoning"]),
    permittedUse: _parseString(json["permittedUse"]),
    allowsConstruction: _parseBool(json["allowsConstruction"]),
    allowsFarming: _parseBool(json["allowsFarming"]),
    allowsParking: _parseBool(json["allowsParking"]),
    allowsEvents: _parseBool(json["allowsEvents"]),
    landFeatures: json["landFeatures"] is List
        ? List<String>.from(json["landFeatures"])
        : null,
    soilType: _parseString(json["soilType"]),
    topography: _parseString(json["topography"]),
    elevation: _parseDouble(json["elevation"]),
    hasTrees: _parseBool(json["hasTrees"]),
    hasWaterAccess: _parseBool(json["hasWaterAccess"]),
    hasElectricity: _parseBool(json["hasElectricity"]),
    hasWaterSupply: _parseBool(json["hasWaterSupply"]),
    hasSewerConnection: _parseBool(json["hasSewerConnection"]),
    hasRoadAccess: _parseBool(json["hasRoadAccess"]),
    roadType: _parseString(json["roadType"]),
    isFenced: _parseBool(json["isFenced"]),
    fenceType: _parseString(json["fenceType"]),
    fenceHeight: _parseDouble(json["fenceHeight"]),
    hasGate: _parseBool(json["hasGate"]),
    hasSecurity: _parseBool(json["hasSecurity"]),
    rentalPrice: _parseDouble(json["rentalPrice"]),
    monthlyRate: _parseDouble(json["monthlyRate"]),
    annualRate: _parseDouble(json["annualRate"]),
    rentalUnit: _parseString(json["rentalUnit"]),
    minimumRentalMonths: _parseInt(json["minimumRentalMonths"]),
    maximumRentalMonths: _parseInt(json["maximumRentalMonths"]),
    availabilityStatus: _parseString(json["availabilityStatus"]) ?? "available",
    availableFrom: _parseString(json["availableFrom"]),
    availableUntil: _parseString(json["availableUntil"]),
    cancellationPolicy: _parseString(json["cancellationPolicy"]),
    depositAmount: _parseDouble(json["depositAmount"]),
    securityDeposit: _parseDouble(json["securityDeposit"]),
    advanceBookingDays: _parseInt(json["advanceBookingDays"]),
    restrictions: _parseString(json["restrictions"]),
    requiresInsurance: _parseBool(json["requiresInsurance"]),
    insuranceRequirements: _parseString(json["insuranceRequirements"]),
    hasParking: _parseBool(json["hasParking"]),
    parkingSpaces: _parseInt(json["parkingSpaces"]),
    hasLoadingDock: _parseBool(json["hasLoadingDock"]),
    hasStorage: _parseBool(json["hasStorage"]),
    storageArea: _parseDouble(json["storageArea"]),
    hasBuildings: _parseBool(json["hasBuildings"]),
    numberOfBuildings: _parseInt(json["numberOfBuildings"]),
    buildingArea: _parseDouble(json["buildingArea"]),
    buildingTypes: json["buildingTypes"] is List
        ? List<String>.from(json["buildingTypes"])
        : null,
    hasInternet: _parseBool(json["hasInternet"]),
    hasPhoneLine: _parseBool(json["hasPhoneLine"]),
    hasGasConnection: _parseBool(json["hasGasConnection"]),
    waterSource: _parseString(json["waterSource"]),
    electricitySource: _parseString(json["electricitySource"]),
    nearbyFacilities: _parseString(json["nearbyFacilities"]),
    distanceToCity: _parseDouble(json["distanceToCity"]),
    distanceToHighway: _parseDouble(json["distanceToHighway"]),
    environmentalFactors: _parseString(json["environmentalFactors"]),
    isFloodZone: _parseBool(json["isFloodZone"]),
    isProtectedArea: _parseBool(json["isProtectedArea"]),
    createdAt: _parseString(json["createdAt"]),
    updatedAt: _parseString(json["updatedAt"]),
    isActive: _parseBool(json["isActive"]) ?? true,
    isVerified: _parseBool(json["isVerified"]) ?? false,
    notes: _parseString(json["notes"]),
  );

  Map<String, dynamic> toJson() => {
    "terrainId": terrainId,
    "propertyId": propertyId,
    "landArea": landArea,
    "width": width,
    "length": length,
    "perimeter": perimeter,
    "shape": shape,
    "landType": landType,
    "zoning": zoning,
    "permittedUse": permittedUse,
    "allowsConstruction": allowsConstruction,
    "allowsFarming": allowsFarming,
    "allowsParking": allowsParking,
    "allowsEvents": allowsEvents,
    "landFeatures": landFeatures,
    "soilType": soilType,
    "topography": topography,
    "elevation": elevation,
    "hasTrees": hasTrees,
    "hasWaterAccess": hasWaterAccess,
    "hasElectricity": hasElectricity,
    "hasWaterSupply": hasWaterSupply,
    "hasSewerConnection": hasSewerConnection,
    "hasRoadAccess": hasRoadAccess,
    "roadType": roadType,
    "isFenced": isFenced,
    "fenceType": fenceType,
    "fenceHeight": fenceHeight,
    "hasGate": hasGate,
    "hasSecurity": hasSecurity,
    "rentalPrice": rentalPrice,
    "monthlyRate": monthlyRate,
    "annualRate": annualRate,
    "rentalUnit": rentalUnit,
    "minimumRentalMonths": minimumRentalMonths,
    "maximumRentalMonths": maximumRentalMonths,
    "availabilityStatus": availabilityStatus,
    "availableFrom": availableFrom,
    "availableUntil": availableUntil,
    "cancellationPolicy": cancellationPolicy,
    "depositAmount": depositAmount,
    "securityDeposit": securityDeposit,
    "advanceBookingDays": advanceBookingDays,
    "restrictions": restrictions,
    "requiresInsurance": requiresInsurance,
    "insuranceRequirements": insuranceRequirements,
    "hasParking": hasParking,
    "parkingSpaces": parkingSpaces,
    "hasLoadingDock": hasLoadingDock,
    "hasStorage": hasStorage,
    "storageArea": storageArea,
    "hasBuildings": hasBuildings,
    "numberOfBuildings": numberOfBuildings,
    "buildingArea": buildingArea,
    "buildingTypes": buildingTypes,
    "hasInternet": hasInternet,
    "hasPhoneLine": hasPhoneLine,
    "hasGasConnection": hasGasConnection,
    "waterSource": waterSource,
    "electricitySource": electricitySource,
    "nearbyFacilities": nearbyFacilities,
    "distanceToCity": distanceToCity,
    "distanceToHighway": distanceToHighway,
    "environmentalFactors": environmentalFactors,
    "isFloodZone": isFloodZone,
    "isProtectedArea": isProtectedArea,
    "createdAt": createdAt,
    "updatedAt": updatedAt,
    "isActive": isActive,
    "isVerified": isVerified,
    "notes": notes,
  };

  // Méthodes utilitaires
  String get formattedRentalPrice {
    if (rentalPrice == null) return "Prix sur demande";
    if (rentalUnit == "month") {
      return "${rentalPrice!.toStringAsFixed(0)}\$/mois";
    } else if (rentalUnit == "year") {
      return "${rentalPrice!.toStringAsFixed(0)}\$/an";
    } else {
      return "${rentalPrice!.toStringAsFixed(0)}\$/jour";
    }
  }

  String get formattedArea {
    if (landArea == null) return "0 m²";
    return "${landArea!.toStringAsFixed(2)} m²";
  }

  bool get isAvailable {
    return availabilityStatus == "available" && (isActive ?? true);
  }
}


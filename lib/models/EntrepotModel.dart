import 'dart:convert';

EntrepotModel entrepotModelFromJson(String str) => EntrepotModel.fromJson(json.decode(str));
String entrepotModelToJson(EntrepotModel data) => json.encode(data.toJson());

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

class EntrepotModel {
  int? entrepotId;
  int? propertyId;
  
  // Dimensions et superficie
  double? warehouseArea;
  double? ceilingHeight;
  double? width;
  double? length;
  double? loadingDockHeight;
  int? numberOfLoadingDocks;
  int? numberOfDoors;
  double? doorWidth;
  double? doorHeight;
  
  // Type et usage
  String? warehouseType; // "distribution", "cold_storage", "general", "refrigerated", "bonded"
  String? storageType; // "pallet", "rack", "bulk", "mixed"
  int? storageCapacity;
  double? maxWeightCapacity;
  String? permittedUse;
  List<String>? allowedIndustries;
  
  // Caractéristiques
  List<String>? warehouseFeatures;
  bool? hasClimateControl;
  String? temperatureRange;
  bool? isRefrigerated;
  double? minTemperature;
  double? maxTemperature;
  bool? hasHumidityControl;
  bool? hasVentilation;
  bool? hasFireSuppression;
  String? fireSuppressionType;
  bool? hasSprinklerSystem;
  bool? hasSecuritySystem;
  bool? hasAlarm;
  bool? hasCCTV;
  bool? has24HourSecurity;
  
  // Accès et transport
  bool? hasLoadingDock;
  bool? hasLeveler;
  bool? hasForkliftAccess;
  bool? hasCrane;
  double? craneCapacity;
  bool? hasRailAccess;
  bool? hasTruckAccess;
  String? accessRoadType;
  double? accessRoadWidth;
  bool? hasParking;
  int? parkingSpaces;
  int? truckParkingSpaces;
  
  // Infrastructure
  bool? hasOfficeSpace;
  double? officeArea;
  int? numberOfOffices;
  bool? hasRestroom;
  int? numberOfRestrooms;
  bool? hasBreakRoom;
  bool? hasKitchen;
  bool? hasLockerRoom;
  bool? hasChangingRoom;
  
  // Équipements
  bool? hasRacking;
  String? rackingType;
  bool? hasMezzanine;
  double? mezzanineArea;
  bool? hasConveyor;
  bool? hasPalletJack;
  bool? hasForklift;
  bool? providesEquipment;
  List<String>? availableEquipment;
  
  // Utilitaires et services
  bool? hasElectricity;
  int? electricalCapacity;
  String? electricalVoltage;
  bool? hasWater;
  bool? hasSewer;
  bool? hasGas;
  bool? hasCompressedAir;
  bool? hasInternet;
  bool? hasPhoneLine;
  bool? hasWiFi;
  
  // Prix et disponibilité
  double? rentalPrice;
  double? monthlyRate;
  double? annualRate;
  double? pricePerSquareMeter;
  String? rentalUnit; // "month", "year"
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
  double? minimumInsurance;
  bool? allowsSubletting;
  bool? allowsModifications;
  String? modificationPolicy;
  
  // Zonage et conformité
  String? zoning;
  bool? isBonded;
  bool? hasCustomsBond;
  bool? isHazmatApproved;
  List<String>? hazmatTypes;
  bool? isFoodGrade;
  bool? isPharmaceuticalGrade;
  String? certifications;
  List<String>? complianceStandards;
  
  // Localisation et accès
  double? distanceToHighway;
  double? distanceToPort;
  double? distanceToAirport;
  double? distanceToCity;
  bool? hasPublicTransport;
  String? transportationOptions;
  
  // Maintenance et services
  bool? includesMaintenance;
  bool? includesCleaning;
  bool? includesSecurity;
  bool? includesUtilities;
  List<String>? includedUtilities;
  List<String>? additionalServices;
  
  // Métadonnées
  String? createdAt;
  String? updatedAt;
  bool? isActive;
  bool? isVerified;
  String? notes;

  EntrepotModel({
    this.entrepotId,
    this.propertyId,
    this.warehouseArea,
    this.ceilingHeight,
    this.width,
    this.length,
    this.loadingDockHeight,
    this.numberOfLoadingDocks,
    this.numberOfDoors,
    this.doorWidth,
    this.doorHeight,
    this.warehouseType,
    this.storageType,
    this.storageCapacity,
    this.maxWeightCapacity,
    this.permittedUse,
    this.allowedIndustries,
    this.warehouseFeatures,
    this.hasClimateControl,
    this.temperatureRange,
    this.isRefrigerated,
    this.minTemperature,
    this.maxTemperature,
    this.hasHumidityControl,
    this.hasVentilation,
    this.hasFireSuppression,
    this.fireSuppressionType,
    this.hasSprinklerSystem,
    this.hasSecuritySystem,
    this.hasAlarm,
    this.hasCCTV,
    this.has24HourSecurity,
    this.hasLoadingDock,
    this.hasLeveler,
    this.hasForkliftAccess,
    this.hasCrane,
    this.craneCapacity,
    this.hasRailAccess,
    this.hasTruckAccess,
    this.accessRoadType,
    this.accessRoadWidth,
    this.hasParking,
    this.parkingSpaces,
    this.truckParkingSpaces,
    this.hasOfficeSpace,
    this.officeArea,
    this.numberOfOffices,
    this.hasRestroom,
    this.numberOfRestrooms,
    this.hasBreakRoom,
    this.hasKitchen,
    this.hasLockerRoom,
    this.hasChangingRoom,
    this.hasRacking,
    this.rackingType,
    this.hasMezzanine,
    this.mezzanineArea,
    this.hasConveyor,
    this.hasPalletJack,
    this.hasForklift,
    this.providesEquipment,
    this.availableEquipment,
    this.hasElectricity,
    this.electricalCapacity,
    this.electricalVoltage,
    this.hasWater,
    this.hasSewer,
    this.hasGas,
    this.hasCompressedAir,
    this.hasInternet,
    this.hasPhoneLine,
    this.hasWiFi,
    this.rentalPrice,
    this.monthlyRate,
    this.annualRate,
    this.pricePerSquareMeter,
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
    this.minimumInsurance,
    this.allowsSubletting,
    this.allowsModifications,
    this.modificationPolicy,
    this.zoning,
    this.isBonded,
    this.hasCustomsBond,
    this.isHazmatApproved,
    this.hazmatTypes,
    this.isFoodGrade,
    this.isPharmaceuticalGrade,
    this.certifications,
    this.complianceStandards,
    this.distanceToHighway,
    this.distanceToPort,
    this.distanceToAirport,
    this.distanceToCity,
    this.hasPublicTransport,
    this.transportationOptions,
    this.includesMaintenance,
    this.includesCleaning,
    this.includesSecurity,
    this.includesUtilities,
    this.includedUtilities,
    this.additionalServices,
    this.createdAt,
    this.updatedAt,
    this.isActive,
    this.isVerified,
    this.notes,
  });

  factory EntrepotModel.fromJson(Map<String, dynamic> json) => EntrepotModel(
    entrepotId: _parseInt(json["entrepotId"]) ?? _parseInt(json["id"]),
    propertyId: _parseInt(json["propertyId"]),
    warehouseArea: _parseDouble(json["warehouseArea"]),
    ceilingHeight: _parseDouble(json["ceilingHeight"]),
    width: _parseDouble(json["width"]),
    length: _parseDouble(json["length"]),
    loadingDockHeight: _parseDouble(json["loadingDockHeight"]),
    numberOfLoadingDocks: _parseInt(json["numberOfLoadingDocks"]),
    numberOfDoors: _parseInt(json["numberOfDoors"]),
    doorWidth: _parseDouble(json["doorWidth"]),
    doorHeight: _parseDouble(json["doorHeight"]),
    warehouseType: _parseString(json["warehouseType"]),
    storageType: _parseString(json["storageType"]),
    storageCapacity: _parseInt(json["storageCapacity"]),
    maxWeightCapacity: _parseDouble(json["maxWeightCapacity"]),
    permittedUse: _parseString(json["permittedUse"]),
    allowedIndustries: json["allowedIndustries"] is List
        ? List<String>.from(json["allowedIndustries"])
        : null,
    warehouseFeatures: json["warehouseFeatures"] is List
        ? List<String>.from(json["warehouseFeatures"])
        : null,
    hasClimateControl: _parseBool(json["hasClimateControl"]),
    temperatureRange: _parseString(json["temperatureRange"]),
    isRefrigerated: _parseBool(json["isRefrigerated"]),
    minTemperature: _parseDouble(json["minTemperature"]),
    maxTemperature: _parseDouble(json["maxTemperature"]),
    hasHumidityControl: _parseBool(json["hasHumidityControl"]),
    hasVentilation: _parseBool(json["hasVentilation"]),
    hasFireSuppression: _parseBool(json["hasFireSuppression"]),
    fireSuppressionType: _parseString(json["fireSuppressionType"]),
    hasSprinklerSystem: _parseBool(json["hasSprinklerSystem"]),
    hasSecuritySystem: _parseBool(json["hasSecuritySystem"]),
    hasAlarm: _parseBool(json["hasAlarm"]),
    hasCCTV: _parseBool(json["hasCCTV"]),
    has24HourSecurity: _parseBool(json["has24HourSecurity"]),
    hasLoadingDock: _parseBool(json["hasLoadingDock"]),
    hasLeveler: _parseBool(json["hasLeveler"]),
    hasForkliftAccess: _parseBool(json["hasForkliftAccess"]),
    hasCrane: _parseBool(json["hasCrane"]),
    craneCapacity: _parseDouble(json["craneCapacity"]),
    hasRailAccess: _parseBool(json["hasRailAccess"]),
    hasTruckAccess: _parseBool(json["hasTruckAccess"]),
    accessRoadType: _parseString(json["accessRoadType"]),
    accessRoadWidth: _parseDouble(json["accessRoadWidth"]),
    hasParking: _parseBool(json["hasParking"]),
    parkingSpaces: _parseInt(json["parkingSpaces"]),
    truckParkingSpaces: _parseInt(json["truckParkingSpaces"]),
    hasOfficeSpace: _parseBool(json["hasOfficeSpace"]),
    officeArea: _parseDouble(json["officeArea"]),
    numberOfOffices: _parseInt(json["numberOfOffices"]),
    hasRestroom: _parseBool(json["hasRestroom"]),
    numberOfRestrooms: _parseInt(json["numberOfRestrooms"]),
    hasBreakRoom: _parseBool(json["hasBreakRoom"]),
    hasKitchen: _parseBool(json["hasKitchen"]),
    hasLockerRoom: _parseBool(json["hasLockerRoom"]),
    hasChangingRoom: _parseBool(json["hasChangingRoom"]),
    hasRacking: _parseBool(json["hasRacking"]),
    rackingType: _parseString(json["rackingType"]),
    hasMezzanine: _parseBool(json["hasMezzanine"]),
    mezzanineArea: _parseDouble(json["mezzanineArea"]),
    hasConveyor: _parseBool(json["hasConveyor"]),
    hasPalletJack: _parseBool(json["hasPalletJack"]),
    hasForklift: _parseBool(json["hasForklift"]),
    providesEquipment: _parseBool(json["providesEquipment"]),
    availableEquipment: json["availableEquipment"] is List
        ? List<String>.from(json["availableEquipment"])
        : null,
    hasElectricity: _parseBool(json["hasElectricity"]),
    electricalCapacity: _parseInt(json["electricalCapacity"]),
    electricalVoltage: _parseString(json["electricalVoltage"]),
    hasWater: _parseBool(json["hasWater"]),
    hasSewer: _parseBool(json["hasSewer"]),
    hasGas: _parseBool(json["hasGas"]),
    hasCompressedAir: _parseBool(json["hasCompressedAir"]),
    hasInternet: _parseBool(json["hasInternet"]),
    hasPhoneLine: _parseBool(json["hasPhoneLine"]),
    hasWiFi: _parseBool(json["hasWiFi"]),
    rentalPrice: _parseDouble(json["rentalPrice"]),
    monthlyRate: _parseDouble(json["monthlyRate"]),
    annualRate: _parseDouble(json["annualRate"]),
    pricePerSquareMeter: _parseDouble(json["pricePerSquareMeter"]),
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
    minimumInsurance: _parseDouble(json["minimumInsurance"]),
    allowsSubletting: _parseBool(json["allowsSubletting"]),
    allowsModifications: _parseBool(json["allowsModifications"]),
    modificationPolicy: _parseString(json["modificationPolicy"]),
    zoning: _parseString(json["zoning"]),
    isBonded: _parseBool(json["isBonded"]),
    hasCustomsBond: _parseBool(json["hasCustomsBond"]),
    isHazmatApproved: _parseBool(json["isHazmatApproved"]),
    hazmatTypes: json["hazmatTypes"] is List
        ? List<String>.from(json["hazmatTypes"])
        : null,
    isFoodGrade: _parseBool(json["isFoodGrade"]),
    isPharmaceuticalGrade: _parseBool(json["isPharmaceuticalGrade"]),
    certifications: _parseString(json["certifications"]),
    complianceStandards: json["complianceStandards"] is List
        ? List<String>.from(json["complianceStandards"])
        : null,
    distanceToHighway: _parseDouble(json["distanceToHighway"]),
    distanceToPort: _parseDouble(json["distanceToPort"]),
    distanceToAirport: _parseDouble(json["distanceToAirport"]),
    distanceToCity: _parseDouble(json["distanceToCity"]),
    hasPublicTransport: _parseBool(json["hasPublicTransport"]),
    transportationOptions: _parseString(json["transportationOptions"]),
    includesMaintenance: _parseBool(json["includesMaintenance"]),
    includesCleaning: _parseBool(json["includesCleaning"]),
    includesSecurity: _parseBool(json["includesSecurity"]),
    includesUtilities: _parseBool(json["includesUtilities"]),
    includedUtilities: json["includedUtilities"] is List
        ? List<String>.from(json["includedUtilities"])
        : null,
    additionalServices: json["additionalServices"] is List
        ? List<String>.from(json["additionalServices"])
        : null,
    createdAt: _parseString(json["createdAt"]),
    updatedAt: _parseString(json["updatedAt"]),
    isActive: _parseBool(json["isActive"]) ?? true,
    isVerified: _parseBool(json["isVerified"]) ?? false,
    notes: _parseString(json["notes"]),
  );

  Map<String, dynamic> toJson() => {
    "entrepotId": entrepotId,
    "propertyId": propertyId,
    "warehouseArea": warehouseArea,
    "ceilingHeight": ceilingHeight,
    "width": width,
    "length": length,
    "loadingDockHeight": loadingDockHeight,
    "numberOfLoadingDocks": numberOfLoadingDocks,
    "numberOfDoors": numberOfDoors,
    "doorWidth": doorWidth,
    "doorHeight": doorHeight,
    "warehouseType": warehouseType,
    "storageType": storageType,
    "storageCapacity": storageCapacity,
    "maxWeightCapacity": maxWeightCapacity,
    "permittedUse": permittedUse,
    "allowedIndustries": allowedIndustries,
    "warehouseFeatures": warehouseFeatures,
    "hasClimateControl": hasClimateControl,
    "temperatureRange": temperatureRange,
    "isRefrigerated": isRefrigerated,
    "minTemperature": minTemperature,
    "maxTemperature": maxTemperature,
    "hasHumidityControl": hasHumidityControl,
    "hasVentilation": hasVentilation,
    "hasFireSuppression": hasFireSuppression,
    "fireSuppressionType": fireSuppressionType,
    "hasSprinklerSystem": hasSprinklerSystem,
    "hasSecuritySystem": hasSecuritySystem,
    "hasAlarm": hasAlarm,
    "hasCCTV": hasCCTV,
    "has24HourSecurity": has24HourSecurity,
    "hasLoadingDock": hasLoadingDock,
    "hasLeveler": hasLeveler,
    "hasForkliftAccess": hasForkliftAccess,
    "hasCrane": hasCrane,
    "craneCapacity": craneCapacity,
    "hasRailAccess": hasRailAccess,
    "hasTruckAccess": hasTruckAccess,
    "accessRoadType": accessRoadType,
    "accessRoadWidth": accessRoadWidth,
    "hasParking": hasParking,
    "parkingSpaces": parkingSpaces,
    "truckParkingSpaces": truckParkingSpaces,
    "hasOfficeSpace": hasOfficeSpace,
    "officeArea": officeArea,
    "numberOfOffices": numberOfOffices,
    "hasRestroom": hasRestroom,
    "numberOfRestrooms": numberOfRestrooms,
    "hasBreakRoom": hasBreakRoom,
    "hasKitchen": hasKitchen,
    "hasLockerRoom": hasLockerRoom,
    "hasChangingRoom": hasChangingRoom,
    "hasRacking": hasRacking,
    "rackingType": rackingType,
    "hasMezzanine": hasMezzanine,
    "mezzanineArea": mezzanineArea,
    "hasConveyor": hasConveyor,
    "hasPalletJack": hasPalletJack,
    "hasForklift": hasForklift,
    "providesEquipment": providesEquipment,
    "availableEquipment": availableEquipment,
    "hasElectricity": hasElectricity,
    "electricalCapacity": electricalCapacity,
    "electricalVoltage": electricalVoltage,
    "hasWater": hasWater,
    "hasSewer": hasSewer,
    "hasGas": hasGas,
    "hasCompressedAir": hasCompressedAir,
    "hasInternet": hasInternet,
    "hasPhoneLine": hasPhoneLine,
    "hasWiFi": hasWiFi,
    "rentalPrice": rentalPrice,
    "monthlyRate": monthlyRate,
    "annualRate": annualRate,
    "pricePerSquareMeter": pricePerSquareMeter,
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
    "minimumInsurance": minimumInsurance,
    "allowsSubletting": allowsSubletting,
    "allowsModifications": allowsModifications,
    "modificationPolicy": modificationPolicy,
    "zoning": zoning,
    "isBonded": isBonded,
    "hasCustomsBond": hasCustomsBond,
    "isHazmatApproved": isHazmatApproved,
    "hazmatTypes": hazmatTypes,
    "isFoodGrade": isFoodGrade,
    "isPharmaceuticalGrade": isPharmaceuticalGrade,
    "certifications": certifications,
    "complianceStandards": complianceStandards,
    "distanceToHighway": distanceToHighway,
    "distanceToPort": distanceToPort,
    "distanceToAirport": distanceToAirport,
    "distanceToCity": distanceToCity,
    "hasPublicTransport": hasPublicTransport,
    "transportationOptions": transportationOptions,
    "includesMaintenance": includesMaintenance,
    "includesCleaning": includesCleaning,
    "includesSecurity": includesSecurity,
    "includesUtilities": includesUtilities,
    "includedUtilities": includedUtilities,
    "additionalServices": additionalServices,
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
    } else {
      return "${rentalPrice!.toStringAsFixed(0)}\$/an";
    }
  }

  String get formattedArea {
    if (warehouseArea == null) return "0 m²";
    return "${warehouseArea!.toStringAsFixed(2)} m²";
  }

  bool get isAvailable {
    return availabilityStatus == "available" && (isActive ?? true);
  }
}


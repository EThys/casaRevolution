import 'dart:convert';

BureauModel bureauModelFromJson(String str) => BureauModel.fromJson(json.decode(str));
String bureauModelToJson(BureauModel data) => json.encode(data.toJson());

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

class BureauModel {
  int? bureauId;
  int? propertyId;
  
  // Dimensions et superficie
  double? surfaceArea;
  double? usableArea;
  int? floor;
  int? numberOfFloors;
  double? ceilingHeight;
  String? layout; // "open", "private", "mixed", "cubicle"
  
  // Capacité et espaces
  int? numberOfDesks;
  int? numberOfWorkstations;
  int? numberOfPrivateOffices;
  int? meetingRooms;
  int? conferenceRooms;
  int? capacity;
  int? maxOccupancy;
  double? meetingRoomArea;
  bool? hasReceptionArea;
  double? receptionArea;
  bool? hasBreakRoom;
  double? breakRoomArea;
  bool? hasKitchen;
  bool? hasPantry;
  bool? hasStorage;
  double? storageArea;
  bool? hasServerRoom;
  double? serverRoomArea;
  
  // Équipements et aménagements
  bool? hasFurniture;
  bool? providesDesks;
  bool? providesChairs;
  bool? providesFilingCabinets;
  bool? hasWhiteboards;
  int? numberOfWhiteboards;
  bool? hasProjectors;
  int? numberOfProjectors;
  bool? hasScreens;
  bool? hasVideoConferencing;
  bool? hasPhoneSystem;
  bool? hasIntercom;
  bool? hasReceptionDesk;
  bool? hasWaitingArea;
  int? waitingAreaSeats;
  
  // Technologie et connectivité
  bool? hasInternet;
  bool? hasWiFi;
  String? internetSpeed;
  bool? hasEthernet;
  int? ethernetPorts;
  bool? hasPhoneLines;
  int? numberOfPhoneLines;
  bool? hasFiberOptic;
  bool? hasCableTV;
  bool? hasSecurityCameras;
  bool? hasAccessControl;
  bool? hasKeycardAccess;
  bool? hasBiometricAccess;
  
  // Parking et accessibilité
  bool? hasParking;
  int? parkingSpaces;
  bool? hasReservedParking;
  int? reservedParkingSpaces;
  bool? hasVisitorParking;
  int? visitorParkingSpaces;
  bool? hasGarage;
  bool? hasElevator;
  bool? isAccessible;
  bool? hasRamp;
  bool? hasWheelchairAccess;
  int? numberOfRestrooms;
  bool? hasAccessibleRestrooms;
  
  // Services et commodités
  bool? hasSecurity;
  bool? has24HourSecurity;
  bool? hasReceptionist;
  bool? hasMailService;
  bool? hasPackageReceiving;
  bool? hasCleaningService;
  bool? hasMaintenanceService;
  bool? hasITSupport;
  bool? hasConcierge;
  bool? hasCafeteria;
  bool? hasCoffeeShop;
  bool? hasGym;
  bool? hasShower;
  bool? hasLockerRoom;
  bool? hasBikeStorage;
  bool? hasEVCharging;
  int? evChargingStations;
  
  // Climatisation et environnement
  bool? hasAirConditioning;
  bool? hasHeating;
  bool? hasVentilation;
  bool? hasNaturalLight;
  String? windowType; // "floor_to_ceiling", "standard", "none"
  bool? hasViews;
  String? viewType;
  bool? hasBalcony;
  bool? hasTerrace;
  bool? hasOutdoorSpace;
  
  // Prix et disponibilité
  double? rentalPrice;
  double? monthlyRate;
  double? annualRate;
  double? pricePerSquareMeter;
  double? pricePerDesk;
  String? rentalUnit; // "month", "year"
  int? minimumRentalMonths;
  int? maximumRentalMonths;
  String? availabilityStatus; // "available", "rented", "maintenance"
  String? availableFrom;
  String? availableUntil;
  bool? allowsShortTerm;
  int? minimumTermMonths;
  
  // Conditions de location
  String? cancellationPolicy;
  double? depositAmount;
  double? securityDeposit;
  int? advanceBookingDays;
  String? restrictions;
  bool? requiresInsurance;
  String? insuranceRequirements;
  bool? allowsSubletting;
  bool? allowsModifications;
  String? modificationPolicy;
  bool? allowsPets;
  bool? allowsSmoking;
  String? operatingHours;
  bool? has24HourAccess;
  
  // Services inclus
  bool? includesUtilities;
  List<String>? includedUtilities;
  bool? includesInternet;
  bool? includesPhone;
  bool? includesCleaning;
  bool? includesMaintenance;
  bool? includesSecurity;
  bool? includesFurniture;
  bool? includesParking;
  List<String>? additionalServices;
  
  // Type de bureau
  String? officeType; // "private", "shared", "coworking", "virtual", "serviced"
  String? businessType; // "corporate", "startup", "freelance", "all"
  bool? isCoworkingSpace;
  bool? isServicedOffice;
  bool? isVirtualOffice;
  bool? hasDedicatedDesks;
  bool? hasHotDesks;
  int? hotDeskCapacity;
  
  // Localisation et accès
  double? distanceToCity;
  double? distanceToPublicTransport;
  double? distanceToRestaurants;
  double? distanceToShopping;
  bool? hasPublicTransport;
  String? transportationOptions;
  String? nearbyFacilities;
  
  // Métadonnées
  String? createdAt;
  String? updatedAt;
  bool? isActive;
  bool? isVerified;
  double? rating;
  int? reviewCount;
  String? notes;

  BureauModel({
    this.bureauId,
    this.propertyId,
    this.surfaceArea,
    this.usableArea,
    this.floor,
    this.numberOfFloors,
    this.ceilingHeight,
    this.layout,
    this.numberOfDesks,
    this.numberOfWorkstations,
    this.numberOfPrivateOffices,
    this.meetingRooms,
    this.conferenceRooms,
    this.capacity,
    this.maxOccupancy,
    this.meetingRoomArea,
    this.hasReceptionArea,
    this.receptionArea,
    this.hasBreakRoom,
    this.breakRoomArea,
    this.hasKitchen,
    this.hasPantry,
    this.hasStorage,
    this.storageArea,
    this.hasServerRoom,
    this.serverRoomArea,
    this.hasFurniture,
    this.providesDesks,
    this.providesChairs,
    this.providesFilingCabinets,
    this.hasWhiteboards,
    this.numberOfWhiteboards,
    this.hasProjectors,
    this.numberOfProjectors,
    this.hasScreens,
    this.hasVideoConferencing,
    this.hasPhoneSystem,
    this.hasIntercom,
    this.hasReceptionDesk,
    this.hasWaitingArea,
    this.waitingAreaSeats,
    this.hasInternet,
    this.hasWiFi,
    this.internetSpeed,
    this.hasEthernet,
    this.ethernetPorts,
    this.hasPhoneLines,
    this.numberOfPhoneLines,
    this.hasFiberOptic,
    this.hasCableTV,
    this.hasSecurityCameras,
    this.hasAccessControl,
    this.hasKeycardAccess,
    this.hasBiometricAccess,
    this.hasParking,
    this.parkingSpaces,
    this.hasReservedParking,
    this.reservedParkingSpaces,
    this.hasVisitorParking,
    this.visitorParkingSpaces,
    this.hasGarage,
    this.hasElevator,
    this.isAccessible,
    this.hasRamp,
    this.hasWheelchairAccess,
    this.numberOfRestrooms,
    this.hasAccessibleRestrooms,
    this.hasSecurity,
    this.has24HourSecurity,
    this.hasReceptionist,
    this.hasMailService,
    this.hasPackageReceiving,
    this.hasCleaningService,
    this.hasMaintenanceService,
    this.hasITSupport,
    this.hasConcierge,
    this.hasCafeteria,
    this.hasCoffeeShop,
    this.hasGym,
    this.hasShower,
    this.hasLockerRoom,
    this.hasBikeStorage,
    this.hasEVCharging,
    this.evChargingStations,
    this.hasAirConditioning,
    this.hasHeating,
    this.hasVentilation,
    this.hasNaturalLight,
    this.windowType,
    this.hasViews,
    this.viewType,
    this.hasBalcony,
    this.hasTerrace,
    this.hasOutdoorSpace,
    this.rentalPrice,
    this.monthlyRate,
    this.annualRate,
    this.pricePerSquareMeter,
    this.pricePerDesk,
    this.rentalUnit,
    this.minimumRentalMonths,
    this.maximumRentalMonths,
    this.availabilityStatus,
    this.availableFrom,
    this.availableUntil,
    this.allowsShortTerm,
    this.minimumTermMonths,
    this.cancellationPolicy,
    this.depositAmount,
    this.securityDeposit,
    this.advanceBookingDays,
    this.restrictions,
    this.requiresInsurance,
    this.insuranceRequirements,
    this.allowsSubletting,
    this.allowsModifications,
    this.modificationPolicy,
    this.allowsPets,
    this.allowsSmoking,
    this.operatingHours,
    this.has24HourAccess,
    this.includesUtilities,
    this.includedUtilities,
    this.includesInternet,
    this.includesPhone,
    this.includesCleaning,
    this.includesMaintenance,
    this.includesSecurity,
    this.includesFurniture,
    this.includesParking,
    this.additionalServices,
    this.officeType,
    this.businessType,
    this.isCoworkingSpace,
    this.isServicedOffice,
    this.isVirtualOffice,
    this.hasDedicatedDesks,
    this.hasHotDesks,
    this.hotDeskCapacity,
    this.distanceToCity,
    this.distanceToPublicTransport,
    this.distanceToRestaurants,
    this.distanceToShopping,
    this.hasPublicTransport,
    this.transportationOptions,
    this.nearbyFacilities,
    this.createdAt,
    this.updatedAt,
    this.isActive,
    this.isVerified,
    this.rating,
    this.reviewCount,
    this.notes,
  });

  factory BureauModel.fromJson(Map<String, dynamic> json) => BureauModel(
    bureauId: _parseInt(json["bureauId"]) ?? _parseInt(json["id"]),
    propertyId: _parseInt(json["propertyId"]),
    surfaceArea: _parseDouble(json["surfaceArea"]),
    usableArea: _parseDouble(json["usableArea"]),
    floor: _parseInt(json["floor"]),
    numberOfFloors: _parseInt(json["numberOfFloors"]),
    ceilingHeight: _parseDouble(json["ceilingHeight"]),
    layout: _parseString(json["layout"]),
    numberOfDesks: _parseInt(json["numberOfDesks"]),
    numberOfWorkstations: _parseInt(json["numberOfWorkstations"]),
    numberOfPrivateOffices: _parseInt(json["numberOfPrivateOffices"]),
    meetingRooms: _parseInt(json["meetingRooms"]),
    conferenceRooms: _parseInt(json["conferenceRooms"]),
    capacity: _parseInt(json["capacity"]),
    maxOccupancy: _parseInt(json["maxOccupancy"]),
    meetingRoomArea: _parseDouble(json["meetingRoomArea"]),
    hasReceptionArea: _parseBool(json["hasReceptionArea"]),
    receptionArea: _parseDouble(json["receptionArea"]),
    hasBreakRoom: _parseBool(json["hasBreakRoom"]),
    breakRoomArea: _parseDouble(json["breakRoomArea"]),
    hasKitchen: _parseBool(json["hasKitchen"]),
    hasPantry: _parseBool(json["hasPantry"]),
    hasStorage: _parseBool(json["hasStorage"]),
    storageArea: _parseDouble(json["storageArea"]),
    hasServerRoom: _parseBool(json["hasServerRoom"]),
    serverRoomArea: _parseDouble(json["serverRoomArea"]),
    hasFurniture: _parseBool(json["hasFurniture"]),
    providesDesks: _parseBool(json["providesDesks"]),
    providesChairs: _parseBool(json["providesChairs"]),
    providesFilingCabinets: _parseBool(json["providesFilingCabinets"]),
    hasWhiteboards: _parseBool(json["hasWhiteboards"]),
    numberOfWhiteboards: _parseInt(json["numberOfWhiteboards"]),
    hasProjectors: _parseBool(json["hasProjectors"]),
    numberOfProjectors: _parseInt(json["numberOfProjectors"]),
    hasScreens: _parseBool(json["hasScreens"]),
    hasVideoConferencing: _parseBool(json["hasVideoConferencing"]),
    hasPhoneSystem: _parseBool(json["hasPhoneSystem"]),
    hasIntercom: _parseBool(json["hasIntercom"]),
    hasReceptionDesk: _parseBool(json["hasReceptionDesk"]),
    hasWaitingArea: _parseBool(json["hasWaitingArea"]),
    waitingAreaSeats: _parseInt(json["waitingAreaSeats"]),
    hasInternet: _parseBool(json["hasInternet"]),
    hasWiFi: _parseBool(json["hasWiFi"]),
    internetSpeed: _parseString(json["internetSpeed"]),
    hasEthernet: _parseBool(json["hasEthernet"]),
    ethernetPorts: _parseInt(json["ethernetPorts"]),
    hasPhoneLines: _parseBool(json["hasPhoneLines"]),
    numberOfPhoneLines: _parseInt(json["numberOfPhoneLines"]),
    hasFiberOptic: _parseBool(json["hasFiberOptic"]),
    hasCableTV: _parseBool(json["hasCableTV"]),
    hasSecurityCameras: _parseBool(json["hasSecurityCameras"]),
    hasAccessControl: _parseBool(json["hasAccessControl"]),
    hasKeycardAccess: _parseBool(json["hasKeycardAccess"]),
    hasBiometricAccess: _parseBool(json["hasBiometricAccess"]),
    hasParking: _parseBool(json["hasParking"]),
    parkingSpaces: _parseInt(json["parkingSpaces"]),
    hasReservedParking: _parseBool(json["hasReservedParking"]),
    reservedParkingSpaces: _parseInt(json["reservedParkingSpaces"]),
    hasVisitorParking: _parseBool(json["hasVisitorParking"]),
    visitorParkingSpaces: _parseInt(json["visitorParkingSpaces"]),
    hasGarage: _parseBool(json["hasGarage"]),
    hasElevator: _parseBool(json["hasElevator"]),
    isAccessible: _parseBool(json["isAccessible"]),
    hasRamp: _parseBool(json["hasRamp"]),
    hasWheelchairAccess: _parseBool(json["hasWheelchairAccess"]),
    numberOfRestrooms: _parseInt(json["numberOfRestrooms"]),
    hasAccessibleRestrooms: _parseBool(json["hasAccessibleRestrooms"]),
    hasSecurity: _parseBool(json["hasSecurity"]),
    has24HourSecurity: _parseBool(json["has24HourSecurity"]),
    hasReceptionist: _parseBool(json["hasReceptionist"]),
    hasMailService: _parseBool(json["hasMailService"]),
    hasPackageReceiving: _parseBool(json["hasPackageReceiving"]),
    hasCleaningService: _parseBool(json["hasCleaningService"]),
    hasMaintenanceService: _parseBool(json["hasMaintenanceService"]),
    hasITSupport: _parseBool(json["hasITSupport"]),
    hasConcierge: _parseBool(json["hasConcierge"]),
    hasCafeteria: _parseBool(json["hasCafeteria"]),
    hasCoffeeShop: _parseBool(json["hasCoffeeShop"]),
    hasGym: _parseBool(json["hasGym"]),
    hasShower: _parseBool(json["hasShower"]),
    hasLockerRoom: _parseBool(json["hasLockerRoom"]),
    hasBikeStorage: _parseBool(json["hasBikeStorage"]),
    hasEVCharging: _parseBool(json["hasEVCharging"]),
    evChargingStations: _parseInt(json["evChargingStations"]),
    hasAirConditioning: _parseBool(json["hasAirConditioning"]),
    hasHeating: _parseBool(json["hasHeating"]),
    hasVentilation: _parseBool(json["hasVentilation"]),
    hasNaturalLight: _parseBool(json["hasNaturalLight"]),
    windowType: _parseString(json["windowType"]),
    hasViews: _parseBool(json["hasViews"]),
    viewType: _parseString(json["viewType"]),
    hasBalcony: _parseBool(json["hasBalcony"]),
    hasTerrace: _parseBool(json["hasTerrace"]),
    hasOutdoorSpace: _parseBool(json["hasOutdoorSpace"]),
    rentalPrice: _parseDouble(json["rentalPrice"]),
    monthlyRate: _parseDouble(json["monthlyRate"]),
    annualRate: _parseDouble(json["annualRate"]),
    pricePerSquareMeter: _parseDouble(json["pricePerSquareMeter"]),
    pricePerDesk: _parseDouble(json["pricePerDesk"]),
    rentalUnit: _parseString(json["rentalUnit"]),
    minimumRentalMonths: _parseInt(json["minimumRentalMonths"]),
    maximumRentalMonths: _parseInt(json["maximumRentalMonths"]),
    availabilityStatus: _parseString(json["availabilityStatus"]) ?? "available",
    availableFrom: _parseString(json["availableFrom"]),
    availableUntil: _parseString(json["availableUntil"]),
    allowsShortTerm: _parseBool(json["allowsShortTerm"]),
    minimumTermMonths: _parseInt(json["minimumTermMonths"]),
    cancellationPolicy: _parseString(json["cancellationPolicy"]),
    depositAmount: _parseDouble(json["depositAmount"]),
    securityDeposit: _parseDouble(json["securityDeposit"]),
    advanceBookingDays: _parseInt(json["advanceBookingDays"]),
    restrictions: _parseString(json["restrictions"]),
    requiresInsurance: _parseBool(json["requiresInsurance"]),
    insuranceRequirements: _parseString(json["insuranceRequirements"]),
    allowsSubletting: _parseBool(json["allowsSubletting"]),
    allowsModifications: _parseBool(json["allowsModifications"]),
    modificationPolicy: _parseString(json["modificationPolicy"]),
    allowsPets: _parseBool(json["allowsPets"]),
    allowsSmoking: _parseBool(json["allowsSmoking"]),
    operatingHours: _parseString(json["operatingHours"]),
    has24HourAccess: _parseBool(json["has24HourAccess"]),
    includesUtilities: _parseBool(json["includesUtilities"]),
    includedUtilities: json["includedUtilities"] is List
        ? List<String>.from(json["includedUtilities"])
        : null,
    includesInternet: _parseBool(json["includesInternet"]),
    includesPhone: _parseBool(json["includesPhone"]),
    includesCleaning: _parseBool(json["includesCleaning"]),
    includesMaintenance: _parseBool(json["includesMaintenance"]),
    includesSecurity: _parseBool(json["includesSecurity"]),
    includesFurniture: _parseBool(json["includesFurniture"]),
    includesParking: _parseBool(json["includesParking"]),
    additionalServices: json["additionalServices"] is List
        ? List<String>.from(json["additionalServices"])
        : null,
    officeType: _parseString(json["officeType"]),
    businessType: _parseString(json["businessType"]),
    isCoworkingSpace: _parseBool(json["isCoworkingSpace"]),
    isServicedOffice: _parseBool(json["isServicedOffice"]),
    isVirtualOffice: _parseBool(json["isVirtualOffice"]),
    hasDedicatedDesks: _parseBool(json["hasDedicatedDesks"]),
    hasHotDesks: _parseBool(json["hasHotDesks"]),
    hotDeskCapacity: _parseInt(json["hotDeskCapacity"]),
    distanceToCity: _parseDouble(json["distanceToCity"]),
    distanceToPublicTransport: _parseDouble(json["distanceToPublicTransport"]),
    distanceToRestaurants: _parseDouble(json["distanceToRestaurants"]),
    distanceToShopping: _parseDouble(json["distanceToShopping"]),
    hasPublicTransport: _parseBool(json["hasPublicTransport"]),
    transportationOptions: _parseString(json["transportationOptions"]),
    nearbyFacilities: _parseString(json["nearbyFacilities"]),
    createdAt: _parseString(json["createdAt"]),
    updatedAt: _parseString(json["updatedAt"]),
    isActive: _parseBool(json["isActive"]) ?? true,
    isVerified: _parseBool(json["isVerified"]) ?? false,
    rating: _parseDouble(json["rating"]),
    reviewCount: _parseInt(json["reviewCount"]),
    notes: _parseString(json["notes"]),
  );

  Map<String, dynamic> toJson() => {
    "bureauId": bureauId,
    "propertyId": propertyId,
    "surfaceArea": surfaceArea,
    "usableArea": usableArea,
    "floor": floor,
    "numberOfFloors": numberOfFloors,
    "ceilingHeight": ceilingHeight,
    "layout": layout,
    "numberOfDesks": numberOfDesks,
    "numberOfWorkstations": numberOfWorkstations,
    "numberOfPrivateOffices": numberOfPrivateOffices,
    "meetingRooms": meetingRooms,
    "conferenceRooms": conferenceRooms,
    "capacity": capacity,
    "maxOccupancy": maxOccupancy,
    "meetingRoomArea": meetingRoomArea,
    "hasReceptionArea": hasReceptionArea,
    "receptionArea": receptionArea,
    "hasBreakRoom": hasBreakRoom,
    "breakRoomArea": breakRoomArea,
    "hasKitchen": hasKitchen,
    "hasPantry": hasPantry,
    "hasStorage": hasStorage,
    "storageArea": storageArea,
    "hasServerRoom": hasServerRoom,
    "serverRoomArea": serverRoomArea,
    "hasFurniture": hasFurniture,
    "providesDesks": providesDesks,
    "providesChairs": providesChairs,
    "providesFilingCabinets": providesFilingCabinets,
    "hasWhiteboards": hasWhiteboards,
    "numberOfWhiteboards": numberOfWhiteboards,
    "hasProjectors": hasProjectors,
    "numberOfProjectors": numberOfProjectors,
    "hasScreens": hasScreens,
    "hasVideoConferencing": hasVideoConferencing,
    "hasPhoneSystem": hasPhoneSystem,
    "hasIntercom": hasIntercom,
    "hasReceptionDesk": hasReceptionDesk,
    "hasWaitingArea": hasWaitingArea,
    "waitingAreaSeats": waitingAreaSeats,
    "hasInternet": hasInternet,
    "hasWiFi": hasWiFi,
    "internetSpeed": internetSpeed,
    "hasEthernet": hasEthernet,
    "ethernetPorts": ethernetPorts,
    "hasPhoneLines": hasPhoneLines,
    "numberOfPhoneLines": numberOfPhoneLines,
    "hasFiberOptic": hasFiberOptic,
    "hasCableTV": hasCableTV,
    "hasSecurityCameras": hasSecurityCameras,
    "hasAccessControl": hasAccessControl,
    "hasKeycardAccess": hasKeycardAccess,
    "hasBiometricAccess": hasBiometricAccess,
    "hasParking": hasParking,
    "parkingSpaces": parkingSpaces,
    "hasReservedParking": hasReservedParking,
    "reservedParkingSpaces": reservedParkingSpaces,
    "hasVisitorParking": hasVisitorParking,
    "visitorParkingSpaces": visitorParkingSpaces,
    "hasGarage": hasGarage,
    "hasElevator": hasElevator,
    "isAccessible": isAccessible,
    "hasRamp": hasRamp,
    "hasWheelchairAccess": hasWheelchairAccess,
    "numberOfRestrooms": numberOfRestrooms,
    "hasAccessibleRestrooms": hasAccessibleRestrooms,
    "hasSecurity": hasSecurity,
    "has24HourSecurity": has24HourSecurity,
    "hasReceptionist": hasReceptionist,
    "hasMailService": hasMailService,
    "hasPackageReceiving": hasPackageReceiving,
    "hasCleaningService": hasCleaningService,
    "hasMaintenanceService": hasMaintenanceService,
    "hasITSupport": hasITSupport,
    "hasConcierge": hasConcierge,
    "hasCafeteria": hasCafeteria,
    "hasCoffeeShop": hasCoffeeShop,
    "hasGym": hasGym,
    "hasShower": hasShower,
    "hasLockerRoom": hasLockerRoom,
    "hasBikeStorage": hasBikeStorage,
    "hasEVCharging": hasEVCharging,
    "evChargingStations": evChargingStations,
    "hasAirConditioning": hasAirConditioning,
    "hasHeating": hasHeating,
    "hasVentilation": hasVentilation,
    "hasNaturalLight": hasNaturalLight,
    "windowType": windowType,
    "hasViews": hasViews,
    "viewType": viewType,
    "hasBalcony": hasBalcony,
    "hasTerrace": hasTerrace,
    "hasOutdoorSpace": hasOutdoorSpace,
    "rentalPrice": rentalPrice,
    "monthlyRate": monthlyRate,
    "annualRate": annualRate,
    "pricePerSquareMeter": pricePerSquareMeter,
    "pricePerDesk": pricePerDesk,
    "rentalUnit": rentalUnit,
    "minimumRentalMonths": minimumRentalMonths,
    "maximumRentalMonths": maximumRentalMonths,
    "availabilityStatus": availabilityStatus,
    "availableFrom": availableFrom,
    "availableUntil": availableUntil,
    "allowsShortTerm": allowsShortTerm,
    "minimumTermMonths": minimumTermMonths,
    "cancellationPolicy": cancellationPolicy,
    "depositAmount": depositAmount,
    "securityDeposit": securityDeposit,
    "advanceBookingDays": advanceBookingDays,
    "restrictions": restrictions,
    "requiresInsurance": requiresInsurance,
    "insuranceRequirements": insuranceRequirements,
    "allowsSubletting": allowsSubletting,
    "allowsModifications": allowsModifications,
    "modificationPolicy": modificationPolicy,
    "allowsPets": allowsPets,
    "allowsSmoking": allowsSmoking,
    "operatingHours": operatingHours,
    "has24HourAccess": has24HourAccess,
    "includesUtilities": includesUtilities,
    "includedUtilities": includedUtilities,
    "includesInternet": includesInternet,
    "includesPhone": includesPhone,
    "includesCleaning": includesCleaning,
    "includesMaintenance": includesMaintenance,
    "includesSecurity": includesSecurity,
    "includesFurniture": includesFurniture,
    "includesParking": includesParking,
    "additionalServices": additionalServices,
    "officeType": officeType,
    "businessType": businessType,
    "isCoworkingSpace": isCoworkingSpace,
    "isServicedOffice": isServicedOffice,
    "isVirtualOffice": isVirtualOffice,
    "hasDedicatedDesks": hasDedicatedDesks,
    "hasHotDesks": hasHotDesks,
    "hotDeskCapacity": hotDeskCapacity,
    "distanceToCity": distanceToCity,
    "distanceToPublicTransport": distanceToPublicTransport,
    "distanceToRestaurants": distanceToRestaurants,
    "distanceToShopping": distanceToShopping,
    "hasPublicTransport": hasPublicTransport,
    "transportationOptions": transportationOptions,
    "nearbyFacilities": nearbyFacilities,
    "createdAt": createdAt,
    "updatedAt": updatedAt,
    "isActive": isActive,
    "isVerified": isVerified,
    "rating": rating,
    "reviewCount": reviewCount,
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
    if (surfaceArea == null) return "0 m²";
    return "${surfaceArea!.toStringAsFixed(2)} m²";
  }

  bool get isAvailable {
    return availabilityStatus == "available" && (isActive ?? true);
  }
}


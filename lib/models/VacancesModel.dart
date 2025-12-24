import 'dart:convert';

VacancesModel vacancesModelFromJson(String str) => VacancesModel.fromJson(json.decode(str));
String vacancesModelToJson(VacancesModel data) => json.encode(data.toJson());

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

class VacancesModel {
  int? vacancesId;
  int? propertyId;
  int? userId;
  int? agenceId;
  String? title;
  String? description;
  String? note;
  String? dateVacance;
  String? heureVacance;
  double? price;
  String? priceCombo;
  String? offre;
  String? address;
  String? cityValue;
  String? countryValue;
  
  // Capacité et hébergement
  int? capacity;
  int? numberOfBedrooms;
  int? numberOfBeds;
  int? numberOfBathrooms;
  int? maxGuests;
  int? numberOfUnits; // Pour les complexes de vacances
  
  // Type de vacances
  String? vacationType; // "apartment", "house", "villa", "cottage", "resort", "cabin"
  String? accommodationType; // "entire", "private", "shared"
  
  // Équipements et commodités
  List<String>? vacationAmenities;
  bool? hasKitchen;
  bool? hasFullKitchen;
  bool? hasWashingMachine;
  bool? hasDryer;
  bool? hasDishwasher;
  bool? hasMicrowave;
  bool? hasRefrigerator;
  bool? hasOven;
  bool? hasStove;
  bool? hasCoffeeMaker;
  bool? hasTV;
  bool? hasCableTV;
  bool? hasStreaming;
  bool? hasWiFi;
  bool? hasAirConditioning;
  bool? hasHeating;
  bool? hasFireplace;
  bool? hasBalcony;
  bool? hasTerrace;
  bool? hasGarden;
  bool? hasPool;
  bool? hasHotTub;
  bool? hasJacuzzi;
  bool? hasSauna;
  bool? hasGym;
  bool? hasParking;
  int? parkingSpaces;
  bool? hasGarage;
  bool? hasBBQ;
  bool? hasOutdoorFurniture;
  bool? hasBeachAccess;
  bool? hasMountainView;
  bool? hasSeaView;
  bool? hasLakeView;
  
  // Prix et disponibilité
  double? rentalPrice;
  double? nightlyRate;
  double? weeklyRate;
  double? monthlyRate;
  double? cleaningFee;
  double? serviceFee;
  String? currency;
  String? availabilityStatus; // "available", "booked", "maintenance"
  String? checkInTime;
  String? checkOutTime;
  int? minimumStayNights;
  int? maximumStayNights;
  List<String>? availableDates;
  List<String>? bookedDates;
  bool? instantBooking;
  
  // Conditions de location
  String? cancellationPolicy; // "flexible", "moderate", "strict", "super_strict"
  double? depositAmount;
  double? securityDeposit;
  int? advanceBookingDays;
  String? restrictions;
  bool? allowsPets;
  bool? allowsSmoking;
  bool? allowsEvents;
  bool? allowsParties;
  int? maxEventGuests;
  bool? allowsChildren;
  bool? isFamilyFriendly;
  bool? isPetFriendly;
  bool? isWheelchairAccessible;
  
  // Services inclus
  bool? includesBreakfast;
  bool? includesCleaning;
  bool? includesLinen;
  bool? includesTowels;
  bool? includesToiletries;
  bool? hasConcierge;
  bool? hasRoomService;
  bool? hasLaundryService;
  List<String>? additionalServices;
  
  // Localisation et accès
  double? distanceToBeach;
  double? distanceToCity;
  double? distanceToAirport;
  double? distanceToRestaurants;
  double? distanceToShopping;
  String? nearbyAttractions;
  bool? hasPublicTransport;
  String? transportationOptions;
  
  // Sécurité et équipements
  bool? hasSecurity;
  bool? hasSafe;
  bool? hasSmokeDetector;
  bool? hasCarbonMonoxideDetector;
  bool? hasFirstAidKit;
  bool? hasFireExtinguisher;
  bool? hasLockbox;
  bool? hasKeylessEntry;
  
  // Règles de la maison
  String? houseRules;
  String? checkInInstructions;
  String? checkOutInstructions;
  String? emergencyContact;
  
  // Métadonnées
  String? createdAt;
  String? updatedAt;
  bool? isActive;
  bool? isVerified;
  double? rating;
  int? reviewCount;
  String? notes;

  VacancesModel({
    this.vacancesId,
    this.propertyId,
    this.userId,
    this.agenceId,
    this.title,
    this.description,
    this.note,
    this.dateVacance,
    this.heureVacance,
    this.price,
    this.priceCombo,
    this.offre,
    this.address,
    this.cityValue,
    this.countryValue,
    this.capacity,
    this.numberOfBedrooms,
    this.numberOfBeds,
    this.numberOfBathrooms,
    this.maxGuests,
    this.numberOfUnits,
    this.vacationType,
    this.accommodationType,
    this.vacationAmenities,
    this.hasKitchen,
    this.hasFullKitchen,
    this.hasWashingMachine,
    this.hasDryer,
    this.hasDishwasher,
    this.hasMicrowave,
    this.hasRefrigerator,
    this.hasOven,
    this.hasStove,
    this.hasCoffeeMaker,
    this.hasTV,
    this.hasCableTV,
    this.hasStreaming,
    this.hasWiFi,
    this.hasAirConditioning,
    this.hasHeating,
    this.hasFireplace,
    this.hasBalcony,
    this.hasTerrace,
    this.hasGarden,
    this.hasPool,
    this.hasHotTub,
    this.hasJacuzzi,
    this.hasSauna,
    this.hasGym,
    this.hasParking,
    this.parkingSpaces,
    this.hasGarage,
    this.hasBBQ,
    this.hasOutdoorFurniture,
    this.hasBeachAccess,
    this.hasMountainView,
    this.hasSeaView,
    this.hasLakeView,
    this.rentalPrice,
    this.nightlyRate,
    this.weeklyRate,
    this.monthlyRate,
    this.cleaningFee,
    this.serviceFee,
    this.currency,
    this.availabilityStatus,
    this.checkInTime,
    this.checkOutTime,
    this.minimumStayNights,
    this.maximumStayNights,
    this.availableDates,
    this.bookedDates,
    this.instantBooking,
    this.cancellationPolicy,
    this.depositAmount,
    this.securityDeposit,
    this.advanceBookingDays,
    this.restrictions,
    this.allowsPets,
    this.allowsSmoking,
    this.allowsEvents,
    this.allowsParties,
    this.maxEventGuests,
    this.allowsChildren,
    this.isFamilyFriendly,
    this.isPetFriendly,
    this.isWheelchairAccessible,
    this.includesBreakfast,
    this.includesCleaning,
    this.includesLinen,
    this.includesTowels,
    this.includesToiletries,
    this.hasConcierge,
    this.hasRoomService,
    this.hasLaundryService,
    this.additionalServices,
    this.distanceToBeach,
    this.distanceToCity,
    this.distanceToAirport,
    this.distanceToRestaurants,
    this.distanceToShopping,
    this.nearbyAttractions,
    this.hasPublicTransport,
    this.transportationOptions,
    this.hasSecurity,
    this.hasSafe,
    this.hasSmokeDetector,
    this.hasCarbonMonoxideDetector,
    this.hasFirstAidKit,
    this.hasFireExtinguisher,
    this.hasLockbox,
    this.hasKeylessEntry,
    this.houseRules,
    this.checkInInstructions,
    this.checkOutInstructions,
    this.emergencyContact,
    this.createdAt,
    this.updatedAt,
    this.isActive,
    this.isVerified,
    this.rating,
    this.reviewCount,
    this.notes,
  });

  factory VacancesModel.fromJson(Map<String, dynamic> json) => VacancesModel(
    vacancesId: _parseInt(json["vacancesId"]) ?? _parseInt(json["id"]),
    propertyId: _parseInt(json["propertyId"]),
    userId: _parseInt(json["userId"]),
    agenceId: _parseInt(json["agenceId"]),
    title: _parseString(json["title"]),
    description: _parseString(json["description"]),
    note: _parseString(json["note"]),
    dateVacance: _parseString(json["dateVacance"]),
    heureVacance: _parseString(json["heureVacance"]),
    price: _parseDouble(json["price"]),
    priceCombo: _parseString(json["priceCombo"]),
    offre: _parseString(json["offre"]),
    address: _parseString(json["address"]),
    cityValue: _parseString(json["cityValue"]),
    countryValue: _parseString(json["countryValue"]),
    capacity: _parseInt(json["capacity"]),
    numberOfBedrooms: _parseInt(json["numberOfBedrooms"]),
    numberOfBeds: _parseInt(json["numberOfBeds"]),
    numberOfBathrooms: _parseInt(json["numberOfBathrooms"]),
    maxGuests: _parseInt(json["maxGuests"]),
    numberOfUnits: _parseInt(json["numberOfUnits"]),
    vacationType: _parseString(json["vacationType"]),
    accommodationType: _parseString(json["accommodationType"]),
    vacationAmenities: json["vacationAmenities"] is List
        ? List<String>.from(json["vacationAmenities"])
        : null,
    hasKitchen: _parseBool(json["hasKitchen"]),
    hasFullKitchen: _parseBool(json["hasFullKitchen"]),
    hasWashingMachine: _parseBool(json["hasWashingMachine"]),
    hasDryer: _parseBool(json["hasDryer"]),
    hasDishwasher: _parseBool(json["hasDishwasher"]),
    hasMicrowave: _parseBool(json["hasMicrowave"]),
    hasRefrigerator: _parseBool(json["hasRefrigerator"]),
    hasOven: _parseBool(json["hasOven"]),
    hasStove: _parseBool(json["hasStove"]),
    hasCoffeeMaker: _parseBool(json["hasCoffeeMaker"]),
    hasTV: _parseBool(json["hasTV"]),
    hasCableTV: _parseBool(json["hasCableTV"]),
    hasStreaming: _parseBool(json["hasStreaming"]),
    hasWiFi: _parseBool(json["hasWiFi"]),
    hasAirConditioning: _parseBool(json["hasAirConditioning"]),
    hasHeating: _parseBool(json["hasHeating"]),
    hasFireplace: _parseBool(json["hasFireplace"]),
    hasBalcony: _parseBool(json["hasBalcony"]),
    hasTerrace: _parseBool(json["hasTerrace"]),
    hasGarden: _parseBool(json["hasGarden"]),
    hasPool: _parseBool(json["hasPool"]),
    hasHotTub: _parseBool(json["hasHotTub"]),
    hasJacuzzi: _parseBool(json["hasJacuzzi"]),
    hasSauna: _parseBool(json["hasSauna"]),
    hasGym: _parseBool(json["hasGym"]),
    hasParking: _parseBool(json["hasParking"]),
    parkingSpaces: _parseInt(json["parkingSpaces"]),
    hasGarage: _parseBool(json["hasGarage"]),
    hasBBQ: _parseBool(json["hasBBQ"]),
    hasOutdoorFurniture: _parseBool(json["hasOutdoorFurniture"]),
    hasBeachAccess: _parseBool(json["hasBeachAccess"]),
    hasMountainView: _parseBool(json["hasMountainView"]),
    hasSeaView: _parseBool(json["hasSeaView"]),
    hasLakeView: _parseBool(json["hasLakeView"]),
    rentalPrice: _parseDouble(json["rentalPrice"]),
    nightlyRate: _parseDouble(json["nightlyRate"]),
    weeklyRate: _parseDouble(json["weeklyRate"]),
    monthlyRate: _parseDouble(json["monthlyRate"]),
    cleaningFee: _parseDouble(json["cleaningFee"]),
    serviceFee: _parseDouble(json["serviceFee"]),
    currency: _parseString(json["currency"]) ?? "USD",
    availabilityStatus: _parseString(json["availabilityStatus"]) ?? "available",
    checkInTime: _parseString(json["checkInTime"]) ?? "15:00",
    checkOutTime: _parseString(json["checkOutTime"]) ?? "11:00",
    minimumStayNights: _parseInt(json["minimumStayNights"]),
    maximumStayNights: _parseInt(json["maximumStayNights"]),
    availableDates: json["availableDates"] is List
        ? List<String>.from(json["availableDates"])
        : null,
    bookedDates: json["bookedDates"] is List
        ? List<String>.from(json["bookedDates"])
        : null,
    instantBooking: _parseBool(json["instantBooking"]),
    cancellationPolicy: _parseString(json["cancellationPolicy"]),
    depositAmount: _parseDouble(json["depositAmount"]),
    securityDeposit: _parseDouble(json["securityDeposit"]),
    advanceBookingDays: _parseInt(json["advanceBookingDays"]),
    restrictions: _parseString(json["restrictions"]),
    allowsPets: _parseBool(json["allowsPets"]),
    allowsSmoking: _parseBool(json["allowsSmoking"]),
    allowsEvents: _parseBool(json["allowsEvents"]),
    allowsParties: _parseBool(json["allowsParties"]),
    maxEventGuests: _parseInt(json["maxEventGuests"]),
    allowsChildren: _parseBool(json["allowsChildren"]),
    isFamilyFriendly: _parseBool(json["isFamilyFriendly"]),
    isPetFriendly: _parseBool(json["isPetFriendly"]),
    isWheelchairAccessible: _parseBool(json["isWheelchairAccessible"]),
    includesBreakfast: _parseBool(json["includesBreakfast"]),
    includesCleaning: _parseBool(json["includesCleaning"]),
    includesLinen: _parseBool(json["includesLinen"]),
    includesTowels: _parseBool(json["includesTowels"]),
    includesToiletries: _parseBool(json["includesToiletries"]),
    hasConcierge: _parseBool(json["hasConcierge"]),
    hasRoomService: _parseBool(json["hasRoomService"]),
    hasLaundryService: _parseBool(json["hasLaundryService"]),
    additionalServices: json["additionalServices"] is List
        ? List<String>.from(json["additionalServices"])
        : null,
    distanceToBeach: _parseDouble(json["distanceToBeach"]),
    distanceToCity: _parseDouble(json["distanceToCity"]),
    distanceToAirport: _parseDouble(json["distanceToAirport"]),
    distanceToRestaurants: _parseDouble(json["distanceToRestaurants"]),
    distanceToShopping: _parseDouble(json["distanceToShopping"]),
    nearbyAttractions: _parseString(json["nearbyAttractions"]),
    hasPublicTransport: _parseBool(json["hasPublicTransport"]),
    transportationOptions: _parseString(json["transportationOptions"]),
    hasSecurity: _parseBool(json["hasSecurity"]),
    hasSafe: _parseBool(json["hasSafe"]),
    hasSmokeDetector: _parseBool(json["hasSmokeDetector"]),
    hasCarbonMonoxideDetector: _parseBool(json["hasCarbonMonoxideDetector"]),
    hasFirstAidKit: _parseBool(json["hasFirstAidKit"]),
    hasFireExtinguisher: _parseBool(json["hasFireExtinguisher"]),
    hasLockbox: _parseBool(json["hasLockbox"]),
    hasKeylessEntry: _parseBool(json["hasKeylessEntry"]),
    houseRules: _parseString(json["houseRules"]),
    checkInInstructions: _parseString(json["checkInInstructions"]),
    checkOutInstructions: _parseString(json["checkOutInstructions"]),
    emergencyContact: _parseString(json["emergencyContact"]),
    createdAt: _parseString(json["createdAt"]),
    updatedAt: _parseString(json["updatedAt"]),
    isActive: json["isActive"] == null ? true : _parseBool(json["isActive"]),
    isVerified: _parseBool(json["isVerified"]),
    rating: _parseDouble(json["rating"]),
    reviewCount: _parseInt(json["reviewCount"]),
    notes: _parseString(json["notes"]),
  );

  Map<String, dynamic> toJson() => {
    "vacancesId": vacancesId,
    "propertyId": propertyId,
    "userId": userId,
    "agenceId": agenceId,
    "title": title,
    "description": description,
    "note": note,
    "dateVacance": dateVacance,
    "heureVacance": heureVacance,
    "price": price,
    "priceCombo": priceCombo,
    "offre": offre,
    "address": address,
    "cityValue": cityValue,
    "countryValue": countryValue,
    "capacity": capacity,
    "numberOfBedrooms": numberOfBedrooms,
    "numberOfBeds": numberOfBeds,
    "numberOfBathrooms": numberOfBathrooms,
    "maxGuests": maxGuests,
    "numberOfUnits": numberOfUnits,
    "vacationType": vacationType,
    "accommodationType": accommodationType,
    "vacationAmenities": vacationAmenities,
    "hasKitchen": hasKitchen,
    "hasFullKitchen": hasFullKitchen,
    "hasWashingMachine": hasWashingMachine,
    "hasDryer": hasDryer,
    "hasDishwasher": hasDishwasher,
    "hasMicrowave": hasMicrowave,
    "hasRefrigerator": hasRefrigerator,
    "hasOven": hasOven,
    "hasStove": hasStove,
    "hasCoffeeMaker": hasCoffeeMaker,
    "hasTV": hasTV,
    "hasCableTV": hasCableTV,
    "hasStreaming": hasStreaming,
    "hasWiFi": hasWiFi,
    "hasAirConditioning": hasAirConditioning,
    "hasHeating": hasHeating,
    "hasFireplace": hasFireplace,
    "hasBalcony": hasBalcony,
    "hasTerrace": hasTerrace,
    "hasGarden": hasGarden,
    "hasPool": hasPool,
    "hasHotTub": hasHotTub,
    "hasJacuzzi": hasJacuzzi,
    "hasSauna": hasSauna,
    "hasGym": hasGym,
    "hasParking": hasParking,
    "parkingSpaces": parkingSpaces,
    "hasGarage": hasGarage,
    "hasBBQ": hasBBQ,
    "hasOutdoorFurniture": hasOutdoorFurniture,
    "hasBeachAccess": hasBeachAccess,
    "hasMountainView": hasMountainView,
    "hasSeaView": hasSeaView,
    "hasLakeView": hasLakeView,
    "rentalPrice": rentalPrice,
    "nightlyRate": nightlyRate,
    "weeklyRate": weeklyRate,
    "monthlyRate": monthlyRate,
    "cleaningFee": cleaningFee,
    "serviceFee": serviceFee,
    "currency": currency,
    "availabilityStatus": availabilityStatus,
    "checkInTime": checkInTime,
    "checkOutTime": checkOutTime,
    "minimumStayNights": minimumStayNights,
    "maximumStayNights": maximumStayNights,
    "availableDates": availableDates,
    "bookedDates": bookedDates,
    "instantBooking": instantBooking,
    "cancellationPolicy": cancellationPolicy,
    "depositAmount": depositAmount,
    "securityDeposit": securityDeposit,
    "advanceBookingDays": advanceBookingDays,
    "restrictions": restrictions,
    "allowsPets": allowsPets,
    "allowsSmoking": allowsSmoking,
    "allowsEvents": allowsEvents,
    "allowsParties": allowsParties,
    "maxEventGuests": maxEventGuests,
    "allowsChildren": allowsChildren,
    "isFamilyFriendly": isFamilyFriendly,
    "isPetFriendly": isPetFriendly,
    "isWheelchairAccessible": isWheelchairAccessible,
    "includesBreakfast": includesBreakfast,
    "includesCleaning": includesCleaning,
    "includesLinen": includesLinen,
    "includesTowels": includesTowels,
    "includesToiletries": includesToiletries,
    "hasConcierge": hasConcierge,
    "hasRoomService": hasRoomService,
    "hasLaundryService": hasLaundryService,
    "additionalServices": additionalServices,
    "distanceToBeach": distanceToBeach,
    "distanceToCity": distanceToCity,
    "distanceToAirport": distanceToAirport,
    "distanceToRestaurants": distanceToRestaurants,
    "distanceToShopping": distanceToShopping,
    "nearbyAttractions": nearbyAttractions,
    "hasPublicTransport": hasPublicTransport,
    "transportationOptions": transportationOptions,
    "hasSecurity": hasSecurity,
    "hasSafe": hasSafe,
    "hasSmokeDetector": hasSmokeDetector,
    "hasCarbonMonoxideDetector": hasCarbonMonoxideDetector,
    "hasFirstAidKit": hasFirstAidKit,
    "hasFireExtinguisher": hasFireExtinguisher,
    "hasLockbox": hasLockbox,
    "hasKeylessEntry": hasKeylessEntry,
    "houseRules": houseRules,
    "checkInInstructions": checkInInstructions,
    "checkOutInstructions": checkOutInstructions,
    "emergencyContact": emergencyContact,
    "createdAt": createdAt,
    "updatedAt": updatedAt,
    "isActive": isActive,
    "isVerified": isVerified,
    "rating": rating,
    "reviewCount": reviewCount,
    "notes": notes,
  };

  // Méthodes utilitaires
  String get formattedNightlyRate {
    if (nightlyRate == null) return "Prix sur demande";
    return "${nightlyRate!.toStringAsFixed(0)}\$/nuit";
  }

  String get formattedWeeklyRate {
    if (weeklyRate == null) return "";
    return "${weeklyRate!.toStringAsFixed(0)}\$/semaine";
  }

  bool get isAvailable {
    return availabilityStatus == "available" && (isActive ?? true);
  }

  double? get totalPricePerNight {
    if (nightlyRate == null) return null;
    double total = nightlyRate!;
    if (cleaningFee != null && cleaningFee! > 0) {
      total += cleaningFee! / (minimumStayNights ?? 1);
    }
    if (serviceFee != null && serviceFee! > 0) {
      total += serviceFee! / (minimumStayNights ?? 1);
    }
    return total;
  }
}


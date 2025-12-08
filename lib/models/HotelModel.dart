import 'dart:convert';

HotelModel hotelModelFromJson(String str) => HotelModel.fromJson(json.decode(str));
String hotelModelToJson(HotelModel data) => json.encode(data.toJson());

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

class HotelModel {
  int? hotelId;
  int? propertyId;
  
  // Capacité et chambres
  int? numberOfRooms;
  int? numberOfSuites;
  int? totalCapacity;
  int? maxGuestsPerRoom;
  List<String>? roomTypes; // "single", "double", "twin", "suite", "presidential"
  bool? hasFamilyRooms;
  int? familyRooms;
  bool? hasAccessibleRooms;
  int? accessibleRooms;
  bool? hasSmokingRooms;
  int? smokingRooms;
  
  // Classification et évaluation
  int? starRating;
  String? hotelCategory; // "budget", "mid-range", "luxury", "boutique", "resort"
  String? hotelChain;
  bool? isIndependent;
  double? rating;
  int? reviewCount;
  String? certification;
  
  // Services de l'hôtel
  List<String>? hotelServices;
  bool? hasRestaurant;
  int? numberOfRestaurants;
  bool? hasBar;
  bool? hasLounge;
  bool? hasRoomService;
  String? roomServiceHours;
  bool? hasConcierge;
  bool? has24HourReception;
  bool? hasLaundryService;
  bool? hasDryCleaning;
  bool? hasBusinessCenter;
  bool? hasMeetingRooms;
  int? meetingRooms;
  double? meetingRoomCapacity;
  bool? hasConferenceFacilities;
  bool? hasEventSpace;
  double? eventSpaceCapacity;
  bool? hasSpa;
  bool? hasFitnessCenter;
  bool? hasGym;
  bool? hasPool;
  bool? hasIndoorPool;
  bool? hasOutdoorPool;
  bool? hasHotTub;
  bool? hasJacuzzi;
  bool? hasSauna;
  bool? hasSteamRoom;
  bool? hasMassage;
  bool? hasBeautySalon;
  bool? hasBarberShop;
  bool? hasGiftShop;
  bool? hasATM;
  bool? hasCurrencyExchange;
  bool? hasTourDesk;
  bool? hasCarRental;
  bool? hasAirportShuttle;
  bool? hasShuttleService;
  
  // Équipements des chambres
  bool? hasWiFi;
  bool? hasFreeWiFi;
  String? wifiSpeed;
  bool? hasTV;
  bool? hasCableTV;
  bool? hasSatelliteTV;
  bool? hasStreaming;
  bool? hasMinibar;
  bool? hasSafe;
  bool? hasAirConditioning;
  bool? hasHeating;
  bool? hasBalcony;
  bool? hasTerrace;
  bool? hasKitchenette;
  bool? hasRefrigerator;
  bool? hasMicrowave;
  bool? hasCoffeeMaker;
  bool? hasKettle;
  bool? hasHairDryer;
  bool? hasIron;
  bool? hasIroningBoard;
  bool? hasWorkDesk;
  bool? hasSittingArea;
  bool? hasSofa;
  bool? hasDiningArea;
  bool? hasBathtub;
  bool? hasShower;
  bool? hasBathrobes;
  bool? hasSlippers;
  bool? hasToiletries;
  bool? hasRoomPhone;
  bool? hasIntercom;
  
  // Parking et transport
  bool? hasParking;
  int? parkingSpaces;
  bool? hasValetParking;
  double? parkingFee;
  bool? hasGarage;
  bool? hasEVCharging;
  int? evChargingStations;
  bool? hasBikeStorage;
  double? distanceToAirport;
  double? distanceToCity;
  double? distanceToBeach;
  double? distanceToPublicTransport;
  bool? hasPublicTransport;
  String? transportationOptions;
  
  // Accessibilité
  bool? isAccessible;
  bool? hasWheelchairAccess;
  bool? hasElevator;
  bool? hasRamp;
  bool? hasAccessibleRestrooms;
  bool? hasAccessibleParking;
  bool? hasBrailleSignage;
  bool? hasHearingAccessibility;
  bool? hasVisualAccessibility;
  
  // Politiques et règles
  String? checkInTime;
  String? checkOutTime;
  bool? allowsEarlyCheckIn;
  bool? allowsLateCheckOut;
  String? cancellationPolicy; // "free", "flexible", "moderate", "strict", "non-refundable"
  int? cancellationHours;
  bool? allowsPets;
  double? petFee;
  String? petPolicy;
  bool? allowsSmoking;
  bool? hasSmokingAreas;
  bool? allowsChildren;
  bool? isFamilyFriendly;
  int? maxChildrenPerRoom;
  bool? providesCribs;
  bool? providesExtraBeds;
  double? extraBedFee;
  int? minimumAge;
  String? ageRestrictions;
  
  // Prix et disponibilité
  double? basePrice;
  double? nightlyRate;
  double? weeklyRate;
  double? monthlyRate;
  String? currency;
  bool? includesBreakfast;
  String? breakfastType; // "continental", "buffet", "a_la_carte", "none"
  double? breakfastFee;
  bool? includesTaxes;
  double? taxRate;
  double? serviceCharge;
  double? resortFee;
  String? availabilityStatus; // "available", "fully_booked", "limited"
  List<String>? availableDates;
  List<String>? bookedDates;
  bool? instantBooking;
  int? minimumStayNights;
  int? maximumStayNights;
  
  // Paiement et conditions
  List<String>? acceptedPaymentMethods;
  bool? requiresDeposit;
  double? depositAmount;
  double? securityDeposit;
  int? advanceBookingDays;
  bool? requiresCreditCard;
  String? paymentPolicy;
  bool? allowsPartialPayment;
  
  // Sécurité et services
  bool? hasSecurity;
  bool? has24HourSecurity;
  bool? hasCCTV;
  bool? hasSafeDepositBox;
  bool? hasLuggageStorage;
  bool? hasLostAndFound;
  bool? hasMedicalService;
  bool? hasDoctorOnCall;
  bool? hasPharmacy;
  bool? hasFireSafety;
  bool? hasSmokeDetectors;
  bool? hasFireExtinguishers;
  bool? hasEmergencyExit;
  bool? hasFirstAid;
  
  // Localisation et attractions
  String? nearbyAttractions;
  double? distanceToRestaurants;
  double? distanceToShopping;
  double? distanceToEntertainment;
  double? distanceToMuseums;
  double? distanceToParks;
  String? viewType; // "city", "ocean", "mountain", "garden", "pool"
  bool? hasViews;
  
  // Équipements supplémentaires
  bool? hasGarden;
  bool? hasRooftop;
  bool? hasOutdoorSeating;
  bool? hasBBQ;
  bool? hasPlayground;
  bool? hasKidsClub;
  bool? hasGameRoom;
  bool? hasLibrary;
  bool? hasReadingRoom;
  bool? hasChapel;
  bool? hasPrayerRoom;
  
  // Métadonnées
  String? createdAt;
  String? updatedAt;
  bool? isActive;
  bool? isVerified;
  String? notes;
  String? description;
  List<String>? languages;
  String? primaryLanguage;

  HotelModel({
    this.hotelId,
    this.propertyId,
    this.numberOfRooms,
    this.numberOfSuites,
    this.totalCapacity,
    this.maxGuestsPerRoom,
    this.roomTypes,
    this.hasFamilyRooms,
    this.familyRooms,
    this.hasAccessibleRooms,
    this.accessibleRooms,
    this.hasSmokingRooms,
    this.smokingRooms,
    this.starRating,
    this.hotelCategory,
    this.hotelChain,
    this.isIndependent,
    this.rating,
    this.reviewCount,
    this.certification,
    this.hotelServices,
    this.hasRestaurant,
    this.numberOfRestaurants,
    this.hasBar,
    this.hasLounge,
    this.hasRoomService,
    this.roomServiceHours,
    this.hasConcierge,
    this.has24HourReception,
    this.hasLaundryService,
    this.hasDryCleaning,
    this.hasBusinessCenter,
    this.hasMeetingRooms,
    this.meetingRooms,
    this.meetingRoomCapacity,
    this.hasConferenceFacilities,
    this.hasEventSpace,
    this.eventSpaceCapacity,
    this.hasSpa,
    this.hasFitnessCenter,
    this.hasGym,
    this.hasPool,
    this.hasIndoorPool,
    this.hasOutdoorPool,
    this.hasHotTub,
    this.hasJacuzzi,
    this.hasSauna,
    this.hasSteamRoom,
    this.hasMassage,
    this.hasBeautySalon,
    this.hasBarberShop,
    this.hasGiftShop,
    this.hasATM,
    this.hasCurrencyExchange,
    this.hasTourDesk,
    this.hasCarRental,
    this.hasAirportShuttle,
    this.hasShuttleService,
    this.hasWiFi,
    this.hasFreeWiFi,
    this.wifiSpeed,
    this.hasTV,
    this.hasCableTV,
    this.hasSatelliteTV,
    this.hasStreaming,
    this.hasMinibar,
    this.hasSafe,
    this.hasAirConditioning,
    this.hasHeating,
    this.hasBalcony,
    this.hasTerrace,
    this.hasKitchenette,
    this.hasRefrigerator,
    this.hasMicrowave,
    this.hasCoffeeMaker,
    this.hasKettle,
    this.hasHairDryer,
    this.hasIron,
    this.hasIroningBoard,
    this.hasWorkDesk,
    this.hasSittingArea,
    this.hasSofa,
    this.hasDiningArea,
    this.hasBathtub,
    this.hasShower,
    this.hasBathrobes,
    this.hasSlippers,
    this.hasToiletries,
    this.hasRoomPhone,
    this.hasIntercom,
    this.hasParking,
    this.parkingSpaces,
    this.hasValetParking,
    this.parkingFee,
    this.hasGarage,
    this.hasEVCharging,
    this.evChargingStations,
    this.hasBikeStorage,
    this.distanceToAirport,
    this.distanceToCity,
    this.distanceToBeach,
    this.distanceToPublicTransport,
    this.hasPublicTransport,
    this.transportationOptions,
    this.isAccessible,
    this.hasWheelchairAccess,
    this.hasElevator,
    this.hasRamp,
    this.hasAccessibleRestrooms,
    this.hasAccessibleParking,
    this.hasBrailleSignage,
    this.hasHearingAccessibility,
    this.hasVisualAccessibility,
    this.checkInTime,
    this.checkOutTime,
    this.allowsEarlyCheckIn,
    this.allowsLateCheckOut,
    this.cancellationPolicy,
    this.cancellationHours,
    this.allowsPets,
    this.petFee,
    this.petPolicy,
    this.allowsSmoking,
    this.hasSmokingAreas,
    this.allowsChildren,
    this.isFamilyFriendly,
    this.maxChildrenPerRoom,
    this.providesCribs,
    this.providesExtraBeds,
    this.extraBedFee,
    this.minimumAge,
    this.ageRestrictions,
    this.basePrice,
    this.nightlyRate,
    this.weeklyRate,
    this.monthlyRate,
    this.currency,
    this.includesBreakfast,
    this.breakfastType,
    this.breakfastFee,
    this.includesTaxes,
    this.taxRate,
    this.serviceCharge,
    this.resortFee,
    this.availabilityStatus,
    this.availableDates,
    this.bookedDates,
    this.instantBooking,
    this.minimumStayNights,
    this.maximumStayNights,
    this.acceptedPaymentMethods,
    this.requiresDeposit,
    this.depositAmount,
    this.securityDeposit,
    this.advanceBookingDays,
    this.requiresCreditCard,
    this.paymentPolicy,
    this.allowsPartialPayment,
    this.hasSecurity,
    this.has24HourSecurity,
    this.hasCCTV,
    this.hasSafeDepositBox,
    this.hasLuggageStorage,
    this.hasLostAndFound,
    this.hasMedicalService,
    this.hasDoctorOnCall,
    this.hasPharmacy,
    this.hasFireSafety,
    this.hasSmokeDetectors,
    this.hasFireExtinguishers,
    this.hasEmergencyExit,
    this.hasFirstAid,
    this.nearbyAttractions,
    this.distanceToRestaurants,
    this.distanceToShopping,
    this.distanceToEntertainment,
    this.distanceToMuseums,
    this.distanceToParks,
    this.viewType,
    this.hasViews,
    this.hasGarden,
    this.hasRooftop,
    this.hasOutdoorSeating,
    this.hasBBQ,
    this.hasPlayground,
    this.hasKidsClub,
    this.hasGameRoom,
    this.hasLibrary,
    this.hasReadingRoom,
    this.hasChapel,
    this.hasPrayerRoom,
    this.createdAt,
    this.updatedAt,
    this.isActive,
    this.isVerified,
    this.notes,
    this.description,
    this.languages,
    this.primaryLanguage,
  });

  factory HotelModel.fromJson(Map<String, dynamic> json) => HotelModel(
    hotelId: _parseInt(json["hotelId"]) ?? _parseInt(json["id"]),
    propertyId: _parseInt(json["propertyId"]),
    numberOfRooms: _parseInt(json["numberOfRooms"]),
    numberOfSuites: _parseInt(json["numberOfSuites"]),
    totalCapacity: _parseInt(json["totalCapacity"]),
    maxGuestsPerRoom: _parseInt(json["maxGuestsPerRoom"]),
    roomTypes: json["roomTypes"] is List
        ? List<String>.from(json["roomTypes"])
        : null,
    hasFamilyRooms: _parseBool(json["hasFamilyRooms"]),
    familyRooms: _parseInt(json["familyRooms"]),
    hasAccessibleRooms: _parseBool(json["hasAccessibleRooms"]),
    accessibleRooms: _parseInt(json["accessibleRooms"]),
    hasSmokingRooms: _parseBool(json["hasSmokingRooms"]),
    smokingRooms: _parseInt(json["smokingRooms"]),
    starRating: _parseInt(json["starRating"]),
    hotelCategory: _parseString(json["hotelCategory"]),
    hotelChain: _parseString(json["hotelChain"]),
    isIndependent: _parseBool(json["isIndependent"]),
    rating: _parseDouble(json["rating"]),
    reviewCount: _parseInt(json["reviewCount"]),
    certification: _parseString(json["certification"]),
    hotelServices: json["hotelServices"] is List
        ? List<String>.from(json["hotelServices"])
        : null,
    hasRestaurant: _parseBool(json["hasRestaurant"]),
    numberOfRestaurants: _parseInt(json["numberOfRestaurants"]),
    hasBar: _parseBool(json["hasBar"]),
    hasLounge: _parseBool(json["hasLounge"]),
    hasRoomService: _parseBool(json["hasRoomService"]),
    roomServiceHours: _parseString(json["roomServiceHours"]),
    hasConcierge: _parseBool(json["hasConcierge"]),
    has24HourReception: _parseBool(json["has24HourReception"]),
    hasLaundryService: _parseBool(json["hasLaundryService"]),
    hasDryCleaning: _parseBool(json["hasDryCleaning"]),
    hasBusinessCenter: _parseBool(json["hasBusinessCenter"]),
    hasMeetingRooms: _parseBool(json["hasMeetingRooms"]),
    meetingRooms: _parseInt(json["meetingRooms"]),
    meetingRoomCapacity: _parseDouble(json["meetingRoomCapacity"]),
    hasConferenceFacilities: _parseBool(json["hasConferenceFacilities"]),
    hasEventSpace: _parseBool(json["hasEventSpace"]),
    eventSpaceCapacity: _parseDouble(json["eventSpaceCapacity"]),
    hasSpa: _parseBool(json["hasSpa"]),
    hasFitnessCenter: _parseBool(json["hasFitnessCenter"]),
    hasGym: _parseBool(json["hasGym"]),
    hasPool: _parseBool(json["hasPool"]),
    hasIndoorPool: _parseBool(json["hasIndoorPool"]),
    hasOutdoorPool: _parseBool(json["hasOutdoorPool"]),
    hasHotTub: _parseBool(json["hasHotTub"]),
    hasJacuzzi: _parseBool(json["hasJacuzzi"]),
    hasSauna: _parseBool(json["hasSauna"]),
    hasSteamRoom: _parseBool(json["hasSteamRoom"]),
    hasMassage: _parseBool(json["hasMassage"]),
    hasBeautySalon: _parseBool(json["hasBeautySalon"]),
    hasBarberShop: _parseBool(json["hasBarberShop"]),
    hasGiftShop: _parseBool(json["hasGiftShop"]),
    hasATM: _parseBool(json["hasATM"]),
    hasCurrencyExchange: _parseBool(json["hasCurrencyExchange"]),
    hasTourDesk: _parseBool(json["hasTourDesk"]),
    hasCarRental: _parseBool(json["hasCarRental"]),
    hasAirportShuttle: _parseBool(json["hasAirportShuttle"]),
    hasShuttleService: _parseBool(json["hasShuttleService"]),
    hasWiFi: _parseBool(json["hasWiFi"]),
    hasFreeWiFi: _parseBool(json["hasFreeWiFi"]),
    wifiSpeed: _parseString(json["wifiSpeed"]),
    hasTV: _parseBool(json["hasTV"]),
    hasCableTV: _parseBool(json["hasCableTV"]),
    hasSatelliteTV: _parseBool(json["hasSatelliteTV"]),
    hasStreaming: _parseBool(json["hasStreaming"]),
    hasMinibar: _parseBool(json["hasMinibar"]),
    hasSafe: _parseBool(json["hasSafe"]),
    hasAirConditioning: _parseBool(json["hasAirConditioning"]),
    hasHeating: _parseBool(json["hasHeating"]),
    hasBalcony: _parseBool(json["hasBalcony"]),
    hasTerrace: _parseBool(json["hasTerrace"]),
    hasKitchenette: _parseBool(json["hasKitchenette"]),
    hasRefrigerator: _parseBool(json["hasRefrigerator"]),
    hasMicrowave: _parseBool(json["hasMicrowave"]),
    hasCoffeeMaker: _parseBool(json["hasCoffeeMaker"]),
    hasKettle: _parseBool(json["hasKettle"]),
    hasHairDryer: _parseBool(json["hasHairDryer"]),
    hasIron: _parseBool(json["hasIron"]),
    hasIroningBoard: _parseBool(json["hasIroningBoard"]),
    hasWorkDesk: _parseBool(json["hasWorkDesk"]),
    hasSittingArea: _parseBool(json["hasSittingArea"]),
    hasSofa: _parseBool(json["hasSofa"]),
    hasDiningArea: _parseBool(json["hasDiningArea"]),
    hasBathtub: _parseBool(json["hasBathtub"]),
    hasShower: _parseBool(json["hasShower"]),
    hasBathrobes: _parseBool(json["hasBathrobes"]),
    hasSlippers: _parseBool(json["hasSlippers"]),
    hasToiletries: _parseBool(json["hasToiletries"]),
    hasRoomPhone: _parseBool(json["hasRoomPhone"]),
    hasIntercom: _parseBool(json["hasIntercom"]),
    hasParking: _parseBool(json["hasParking"]),
    parkingSpaces: _parseInt(json["parkingSpaces"]),
    hasValetParking: _parseBool(json["hasValetParking"]),
    parkingFee: _parseDouble(json["parkingFee"]),
    hasGarage: _parseBool(json["hasGarage"]),
    hasEVCharging: _parseBool(json["hasEVCharging"]),
    evChargingStations: _parseInt(json["evChargingStations"]),
    hasBikeStorage: _parseBool(json["hasBikeStorage"]),
    distanceToAirport: _parseDouble(json["distanceToAirport"]),
    distanceToCity: _parseDouble(json["distanceToCity"]),
    distanceToBeach: _parseDouble(json["distanceToBeach"]),
    distanceToPublicTransport: _parseDouble(json["distanceToPublicTransport"]),
    hasPublicTransport: _parseBool(json["hasPublicTransport"]),
    transportationOptions: _parseString(json["transportationOptions"]),
    isAccessible: _parseBool(json["isAccessible"]),
    hasWheelchairAccess: _parseBool(json["hasWheelchairAccess"]),
    hasElevator: _parseBool(json["hasElevator"]),
    hasRamp: _parseBool(json["hasRamp"]),
    hasAccessibleRestrooms: _parseBool(json["hasAccessibleRestrooms"]),
    hasAccessibleParking: _parseBool(json["hasAccessibleParking"]),
    hasBrailleSignage: _parseBool(json["hasBrailleSignage"]),
    hasHearingAccessibility: _parseBool(json["hasHearingAccessibility"]),
    hasVisualAccessibility: _parseBool(json["hasVisualAccessibility"]),
    checkInTime: _parseString(json["checkInTime"]) ?? "15:00",
    checkOutTime: _parseString(json["checkOutTime"]) ?? "11:00",
    allowsEarlyCheckIn: _parseBool(json["allowsEarlyCheckIn"]),
    allowsLateCheckOut: _parseBool(json["allowsLateCheckOut"]),
    cancellationPolicy: _parseString(json["cancellationPolicy"]),
    cancellationHours: _parseInt(json["cancellationHours"]),
    allowsPets: _parseBool(json["allowsPets"]),
    petFee: _parseDouble(json["petFee"]),
    petPolicy: _parseString(json["petPolicy"]),
    allowsSmoking: _parseBool(json["allowsSmoking"]),
    hasSmokingAreas: _parseBool(json["hasSmokingAreas"]),
    allowsChildren: _parseBool(json["allowsChildren"]),
    isFamilyFriendly: _parseBool(json["isFamilyFriendly"]),
    maxChildrenPerRoom: _parseInt(json["maxChildrenPerRoom"]),
    providesCribs: _parseBool(json["providesCribs"]),
    providesExtraBeds: _parseBool(json["providesExtraBeds"]),
    extraBedFee: _parseDouble(json["extraBedFee"]),
    minimumAge: _parseInt(json["minimumAge"]),
    ageRestrictions: _parseString(json["ageRestrictions"]),
    basePrice: _parseDouble(json["basePrice"]),
    nightlyRate: _parseDouble(json["nightlyRate"]),
    weeklyRate: _parseDouble(json["weeklyRate"]),
    monthlyRate: _parseDouble(json["monthlyRate"]),
    currency: _parseString(json["currency"]) ?? "USD",
    includesBreakfast: _parseBool(json["includesBreakfast"]),
    breakfastType: _parseString(json["breakfastType"]),
    breakfastFee: _parseDouble(json["breakfastFee"]),
    includesTaxes: _parseBool(json["includesTaxes"]),
    taxRate: _parseDouble(json["taxRate"]),
    serviceCharge: _parseDouble(json["serviceCharge"]),
    resortFee: _parseDouble(json["resortFee"]),
    availabilityStatus: _parseString(json["availabilityStatus"]) ?? "available",
    availableDates: json["availableDates"] is List
        ? List<String>.from(json["availableDates"])
        : null,
    bookedDates: json["bookedDates"] is List
        ? List<String>.from(json["bookedDates"])
        : null,
    instantBooking: _parseBool(json["instantBooking"]),
    minimumStayNights: _parseInt(json["minimumStayNights"]),
    maximumStayNights: _parseInt(json["maximumStayNights"]),
    acceptedPaymentMethods: json["acceptedPaymentMethods"] is List
        ? List<String>.from(json["acceptedPaymentMethods"])
        : null,
    requiresDeposit: _parseBool(json["requiresDeposit"]),
    depositAmount: _parseDouble(json["depositAmount"]),
    securityDeposit: _parseDouble(json["securityDeposit"]),
    advanceBookingDays: _parseInt(json["advanceBookingDays"]),
    requiresCreditCard: _parseBool(json["requiresCreditCard"]),
    paymentPolicy: _parseString(json["paymentPolicy"]),
    allowsPartialPayment: _parseBool(json["allowsPartialPayment"]),
    hasSecurity: _parseBool(json["hasSecurity"]),
    has24HourSecurity: _parseBool(json["has24HourSecurity"]),
    hasCCTV: _parseBool(json["hasCCTV"]),
    hasSafeDepositBox: _parseBool(json["hasSafeDepositBox"]),
    hasLuggageStorage: _parseBool(json["hasLuggageStorage"]),
    hasLostAndFound: _parseBool(json["hasLostAndFound"]),
    hasMedicalService: _parseBool(json["hasMedicalService"]),
    hasDoctorOnCall: _parseBool(json["hasDoctorOnCall"]),
    hasPharmacy: _parseBool(json["hasPharmacy"]),
    hasFireSafety: _parseBool(json["hasFireSafety"]),
    hasSmokeDetectors: _parseBool(json["hasSmokeDetectors"]),
    hasFireExtinguishers: _parseBool(json["hasFireExtinguishers"]),
    hasEmergencyExit: _parseBool(json["hasEmergencyExit"]),
    hasFirstAid: _parseBool(json["hasFirstAid"]),
    nearbyAttractions: _parseString(json["nearbyAttractions"]),
    distanceToRestaurants: _parseDouble(json["distanceToRestaurants"]),
    distanceToShopping: _parseDouble(json["distanceToShopping"]),
    distanceToEntertainment: _parseDouble(json["distanceToEntertainment"]),
    distanceToMuseums: _parseDouble(json["distanceToMuseums"]),
    distanceToParks: _parseDouble(json["distanceToParks"]),
    viewType: _parseString(json["viewType"]),
    hasViews: _parseBool(json["hasViews"]),
    hasGarden: _parseBool(json["hasGarden"]),
    hasRooftop: _parseBool(json["hasRooftop"]),
    hasOutdoorSeating: _parseBool(json["hasOutdoorSeating"]),
    hasBBQ: _parseBool(json["hasBBQ"]),
    hasPlayground: _parseBool(json["hasPlayground"]),
    hasKidsClub: _parseBool(json["hasKidsClub"]),
    hasGameRoom: _parseBool(json["hasGameRoom"]),
    hasLibrary: _parseBool(json["hasLibrary"]),
    hasReadingRoom: _parseBool(json["hasReadingRoom"]),
    hasChapel: _parseBool(json["hasChapel"]),
    hasPrayerRoom: _parseBool(json["hasPrayerRoom"]),
    createdAt: _parseString(json["createdAt"]),
    updatedAt: _parseString(json["updatedAt"]),
    isActive: _parseBool(json["isActive"]) ?? true,
    isVerified: _parseBool(json["isVerified"]) ?? false,
    notes: _parseString(json["notes"]),
    description: _parseString(json["description"]),
    languages: json["languages"] is List
        ? List<String>.from(json["languages"])
        : null,
    primaryLanguage: _parseString(json["primaryLanguage"]),
  );

  Map<String, dynamic> toJson() => {
    "hotelId": hotelId,
    "propertyId": propertyId,
    "numberOfRooms": numberOfRooms,
    "numberOfSuites": numberOfSuites,
    "totalCapacity": totalCapacity,
    "maxGuestsPerRoom": maxGuestsPerRoom,
    "roomTypes": roomTypes,
    "hasFamilyRooms": hasFamilyRooms,
    "familyRooms": familyRooms,
    "hasAccessibleRooms": hasAccessibleRooms,
    "accessibleRooms": accessibleRooms,
    "hasSmokingRooms": hasSmokingRooms,
    "smokingRooms": smokingRooms,
    "starRating": starRating,
    "hotelCategory": hotelCategory,
    "hotelChain": hotelChain,
    "isIndependent": isIndependent,
    "rating": rating,
    "reviewCount": reviewCount,
    "certification": certification,
    "hotelServices": hotelServices,
    "hasRestaurant": hasRestaurant,
    "numberOfRestaurants": numberOfRestaurants,
    "hasBar": hasBar,
    "hasLounge": hasLounge,
    "hasRoomService": hasRoomService,
    "roomServiceHours": roomServiceHours,
    "hasConcierge": hasConcierge,
    "has24HourReception": has24HourReception,
    "hasLaundryService": hasLaundryService,
    "hasDryCleaning": hasDryCleaning,
    "hasBusinessCenter": hasBusinessCenter,
    "hasMeetingRooms": hasMeetingRooms,
    "meetingRooms": meetingRooms,
    "meetingRoomCapacity": meetingRoomCapacity,
    "hasConferenceFacilities": hasConferenceFacilities,
    "hasEventSpace": hasEventSpace,
    "eventSpaceCapacity": eventSpaceCapacity,
    "hasSpa": hasSpa,
    "hasFitnessCenter": hasFitnessCenter,
    "hasGym": hasGym,
    "hasPool": hasPool,
    "hasIndoorPool": hasIndoorPool,
    "hasOutdoorPool": hasOutdoorPool,
    "hasHotTub": hasHotTub,
    "hasJacuzzi": hasJacuzzi,
    "hasSauna": hasSauna,
    "hasSteamRoom": hasSteamRoom,
    "hasMassage": hasMassage,
    "hasBeautySalon": hasBeautySalon,
    "hasBarberShop": hasBarberShop,
    "hasGiftShop": hasGiftShop,
    "hasATM": hasATM,
    "hasCurrencyExchange": hasCurrencyExchange,
    "hasTourDesk": hasTourDesk,
    "hasCarRental": hasCarRental,
    "hasAirportShuttle": hasAirportShuttle,
    "hasShuttleService": hasShuttleService,
    "hasWiFi": hasWiFi,
    "hasFreeWiFi": hasFreeWiFi,
    "wifiSpeed": wifiSpeed,
    "hasTV": hasTV,
    "hasCableTV": hasCableTV,
    "hasSatelliteTV": hasSatelliteTV,
    "hasStreaming": hasStreaming,
    "hasMinibar": hasMinibar,
    "hasSafe": hasSafe,
    "hasAirConditioning": hasAirConditioning,
    "hasHeating": hasHeating,
    "hasBalcony": hasBalcony,
    "hasTerrace": hasTerrace,
    "hasKitchenette": hasKitchenette,
    "hasRefrigerator": hasRefrigerator,
    "hasMicrowave": hasMicrowave,
    "hasCoffeeMaker": hasCoffeeMaker,
    "hasKettle": hasKettle,
    "hasHairDryer": hasHairDryer,
    "hasIron": hasIron,
    "hasIroningBoard": hasIroningBoard,
    "hasWorkDesk": hasWorkDesk,
    "hasSittingArea": hasSittingArea,
    "hasSofa": hasSofa,
    "hasDiningArea": hasDiningArea,
    "hasBathtub": hasBathtub,
    "hasShower": hasShower,
    "hasBathrobes": hasBathrobes,
    "hasSlippers": hasSlippers,
    "hasToiletries": hasToiletries,
    "hasRoomPhone": hasRoomPhone,
    "hasIntercom": hasIntercom,
    "hasParking": hasParking,
    "parkingSpaces": parkingSpaces,
    "hasValetParking": hasValetParking,
    "parkingFee": parkingFee,
    "hasGarage": hasGarage,
    "hasEVCharging": hasEVCharging,
    "evChargingStations": evChargingStations,
    "hasBikeStorage": hasBikeStorage,
    "distanceToAirport": distanceToAirport,
    "distanceToCity": distanceToCity,
    "distanceToBeach": distanceToBeach,
    "distanceToPublicTransport": distanceToPublicTransport,
    "hasPublicTransport": hasPublicTransport,
    "transportationOptions": transportationOptions,
    "isAccessible": isAccessible,
    "hasWheelchairAccess": hasWheelchairAccess,
    "hasElevator": hasElevator,
    "hasRamp": hasRamp,
    "hasAccessibleRestrooms": hasAccessibleRestrooms,
    "hasAccessibleParking": hasAccessibleParking,
    "hasBrailleSignage": hasBrailleSignage,
    "hasHearingAccessibility": hasHearingAccessibility,
    "hasVisualAccessibility": hasVisualAccessibility,
    "checkInTime": checkInTime,
    "checkOutTime": checkOutTime,
    "allowsEarlyCheckIn": allowsEarlyCheckIn,
    "allowsLateCheckOut": allowsLateCheckOut,
    "cancellationPolicy": cancellationPolicy,
    "cancellationHours": cancellationHours,
    "allowsPets": allowsPets,
    "petFee": petFee,
    "petPolicy": petPolicy,
    "allowsSmoking": allowsSmoking,
    "hasSmokingAreas": hasSmokingAreas,
    "allowsChildren": allowsChildren,
    "isFamilyFriendly": isFamilyFriendly,
    "maxChildrenPerRoom": maxChildrenPerRoom,
    "providesCribs": providesCribs,
    "providesExtraBeds": providesExtraBeds,
    "extraBedFee": extraBedFee,
    "minimumAge": minimumAge,
    "ageRestrictions": ageRestrictions,
    "basePrice": basePrice,
    "nightlyRate": nightlyRate,
    "weeklyRate": weeklyRate,
    "monthlyRate": monthlyRate,
    "currency": currency,
    "includesBreakfast": includesBreakfast,
    "breakfastType": breakfastType,
    "breakfastFee": breakfastFee,
    "includesTaxes": includesTaxes,
    "taxRate": taxRate,
    "serviceCharge": serviceCharge,
    "resortFee": resortFee,
    "availabilityStatus": availabilityStatus,
    "availableDates": availableDates,
    "bookedDates": bookedDates,
    "instantBooking": instantBooking,
    "minimumStayNights": minimumStayNights,
    "maximumStayNights": maximumStayNights,
    "acceptedPaymentMethods": acceptedPaymentMethods,
    "requiresDeposit": requiresDeposit,
    "depositAmount": depositAmount,
    "securityDeposit": securityDeposit,
    "advanceBookingDays": advanceBookingDays,
    "requiresCreditCard": requiresCreditCard,
    "paymentPolicy": paymentPolicy,
    "allowsPartialPayment": allowsPartialPayment,
    "hasSecurity": hasSecurity,
    "has24HourSecurity": has24HourSecurity,
    "hasCCTV": hasCCTV,
    "hasSafeDepositBox": hasSafeDepositBox,
    "hasLuggageStorage": hasLuggageStorage,
    "hasLostAndFound": hasLostAndFound,
    "hasMedicalService": hasMedicalService,
    "hasDoctorOnCall": hasDoctorOnCall,
    "hasPharmacy": hasPharmacy,
    "hasFireSafety": hasFireSafety,
    "hasSmokeDetectors": hasSmokeDetectors,
    "hasFireExtinguishers": hasFireExtinguishers,
    "hasEmergencyExit": hasEmergencyExit,
    "hasFirstAid": hasFirstAid,
    "nearbyAttractions": nearbyAttractions,
    "distanceToRestaurants": distanceToRestaurants,
    "distanceToShopping": distanceToShopping,
    "distanceToEntertainment": distanceToEntertainment,
    "distanceToMuseums": distanceToMuseums,
    "distanceToParks": distanceToParks,
    "viewType": viewType,
    "hasViews": hasViews,
    "hasGarden": hasGarden,
    "hasRooftop": hasRooftop,
    "hasOutdoorSeating": hasOutdoorSeating,
    "hasBBQ": hasBBQ,
    "hasPlayground": hasPlayground,
    "hasKidsClub": hasKidsClub,
    "hasGameRoom": hasGameRoom,
    "hasLibrary": hasLibrary,
    "hasReadingRoom": hasReadingRoom,
    "hasChapel": hasChapel,
    "hasPrayerRoom": hasPrayerRoom,
    "createdAt": createdAt,
    "updatedAt": updatedAt,
    "isActive": isActive,
    "isVerified": isVerified,
    "notes": notes,
    "description": description,
    "languages": languages,
    "primaryLanguage": primaryLanguage,
  };

  // Méthodes utilitaires
  String get formattedNightlyRate {
    if (nightlyRate == null) return "Prix sur demande";
    return "${nightlyRate!.toStringAsFixed(0)}\$/nuit";
  }

  String get starRatingDisplay {
    if (starRating == null) return "";
    return "⭐" * starRating!;
  }

  bool get isAvailable {
    return availabilityStatus == "available" && (isActive ?? true);
  }

  double? get totalPricePerNight {
    if (nightlyRate == null) return null;
    double total = nightlyRate!;
    if (serviceCharge != null && serviceCharge! > 0) total += serviceCharge!;
    if (resortFee != null && resortFee! > 0) total += resortFee!;
    if (parkingFee != null && parkingFee! > 0) total += parkingFee!;
    if ((includesTaxes == null || !includesTaxes!) && taxRate != null && taxRate! > 0) {
      total += (nightlyRate! * taxRate! / 100);
    }
    return total;
  }
}


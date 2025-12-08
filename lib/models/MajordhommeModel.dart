import 'dart:convert';
import 'UserModel.dart';

MajordhommeModel majordhommeModelFromJson(String str) => MajordhommeModel.fromJson(json.decode(str));
String majordhommeModelToJson(MajordhommeModel data) => json.encode(data.toJson());

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

class MajordhommeModel {
  int? majordhommeId;
  int? serviceId;
  int? userId;
  UserModel? user;
  String? username;
  
  // Informations générales
  String? title;
  String? description;
  String? firstName;
  String? lastName;
  String? fullName;
  
  // Spécialités et compétences
  List<String>? specialties; // ['nettoyage', 'cuisine', 'jardinage', 'ménage', 'repassage', 'courses', 'garde_enfants', 'garde_animaux']
  List<String>? skills; // Compétences spécifiques
  int? experienceYears;
  String? experienceLevel; // 'debutant', 'intermediaire', 'expert'
  
  // Services offerts
  bool? offersCleaning;
  bool? offersCooking;
  bool? offersGardening;
  bool? offersLaundry;
  bool? offersIroning;
  bool? offersShopping;
  bool? offersChildcare;
  bool? offersPetCare;
  bool? offersElderlyCare;
  bool? offersHousekeeping;
  bool? offersEventService;
  bool? offersConcierge;
  
  // Disponibilité
  bool? isAvailable;
  String? availabilityStatus; // 'available', 'busy', 'unavailable'
  List<String>? availableDays; // ['lundi', 'mardi', 'mercredi', ...]
  String? availableHours; // "08:00-18:00"
  bool? availableWeekends;
  bool? availableHolidays;
  bool? availableEvenings;
  bool? availableNights;
  bool? isFullTime;
  bool? isPartTime;
  int? maxHoursPerWeek;
  
  // Prix et tarification
  double? hourlyRate;
  double? dailyRate;
  double? weeklyRate;
  double? monthlyRate;
  String? priceUnit; // 'hour', 'day', 'week', 'month'
  double? minimumHours;
  bool? negotiablePrice;
  List<String>? acceptedPaymentMethods;
  
  // Localisation
  String? address;
  int? cityId;
  int? communeId;
  int? quartierId;
  int? districtId;
  String? cityValue;
  String? communeValue;
  String? quartierValue;
  String? districtValue;
  double? latitude;
  double? longitude;
  String? postalCode;
  String? serviceArea; // Zone de service (rayon en km)
  List<String>? serviceCities; // Villes où le service est disponible
  
  // Contact
  String? phone;
  String? email;
  String? whatsapp;
  String? website;
  List<String>? socialMedia;
  
  // Certifications et qualifications
  List<String>? certifications;
  List<String>? qualifications;
  bool? isCertified;
  bool? hasBackgroundCheck;
  bool? hasReferences;
  List<String>? languages; // Langues parlées
  String? primaryLanguage;
  
  // Équipements et outils
  bool? hasOwnEquipment;
  List<String>? equipment; // ['aspirateur', 'nettoyants', 'outils_jardinage', etc.]
  bool? hasVehicle;
  String? vehicleType;
  bool? hasUniform;
  
  // Conditions de travail
  bool? canWorkRemotely;
  bool? canWorkOnSite;
  bool? requiresAccommodation;
  bool? canTravel;
  int? maxTravelDistance; // en km
  String? workSchedule; // 'flexible', 'fixed', 'on_call'
  
  // Références et avis
  double? rating;
  int? reviewCount;
  int? completedJobs;
  int? activeJobs;
  List<String>? testimonials;
  
  // Images et médias
  List<String>? images;
  String? profilePhoto;
  List<String>? certificatesImages;
  
  // Métadonnées
  bool? isActive;
  bool? isVerified;
  bool? isFeatured;
  bool? isPremium;
  int? viewCount;
  int? favoriteCount;
  bool? isFavorite;
  String? status; // 'active', 'pending', 'suspended', 'inactive'
  String? rejectionReason;
  String? createdAt;
  String? updatedAt;
  String? lastActiveAt;
  
  // Notes et informations supplémentaires
  String? notes;
  String? additionalInfo;
  List<String>? tags;

  MajordhommeModel({
    this.majordhommeId,
    this.serviceId,
    this.userId,
    this.user,
    this.username,
    this.title,
    this.description,
    this.firstName,
    this.lastName,
    this.fullName,
    this.specialties,
    this.skills,
    this.experienceYears,
    this.experienceLevel,
    this.offersCleaning,
    this.offersCooking,
    this.offersGardening,
    this.offersLaundry,
    this.offersIroning,
    this.offersShopping,
    this.offersChildcare,
    this.offersPetCare,
    this.offersElderlyCare,
    this.offersHousekeeping,
    this.offersEventService,
    this.offersConcierge,
    this.isAvailable,
    this.availabilityStatus,
    this.availableDays,
    this.availableHours,
    this.availableWeekends,
    this.availableHolidays,
    this.availableEvenings,
    this.availableNights,
    this.isFullTime,
    this.isPartTime,
    this.maxHoursPerWeek,
    this.hourlyRate,
    this.dailyRate,
    this.weeklyRate,
    this.monthlyRate,
    this.priceUnit,
    this.minimumHours,
    this.negotiablePrice,
    this.acceptedPaymentMethods,
    this.address,
    this.cityId,
    this.communeId,
    this.quartierId,
    this.districtId,
    this.cityValue,
    this.communeValue,
    this.quartierValue,
    this.districtValue,
    this.latitude,
    this.longitude,
    this.postalCode,
    this.serviceArea,
    this.serviceCities,
    this.phone,
    this.email,
    this.whatsapp,
    this.website,
    this.socialMedia,
    this.certifications,
    this.qualifications,
    this.isCertified,
    this.hasBackgroundCheck,
    this.hasReferences,
    this.languages,
    this.primaryLanguage,
    this.hasOwnEquipment,
    this.equipment,
    this.hasVehicle,
    this.vehicleType,
    this.hasUniform,
    this.canWorkRemotely,
    this.canWorkOnSite,
    this.requiresAccommodation,
    this.canTravel,
    this.maxTravelDistance,
    this.workSchedule,
    this.rating,
    this.reviewCount,
    this.completedJobs,
    this.activeJobs,
    this.testimonials,
    this.images,
    this.profilePhoto,
    this.certificatesImages,
    this.isActive,
    this.isVerified,
    this.isFeatured,
    this.isPremium,
    this.viewCount,
    this.favoriteCount,
    this.isFavorite,
    this.status,
    this.rejectionReason,
    this.createdAt,
    this.updatedAt,
    this.lastActiveAt,
    this.notes,
    this.additionalInfo,
    this.tags,
  });

  factory MajordhommeModel.fromJson(Map<String, dynamic> json) => MajordhommeModel(
    majordhommeId: _parseInt(json["majordhommeId"]) ?? _parseInt(json["id"]),
    serviceId: _parseInt(json["serviceId"]),
    userId: _parseInt(json["userId"]),
    user: json["user"] is Map<String, dynamic>
        ? UserModel.fromJson(json["user"])
        : null,
    username: _parseString(json["username"]),
    title: _parseString(json["title"]),
    description: _parseString(json["description"]),
    firstName: _parseString(json["firstName"]),
    lastName: _parseString(json["lastName"]),
    fullName: _parseString(json["fullName"]),
    specialties: json["specialties"] is List
        ? List<String>.from(json["specialties"])
        : null,
    skills: json["skills"] is List
        ? List<String>.from(json["skills"])
        : null,
    experienceYears: _parseInt(json["experienceYears"]),
    experienceLevel: _parseString(json["experienceLevel"]),
    offersCleaning: _parseBool(json["offersCleaning"]),
    offersCooking: _parseBool(json["offersCooking"]),
    offersGardening: _parseBool(json["offersGardening"]),
    offersLaundry: _parseBool(json["offersLaundry"]),
    offersIroning: _parseBool(json["offersIroning"]),
    offersShopping: _parseBool(json["offersShopping"]),
    offersChildcare: _parseBool(json["offersChildcare"]),
    offersPetCare: _parseBool(json["offersPetCare"]),
    offersElderlyCare: _parseBool(json["offersElderlyCare"]),
    offersHousekeeping: _parseBool(json["offersHousekeeping"]),
    offersEventService: _parseBool(json["offersEventService"]),
    offersConcierge: _parseBool(json["offersConcierge"]),
    isAvailable: _parseBool(json["isAvailable"]) ?? true,
    availabilityStatus: _parseString(json["availabilityStatus"]) ?? "available",
    availableDays: json["availableDays"] is List
        ? List<String>.from(json["availableDays"])
        : null,
    availableHours: _parseString(json["availableHours"]),
    availableWeekends: _parseBool(json["availableWeekends"]),
    availableHolidays: _parseBool(json["availableHolidays"]),
    availableEvenings: _parseBool(json["availableEvenings"]),
    availableNights: _parseBool(json["availableNights"]),
    isFullTime: _parseBool(json["isFullTime"]),
    isPartTime: _parseBool(json["isPartTime"]),
    maxHoursPerWeek: _parseInt(json["maxHoursPerWeek"]),
    hourlyRate: _parseDouble(json["hourlyRate"]),
    dailyRate: _parseDouble(json["dailyRate"]),
    weeklyRate: _parseDouble(json["weeklyRate"]),
    monthlyRate: _parseDouble(json["monthlyRate"]),
    priceUnit: _parseString(json["priceUnit"]) ?? "hour",
    minimumHours: _parseDouble(json["minimumHours"]),
    negotiablePrice: _parseBool(json["negotiablePrice"]),
    acceptedPaymentMethods: json["acceptedPaymentMethods"] is List
        ? List<String>.from(json["acceptedPaymentMethods"])
        : null,
    address: _parseString(json["address"]),
    cityId: _parseInt(json["cityId"]),
    communeId: _parseInt(json["communeId"]),
    quartierId: _parseInt(json["quartierId"]),
    districtId: _parseInt(json["districtId"]),
    cityValue: _parseString(json["cityValue"]),
    communeValue: _parseString(json["communeValue"]),
    quartierValue: _parseString(json["quartierValue"]),
    districtValue: _parseString(json["districtValue"]),
    latitude: _parseDouble(json["latitude"]),
    longitude: _parseDouble(json["longitude"]),
    postalCode: _parseString(json["postalCode"]),
    serviceArea: _parseString(json["serviceArea"]),
    serviceCities: json["serviceCities"] is List
        ? List<String>.from(json["serviceCities"])
        : null,
    phone: _parseString(json["phone"]),
    email: _parseString(json["email"]),
    whatsapp: _parseString(json["whatsapp"]),
    website: _parseString(json["website"]),
    socialMedia: json["socialMedia"] is List
        ? List<String>.from(json["socialMedia"])
        : null,
    certifications: json["certifications"] is List
        ? List<String>.from(json["certifications"])
        : null,
    qualifications: json["qualifications"] is List
        ? List<String>.from(json["qualifications"])
        : null,
    isCertified: _parseBool(json["isCertified"]),
    hasBackgroundCheck: _parseBool(json["hasBackgroundCheck"]),
    hasReferences: _parseBool(json["hasReferences"]),
    languages: json["languages"] is List
        ? List<String>.from(json["languages"])
        : null,
    primaryLanguage: _parseString(json["primaryLanguage"]),
    hasOwnEquipment: _parseBool(json["hasOwnEquipment"]),
    equipment: json["equipment"] is List
        ? List<String>.from(json["equipment"])
        : null,
    hasVehicle: _parseBool(json["hasVehicle"]),
    vehicleType: _parseString(json["vehicleType"]),
    hasUniform: _parseBool(json["hasUniform"]),
    canWorkRemotely: _parseBool(json["canWorkRemotely"]),
    canWorkOnSite: _parseBool(json["canWorkOnSite"]),
    requiresAccommodation: _parseBool(json["requiresAccommodation"]),
    canTravel: _parseBool(json["canTravel"]),
    maxTravelDistance: _parseInt(json["maxTravelDistance"]),
    workSchedule: _parseString(json["workSchedule"]),
    rating: _parseDouble(json["rating"]),
    reviewCount: _parseInt(json["reviewCount"]),
    completedJobs: _parseInt(json["completedJobs"]),
    activeJobs: _parseInt(json["activeJobs"]),
    testimonials: json["testimonials"] is List
        ? List<String>.from(json["testimonials"])
        : null,
    images: json["images"] is List
        ? List<String>.from(json["images"])
        : null,
    profilePhoto: _parseString(json["profilePhoto"]),
    certificatesImages: json["certificatesImages"] is List
        ? List<String>.from(json["certificatesImages"])
        : null,
    isActive: _parseBool(json["isActive"]) ?? true,
    isVerified: _parseBool(json["isVerified"]) ?? false,
    isFeatured: _parseBool(json["isFeatured"]) ?? false,
    isPremium: _parseBool(json["isPremium"]) ?? false,
    viewCount: _parseInt(json["viewCount"]) ?? 0,
    favoriteCount: _parseInt(json["favoriteCount"]) ?? 0,
    isFavorite: _parseBool(json["isFavorite"]),
    status: _parseString(json["status"]) ?? "active",
    rejectionReason: _parseString(json["rejectionReason"]),
    createdAt: _parseString(json["createdAt"]),
    updatedAt: _parseString(json["updatedAt"]),
    lastActiveAt: _parseString(json["lastActiveAt"]),
    notes: _parseString(json["notes"]),
    additionalInfo: _parseString(json["additionalInfo"]),
    tags: json["tags"] is List
        ? List<String>.from(json["tags"])
        : null,
  );

  Map<String, dynamic> toJson() => {
    "majordhommeId": majordhommeId,
    "serviceId": serviceId,
    "userId": userId,
    "user": user?.toJson(),
    "username": username,
    "title": title,
    "description": description,
    "firstName": firstName,
    "lastName": lastName,
    "fullName": fullName,
    "specialties": specialties,
    "skills": skills,
    "experienceYears": experienceYears,
    "experienceLevel": experienceLevel,
    "offersCleaning": offersCleaning,
    "offersCooking": offersCooking,
    "offersGardening": offersGardening,
    "offersLaundry": offersLaundry,
    "offersIroning": offersIroning,
    "offersShopping": offersShopping,
    "offersChildcare": offersChildcare,
    "offersPetCare": offersPetCare,
    "offersElderlyCare": offersElderlyCare,
    "offersHousekeeping": offersHousekeeping,
    "offersEventService": offersEventService,
    "offersConcierge": offersConcierge,
    "isAvailable": isAvailable,
    "availabilityStatus": availabilityStatus,
    "availableDays": availableDays,
    "availableHours": availableHours,
    "availableWeekends": availableWeekends,
    "availableHolidays": availableHolidays,
    "availableEvenings": availableEvenings,
    "availableNights": availableNights,
    "isFullTime": isFullTime,
    "isPartTime": isPartTime,
    "maxHoursPerWeek": maxHoursPerWeek,
    "hourlyRate": hourlyRate,
    "dailyRate": dailyRate,
    "weeklyRate": weeklyRate,
    "monthlyRate": monthlyRate,
    "priceUnit": priceUnit,
    "minimumHours": minimumHours,
    "negotiablePrice": negotiablePrice,
    "acceptedPaymentMethods": acceptedPaymentMethods,
    "address": address,
    "cityId": cityId,
    "communeId": communeId,
    "quartierId": quartierId,
    "districtId": districtId,
    "cityValue": cityValue,
    "communeValue": communeValue,
    "quartierValue": quartierValue,
    "districtValue": districtValue,
    "latitude": latitude,
    "longitude": longitude,
    "postalCode": postalCode,
    "serviceArea": serviceArea,
    "serviceCities": serviceCities,
    "phone": phone,
    "email": email,
    "whatsapp": whatsapp,
    "website": website,
    "socialMedia": socialMedia,
    "certifications": certifications,
    "qualifications": qualifications,
    "isCertified": isCertified,
    "hasBackgroundCheck": hasBackgroundCheck,
    "hasReferences": hasReferences,
    "languages": languages,
    "primaryLanguage": primaryLanguage,
    "hasOwnEquipment": hasOwnEquipment,
    "equipment": equipment,
    "hasVehicle": hasVehicle,
    "vehicleType": vehicleType,
    "hasUniform": hasUniform,
    "canWorkRemotely": canWorkRemotely,
    "canWorkOnSite": canWorkOnSite,
    "requiresAccommodation": requiresAccommodation,
    "canTravel": canTravel,
    "maxTravelDistance": maxTravelDistance,
    "workSchedule": workSchedule,
    "rating": rating,
    "reviewCount": reviewCount,
    "completedJobs": completedJobs,
    "activeJobs": activeJobs,
    "testimonials": testimonials,
    "images": images,
    "profilePhoto": profilePhoto,
    "certificatesImages": certificatesImages,
    "isActive": isActive,
    "isVerified": isVerified,
    "isFeatured": isFeatured,
    "isPremium": isPremium,
    "viewCount": viewCount,
    "favoriteCount": favoriteCount,
    "isFavorite": isFavorite,
    "status": status,
    "rejectionReason": rejectionReason,
    "createdAt": createdAt,
    "updatedAt": updatedAt,
    "lastActiveAt": lastActiveAt,
    "notes": notes,
    "additionalInfo": additionalInfo,
    "tags": tags,
  };

  // Méthodes utilitaires
  String get formattedHourlyRate {
    if (hourlyRate == null) return "Prix sur demande";
    return "${hourlyRate!.toStringAsFixed(0)}\$/heure";
  }

  String get formattedDailyRate {
    if (dailyRate == null) return "";
    return "${dailyRate!.toStringAsFixed(0)}\$/jour";
  }

  bool get isCurrentlyAvailable {
    return (isAvailable ?? true) && (availabilityStatus == "available" || availabilityStatus == null);
  }

  String get experienceDisplay {
    if (experienceYears == null) return "Expérience non spécifiée";
    if (experienceYears! < 1) return "Débutant";
    if (experienceYears! < 3) return "$experienceYears ans d'expérience";
    if (experienceYears! < 5) return "$experienceYears ans d'expérience";
    return "$experienceYears ans d'expérience (Expert)";
  }
}


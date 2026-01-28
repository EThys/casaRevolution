import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'CommuneModel.dart';
import 'CityModel.dart';
import 'DistrictModel.dart';
import 'QuartierModel.dart';
import 'UserModel.dart';

ServiceModel serviceModelFromJson(String str) => ServiceModel.fromJson(json.decode(str));
String serviceModelToJson(ServiceModel data) => json.encode(data.toJson());

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

enum ServiceType {
  majordhomme,
  demenagement,
  nettoyage,
  jardinage,
  plomberie,
  electricite,
  peinture,
  reparation,
  securite,
  gardiennage,
  menage,
  cuisine,
  livraison,
  transport,
  installation,
  renovation,
  decoration,
  climatisation,
  chauffage,
  serrurerie,
  vitrerie,
  carrelage,
  hotel,
  bureau,
  vacances,
  salleFete,
  salleFuneraire,
  terrain,
  entrepot,
}

extension ServiceTypeExtension on ServiceType {
  String get value {
    switch (this) {
      case ServiceType.majordhomme:
        return 'majordhomme';
      case ServiceType.demenagement:
        return 'demenagement';
      case ServiceType.nettoyage:
        return 'nettoyage';
      case ServiceType.jardinage:
        return 'jardinage';
      case ServiceType.plomberie:
        return 'plomberie';
      case ServiceType.electricite:
        return 'electricite';
      case ServiceType.peinture:
        return 'peinture';
      case ServiceType.reparation:
        return 'reparation';
      case ServiceType.securite:
        return 'securite';
      case ServiceType.gardiennage:
        return 'gardiennage';
      case ServiceType.menage:
        return 'menage';
      case ServiceType.cuisine:
        return 'cuisine';
      case ServiceType.livraison:
        return 'livraison';
      case ServiceType.transport:
        return 'transport';
      case ServiceType.installation:
        return 'installation';
      case ServiceType.renovation:
        return 'renovation';
      case ServiceType.decoration:
        return 'decoration';
      case ServiceType.climatisation:
        return 'climatisation';
      case ServiceType.chauffage:
        return 'chauffage';
      case ServiceType.serrurerie:
        return 'serrurerie';
      case ServiceType.vitrerie:
        return 'vitrerie';
      case ServiceType.carrelage:
        return 'carrelage';
      case ServiceType.hotel:
        return 'hotel';
      case ServiceType.bureau:
        return 'bureau';
      case ServiceType.vacances:
        return 'vacances';
      case ServiceType.salleFete:
        return 'salle_fete';
      case ServiceType.salleFuneraire:
        return 'salle_funeraire';
      case ServiceType.terrain:
        return 'terrain';
      case ServiceType.entrepot:
        return 'entrepot';
    }
  }

  String get description {
    switch (this) {
      case ServiceType.majordhomme:
        return 'Entretien de maison, cuisine et plus';
      case ServiceType.demenagement:
        return 'Déménagement sécurisé et rapide';
      case ServiceType.nettoyage:
        return 'Services de nettoyage professionnels';
      case ServiceType.jardinage:
        return 'Entretien d\'espaces verts et jardins';
      case ServiceType.plomberie:
        return 'Installation et réparation plomberie';
      case ServiceType.electricite:
        return 'Travaux et dépannage électrique';
      case ServiceType.peinture:
        return 'Peinture intérieure et extérieure';
      case ServiceType.reparation:
        return 'Réparations diverses à domicile';
      case ServiceType.securite:
        return 'Systèmes de sécurité et gardiennage';
      case ServiceType.gardiennage:
        return 'Surveillance de biens et personnes';
      case ServiceType.menage:
        return 'Ménage quotidien ou ponctuel';
      case ServiceType.cuisine:
        return 'Cuisine à domicile et traiteur';
      case ServiceType.livraison:
        return 'Livraison de colis et courses';
      case ServiceType.transport:
        return 'Déplacements urbains et logistique';
      case ServiceType.installation:
        return 'Installation d\'équipements divers';
      case ServiceType.renovation:
        return 'Rénovation complète ou partielle';
      case ServiceType.decoration:
        return 'Conseil et aménagement intérieur';
      case ServiceType.climatisation:
        return 'Pose et entretien clim et froid';
      case ServiceType.chauffage:
        return 'Chauffage central et chauffe-eau';
      case ServiceType.serrurerie:
        return 'Dépannage et sécurité serrures';
      case ServiceType.vitrerie:
        return 'Pose et remplacement de vitres';
      case ServiceType.carrelage:
        return 'Pose de carrelage et revêtements';
      case ServiceType.hotel:
        return 'Séjours hôteliers confortables';
      case ServiceType.bureau:
        return 'Espaces de travail et bureaux';
      case ServiceType.vacances:
        return 'Locations saisonnières de rêve';
      case ServiceType.salleFete:
        return 'Espaces pour vos célébrations';
      case ServiceType.salleFuneraire:
        return 'Services funéraires dignes';
      case ServiceType.terrain:
        return 'Vente et achat de terrains';
      case ServiceType.entrepot:
        return 'Stockage et logistique entrepôt';
    }
  }

  String get displayName {
    switch (this) {
      case ServiceType.majordhomme:
        return 'Majord\'homme';
      case ServiceType.demenagement:
        return 'Service de déménagement';
      case ServiceType.nettoyage:
        return 'Nettoyage';
      case ServiceType.jardinage:
        return 'Jardinage';
      case ServiceType.plomberie:
        return 'Plomberie';
      case ServiceType.electricite:
        return 'Électricité';
      case ServiceType.peinture:
        return 'Peinture';
      case ServiceType.reparation:
        return 'Réparation';
      case ServiceType.securite:
        return 'Sécurité';
      case ServiceType.gardiennage:
        return 'Gardiennage';
      case ServiceType.menage:
        return 'Ménage';
      case ServiceType.cuisine:
        return 'Cuisine';
      case ServiceType.livraison:
        return 'Livraison';
      case ServiceType.transport:
        return 'Transport';
      case ServiceType.installation:
        return 'Installation';
      case ServiceType.renovation:
        return 'Rénovation';
      case ServiceType.decoration:
        return 'Décoration';
      case ServiceType.climatisation:
        return 'Climatisation';
      case ServiceType.chauffage:
        return 'Chauffage';
      case ServiceType.serrurerie:
        return 'Serrurerie';
      case ServiceType.vitrerie:
        return 'Vitrerie';
      case ServiceType.carrelage:
        return 'Carrelage';
      case ServiceType.hotel:
        return 'Hôtel';
      case ServiceType.bureau:
        return 'Bureau';
      case ServiceType.vacances:
        return 'Location de vacances';
      case ServiceType.salleFete:
        return 'Salle de fête';
      case ServiceType.salleFuneraire:
        return 'Salle funéraire';
      case ServiceType.terrain:
        return 'Terrain';
      case ServiceType.entrepot:
        return 'Entrepôt';
    }
  }

  IconData get icon {
    switch (this) {
      case ServiceType.majordhomme:
        return Icons.cleaning_services_rounded;
      case ServiceType.demenagement:
        return Icons.local_shipping_rounded;
      case ServiceType.nettoyage:
        return Icons.cleaning_services_rounded;
      case ServiceType.jardinage:
        return Icons.grass_rounded;
      case ServiceType.plomberie:
        return Icons.plumbing_rounded;
      case ServiceType.electricite:
        return Icons.electrical_services_rounded;
      case ServiceType.peinture:
        return Icons.format_paint_rounded;
      case ServiceType.reparation:
        return Icons.build_rounded;
      case ServiceType.securite:
        return Icons.security_rounded;
      case ServiceType.gardiennage:
        return Icons.person_outline_rounded;
      case ServiceType.menage:
        return Icons.cleaning_services_rounded;
      case ServiceType.cuisine:
        return Icons.restaurant_rounded;
      case ServiceType.livraison:
        return Icons.delivery_dining_rounded;
      case ServiceType.transport:
        return Icons.local_taxi_rounded;
      case ServiceType.installation:
        return Icons.install_mobile_rounded;
      case ServiceType.renovation:
        return Icons.home_repair_service_rounded;
      case ServiceType.decoration:
        return Icons.palette_rounded;
      case ServiceType.climatisation:
        return Icons.ac_unit_rounded;
      case ServiceType.chauffage:
        return Icons.thermostat_rounded;
      case ServiceType.serrurerie:
        return Icons.lock_rounded;
      case ServiceType.vitrerie:
        return Icons.window_rounded;
      case ServiceType.carrelage:
        return Icons.square_foot_rounded;
      case ServiceType.hotel:
        return Icons.hotel_rounded;
      case ServiceType.bureau:
        return Icons.business_rounded;
      case ServiceType.vacances:
        return Icons.beach_access_rounded;
      case ServiceType.salleFete:
        return Icons.celebration_rounded;
      case ServiceType.salleFuneraire:
        return Icons.church_rounded;
      case ServiceType.terrain:
        return Icons.landscape_rounded;
      case ServiceType.entrepot:
        return Icons.warehouse_rounded;
    }
  }

  static ServiceType fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'majordhomme':
      case 'majord\'homme':
        return ServiceType.majordhomme;
      case 'demenagement':
      case 'déménagement':
        return ServiceType.demenagement;
      case 'nettoyage':
        return ServiceType.nettoyage;
      case 'jardinage':
        return ServiceType.jardinage;
      case 'plomberie':
        return ServiceType.plomberie;
      case 'electricite':
      case 'électricité':
        return ServiceType.electricite;
      case 'peinture':
        return ServiceType.peinture;
      case 'reparation':
      case 'réparation':
        return ServiceType.reparation;
      case 'securite':
      case 'sécurité':
        return ServiceType.securite;
      case 'gardiennage':
        return ServiceType.gardiennage;
      case 'menage':
      case 'ménage':
        return ServiceType.menage;
      case 'cuisine':
        return ServiceType.cuisine;
      case 'livraison':
        return ServiceType.livraison;
      case 'transport':
        return ServiceType.transport;
      case 'installation':
        return ServiceType.installation;
      case 'renovation':
      case 'rénovation':
        return ServiceType.renovation;
      case 'decoration':
      case 'décoration':
        return ServiceType.decoration;
      case 'climatisation':
        return ServiceType.climatisation;
      case 'chauffage':
        return ServiceType.chauffage;
      case 'serrurerie':
        return ServiceType.serrurerie;
      case 'vitrerie':
        return ServiceType.vitrerie;
      case 'carrelage':
        return ServiceType.carrelage;
      case 'hotel':
      case 'hôtel':
        return ServiceType.hotel;
      case 'bureau':
        return ServiceType.bureau;
      case 'vacances':
        return ServiceType.vacances;
      case 'salle_fete':
      case 'salleftete':
      case 'salle de fête':
        return ServiceType.salleFete;
      case 'salle_funeraire':
      case 'sallefuneraire':
      case 'salle funéraire':
        return ServiceType.salleFuneraire;
      case 'terrain'
          :
        return ServiceType.terrain;
      case 'entrepot':
      case 'entrepôt':
        return ServiceType.entrepot;
      default:
        return ServiceType.majordhomme;
    }
  }
}

class ServiceModel {
  int? serviceId;
  String? title;
  String? description;
  ServiceType? serviceType;
  double? price;
  String? priceUnit; // Par heure, par jour, par déménagement, etc.
  
  // Location
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
  
  // Contact
  String? phone;
  String? email;
  String? whatsapp;
  
  // Availability
  bool? isAvailable;
  List<String>? availableDays; // ['lundi', 'mardi', ...]
  String? availableHours; // "08:00-18:00"
  
  // Additional info
  int? experienceYears;
  List<String>? specialties; // Pour majordome: ['nettoyage', 'cuisine', 'jardinage']
  bool? hasVehicle; // Pour déménagement
  bool? hasTeam; // Pour déménagement
  int? teamSize; // Pour déménagement
  
  // Pour Hotel
  int? numberOfRooms;
  int? starRating;
  List<String>? hotelServices; // ['restaurant', 'spa', 'piscine', 'parking', 'wifi', etc.]
  
  // Pour Bureau
  double? surfaceArea; // en m²
  int? numberOfDesks;
  int? meetingRooms;
  bool? hasParking;
  bool? hasSecurity;
  
  // Pour Vacances
  int? capacity; // nombre de personnes
  String? vacationType; // 'villa', 'appartement', 'maison', 'studio'
  List<String>? vacationAmenities; // ['piscine', 'plage', 'wifi', 'cuisine', etc.]
  
  // Pour Salle de fête
  int? eventCapacity;
  List<String>? eventEquipment; // ['son', 'lumiere', 'cuisine', 'parking', etc.]
  
  // Pour Salle funéraire
  int? funeralCapacity;
  List<String>? funeralServices; // ['chapelle', 'parking', 'reception', etc.]
  
  // Pour Terrain
  double? landArea; // Superficie en m² ou hectares
  String? landType; // 'constructible', 'agricole', 'commercial', 'residentiel'
  List<String>? landFeatures; // ['cloture', 'acces_route', 'eau', 'electricite', etc.]
  
  // Pour Entrepôt
  double? warehouseArea; // Superficie en m²
  double? ceilingHeight; // Hauteur sous plafond en mètres
  String? warehouseType; // 'entrepot', 'hangar', 'depot'
  List<String>? warehouseFeatures; // ['quai_chargement', 'portes', 'securite', 'climatisation', etc.]
  
  // Images
  List<String>? images;
  
  // User info
  int? userId;
  UserModel? user;
  String? username;
  
  // Metadata
  bool? isActive;
  bool? isVerified;
  double? rating;
  int? reviewCount;
  int? viewCount;
  int? favoriteCount;
  bool? isFavorite;
  
  // Timestamps
  String? createdAt;
  String? updatedAt;
  
  // Status
  String? status;
  String? rejectionReason;
  
  // Currency
  int? deviseId; // 1 for FC, 2 for USD

  ServiceModel({
    this.serviceId,
    this.title,
    this.description,
    this.serviceType,
    this.price,
    this.priceUnit,
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
    this.phone,
    this.email,
    this.whatsapp,
    this.isAvailable,
    this.availableDays,
    this.availableHours,
    this.experienceYears,
    this.specialties,
    this.hasVehicle,
    this.hasTeam,
    this.teamSize,
    this.numberOfRooms,
    this.starRating,
    this.hotelServices,
    this.surfaceArea,
    this.numberOfDesks,
    this.meetingRooms,
    this.hasParking,
    this.hasSecurity,
    this.capacity,
    this.vacationType,
    this.vacationAmenities,
    this.eventCapacity,
    this.eventEquipment,
    this.funeralCapacity,
    this.funeralServices,
    this.landArea,
    this.landType,
    this.landFeatures,
    this.warehouseArea,
    this.ceilingHeight,
    this.warehouseType,
    this.warehouseFeatures,
    this.images,
    this.userId,
    this.user,
    this.username,
    this.isActive,
    this.isVerified,
    this.rating,
    this.reviewCount,
    this.viewCount,
    this.favoriteCount,
    this.isFavorite,
    this.createdAt,
    this.updatedAt,
    this.status,
    this.rejectionReason,
    this.deviseId,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      serviceId: _parseInt(json["serviceId"]) ?? _parseInt(json["id"]),
      title: _parseString(json["title"]),
      description: _parseString(json["description"]),
      serviceType: json["serviceType"] != null
          ? ServiceTypeExtension.fromString(_parseString(json["serviceType"]))
          : null,
      price: _parseDouble(json["price"]),
      priceUnit: _parseString(json["priceUnit"]),
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
      phone: _parseString(json["phone"]),
      email: _parseString(json["email"]),
      whatsapp: _parseString(json["whatsapp"]),
      isAvailable: _parseBool(json["isAvailable"]),
      availableDays: json["availableDays"] is List
          ? List<String>.from(json["availableDays"])
          : (json["plageJourPrestation"] is String 
              ? (json["plageJourPrestation"] as String).split(',').map((e) => e.trim()).toList()
              : null),
      availableHours: _parseString(json["availableHours"]) ?? _parseString(json["plageHeurePrestation"]),
      experienceYears: _parseInt(json["experienceYears"]),
      specialties: json["specialties"] is List
          ? List<String>.from(json["specialties"])
          : null,
      hasVehicle: _parseBool(json["hasVehicle"]),
      hasTeam: _parseBool(json["hasTeam"]),
      teamSize: _parseInt(json["teamSize"]),
      numberOfRooms: _parseInt(json["numberOfRooms"]),
      starRating: _parseInt(json["starRating"]),
      hotelServices: json["hotelServices"] is List
          ? List<String>.from(json["hotelServices"])
          : null,
      surfaceArea: _parseDouble(json["surfaceArea"]),
      numberOfDesks: _parseInt(json["numberOfDesks"]),
      meetingRooms: _parseInt(json["meetingRooms"]),
      hasParking: _parseBool(json["hasParking"]),
      hasSecurity: _parseBool(json["hasSecurity"]),
      capacity: _parseInt(json["capacity"]),
      vacationType: _parseString(json["vacationType"]),
      vacationAmenities: json["vacationAmenities"] is List
          ? List<String>.from(json["vacationAmenities"])
          : null,
      eventCapacity: _parseInt(json["eventCapacity"]),
      eventEquipment: json["eventEquipment"] is List
          ? List<String>.from(json["eventEquipment"])
          : null,
      funeralCapacity: _parseInt(json["funeralCapacity"]),
      funeralServices: json["funeralServices"] is List
          ? List<String>.from(json["funeralServices"])
          : null,
      landArea: _parseDouble(json["landArea"]),
      landType: _parseString(json["landType"]),
      landFeatures: json["landFeatures"] is List
          ? List<String>.from(json["landFeatures"])
          : null,
      warehouseArea: _parseDouble(json["warehouseArea"]),
      ceilingHeight: _parseDouble(json["ceilingHeight"]),
      warehouseType: _parseString(json["warehouseType"]),
      warehouseFeatures: json["warehouseFeatures"] is List
          ? List<String>.from(json["warehouseFeatures"])
          : null,
      images: json["images"] is List
          ? List<String>.from(json["images"])
          : null,
      userId: _parseInt(json["userId"]),
      user: json["user"] is Map<String, dynamic>
          ? UserModel.fromJson(json["user"])
          : null,
      username: _parseString(json["username"]) ?? _parseString(json["postBy"]),
      isActive: _parseBool(json["isActive"]),
      isVerified: _parseBool(json["isVerified"]),
      rating: _parseDouble(json["rating"]),
      reviewCount: _parseInt(json["reviewCount"]),
      viewCount: _parseInt(json["viewCount"]),
      favoriteCount: _parseInt(json["favoriteCount"]),
      isFavorite: _parseBool(json["isFavorite"]),
      createdAt: _parseString(json["createdAt"]) ?? _parseString(json["dateCreated"]),
      updatedAt: _parseString(json["updatedAt"]),
      status: _parseString(json["status"]),
      rejectionReason: _parseString(json["rejectionReason"]),
      deviseId: _parseInt(json["deviseId"]) ?? _parseInt(json["devise"]?["id"]),
    );
  }

  Map<String, dynamic> toJson() => {
    "serviceId": serviceId,
    "title": title,
    "description": description,
    "serviceType": serviceType?.value,
    "price": price,
    "priceUnit": priceUnit,
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
    "phone": phone,
    "email": email,
    "whatsapp": whatsapp,
    "isAvailable": isAvailable,
    "availableDays": availableDays,
    "availableHours": availableHours,
    "experienceYears": experienceYears,
    "specialties": specialties,
    "hasVehicle": hasVehicle,
    "hasTeam": hasTeam,
    "teamSize": teamSize,
    "numberOfRooms": numberOfRooms,
    "starRating": starRating,
    "hotelServices": hotelServices,
    "surfaceArea": surfaceArea,
    "numberOfDesks": numberOfDesks,
    "meetingRooms": meetingRooms,
    "hasParking": hasParking,
    "hasSecurity": hasSecurity,
    "capacity": capacity,
    "vacationType": vacationType,
    "vacationAmenities": vacationAmenities,
    "eventCapacity": eventCapacity,
    "eventEquipment": eventEquipment,
    "funeralCapacity": funeralCapacity,
    "funeralServices": funeralServices,
    "landArea": landArea,
    "landType": landType,
    "landFeatures": landFeatures,
    "warehouseArea": warehouseArea,
    "ceilingHeight": ceilingHeight,
    "warehouseType": warehouseType,
    "warehouseFeatures": warehouseFeatures,
    "images": images,
    "userId": userId,
    "username": username,
    "isActive": isActive,
    "isVerified": isVerified,
    "rating": rating,
    "reviewCount": reviewCount,
    "viewCount": viewCount,
    "favoriteCount": favoriteCount,
    "isFavorite": isFavorite,
    "createdAt": createdAt,
    "updatedAt": updatedAt,
    "status": status,
    "rejectionReason": rejectionReason,
    "deviseId": deviseId,
  };

  // Méthode pour créer une copie du modèle
  ServiceModel copyWith({
    int? serviceId,
    String? title,
    String? description,
    ServiceType? serviceType,
    double? price,
    String? priceUnit,
    String? address,
    int? cityId,
    int? communeId,
    int? quartierId,
    int? districtId,
    String? cityValue,
    String? communeValue,
    String? quartierValue,
    String? districtValue,
    double? latitude,
    double? longitude,
    String? postalCode,
    String? phone,
    String? email,
    String? whatsapp,
    bool? isAvailable,
    List<String>? availableDays,
    String? availableHours,
    int? experienceYears,
    List<String>? specialties,
    bool? hasVehicle,
    bool? hasTeam,
    int? teamSize,
    int? numberOfRooms,
    int? starRating,
    List<String>? hotelServices,
    double? surfaceArea,
    int? numberOfDesks,
    int? meetingRooms,
    bool? hasParking,
    bool? hasSecurity,
    int? capacity,
    String? vacationType,
    List<String>? vacationAmenities,
    int? eventCapacity,
    List<String>? eventEquipment,
    int? funeralCapacity,
    List<String>? funeralServices,
    double? landArea,
    String? landType,
    List<String>? landFeatures,
    double? warehouseArea,
    double? ceilingHeight,
    String? warehouseType,
    List<String>? warehouseFeatures,
    List<String>? images,
    int? userId,
    UserModel? user,
    String? username,
    bool? isActive,
    bool? isVerified,
    double? rating,
    int? reviewCount,
    int? viewCount,
    int? favoriteCount,
    bool? isFavorite,
    String? createdAt,
    String? updatedAt,
    String? status,
    String? rejectionReason,
    int? deviseId,
  }) {
    return ServiceModel(
      serviceId: serviceId ?? this.serviceId,
      title: title ?? this.title,
      description: description ?? this.description,
      serviceType: serviceType ?? this.serviceType,
      price: price ?? this.price,
      priceUnit: priceUnit ?? this.priceUnit,
      address: address ?? this.address,
      cityId: cityId ?? this.cityId,
      communeId: communeId ?? this.communeId,
      quartierId: quartierId ?? this.quartierId,
      districtId: districtId ?? this.districtId,
      cityValue: cityValue ?? this.cityValue,
      communeValue: communeValue ?? this.communeValue,
      quartierValue: quartierValue ?? this.quartierValue,
      districtValue: districtValue ?? this.districtValue,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      postalCode: postalCode ?? this.postalCode,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      whatsapp: whatsapp ?? this.whatsapp,
      isAvailable: isAvailable ?? this.isAvailable,
      availableDays: availableDays ?? this.availableDays,
      availableHours: availableHours ?? this.availableHours,
      experienceYears: experienceYears ?? this.experienceYears,
      specialties: specialties ?? this.specialties,
      hasVehicle: hasVehicle ?? this.hasVehicle,
      hasTeam: hasTeam ?? this.hasTeam,
      teamSize: teamSize ?? this.teamSize,
      numberOfRooms: numberOfRooms ?? this.numberOfRooms,
      starRating: starRating ?? this.starRating,
      hotelServices: hotelServices ?? this.hotelServices,
      surfaceArea: surfaceArea ?? this.surfaceArea,
      numberOfDesks: numberOfDesks ?? this.numberOfDesks,
      meetingRooms: meetingRooms ?? this.meetingRooms,
      hasParking: hasParking ?? this.hasParking,
      hasSecurity: hasSecurity ?? this.hasSecurity,
      capacity: capacity ?? this.capacity,
      vacationType: vacationType ?? this.vacationType,
      vacationAmenities: vacationAmenities ?? this.vacationAmenities,
      eventCapacity: eventCapacity ?? this.eventCapacity,
      eventEquipment: eventEquipment ?? this.eventEquipment,
      funeralCapacity: funeralCapacity ?? this.funeralCapacity,
      funeralServices: funeralServices ?? this.funeralServices,
      landArea: landArea ?? this.landArea,
      landType: landType ?? this.landType,
      landFeatures: landFeatures ?? this.landFeatures,
      warehouseArea: warehouseArea ?? this.warehouseArea,
      ceilingHeight: ceilingHeight ?? this.ceilingHeight,
      warehouseType: warehouseType ?? this.warehouseType,
      warehouseFeatures: warehouseFeatures ?? this.warehouseFeatures,
      images: images ?? this.images,
      userId: userId ?? this.userId,
      user: user ?? this.user,
      username: username ?? this.username,
      isActive: isActive ?? this.isActive,
      isVerified: isVerified ?? this.isVerified,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      viewCount: viewCount ?? this.viewCount,
      favoriteCount: favoriteCount ?? this.favoriteCount,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      deviseId: deviseId ?? this.deviseId,
    );
  }
  
  // Currency getter similar to PropertyModel
  String get currency => (deviseId == 1) ? "FC" : "\$";
}


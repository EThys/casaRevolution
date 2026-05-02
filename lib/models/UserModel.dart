import 'dart:convert';
import 'CityModel.dart';
import 'TypeAccountModel.dart';

UserModel userModelFromJson(String str) => UserModel.fromJson(json.decode(str));
String userModelToJson(UserModel data) => json.encode(data.toJson());

class UserModel {
  int? userId;
  String? password;
  TypeAccountModel? typeAccount;
  String? email;
  String? username;
  String? phone;
  String? city;
  String? country;
  bool? isPremium;
  bool? isCertified;
  CityModel? cityModel;
  String? createdStart;
  String? profilePicture;
  String? fullName;

  UserModel({
    this.userId,
    this.password,
    this.typeAccount,
    this.email,
    this.username,
    this.phone,
    this.city,
    this.country,
    this.isPremium,
    this.isCertified,
    this.cityModel,
    this.createdStart,
    this.profilePicture,
    this.fullName,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    try {
      // Détection de la structure imbriquée (comme vu dans GetStorage)
      final source = (json.containsKey('user') && json['user'] is Map)
          ? json['user'] as Map<String, dynamic>
          : json;

      // GET /protected/users/{id} : `profile` est un objet (images, fullName, …)
      Map<String, dynamic>? profileMap;
      if (source['profile'] is Map) {
        profileMap = Map<String, dynamic>.from(source['profile'] as Map);
      } else if (json['profile'] is Map) {
        profileMap = Map<String, dynamic>.from(json['profile'] as Map);
      }

      String? profilePicture = _safeParseString(source["profilePicture"] ??
          source["avatar"] ??
          json["profilePicture"] ??
          json["avatar"]);
      if ((profilePicture == null || profilePicture.isEmpty) &&
          profileMap != null) {
        profilePicture = _safeParseString(profileMap['images']);
      }

      String? fullName = _safeParseString(source["fullName"] ??
          source["fullname"] ??
          json["fullName"] ??
          json["fullname"]);
      if ((fullName == null || fullName.isEmpty) && profileMap != null) {
        fullName = _safeParseString(
            profileMap['fullName'] ?? profileMap['full_name']);
        if (fullName == null || fullName.isEmpty) {
          final f = _safeParseString(
              profileMap['firstName'] ?? profileMap['first_name']);
          final l = _safeParseString(
              profileMap['lastName'] ?? profileMap['last_name']);
          final combined = '${f ?? ''} ${l ?? ''}'.trim();
          if (combined.isNotEmpty) fullName = combined;
        }
      }

      return UserModel(
        userId: _safeParseInt(source["userId"] ??
            source["id"] ??
            json["userId"] ??
            json["id"]),
        password: _safeParseString(source["password"] ?? json["password"]),
        typeAccount:
            _safeParseTypeAccount(source["typeAccount"] ?? json["typeAccount"]),
        email: _safeParseString(source["email"] ?? json["email"]),
        username: _safeParseString(source["username"] ?? json["username"]),
        phone: _safeParseString(source["phone"] ??
            source["telephone"] ??
            json["phone"] ??
            json["telephone"]),
        city: _safeParseString(source["city"] ?? json["city"]),
        country: _safeParseString(source["country"] ?? json["country"]),
        isPremium: _parsePremium(
          source["isPremium"] ??
              source["premium"] ??
              source["is_premium"] ??
              json["isPremium"] ??
              json["premium"] ??
              json["is_premium"],
        ),
        isCertified: _safeParseBool(source["isCertified"] ??
            source["certified"] ??
            json["isCertified"] ??
            json["certified"]),
        cityModel: _safeParseCityModel(source["cityModel"] ?? json["cityModel"]),
        createdStart:
            _safeParseString(json["createdStart"] ?? json["createdAt"]),
        profilePicture: profilePicture,
        fullName: fullName,
      );
    } catch (e, stack) {
      print("❌ Erreur dans UserModel.fromJson: $e");
      print("🔍 Stack trace: $stack");
      print("📋 Données reçues: $json");
      rethrow;
    }
  }

// Méthodes helpers pour le parsing sécurisé
  static int? _safeParseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is double) return value.toInt();
    return null;
  }

  static String? _safeParseString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value.isEmpty ? null : value;
    return value.toString();
  }

  static bool? _safeParseBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is String) {
      return value.toLowerCase() == 'true' || value == '1';
    }
    if (value is int) return value == 1;
    return false;
  }

  /// Premium : BD/API souvent `is_premium` ; `null` si absent (ne pas forcer false).
  static bool? _parsePremium(dynamic value) {
    if (value == null) return null;
    return _safeParseBool(value);
  }

  static TypeAccountModel? _safeParseTypeAccount(dynamic value) {
    if (value == null) return null;
    try {
      if (value is TypeAccountModel) return value;
      if (value is Map) {
        // Convertir en Map<String, dynamic> pour éviter les problèmes de type
        final Map<String, dynamic> safeMap = value.cast<String, dynamic>();
        return TypeAccountModel.fromJson(safeMap);
      }
      return null;
    } catch (e) {
      print("⚠️ Erreur parsing TypeAccount: $e");
      return null;
    }
  }

  static CityModel? _safeParseCityModel(dynamic value) {
    if (value == null) return null;
    try {
      if (value is CityModel) return value;
      if (value is Map) {
        final Map<String, dynamic> safeMap = value.cast<String, dynamic>();
        return CityModel.fromJson(safeMap);
      }
      return null;
    } catch (e) {
      print("⚠️ Erreur parsing CityModel: $e");
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
    "userId": userId,
    "password": password,
    "typeAccount": typeAccount?.toJson(),
    "email": email,
    "username": username,
    "phone": phone,
    "city": city,
    "country": country,
    "isPremium": isPremium,
    "premium": isPremium,
    "is_premium": isPremium,
    "isCertified": isCertified,
    "certified": isCertified,
    "cityModel": cityModel?.toJson(),
    "createdStart": createdStart,
    "profilePicture": profilePicture,
    "fullName": fullName,
  };

  String get displayName {
    return username ?? email?.split('@').first ?? 'Utilisateur';
  }

  String get displayFullName {
    return fullName ?? username ?? email?.split('@').first ?? 'Utilisateur';
  }

  String get formattedLocation {
    List<String> parts = [];
    if (city != null && city!.isNotEmpty) parts.add(city!);
    if (country != null && country!.isNotEmpty) parts.add(country!);
    return parts.join(', ');
  }

  bool get isProUser {
    return isPremium == true || isCertified == true;
  }

  String get userStatus {
    if (isCertified == true) return 'Certifié';
    if (isPremium == true) return 'Premium';
    return 'Standard';
  }

  @override
  String toString() {
    return 'UserModel(userId: $userId, email: $email, username: $username, isPremium: $isPremium, isCertified: $isCertified)';
  }

  UserModel copyWith({
    int? userId,
    String? password,
    TypeAccountModel? typeAccount,
    String? email,
    String? username,
    String? phone,
    String? city,
    String? country,
    bool? isPremium,
    bool? isCertified,
    CityModel? cityModel,
    String? createdStart,
    String? profilePicture,
    String? fullName,
  }) {
    return UserModel(
      userId: userId ?? this.userId,
      password: password ?? this.password,
      typeAccount: typeAccount ?? this.typeAccount,
      email: email ?? this.email,
      username: username ?? this.username,
      phone: phone ?? this.phone,
      city: city ?? this.city,
      country: country ?? this.country,
      isPremium: isPremium ?? this.isPremium,
      isCertified: isCertified ?? this.isCertified,
      cityModel: cityModel ?? this.cityModel,
      createdStart: createdStart ?? this.createdStart,
      profilePicture: profilePicture ?? this.profilePicture,
      fullName: fullName ?? this.fullName,
    );
  }
}
import 'UserModel.dart';

double? _parseCote(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

int? _parseInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is String) return int.tryParse(v);
  if (v is double) return v.toInt();
  return null;
}

/// Avis lié à une sollicitation (API `cotation`).
class CotationModel {
  int? id;
  int? userId;
  int? sollicitationId;
  /// Présent sur certains endpoints publics (avis filtrable par prestation).
  int? prestationId;
  /// Certains endpoints renvoient directement l'identité du client (dérivée de la sollicitation).
  String? name;
  String? profile;
  String? commentaire;
  double? cote;
  String? createdAt;
  UserModel? user;

  CotationModel({
    this.id,
    this.userId,
    this.sollicitationId,
    this.prestationId,
    this.name,
    this.profile,
    this.commentaire,
    this.cote,
    this.createdAt,
    this.user,
  });

  static int? _prestationIdFromJson(Map<String, dynamic> json) {
    int? p = _parseInt(json['prestationId']);
    if (p != null) return p;
    final sol = json['sollicitation'];
    if (sol is Map) {
      final m = Map<String, dynamic>.from(sol);
      p = _parseInt(m['prestationId']);
      if (p != null) return p;
      final prest = m['prestation'];
      if (prest is Map) {
        p = _parseInt(Map<String, dynamic>.from(prest)['id']);
      }
    }
    return p;
  }

  factory CotationModel.fromJson(Map<String, dynamic> json) {
    final rawName = json['name']?.toString();
    final rawProfile = json['profile']?.toString();
    final hasDirectIdentity =
        rawName != null && rawName.trim().isNotEmpty && rawName != 'null';

    return CotationModel(
      id: _parseInt(json['id']),
      userId: _parseInt(json['userId']),
      sollicitationId: _parseInt(json['sollicitationId']),
      prestationId: _prestationIdFromJson(json),
      name: hasDirectIdentity ? rawName?.trim() : null,
      profile: (rawProfile != null && rawProfile.trim().isNotEmpty && rawProfile != 'null')
          ? rawProfile.trim()
          : null,
      commentaire: json['commentaire']?.toString(),
      cote: _parseCote(json['cote']),
      createdAt: json['createdAt']?.toString(),
      user: json['user'] is Map<String, dynamic>
          ? UserModel.fromJson(Map<String, dynamic>.from(json['user']))
          : (hasDirectIdentity
              ? UserModel(
                  userId: _parseInt(json['userId']),
                  username: rawName?.trim(),
                  fullName: rawName?.trim(),
                  profilePicture: (rawProfile != null &&
                          rawProfile.trim().isNotEmpty &&
                          rawProfile != 'null')
                      ? rawProfile.trim()
                      : null,
                )
              : null),
    );
  }
}

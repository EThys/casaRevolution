import 'CommuneModel.dart';

class QuartierModel {
  final int? quartierId;
  final String? name;
  final int? communeId;
  final CommuneModel? commune;

  QuartierModel({
    this.quartierId,
    this.name,
    this.communeId,
    this.commune,
  });

  factory QuartierModel.fromJson(Map<String, dynamic> json) {
    return QuartierModel(
      quartierId: json['quartierId'],
      name: json['name'],
      communeId: json['communeId'] ?? (json['commune'] != null ? json['commune']['communeId'] : null),
      commune: json['commune'] != null ? CommuneModel.fromJson(json['commune']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'quartierId': quartierId,
      'name': name,
      'communeId': communeId,
      if (commune != null) 'commune': commune!.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is QuartierModel &&
              runtimeType == other.runtimeType &&
              quartierId == other.quartierId;

  @override
  int get hashCode => quartierId.hashCode;

  @override
  String toString() {
    return 'QuartierModel{quartierId: $quartierId, name: $name, communeId: $communeId}';
  }

  // Méthode pour copier l'objet avec des modifications
  QuartierModel copyWith({
    int? quartierId,
    String? name,
    int? communeId,
    CommuneModel? commune,
  }) {
    return QuartierModel(
      quartierId: quartierId ?? this.quartierId,
      name: name ?? this.name,
      communeId: communeId ?? this.communeId,
      commune: commune ?? this.commune,
    );
  }
}
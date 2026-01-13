class DeviseModel {
  int? id;
  String? name;
  String? code;
  double? tauxLocal;

  DeviseModel({this.id, this.name, this.code, this.tauxLocal});

  factory DeviseModel.fromJson(Map<String, dynamic> json) {
    return DeviseModel(
      id: json['id'],
      name: json['name'],
      code: json['code'],
      tauxLocal: (json['tauxLocal'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'tauxLocal': tauxLocal,
    };
  }
}

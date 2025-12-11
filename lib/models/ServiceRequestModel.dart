import 'ServiceRequestResponseModel.dart';

class ServiceRequestModel {
  int? requestId;
  int? userId;
  String? serviceType;
  String? message;
  bool? isUrgent;
  double? latitude;
  double? longitude;
  String? address;
  String? status; // PENDING, ACCEPTED, DECLINED, COMPLETED, CANCELLED
  DateTime? createdAt;
  DateTime? updatedAt;
  List<ServiceRequestResponseModel>? responses;
  int? acceptedResponseId;
  
  // Informations du demandeur (pour l'affichage)
  String? userName;
  String? userAvatar;
  String? userPhone;

  ServiceRequestModel({
    this.requestId,
    this.userId,
    this.serviceType,
    this.message,
    this.isUrgent,
    this.latitude,
    this.longitude,
    this.address,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.responses,
    this.acceptedResponseId,
    this.userName,
    this.userAvatar,
    this.userPhone,
  });

  factory ServiceRequestModel.fromJson(Map<String, dynamic> json) {
    List<ServiceRequestResponseModel>? responsesList;
    if (json['responses'] != null && json['responses'] is List) {
      responsesList = (json['responses'] as List)
          .map((response) => ServiceRequestResponseModel.fromJson(response))
          .toList();
    }

    return ServiceRequestModel(
      requestId: json['requestId'] as int? ?? json['id'] as int?,
      userId: json['userId'] as int?,
      serviceType: json['serviceType'] as String?,
      message: json['message'] as String?,
      isUrgent: json['isUrgent'] as bool? ?? false,
      latitude: json['latitude'] != null ? double.tryParse(json['latitude'].toString()) : null,
      longitude: json['longitude'] != null ? double.tryParse(json['longitude'].toString()) : null,
      address: json['address'] as String?,
      status: json['status'] as String? ?? 'PENDING',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
      responses: responsesList,
      acceptedResponseId: json['acceptedResponseId'] as int?,
      userName: json['userName'] as String? ?? json['user']?['name'] as String?,
      userAvatar: json['userAvatar'] as String? ?? json['user']?['avatar'] as String?,
      userPhone: json['userPhone'] as String? ?? json['user']?['phone'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'requestId': requestId,
      'userId': userId,
      'serviceType': serviceType,
      'message': message,
      'isUrgent': isUrgent ?? false,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'status': status ?? 'PENDING',
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'responses': responses?.map((r) => r.toJson()).toList(),
      'acceptedResponseId': acceptedResponseId,
      'userName': userName,
      'userAvatar': userAvatar,
      'userPhone': userPhone,
    };
  }

  ServiceRequestModel copyWith({
    int? requestId,
    int? userId,
    String? serviceType,
    String? message,
    bool? isUrgent,
    double? latitude,
    double? longitude,
    String? address,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ServiceRequestResponseModel>? responses,
    int? acceptedResponseId,
    String? userName,
    String? userAvatar,
    String? userPhone,
  }) {
    return ServiceRequestModel(
      requestId: requestId ?? this.requestId,
      userId: userId ?? this.userId,
      serviceType: serviceType ?? this.serviceType,
      message: message ?? this.message,
      isUrgent: isUrgent ?? this.isUrgent,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      responses: responses ?? this.responses,
      acceptedResponseId: acceptedResponseId ?? this.acceptedResponseId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      userPhone: userPhone ?? this.userPhone,
    );
  }
}


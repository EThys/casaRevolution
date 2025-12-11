class ServiceRequestResponseModel {
  int? responseId;
  int? requestId;
  int? providerId;
  String? providerName;
  String? providerAvatar;
  String? providerPhone;
  String? message;
  double? price;
  String? estimatedTime;
  String? status; // PENDING, ACCEPTED, DECLINED
  DateTime? createdAt;
  DateTime? updatedAt;

  ServiceRequestResponseModel({
    this.responseId,
    this.requestId,
    this.providerId,
    this.providerName,
    this.providerAvatar,
    this.providerPhone,
    this.message,
    this.price,
    this.estimatedTime,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory ServiceRequestResponseModel.fromJson(Map<String, dynamic> json) {
    return ServiceRequestResponseModel(
      responseId: json['responseId'] as int? ?? json['id'] as int?,
      requestId: json['requestId'] as int?,
      providerId: json['providerId'] as int? ?? json['provider']?['id'] as int?,
      providerName: json['providerName'] as String? ?? 
                    json['provider']?['name'] as String? ??
                    json['provider']?['fullname'] as String?,
      providerAvatar: json['providerAvatar'] as String? ?? json['provider']?['avatar'] as String?,
      providerPhone: json['providerPhone'] as String? ?? json['provider']?['phone'] as String?,
      message: json['message'] as String?,
      price: json['price'] != null ? double.tryParse(json['price'].toString()) : null,
      estimatedTime: json['estimatedTime'] as String?,
      status: json['status'] as String? ?? 'PENDING',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'responseId': responseId,
      'requestId': requestId,
      'providerId': providerId,
      'providerName': providerName,
      'providerAvatar': providerAvatar,
      'providerPhone': providerPhone,
      'message': message,
      'price': price,
      'estimatedTime': estimatedTime,
      'status': status ?? 'PENDING',
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  ServiceRequestResponseModel copyWith({
    int? responseId,
    int? requestId,
    int? providerId,
    String? providerName,
    String? providerAvatar,
    String? providerPhone,
    String? message,
    double? price,
    String? estimatedTime,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ServiceRequestResponseModel(
      responseId: responseId ?? this.responseId,
      requestId: requestId ?? this.requestId,
      providerId: providerId ?? this.providerId,
      providerName: providerName ?? this.providerName,
      providerAvatar: providerAvatar ?? this.providerAvatar,
      providerPhone: providerPhone ?? this.providerPhone,
      message: message ?? this.message,
      price: price ?? this.price,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}


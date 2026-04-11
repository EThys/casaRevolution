import 'package:flutter/material.dart';
import '../utils/Endpoints.dart';
import '../utils/log_redaction.dart';
import '../utils/requetes.dart' show HttpResponse, postDataOtp;

class ForgotPasswordController with ChangeNotifier {
  bool loading = false;
  String? phoneNumber;
  int? userId;
  String? otpStatus;
  /// Jeton renvoyé après OTP réussi (requis pour `protected/reset/password`), si l’API le fournit.
  String? passwordResetToken;

  static String? _readTokenFromMap(Map<dynamic, dynamic> map) {
    const keys = ['token', 'accessToken', 'access_token', 'resetToken', 'bearer', 'jwt'];
    for (final k in keys) {
      final v = map[k];
      if (v != null && v.toString().trim().isNotEmpty) {
        return v.toString();
      }
    }
    return null;
  }

  void _capturePasswordResetToken(Map<String, dynamic> responseData) {
    passwordResetToken = _readTokenFromMap(responseData);
    if (passwordResetToken != null) return;
    final user = responseData['user'];
    if (user is Map) {
      passwordResetToken = _readTokenFromMap(user);
    }
    if (passwordResetToken != null) return;
    final nested = responseData['data'];
    if (nested is Map) {
      passwordResetToken = _readTokenFromMap(nested);
    }
  }

  Future<HttpResponse> generateOTP(String identifier) async {
    loading = true;
    notifyListeners();

    try {
      print("🚀 Génération OTP pour: $identifier");

      final url = Endpoints.otpGenerate;
      final data = {
        "identifier": identifier,
      };

      HttpResponse response = await postDataOtp(url, data);

      if (response.status == true && response.data != null) {
        if (response.data is Map) {
          final responseData = response.data as Map<String, dynamic>;

          if (responseData.containsKey('phone')) {
            phoneNumber = responseData['phone'] as String?;
            otpStatus = responseData['status'] as String?;
            print("✅ OTP généré avec succès pour: $phoneNumber");
          }

          if (responseData.containsKey('message')) {
            print("📝 Message: ${responseData['message']}");
          }
        }
      } else {
        print("❌ Erreur lors de la génération OTP");
        if (response.errorMsg != null) {
          print("❌ Message d'erreur: ${response.errorMsg}");
        }
      }

      loading = false;
      notifyListeners();
      return response;
    } catch (e) {
      print("❌ Erreur critique dans generateOTP: $e");
      loading = false;
      notifyListeners();

      return HttpResponse(
        status: false,
        errorMsg: "Erreur lors de la génération du code: ${e.toString()}",
        isException: true,
        data: {
          'error': e.toString(),
          'timestamp': DateTime.now().toIso8601String()
        }
      );
    }
  }

  Future<HttpResponse> verifyOTP(String identifier, String code) async {
    loading = true;
    notifyListeners();

    try {
      print("🔍 Vérification OTP pour: $identifier avec code: $code");

      final url = Endpoints.otpVerify;
      final data = {
        "identifier": identifier,
        "code": code,
      };

      HttpResponse response = await postDataOtp(url, data);

      if (response.status == true && response.data != null) {
        if (response.data is Map) {
          final responseData = response.data as Map<String, dynamic>;

          final status = responseData['status'] as String?;

          if (status == "approved") {
            _capturePasswordResetToken(responseData);
            print(
                '🔑 ${describeSecretPresence(passwordResetToken, name: 'Jeton reset (après OTP)')}');
            if (responseData.containsKey('user')) {
              final user = responseData['user'];
              if (user is Map && user.containsKey('id')) {
                userId = user['id'] as int?;
                print("✅ OTP vérifié avec succès. User ID: $userId");
              } else if (user is int) {
                userId = user;
                print("✅ OTP vérifié avec succès. User ID: $userId");
              }
            } else if (responseData.containsKey('userId')) {
              userId = responseData['userId'] as int?;
              print("✅ OTP vérifié avec succès. User ID: $userId");
            }

            otpStatus = status;
          } else {
            print("⚠️ Status OTP: $status (code expiré ou invalide)");
            loading = false;
            notifyListeners();

            return HttpResponse(
              status: false,
              errorMsg: "Code expiré ou invalide",
              data: responseData
            );
          }
        }
      } else {
        print("❌ Erreur lors de la vérification OTP");
        if (response.errorMsg != null) {
          print("❌ Message d'erreur: ${response.errorMsg}");
        }
      }

      loading = false;
      notifyListeners();
      return response;
    } catch (e) {
      print("❌ Erreur critique dans verifyOTP: $e");
      loading = false;
      notifyListeners();

      return HttpResponse(
        status: false,
        errorMsg: "Erreur lors de la vérification du code: ${e.toString()}",
        isException: true,
        data: {
          'error': e.toString(),
          'timestamp': DateTime.now().toIso8601String()
        }
      );
    }
  }

  void reset() {
    phoneNumber = null;
    userId = null;
    otpStatus = null;
    passwordResetToken = null;
    loading = false;
    notifyListeners();
  }
}

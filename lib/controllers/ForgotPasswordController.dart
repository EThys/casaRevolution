import 'package:flutter/material.dart';
import '../utils/Endpoints.dart';
import '../utils/requetes.dart' show postData, HttpResponse, postDataOtp, putData;

class ForgotPasswordController with ChangeNotifier {
  bool loading = false;
  String? phoneNumber;
  int? userId;
  String? otpStatus;

  // Générer l'OTP
  Future<HttpResponse> generateOTP(String identifier) async {
    loading = true;
    notifyListeners();

    try {
      print("🚀 Génération OTP pour: $identifier");
      
      final url = Endpoints.otpGenerate;
      final data = {
        "identifier": identifier,
      };

      HttpResponse response = await postDataOtp(url, data, token: "");

      if (response.status == true && response.data != null) {
        // Vérifier la structure de la réponse
        if (response.data is Map) {
          final responseData = response.data as Map<String, dynamic>;
          
          // Extraire le numéro de téléphone de la réponse
          if (responseData.containsKey('phone')) {
            phoneNumber = responseData['phone'] as String?;
            otpStatus = responseData['status'] as String?;
            print("✅ OTP généré avec succès pour: $phoneNumber");
          }
          
          // Vérifier le message
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

  // Vérifier l'OTP
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

      HttpResponse response = await postDataOtp(url, data, token: "");

      if (response.status == true && response.data != null) {
        // Vérifier la structure de la réponse
        if (response.data is Map) {
          final responseData = response.data as Map<String, dynamic>;
          
          // Vérifier le status
          final status = responseData['status'] as String?;
          
          if (status == "approved") {
            // Extraire l'ID de l'utilisateur
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
            // Status différent de "approved" = code expiré ou invalide
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

  // Réinitialiser le mot de passe
  Future<HttpResponse> resetPassword(String newPassword, int userUserId) async {
    loading = true;
    notifyListeners();

    try {
      print("🔐 Réinitialisation du mot de passe pour User ID: $userUserId");
      
      final url = Endpoints.resetPasswordEndpoint;
      final data = {
        "newPassword": newPassword,
        "userId": userUserId,
      };

      HttpResponse response = await putData(url, data, token: "");

      if (response.status == true) {
        print("✅ Mot de passe réinitialisé avec succès");
        
        // Réinitialiser les variables après succès
        userId = null;
        phoneNumber = null;
        otpStatus = null;
      } else {
        print("❌ Erreur lors de la réinitialisation");
        if (response.errorMsg != null) {
          print("❌ Message d'erreur: ${response.errorMsg}");
        }
      }

      loading = false;
      notifyListeners();
      return response;
    } catch (e) {
      print("❌ Erreur critique dans resetPassword: $e");
      loading = false;
      notifyListeners();
      
      return HttpResponse(
        status: false,
        errorMsg: "Erreur lors de la réinitialisation: ${e.toString()}",
        isException: true,
        data: {
          'error': e.toString(),
          'timestamp': DateTime.now().toIso8601String()
        }
      );
    }
  }

  // Réinitialiser l'état du contrôleur
  void reset() {
    phoneNumber = null;
    userId = null;
    otpStatus = null;
    loading = false;
    notifyListeners();
  }
}


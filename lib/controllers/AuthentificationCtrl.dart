import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import '../models/UserModel.dart';
import '../utils/Endpoints.dart';
import '../utils/StockageKeys.dart';
import '../utils/requetes.dart';
import '../utils/DraftHelper.dart';

class AuthentificationCtrl with ChangeNotifier {
  AuthentificationCtrl({this.stockage});

  String _token = "";
  UserModel _user = UserModel();
  List<UserModel> listUsers = [];
  UserModel _userAuth = UserModel();
  GetStorage? stockage;

  List<UserModel> Listregister = [];
  List<UserModel> Listlogin = [];
  bool loading = false;

  String get token {
    if (_token.isEmpty) {
      _token = stockage?.read<String>(StockageKeys.tokenKey) ?? "";
    }
    return _token;
  }

  set token(String value) {
    _token = value;
    stockage?.write(StockageKeys.tokenKey, value);
    notifyListeners();
  }

  UserModel get user {
    if (_user.userId == null) {
      try {
        final locale = stockage?.read<Map<String, dynamic>>(StockageKeys.userKey);
        if (locale != null) {
          _user = UserModel.fromJson(locale);
        }
      } catch (e) {
        print("❌ Erreur de décodage de l'utilisateur: $e");
        _user = UserModel();
      }
    }
    return _user;
  }

  set user(UserModel value) {
    _user = value;
    try {
      stockage?.write(StockageKeys.userKey, value.toJson());
      notifyListeners();
    } catch (e) {
      print("❌ Erreur d'encodage de l'utilisateur: $e");
    }
  }

  bool get isLoggedIn {
    return token.isNotEmpty && user.userId != null;
  }

  UserModel get userPreference {
    try {
      var locale = stockage?.read<Map<String, dynamic>>(StockageKeys.userPreferenceKey);
      if (locale != null) {
        _userAuth = UserModel.fromJson(locale);
      }
    } catch (e) {
      print("❌ Erreur de décodage des préférences utilisateur: $e");
    }
    return _userAuth;
  }

  set userPreference(UserModel value) {
    _userAuth = value;
    stockage?.write(StockageKeys.userPreferenceKey, value.toJson());
  }

  // Initialisation du stockage
  Future<void> initStorage() async {
    try {
      await GetStorage.init();
      stockage = GetStorage();
      print("✅ Stockage initialisé avec succès");
    } catch (e) {
      print("❌ Erreur d'initialisation du stockage: $e");
    }
  }
  Future<HttpResponse> login(Map<String, dynamic> data) async {
    try {
      loading = true;
      notifyListeners();

      // Initialiser le stockage si nécessaire
      if (stockage == null) {
        await initStorage();
      }

      var url = "${Endpoints.login}";
      print("URL de connexion: $url");
      print("Données envoyées: $data");

      HttpResponse response = await postDataForAuth(url, data, token: "");
      print("Statut de la réponse: ${response.status}");
      print("Réponse API: ${response.data}");

      if (response.status != true) {
        loading = false;
        notifyListeners();
        print("❌ Statut HTTP non valide: ${response.status}");
        return response;
      }

      // Vérification de la présence du mot "réussie" dans le message
      String message = response.data['message']?.toString() ?? '';
      bool isSuccess = message.toLowerCase().contains('réussie');

        if (isSuccess) {
        print("✅ Message de succès détecté: $message");

        var token = response.data['token'];
        var refreshToken = response.data['refresh_token'];
        var member = response.data['member'];

        if (token != null && member != null) {
          var userJson = member['user'];
          var profileJson = member['profile'];

          print("Token reçu: ${token.toString().substring(0, 10)}...");
          print("Données utilisateur reçues: ${userJson['email']}");

          // Stockage sécurisé des données
          await _storeAuthData(token, refreshToken, userJson, profileJson);
          
          // Sauvegarder aussi les comptes du user si besoin
           if (member['accounts'] != null) {
              await stockage?.write('user_accounts', member['accounts']);
           }

          print("✅ Connexion et stockage réussis");
        } else {
          print("❌ Token ou données membre manquants dans la réponse");
          throw Exception("Données d'authentification incomplètes");
        }
      } else {
        String errorMessage = response.data['detailMessage'] ?? "Échec de la connexion";
        print("❌ Échec connexion: $errorMessage");
        throw Exception(errorMessage);
      }

      loading = false;
      notifyListeners();
      return response;

    } catch (e, stack) {
      loading = false;
      notifyListeners();
      print("❌ Erreur critique lors du login: $e");
      print("🔍 Stack trace: $stack");

      // Retourner une réponse d'erreur cohérente
      return HttpResponse(
        data: {
          'message': e.toString(),
        },
        status: false,
      );
    }
  }

// Méthode pour stocker les données d'authentification
// Méthode pour stocker les données d'authentification - VERSION CORRIGÉE
  Future<void> _storeAuthData(String token, String? refreshToken, Map<String, dynamic> userJson, Map<String, dynamic>? profileJson) async {
    try {
      print("💾 Début du stockage des données d'authentification...");

      // Stockage des tokens
      await stockage?.write(StockageKeys.tokenKey, token);
      print("✅ Token stocké");

      if (refreshToken != null) {
        await stockage?.write(StockageKeys.refreshTokenKey, refreshToken);
        print("✅ Refresh token stocké");
      }

      // Conversion et stockage de l'utilisateur
      UserModel user = UserModel.fromJson(userJson);
      await stockage?.write(StockageKeys.userKey, user.toJson());
      print("✅ Données utilisateur stockées");

      // Stockage du profile si disponible - CORRECTION ICI
      if (profileJson != null) {
        // Vérifier que profileJson est bien un Map et non une String
        if (profileJson is Map<String, dynamic>) {
          await stockage?.write(StockageKeys.profileKey, profileJson);
          print("✅ Données profile stockées");

          // Afficher les infos du profile pour debug
          print("📋 Profile stocké - Prénom: ${profileJson['firstname']}, Nom: ${profileJson['lastname']}");
        } else {
          print("⚠️ Format de profile invalide: ${profileJson.runtimeType}");
        }
      } else {
        print("⚠️ Aucun profile reçu dans la réponse");
      }

      // Mise à jour des propriétés en mémoire
      _token = token;
      _user = user;

      print("📊 Données stockées - User ID: ${user.userId}, Email: ${user.email}");
      print("🎫 Token en mémoire: ${_token.substring(0, 20)}...");

    } catch (e, stack) {
      print("❌ Erreur lors du stockage des données: $e");
      print("🔍 Détails de l'erreur: $stack");

      // Nettoyage en cas d'erreur
      await _cleanupStorage();
      throw Exception("Erreur de stockage des données: $e");
    }
    }

  // Vérification d'identité
    Future<HttpResponse> verifyIdentity(String userId, Map<String, dynamic> payload) async {
    try {
      loading = true;
      notifyListeners();

      // Récupérer le profile ID depuis le stockage si possible
      String targetId = userId;
      try {
        final profileData = stockage?.read(StockageKeys.profileKey);
        if (profileData != null && profileData is Map) {
             final profileId = profileData['id'];
             if (profileId != null) {
               targetId = profileId.toString();
               print("🆔 Utilisation de l'ID du profil: $targetId au lieu de $userId");
             }
        }
      } catch (e) {
        print("⚠️ Erreur récupération profile ID: $e");
      }

      // Utilisation de l'endpoint PUT /api/members/{id} (ici profileId)
      final url = "members/$targetId";
      print("📤 Envoi vérification d'identité vers $url");
      
      final response = await putData(url, payload, token: token);
      
      print("📥 Réponse vérification: ${response.data}");

      if (response.status == true) {
        // La réponse contient "person"
        final personData = response.data['person'];
        
        if (personData != null) {
            print("✅ Identité mise à jour pour: ${personData['fullName']}");
            
            // Mettre à jour le profil local
            try {
              // Structure attendue pour le profileKey basée sur les logs user
              Map<String, dynamic> updatedProfile = {
                 'id': personData['id'], // Important: garder l'ID du profil
                 'firstname': personData['firstName'],
                 'lastname': personData['lastName'],
                 'fullname': personData['fullName'],
                 'address': personData['address'],
                 'images': personData['images'],
                 'cardFront': personData['cardFront'],
                 'cardBack': personData['cardBack'],
                 'numberCard': personData['numberCard'],
                 // Garder d'autres champs potentiels de l'ancien profil si nécessaire, mais ici on semble avoir tout
              };
              
              // Fusionner avec l'existant pour ne rien perdre (ex: bio si elle n'est pas renvoyée ?)
              Map<String, dynamic>? currentProfile = stockage?.read(StockageKeys.profileKey);
              if (currentProfile != null) {
                  currentProfile.addAll(updatedProfile);
                  await stockage?.write(StockageKeys.profileKey, currentProfile);
              } else {
                  await stockage?.write(StockageKeys.profileKey, updatedProfile);
              }
              
              print("💾 Profil local mis à jour avec les infos d'identité");
            } catch (e) {
              print("⚠️ Erreur mise à jour profil local: $e");
            }

             // Optimistic update status user
             _user.isCertified = true; 
             // On met à jour l'objet user s'il est retourné dans la réponse (non visible dans le log snippet "person")
             // Mais on sait que le user est certifié maintenant.
             await stockage?.write(StockageKeys.userKey, _user.toJson());
        }
        notifyListeners();
      }

      loading = false;
      notifyListeners();
      return response;
    } catch (e) {
      loading = false;
      notifyListeners();
      print("❌ Erreur verifyIdentity: $e");
      return HttpResponse(status: false, errorMsg: e.toString(), isException: true);
    }
  }

    Future<HttpResponse> register(Map<String, dynamic> payload, {required String url}) async {
    try {
      // Endpoint fixe selon la demande
      const registerUrl = Endpoints.register; 
      print("Payload d'inscription: $payload");

      HttpResponse response = await postData(registerUrl, payload, token: "");

      if (response.data == null) {
        return HttpResponse(
          status: false,
          errorMsg: "Réponse vide du serveur",
          isException: true,
        );
      }

      print("Réponse API (Inscription): ${response.data}");

      // Vérification du succès (similaire au login souvent, ou présence de token/member)
      // La réponse exemple n'est pas explicite sur le succès, mais on suppose un 200 OK avec structure similaire
       String message = response.data['message']?.toString() ?? '';
       // Parfois inscription retourne direct le token, parfois demande confirmation.
       // Ici on suppose que ça connecte direct comme avant si token présent.
       
       var token = response.data['token'];
       var member = response.data['member'];
       
       if (token != null && member != null) {
          var userJson = member['user'];
           await stockage?.write(StockageKeys.tokenKey, token);
           user = UserModel.fromJson(userJson);
           this.user = user;
           notifyListeners();
           
           return HttpResponse(
            status: true,
            data: response.data,
            errorMsg: message
           );
       } else if (response.status == true) {
           // Succès sans login automatique (ex: "Compte créé")
           return response;
       } else {
          print("Token ou membre manquant dans la réponse d'inscription");
           // Gestion des erreurs API
        String errorMsg = response.data['message'] ??
            response.data['errors']?.toString() ??
            "Erreur lors de l'inscription";
        return HttpResponse(
          status: false,
          errorMsg: errorMsg,
          data: response.data,
        );
       }


      return response;
    } catch (e, stackTrace) {
      print("Exception lors de l'inscription: $e");
      print("Stack trace: $stackTrace");
      return HttpResponse(
        status: false,
        errorMsg: e.toString(),
        isException: true,
      );
    }
  }


  // Nettoyage du stockage en cas d'erreur
  Future<void> _cleanupStorage() async {
    try {
      await stockage?.remove(StockageKeys.tokenKey);
      await stockage?.remove(StockageKeys.refreshTokenKey);
      await stockage?.remove(StockageKeys.userKey);
      print("🧹 Stockage nettoyé après erreur");
    } catch (e) {
      print("❌ Erreur lors du nettoyage: $e");
    }
  }




  // LOGOUT USER
  Future<HttpResponse> logout(Map<String, dynamic> data) async {
    try {
      loading = true;
      notifyListeners();

      var url = "${Endpoints.logout}";
      var tkn = token;

      print("Déconnexion en cours...");
      HttpResponse response = await postData(url, data, token: tkn);

      if (response.status == true) {
        print("Déconnexion API réussie");

        // Nettoyage local regardless de la réponse API
        await _clearLocalAuthData();

        print("✅ Données locales supprimées");
      } else {
        print("Déconnexion API échouée, nettoyage local quand même");
        await _clearLocalAuthData();
      }

      loading = false;
      notifyListeners();
      return response;

    } catch (e) {
      loading = false;
      notifyListeners();
      print("❌ Erreur lors de la déconnexion: $e");

      // Nettoyage local même en cas d'erreur
      await _clearLocalAuthData();

      return HttpResponse(
        data: {'message': e.toString()},
        status: false,
      );
    }
  }

  Future<void> _clearLocalAuthData() async {
    try {
      _token = "";
      _user = UserModel();
      _userAuth = UserModel();

      await stockage?.remove(StockageKeys.tokenKey);
      await stockage?.remove(StockageKeys.refreshTokenKey);
      await stockage?.remove(StockageKeys.userKey);
      await stockage?.remove(StockageKeys.userPreferenceKey);
      await stockage?.remove(StockageKeys.profileKey);

      // Supprimer les brouillons expirés
      try {
        await DraftHelper.clearAllDrafts();
        print("✅ Brouillons expirés supprimés");
      } catch (e) {
        print("⚠️ Erreur lors de la suppression des brouillons: $e");
      }

      print("✅ Données d'authentification locales supprimées");
    } catch (e) {
      print("❌ Erreur lors du nettoyage des données locales: $e");
    }
  }

  // Méthode pour vérifier si l'utilisateur est déjà connecté au démarrage
  Future<bool> checkExistingAuth() async {
    try {
      if (stockage == null) {
        await initStorage();
      }

      String storedToken = stockage?.read<String>(StockageKeys.tokenKey) ?? "";

      if (storedToken.isNotEmpty) {
        print("Token trouvé dans le stockage local");

        Map<String, dynamic>? userData = stockage?.read<Map<String, dynamic>>(StockageKeys.userKey);
        if (userData != null) {
          _token = storedToken;
          _user = UserModel.fromJson(userData);
          print("Session restaurée pour: ${_user.email}");
          print("👤 User ID: ${_user.userId}");
          return true;
        } else {
          print("❌ Données utilisateur non trouvées");
          await _clearLocalAuthData();
        }
      } else {
        print("🔍 Aucun token trouvé dans le stockage");
      }
    } catch (e) {
      print("❌ Erreur lors de la vérification de l'authentification: $e");
      await _clearLocalAuthData();
    }
    return false;
  }

  // Méthode pour rafraîchir le token
  // Future<bool> refreshToken() async {
  //   try {
  //     String? refreshToken = stockage?.read<String>(StockageKeys.refreshTokenKey);
  //
  //     if (refreshToken == null) {
  //       print("❌ Aucun refresh token disponible");
  //       return false;
  //     }
  //
  //     print("🔄 Rafraîchissement du token en cours...");
  //     var url = "${Endpoints.refreshToken}";
  //     var response = await postData(url, {"refresh_token": refreshToken});
  //
  //     if (response.status == 200) {
  //       // Vérifier si la réponse contient un message de succès
  //       String message = response.data['message']?.toString() ?? '';
  //       bool isSuccess = message.toLowerCase().contains('réussie') ||
  //           response.data['token'] != null;
  //
  //       if (isSuccess) {
  //         String newToken = response.data['token'] ?? response.data['data']['token'];
  //         this.token = newToken;
  //         print("✅ Token rafraîchi avec succès");
  //         return true;
  //       }
  //     }
  //
  //     print("❌ Échec du rafraîchissement du token");
  //     return false;
  //   } catch (e) {
  //     print("❌ Erreur lors du rafraîchissement du token: $e");
  //     return false;
  //   }
  // }

  // Méthode pour afficher les informations de debug
  void printAuthStatus() {
    print("=== ÉTAT AUTHENTIFICATION ===");
    print("🔐 Token présent: ${token.isNotEmpty}");
    print("👤 User ID: ${user.userId}");
    print("📧 Email: ${user.email}");
    print("✅ Connecté: $isLoggedIn");
    print("==============================");
  }

  // Déconnexion silencieuse (sans appel API)
  Future<void> silentLogout() async {
    await _clearLocalAuthData();
    notifyListeners();
    print("🔒 Déconnexion silencieuse effectuée");
  }

  // Mot de passe oublié - Envoie un code OTP
  Future<HttpResponse> forgotPassword(Map<String, dynamic> data) async {
    try {
      loading = true;
      notifyListeners();

      var url = "${Endpoints.forgotPassword}";
      print("URL forgot password: $url");
      print("Données envoyées: $data");

      HttpResponse response = await postDataForAuth(url, data, token: "");

      print("Statut de la réponse: ${response.status}");
      print("Réponse API: ${response.data}");

      loading = false;
      notifyListeners();
      return response;
    } catch (e, stack) {
      loading = false;
      notifyListeners();
      print("❌ Erreur lors de la demande de réinitialisation: $e");
      print("🔍 Stack trace: $stack");

      return HttpResponse(
        data: {
          'message': e.toString(),
        },
        status: false,
      );
    }
  }

  // Vérification du code OTP
  Future<HttpResponse> verifyOTP(Map<String, dynamic> data) async {
    try {
      loading = true;
      notifyListeners();

      // Si votre API utilise un endpoint séparé pour la vérification, utilisez-le
      // Sinon, vous pouvez utiliser le même endpoint que forgot-password avec un paramètre action
      var url = "${Endpoints.verifyOTP}";
      print("URL verify OTP: $url");
      print("Données envoyées: ${data.containsKey('otp') ? 'phone: ${data['phone']}, otp: ***' : data}");

      HttpResponse response = await postDataForAuth(url, data, token: "");

      print("Statut de la réponse: ${response.status}");
      print("Réponse API: ${response.data}");

      loading = false;
      notifyListeners();
      return response;
    } catch (e, stack) {
      loading = false;
      notifyListeners();
      print("❌ Erreur lors de la vérification OTP: $e");
      print("🔍 Stack trace: $stack");

      // Si l'endpoint verify-otp n'existe pas, vous pouvez essayer avec forgot-password/verify
      // ou ajuster selon votre API
      return HttpResponse(
        data: {
          'message': e.toString(),
        },
        status: false,
      );
    }
  }

  // Mise à jour de la photo de profil uniquement
  Future<HttpResponse> updateProfilePicture(int profileId, String base64Image) async {
    try {
      loading = true;
      notifyListeners();

      final url = "members/$profileId/profile";
      final payload = {"image": base64Image};

      print("📤 Mise à jour photo profil vers $url");

      final response = await putData(url, payload, token: token);

      if (response.status == true) {
        print("✅ Photo de profil mise à jour avec succès");
        
        // Mettre à jour le profil local
        try {
          Map<String, dynamic>? currentProfile = stockage?.read(StockageKeys.profileKey);
          if (currentProfile != null) {
            currentProfile['image'] = base64Image; // ou l'URL retournée si l'API renvoie l'URL
            
            // Si l'API renvoie le profil mis à jour, on l'utilise
            if (response.data != null && response.data['data'] != null) {
                 final newData = response.data['data'];
                 if (newData['image'] != null) {
                   currentProfile['image'] = newData['image'];
                 }
            }
            
            await stockage?.write(StockageKeys.profileKey, currentProfile);
            print("💾 Photo mise à jour dans le stockage local");
          }
        } catch (e) {
          print("⚠️ Erreur mise à jour locale photo: $e");
        }
      }

      loading = false;
      notifyListeners();
      return response;
    } catch (e) {
      loading = false;
      notifyListeners();
      print("❌ Erreur updateProfilePicture: $e");
      return HttpResponse(status: false, errorMsg: e.toString(), isException: true);
    }
  }

  // Réinitialisation du mot de passe
  Future<HttpResponse> resetPassword(Map<String, dynamic> data) async {
    try {
      loading = true;
      notifyListeners();

      var url = "${Endpoints.resetPassword}";
      print("URL reset password: $url");
      print("Données envoyées: ${data.containsKey('new_password') ? 'new_password: ***, confirm_password: ***' : data}");

      HttpResponse response = await postDataForAuth(url, data, token: "");

      print("Statut de la réponse: ${response.status}");
      print("Réponse API: ${response.data}");

      loading = false;
      notifyListeners();
      return response;
    } catch (e, stack) {
      loading = false;
      notifyListeners();
      print("❌ Erreur lors de la réinitialisation du mot de passe: $e");
      print("🔍 Stack trace: $stack");

      return HttpResponse(
        data: {
          'message': e.toString(),
        },
        status: false,
      );
    }
  }
}
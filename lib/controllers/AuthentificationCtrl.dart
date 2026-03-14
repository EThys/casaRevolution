import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import '../models/UserModel.dart';
import '../utils/Endpoints.dart';
import '../utils/StockageKeys.dart';
import '../utils/requetes.dart';
import '../utils/DraftHelper.dart';
import '../utils/AgenceDatabaseHelper.dart';
import '../utils/database/DatabaseHelper.dart';
import '../utils/database/PropertyDatabaseHelper.dart';
import '../utils/database/PrestationDatabaseHelper.dart';
import '../utils/TerrainDatabaseHelper.dart';
import '../utils/StompService.dart';
import 'NotificationController.dart';

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
        print("Erreur de décodage de l'utilisateur: $e");
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
      print("Erreur d'encodage de l'utilisateur: $e");
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
      print("Erreur de décodage des préférences utilisateur: $e");
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
      print("Stockage initialisé avec succès");
    } catch (e) {
      print("Erreur d'initialisation du stockage: $e");
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
        print("Statut HTTP non valide: ${response.status}");
        return response;
      }

      // Vérification de la présence du mot "réussie" dans le message
      String message = response.data['message']?.toString() ?? '';
      bool isSuccess = message.toLowerCase().contains('réussie');

        if (isSuccess) {
        print("Message de succès détecté: $message");

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

          // Activer les notifications WebSocket
          NotificationController().loadForUser(user.userId.toString());

          print("Connexion et stockage réussis");
        } else {
          print("Token ou données membre manquants dans la réponse");
          throw Exception("Données d'authentification incomplètes");
        }
      } else {
        String errorMessage = response.data['detailMessage'] ?? "Échec de la connexion";
        print("Échec connexion: $errorMessage");
        throw Exception(errorMessage);
      }

      loading = false;
      notifyListeners();
      return response;

    } catch (e, stack) {
      loading = false;
      notifyListeners();
      print("Erreur critique lors du login: $e");
      print("Stack trace: $stack");

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
      print("Début du stockage des données d'authentification...");

      // Stockage des tokens
      await stockage?.write(StockageKeys.tokenKey, token);
      print("Token stocké");

      if (refreshToken != null) {
        await stockage?.write(StockageKeys.refreshTokenKey, refreshToken);
        print("Refresh token stocké");
      }

      // Conversion et stockage de l'utilisateur
      UserModel user = UserModel.fromJson(userJson);
      Map<String, dynamic> userData = user.toJson();
      
      // Vérifier et mettre à jour isCertified depuis la réponse API
      // Si le cache a été effacé, on récupère isCertified depuis l'API lors de la connexion
      final isCertifiedValue = userJson['isCertified'] ?? userJson['certified'] ?? false;
      userData['isCertified'] = isCertifiedValue == true;
      userData['certified'] = isCertifiedValue == true;
      user.isCertified = isCertifiedValue == true;
      print("Statut isCertified mis à jour depuis l'API lors de la connexion: $isCertifiedValue");
      
      await stockage?.write(StockageKeys.userKey, userData);
      print("Données utilisateur stockées");

      // Stockage du profile si disponible - CORRECTION ICI
      if (profileJson != null) {
        // Vérifier que profileJson est bien un Map et non une String
        if (profileJson is Map<String, dynamic>) {
          await stockage?.write(StockageKeys.profileKey, profileJson);
          print("Données profile stockées");

          // Afficher les infos du profile pour debug
          print("📋 Profile stocké - Prénom: ${profileJson['firstname']}, Nom: ${profileJson['lastname']}");
        } else {
          print("Format de profile invalide: ${profileJson.runtimeType}");
        }
      } else {
        print("Aucun profile reçu dans la réponse");
      }

      // Mise à jour des propriétés en mémoire
      _token = token;
      _user = user;

      print("📊 Données stockées - User ID: ${user.userId}, Email: ${user.email}");
      print("🎫 Token en mémoire: ${_token.substring(0, 20)}...");

    } catch (e, stack) {
      print("Erreur lors du stockage des données: $e");
      print("Détails de l'erreur: $stack");

      // Nettoyage en cas d'erreur
      await _cleanupStorage();
      throw Exception("Erreur de stockage des données: $e");
    }
    }

  // Vérification d'identité
  // Le paramètre userId est en fait le profileId (profile.id) pour l'URL /api/members/{profileId}
  Future<HttpResponse> verifyIdentity(String profileId, Map<String, dynamic> payload) async {
    try {
      loading = true;
      notifyListeners();

      // Utilisation de l'endpoint PUT /api/{version}/protected/members/{profileId}
      final url = "${Endpoints.protectedMembers}/$profileId";
      print("Envoi vérification d'identité vers $url (profileId: $profileId)");
      
      final response = await putData(url, payload, token: token);
      
      print(" Réponse vérification: ${response.data}");

      // Vérifier le message de succès : doit contenir "updated" ET "successfully"
      final message = response.data['message']?.toString().toLowerCase() ?? "";
      final isSuccess = message.contains('updated') && message.contains('successfully');
      
      if (response.status == true && isSuccess) {
        // La réponse contient "person" et "user"
        final personData = response.data['person'];
        final userData = response.data['user'];
        
        if (personData != null) {
            print("Identité mise à jour pour: ${personData['fullName']}");
            
            // Mettre à jour le profil local
            try {
              // Structure attendue pour le profileKey basée sur les logs user
              Map<String, dynamic> updatedProfile = {
                  'id': personData['id'], // Important: garder l'ID du profil
                  'firstname': personData['firstName'] ?? personData['first_name'],
                  'lastname': personData['lastName'] ?? personData['last_name'],
                  'fullname': personData['fullName'] ?? personData['full_name'],
                  'address': personData['address'],
                  'images': personData['images'],
                  'cardFront': personData['cardFront'] ?? personData['card_front'],
                  'cardBack': personData['cardBack'] ?? personData['card_back'],
                  'numberCard': personData['numberCard'] ?? personData['number_card'],
                  'typeCardId': personData['typeCardId'] ?? personData['type_card_id'],
                  'parrainId': personData['parrainId'] ?? personData['parrain_id'],
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
              
              print("Profil local mis à jour avec les infos d'identité");
            } catch (e) {
              print("Erreur mise à jour profil local: $e");
            }
        }
        
        // Mettre à jour le statut certified depuis la réponse user
        if (userData != null && userData['certified'] == true) {
          print("Utilisateur certifié: ${userData['certified']}");
          _user.isCertified = true;
          
          // Mettre à jour le stockage local avec les données user complètes
          try {
            Map<String, dynamic>? currentUser = stockage?.read(StockageKeys.userKey);
            if (currentUser != null && currentUser is Map<String, dynamic>) {
              // Fusionner avec les nouvelles données user
              // Mettre à jour isCertified explicitement
              currentUser['isCertified'] = true;
              currentUser['certified'] = true;
              // Fusionner avec les autres données user de la réponse
              currentUser.addAll(userData);
              await stockage?.write(StockageKeys.userKey, currentUser);
            } else {
              // Créer un nouveau user avec certified = true
              final newUser = Map<String, dynamic>.from(userData);
              newUser['isCertified'] = true;
              newUser['certified'] = true;
              await stockage?.write(StockageKeys.userKey, newUser);
            }
            
            // Mettre à jour aussi l'objet user en mémoire
            _user.isCertified = true;
            
            print("Statut certified mis à jour dans le stockage local (isCertified = true)");
          } catch (e) {
            print("Erreur mise à jour user local: $e");
          }
        }
        
        notifyListeners();
      } else {
        // Si le message ne contient pas "updated" et "successfully", c'est une erreur
        final errorMsg = response.data['detailMessage'] ?? response.data['message'] ?? "Erreur lors de la vérification";
        print("Vérification échouée: $errorMsg");
        loading = false;
        notifyListeners();
        return HttpResponse(status: false, errorMsg: errorMsg.toString(), isException: false);
      }

      loading = false;
      notifyListeners();
      return response;
    } catch (e) {
      loading = false;
      notifyListeners();
      print("Erreur verifyIdentity: $e");
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
      print("Erreur lors du nettoyage: $e");
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

        print("Données locales supprimées");
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
      print("Erreur lors de la déconnexion: $e");

      // Nettoyage local même en cas d'erreur
      await _clearLocalAuthData();

      return HttpResponse(
        data: {'message': e.toString()},
        status: false,
      );
    }
  }

  // DELETE ACCOUNT
  Future<HttpResponse> deleteAccount() async {
    try {
      loading = true;
      notifyListeners();

      var url = Endpoints.deleteAccount;
      var tkn = token;

      print("Suppression du compte en cours...");
      // Habituellement on envoie le userId ou c'est géré via le token
      final response = await deleteData(url, token: tkn);

      if (response.status == true) {
        print("Compte supprimé avec succès sur le serveur");
        await _clearLocalAuthData();
      } else {
        print("Échec de la suppression du compte");
      }

      loading = false;
      notifyListeners();
      return response;
    } catch (e) {
      loading = false;
      notifyListeners();
      print("Erreur lors de la suppression du compte: $e");
      return HttpResponse(
        status: false,
        errorMsg: e.toString(),
        isException: true,
      );
    }
  }

  Future<void> _clearLocalAuthData() async {
    try {
      _token = "";
      _user = UserModel();
      _userAuth = UserModel();

      StompService().disconnect();

      await stockage?.remove(StockageKeys.tokenKey);
      await stockage?.remove(StockageKeys.refreshTokenKey);
      await stockage?.remove(StockageKeys.userKey);
      await stockage?.remove(StockageKeys.userPreferenceKey);
      await stockage?.remove(StockageKeys.profileKey);

      // Supprimer les images et données de cache (Garanti retour à zéro)
      await stockage?.remove('user_image_path');
      await stockage?.remove('profile_image_path');
      await stockage?.remove('card_front_path');
      await stockage?.remove('card_back_path');
      await stockage?.remove('user_accounts');
      await stockage?.remove('published_properties_count');
      await stockage?.remove('referrals_count');
      await stockage?.remove('user_data'); 

      // NETTOYAGE RADICAL DES BASES DE DONNÉES SQL (Sécurité totale)
      try {
        print("🧹 Début du nettoyage radical des bases SQL...");
        
        // 1. Services & Prestations
        await PrestationDatabaseHelper.instance.clearAllPrestations();
        
        // 2. Propriétés générales & Catégories spéciales
        final db = DatabaseHelper.instance;
        await db.clearProperties();
        await db.clearCategory(DatabaseHelper.tableBureaux);
        await db.clearCategory(DatabaseHelper.tableFestives);
        await db.clearCategory(DatabaseHelper.tableFuneraires);
        
        // 3. Transactions & Requêtes
        await db.clearUserSolicitations();
        await db.clearHostSolicitations();
        await db.clearUserReservations();
        await db.clearHostReservations();
        await db.clearServiceRequests();
        
        // 4. Données utilisateur spécifiques
        await PropertyDatabaseHelper.instance.clearDatabase();
        await TerrainDatabaseHelper.instance.clearTerrains();
        
        print("Nettoyage radical terminé");
      } catch (e) {
        print("Erreur lors du nettoyage radical SQL: $e");
      }

      // Supprimer les brouillons expirés
      try {
        await DraftHelper.clearAllDrafts();
        print("Brouillons expirés supprimés");
      } catch (e) {
        print("Erreur lors de la suppression des brouillons: $e");
      }

      // Supprimer les agences en cache local (SQL database)
      try {
        await AgenceDatabaseHelper.instance.clearAgencies();
        print("Agences locales supprimées");
      } catch (e) {
        print("Erreur lors de la suppression des agences locales: $e");
      }

      print("Données d'authentification locales supprimées");
    } catch (e) {
      print("Erreur lors du nettoyage des données locales: $e");
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
          print("User ID: ${_user.userId}");
          return true;
        } else {
          print("Données utilisateur non trouvées");
          await _clearLocalAuthData();
        }
      } else {
        print("Aucun token trouvé dans le stockage");
      }
    } catch (e) {
      print("Erreur lors de la vérification de l'authentification: $e");
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
  //       print("Aucun refresh token disponible");
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
  //         print("Token rafraîchi avec succès");
  //         return true;
  //       }
  //     }
  //
  //     print("Échec du rafraîchissement du token");
  //     return false;
  //   } catch (e) {
  //     print("Erreur lors du rafraîchissement du token: $e");
  //     return false;
  //   }
  // }

  // Méthode pour afficher les informations de debug
  void printAuthStatus() {
    print("=== ÉTAT AUTHENTIFICATION ===");
    print("Token présent: ${token.isNotEmpty}");
    print("User ID: ${user.userId}");
    print("Email: ${user.email}");
    print("Connecté: $isLoggedIn");
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
      print("Erreur lors de la demande de réinitialisation: $e");
      print("Stack trace: $stack");

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
      var url = "${Endpoints.otpVerify}";
      print("URL verify OTP: $url");
      print("Données envoyées: ${data.containsKey('otp') ? 'phone: ${data['phone']}, otp: ***' : data}");

      HttpResponse response = await postData(url, data, token: "");

      print("Statut de la réponse: ${response.status}");
      print("Réponse API: ${response.data}");

      loading = false;
      notifyListeners();
      return response;
    } catch (e, stack) {
      loading = false;
      notifyListeners();
      print("Erreur lors de la vérification OTP: $e");
      print("Stack trace: $stack");

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

  // Mise à jour du profil (pour modification de profil, avec user, sans cartes)
  // La clé "user" doit toujours être présente avec toutes ses propriétés (même vides)
  Future<HttpResponse> updateProfile(String userId, Map<String, dynamic> payload) async {
    try {
      loading = true;
      notifyListeners();

      // Utilisation de l'endpoint PUT /api/{version}/protected/members/{userId}
      final url = "${Endpoints.protectedMembers}/$userId";
      print("Mise à jour profil vers $url");
      
      // S'assurer que la clé "user" est toujours présente avec toutes ses propriétés
      if (!payload.containsKey('user')) {
        // Récupérer les données utilisateur depuis le stockage
        final userData = stockage?.read(StockageKeys.userKey) ?? {};
        final emailValue = userData['email']?.toString() ?? "";
        payload['user'] = {
          "email": emailValue.isEmpty ? "string" : emailValue,
          "phone": userData['phone']?.toString() ?? "",
          "city": userData['city']?.toString() ?? "",
          "country": userData['country']?.toString() ?? "",
        };
      }
      
      // S'assurer que toutes les propriétés de "user" sont présentes (même vides)
      if (payload['user'] is Map) {
        final userMap = payload['user'] as Map<String, dynamic>;
        // Ajouter les propriétés manquantes avec des valeurs par défaut
        // Si l'email est vide, envoyer "string" pour éviter l'erreur API
        if (!userMap.containsKey('email') || (userMap['email']?.toString() ?? "").isEmpty) {
          userMap['email'] = "string";
        }
        if (!userMap.containsKey('phone')) userMap['phone'] = "";
        if (!userMap.containsKey('city')) userMap['city'] = "";
        if (!userMap.containsKey('country')) userMap['country'] = "";
      }
      
      // S'assurer que tous les champs requis sont présents dans le payload
      // Même structure pour vérification et modification
      if (!payload.containsKey('cardFront')) payload['cardFront'] = "";
      if (!payload.containsKey('cardBack')) payload['cardBack'] = "";
      if (!payload.containsKey('typeCardId')) payload['typeCardId'] = 1;
      if (!payload.containsKey('parrainId')) payload['parrainId'] = 0;
      if (!payload.containsKey('numberCard')) payload['numberCard'] = "";
      
      print("Payload (avec user, sans cartes): ${payload.keys.toList()}");

      final response = await putData(url, payload, token: token);
      
      print(" Réponse mise à jour profil: ${response.data}");

      // Vérifier le message de succès : doit contenir "updated" ET "successfully"
      final message = response.data['message']?.toString().toLowerCase() ?? "";
      final isSuccess = message.contains('updated') && message.contains('successfully');

      if (response.status == true && isSuccess) {
        print("Profil mis à jour avec succès");
        
        // Mettre à jour le profil et user local
        final personData = response.data['person'];
        final userData = response.data['user'];
        
        if (personData != null) {
          try {
            Map<String, dynamic>? currentProfile = stockage?.read(StockageKeys.profileKey);
            if (currentProfile != null) {
              currentProfile.addAll({
                'id': personData['id'],
                'firstname': personData['firstName'] ?? personData['first_name'],
                'lastname': personData['lastName'] ?? personData['last_name'],
                'fullname': personData['fullName'] ?? personData['full_name'],
                'address': personData['address'],
                'images': personData['images'],
                'typeCardId': personData['typeCardId'] ?? personData['type_card_id'],
                'parrainId': personData['parrainId'] ?? personData['parrain_id'],
                'numberCard': personData['numberCard'] ?? personData['number_card'],
              });
              await stockage?.write(StockageKeys.profileKey, currentProfile);
            }
          } catch (e) {
            print("Erreur mise à jour profil local: $e");
          }
        }
        
        if (userData != null) {
          try {
            Map<String, dynamic>? currentUser = stockage?.read(StockageKeys.userKey);
            if (currentUser != null && currentUser is Map) {
              currentUser.addAll(userData);
              await stockage?.write(StockageKeys.userKey, currentUser);
            } else {
              await stockage?.write(StockageKeys.userKey, userData);
            }
            
            // Mettre à jour l'objet user
            _user = UserModel.fromJson(userData);
            print("User local mis à jour");
          } catch (e) {
            print("Erreur mise à jour user local: $e");
          }
        }
        
        notifyListeners();
      } else {
        // Si le message ne contient pas "updated" et "successfully", c'est une erreur
        final errorMsg = response.data['detailMessage'] ?? response.data['message'] ?? "Erreur lors de la mise à jour du profil";
        print("Mise à jour profil échouée: $errorMsg");
        loading = false;
        notifyListeners();
        return HttpResponse(status: false, errorMsg: errorMsg.toString(), isException: false);
      }

      loading = false;
      notifyListeners();
      return response;
    } catch (e) {
      loading = false;
      notifyListeners();
      print("Erreur updateProfile: $e");
      return HttpResponse(status: false, errorMsg: e.toString(), isException: true);
    }
  }

  // Réinitialisation du mot de passe
  Future<HttpResponse> resetPassword(Map<String, dynamic> data) async {
    try {
      loading = true;
      notifyListeners();

      var url = "${Endpoints.resetPassword}";
      
      HttpResponse response = await putDataForAuth(url, data);

      loading = false;
      notifyListeners();
      return response;
    } catch (e, stack) {
      loading = false;
      notifyListeners();
      print("Erreur lors de la réinitialisation du mot de passe: $e");

      return HttpResponse(
        data: {'message': e.toString()},
        status: false,
        errorMsg: e.toString()
      );
    }
  }

  // Mise à jour de l'image de profil via l'endpoint /api/{version}/protected/members/{id}/profile
  Future<HttpResponse> updateProfilePicture(String profileId, String base64Image) async {
    try {
      loading = true;
      notifyListeners();

      final url = "${Endpoints.updateProfilePicture}/$profileId/profile";
      print("Upload image de profil vers $url");
      
      final payload = {
        "image": base64Image,
      };

      final response = await putData(url, payload, token: token);
      
      print(" Réponse upload image de profil: ${response.data}");

      // Vérifier le message de succès
      final message = response.data['message']?.toString().toLowerCase() ?? "";
      final isSuccess = message.contains('updated') || message.contains('success') || response.status == true;

      if (isSuccess) {
        // Récupérer l'URL de l'image depuis la réponse
        final imageUrl = response.data['image'] ?? response.data['images'] ?? response.data['profile']?['image'] ?? response.data['profile']?['images'];
        
        if (imageUrl != null && imageUrl.toString().isNotEmpty) {
          // Mettre à jour le profil local avec l'URL de l'image (pas le base64)
          try {
            Map<String, dynamic>? currentProfile = stockage?.read(StockageKeys.profileKey);
            if (currentProfile != null && currentProfile is Map<String, dynamic>) {
              currentProfile['image'] = imageUrl.toString();
              currentProfile['images'] = imageUrl.toString();
              await stockage?.write(StockageKeys.profileKey, currentProfile);
              print("Image de profil mise à jour dans le stockage local: $imageUrl");
            }
          } catch (e) {
            print("Erreur mise à jour profil local: $e");
          }
        }
        
        loading = false;
        notifyListeners();
        return response;
      } else {
        final errorMsg = response.data['detailMessage'] ?? response.data['message'] ?? "Erreur lors de l'upload de l'image de profil";
        print("Upload image de profil échoué: $errorMsg");
        loading = false;
        notifyListeners();
        return HttpResponse(status: false, errorMsg: errorMsg.toString(), isException: false);
      }
    } catch (e) {
      loading = false;
      notifyListeners();
      print("Erreur updateProfilePicture: $e");
      return HttpResponse(status: false, errorMsg: e.toString(), isException: true);
    }
  }

  bool hasAgence = false;

  // Vérifier si l'utilisateur a une agence
  Future<bool> checkUserAgency(int userId) async {
    try {
      // Utilisation de l'endpoint GET /api/{version}/protected/agences/owner/{userId}
      final url = "${Endpoints.protectedAgencesByOwner}/$userId";
      print("Vérification agence pour user $userId: $url");
      
      // getData retourne le body JSON décodé (Map ou List) si 200, sinon null
      final response = await getData(url, token: token);
      
      if (response != null && response is Map && response['data'] != null) {
        final data = response['data'];
        if (data is List && data.isNotEmpty) {
           print("Agence trouvée: ${data.length} agence(s)");
           hasAgence = true;
           notifyListeners();
           return true; 
        }
      }
      
      print("ℹ️ Réponse valide mais aucune agence trouvée (data vide).");
      hasAgence = false;
      notifyListeners();
      return false;
    } catch (e) {
      print("ℹ️ Erreur checkUserAgency (User $userId): $e");
      hasAgence = false;
      notifyListeners();
      return false;
    }
  }
}
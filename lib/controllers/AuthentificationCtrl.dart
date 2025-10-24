import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import '../models/UserModel.dart';
import '../utils/Endpoints.dart';
import '../utils/StockageKeys.dart';
import '../utils/requetes.dart';

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

      HttpResponse response = await postDataForAuth(url, data);
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

        String? newToken = response.data['token'];
        String? refreshToken = response.data['refresh_token'];
        var userJson = response.data['user'];

        // Vérification des données requises
        if (newToken != null && userJson != null) {
          print("Token reçu: ${newToken.substring(0, 20)}...");
          if (refreshToken != null) {
            print("Refresh token reçu: ${refreshToken.substring(0, 20)}...");
          }
          print("Données utilisateur reçues");

          // Stockage sécurisé des données
          await _storeAuthData(newToken, refreshToken, userJson);

          print("✅ Connexion et stockage réussis pour: ${userJson['email']}");
          print("✅ Connexion et stockage réussis pour: $_storeAuthData");
        } else {
          print("❌ Token ou utilisateur manquant dans la réponse");
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


  Future<HttpResponse> register(Map<String, dynamic> userData, {required String url}) async {
    try {
      const url = Endpoints.register;
      print("Payload d'inscription: ${(userData)}");

      HttpResponse response = await postData(url, userData);

      if (response.data == null) {
        return HttpResponse(
          status: false,
          errorMsg: "Réponse vide du serveur",
          isException: true,
        );
      }

      print("Réponse API: ${(response.data)}");

      // Vérifiez d'abord si la requête a réussi
      if (response.data['success'] == true) {
        final data = response.data['data'] ?? {};

        String? token = data['token'];
        var userJson = data['user'];

        if (token != null && userJson != null) {
          await stockage?.write(StockageKeys.tokenKey, token);
          user = UserModel.fromJson(userJson);
          this.user = user;
          notifyListeners();
        } else {
          print("Token ou user manquant dans la réponse");
          return HttpResponse(
            status: false,
            errorMsg: "Données utilisateur manquantes dans la réponse",
            data: response.data,
          );
        }
      } else {
        // Gestion des erreurs API
        String errorMsg = response.data['message'] ??
            response.data['errors']?.toString() ??
            "Erreur inconnue lors de l'inscription";
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



  // Méthode pour stocker les données d'authentification
  Future<void> _storeAuthData(String token, String? refreshToken, Map<String, dynamic> userJson) async {
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

      // Mise à jour des propriétés en mémoire
      _token = token;
      _user = user;

      print("📊 Données stockées - User ID: ${user.userId}, Email: ${user.email}");
      print("🎫 Token en mémoire: ${_token.substring(0, 20)}...");

    } catch (e) {
      print("❌ Erreur lors du stockage des données: $e");
      // Nettoyage en cas d'erreur
      await _cleanupStorage();
      throw Exception("Erreur de stockage des données: $e");
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

  // Nettoyage des données d'authentification locales
  Future<void> _clearLocalAuthData() async {
    try {
      _token = "";
      _user = UserModel();
      _userAuth = UserModel();

      await stockage?.remove(StockageKeys.tokenKey);
      await stockage?.remove(StockageKeys.refreshTokenKey);
      await stockage?.remove(StockageKeys.userKey);
      await stockage?.remove(StockageKeys.userPreferenceKey);

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
}
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import '../models/UserModel.dart';
import '../utils/Endpoints.dart';
import '../utils/StockageKeys.dart';
import '../utils/requetes.dart';

class AuthentificationCtrl with ChangeNotifier {

  AuthentificationCtrl({this.stockage});

  String _token = "";

  String get token {
    var locale = stockage?.read<String>(StockageKeys.tokenKey);
    return locale ?? "";
  }

  set token(String value) {
    stockage?.write(StockageKeys.tokenKey, value);
    _token = value;
  }

  UserModel _user = UserModel();
  List <UserModel> listUsers = [];
  UserModel _userAuth=UserModel();
  GetStorage? stockage;

  List<UserModel> Listregister = [];
  List<UserModel> Listlogin = [];
  bool loading = false;

  UserModel get user {
    var locale = stockage?.read(StockageKeys.userKey);
    _user = UserModel?.fromJson(locale);
    return _user;
  }
  set user(UserModel value) {
    stockage?.write(StockageKeys.userKey, value.toJson());
    _user = value;
  }

  UserModel get userPreference {
    var locale = stockage?.read(StockageKeys.userPreferenceKey);
    _user = UserModel?.fromJson(locale);
    return _user;
  }

  set userPreference(UserModel value) {
    stockage?.write(StockageKeys.userPreferenceKey, value.toJson());
    _user = value;
  }

  //LOGIN USER
  Future<HttpResponse> login(Map data) async {
    try {
      var url = "${Endpoints.login}";
      print("URL de connexion: $url");

      HttpResponse response = await postData(url, data);
      print("Réponse API: ${response.data}");

      if (response.data == null) {
        print("Réponse API null");
        return response;
      }

      // Vérification de la structure de la réponse
      if (response.data['success'] == true) {
        final responseData = response.data['data'];

        if (responseData != null) {
          String? token = responseData['token'];
          var userJson = responseData['user'];

          // Vérification cruciale avant stockage
          if (token != null && userJson != null) {
            print("Token reçu: $token");
            print("User reçu: $userJson");

            // Stockage du token
            await stockage?.write(StockageKeys.tokenKey, token);

            try {
              // Conversion et vérification de l'utilisateur
              UserModel user = UserModel.fromJson(userJson);
              await stockage?.write(StockageKeys.userKey, user.toJson());
              this.user = user; // Utilise le setter

              print("Utilisateur stocké avec succès");
            } catch (e) {
              print("Erreur conversion utilisateur: $e");
              await stockage?.remove(StockageKeys.tokenKey); // Nettoyage
              throw Exception("Format utilisateur invalide");
            }
          } else {
            print("Token ou utilisateur manquant dans la réponse");
          }
        } else {
          print("Champ 'data' manquant dans la réponse");
        }
      } else {
        print("Échec connexion: ${response.data['message']}");
      }

      notifyListeners();
      return response;
    } catch (e, stack) {
      print("Erreur lors du login: $e\n$stack");
      rethrow;
    }
  }

  //REGISTER USER
  Future<HttpResponse> register(Map<String, dynamic> userData) async {
    try {
      const url = Endpoints.register;
      print("URL d'inscription: $url");

      HttpResponse response = await postData(url, userData);
      print(response.data);
      var test=response.data != null;


      if (test) {
        var token = response.data['data']['token'];
        print("token${token}");
        var user = response.data['data']['user'];

        // Stocker le token
        stockage?.write(StockageKeys.tokenKey, token);

        // Stocker les informations de l'utilisateur
        user = UserModel.fromJson(user);
        this.user = user;

        print("Inscription réussie: Informations de l'utilisateur - $user");
        print("Token stocké: ${stockage?.read(StockageKeys.tokenKey)}");

        notifyListeners();
      } else {
        print("Échec de l'inscription: ${response.data["errors"]}");
      }

      return response;
    } catch (e) {
      print("Exception lors de l'inscription: $e");
      return HttpResponse(
        status: false,
        errorMsg: "Une erreur est survenue lors de l'inscription",
        isException: true,
      );
    }
  }


  //LOGOUT USER

  Future<HttpResponse> logout(Map data) async {
    var url = "${Endpoints.logout}";
    var tkn = stockage?.read(StockageKeys.tokenKey);
    HttpResponse response = await postData(url, data, token: tkn);
    if (response.status) {
      print("${response.status}");
      notifyListeners();
    }
    print(response.data);

    return response;
  }

// "identifiant": "jean.dupont@example.com",
// "password": "12345678"
}
main() async {
  await GetStorage.init();
  var stockage = GetStorage();
  var ctrl = AuthentificationCtrl(stockage: stockage);
  ctrl.login(
      {
        "email": "ethberg@example.com",
        "password": "MotDePasseSecurise123!",
        "TypeAccountId": 2,
        "CityId": 2,
        "postal_code": "75010",
        "country": "France",
        "date_of_birth": "1990-05-15",
        "gender": "male",
        "profile_picture": "iVBORw0KGgoAAAANSUhEUgAA...",
        "bio": "Utilisateur passionné par l’immobilier et la technologie.",
        "is_agent": true,
        "is_admin": false
      }

  );
}


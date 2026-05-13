import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:get_storage/get_storage.dart';
import '../models/UserModel.dart';
import '../utils/Constantes.dart';
import '../utils/Endpoints.dart';
import '../utils/StockageKeys.dart';
import '../utils/requetes.dart';
import '../services/onesignal_device_headers.dart';
import '../services/onesignal_service.dart';
import '../utils/DraftHelper.dart';
import '../utils/AgenceDatabaseHelper.dart';
import '../utils/database/DatabaseHelper.dart';
import '../utils/database/PropertyDatabaseHelper.dart';
import '../utils/database/PrestationDatabaseHelper.dart';
import '../utils/TerrainDatabaseHelper.dart';
import '../utils/StompService.dart';
import 'NotificationController.dart';
import '../utils/database/UserDatabaseHelper.dart';

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

      // Crashlytics: associer les erreurs au bon utilisateur dans la console Firebase.
      // (Utile pour filtrer Non‑fatal/Crashes par userId)
      final uid = value.userId?.toString();
      if (uid != null && uid.isNotEmpty) {
        FirebaseCrashlytics.instance.setUserIdentifier(uid);
        FirebaseCrashlytics.instance.setCustomKey('userId', uid);
        if ((value.email ?? '').trim().isNotEmpty) {
          FirebaseCrashlytics.instance.setCustomKey('email', value.email!.trim());
        }
        if ((value.username ?? '').trim().isNotEmpty) {
          FirebaseCrashlytics.instance.setCustomKey('username', value.username!.trim());
        }
      }

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

      await logOneSignalStateBeforeLoginDebug();

      HttpResponse response = await postDataForAuth(
        url,
        data,
        token: "",
        extraHeaders: buildOneSignalAuthHeaders(),
      );
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

          oneSignalLoginWithAppUserId(user.userId.toString());

          if (kDebugMode) {
            await Future<void>.delayed(const Duration(milliseconds: 600));
            await logOneSignalStateAfterLoginDebug(user.userId.toString());
          }

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
      final isCertifiedValue = userJson['isCertified'] ?? userJson['certified'] ?? false;
      final bool isNowCertified = isCertifiedValue == true;

      // Gestion de l'historique de certification (was_certified)
      // On vérifie d'abord si on avait déjà un statut "était certifié"
      final String currentUserId = userJson['userId']?.toString() ?? user.userId?.toString() ?? "";
      bool hadBeenCertified = stockage?.read<bool>('${StockageKeys.wasCertifiedKey}_$currentUserId') ?? false;
      
      // Si pas dans GetStorage, on peut vérifier en DB (async)
      if (!hadBeenCertified && user.userId != null) {
          // Note: On ne peut pas await facilement ici sans changer la signature de manière importante si on veut être strict
          // Mais on peut lancer l'update en arrière-plan ou charger au besoin.
          // Ici on va privilégier la mise à jour si le nouveau statut est true.
      }

      if (isNowCertified) {
          hadBeenCertified = true;
          await stockage?.write('${StockageKeys.wasCertifiedKey}_$currentUserId', true);
          if (user.userId != null) {
            await UserDatabaseHelper.instance.saveCertificationStatus(user.userId.toString(), true);
          }
      } else {
        // Si maintenant false mais était true avant (via GetStorage)
        if (hadBeenCertified) {
            print("⚠️ L'utilisateur a été décertifié ! Conservation du flag was_certified.");
        }
      }

      userData['isCertified'] = isNowCertified;
      userData['certified'] = isNowCertified;
      user.isCertified = isNowCertified;
      
      print("Statut isCertified mis à jour depuis l'API lors de la connexion: $isNowCertified (wasCertified: $hadBeenCertified)");

      // Alignement BD/API : colonne souvent `is_premium` (snake_case)
      final dynamic premiumRaw =
          userJson['isPremium'] ?? userJson['premium'] ?? userJson['is_premium'];
      if (premiumRaw != null) {
        final bool isNowPremium = premiumRaw == true ||
            premiumRaw == 1 ||
            premiumRaw.toString().toLowerCase() == 'true';
        userData['isPremium'] = isNowPremium;
        userData['premium'] = isNowPremium;
        userData['is_premium'] = isNowPremium;
        user.isPremium = isNowPremium;
        print("Statut premium (is_premium / isPremium) depuis l'API à la connexion: $isNowPremium");
      }
      
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

  /// Met à jour le statut de certification en temps réel (via WebSocket par ex)
  Future<void> updateCertificationStatus(bool isCertifiedValue) async {
    if (_user.userId == null) return;
    
    print("🔄 [AuthentificationCtrl] Mise à jour temps réel certification: $isCertifiedValue");
    
    final bool isNowCertified = isCertifiedValue;
    
    // 1. Mise à jour de l'objet en mémoire
    _user.isCertified = isNowCertified;
    _userAuth.isCertified = isNowCertified;
    
    // 2. Mise à jour du GetStorage (User JSON)
    Map<String, dynamic>? userData = stockage?.read(StockageKeys.userKey);
    if (userData != null) {
      userData['isCertified'] = isNowCertified;
      userData['certified'] = isNowCertified;
      await stockage?.write(StockageKeys.userKey, userData);
    }
    
    // 3. Gestion de l'historique wasCertified
    if (isNowCertified) {
      await stockage?.write('${StockageKeys.wasCertifiedKey}_${_user.userId}', true);
      await UserDatabaseHelper.instance.saveCertificationStatus(_user.userId.toString(), true);
    }
    
    // 4. Notification des widgets
    notifyListeners();
    print("✅ [AuthentificationCtrl] Statut de certification mis à jour et widgets notifiés");
  }

  /// Premium (abonnement) — même principe que la certification : WebSocket / API peuvent envoyer `premium` ou `isPremium`.
  Future<void> updatePremiumStatus(bool isPremiumValue) async {
    if (_user.userId == null) return;

    print("🔄 [AuthentificationCtrl] Mise à jour premium: $isPremiumValue");

    _user.isPremium = isPremiumValue;
    _userAuth.isPremium = isPremiumValue;

    Map<String, dynamic>? userData = stockage?.read(StockageKeys.userKey);
    if (userData != null) {
      userData['isPremium'] = isPremiumValue;
      userData['premium'] = isPremiumValue;
      userData['is_premium'] = isPremiumValue;
      await stockage?.write(StockageKeys.userKey, userData);
    }

    notifyListeners();
    print("✅ [AuthentificationCtrl] Statut premium mis à jour (stockage + UI)");
  }

  DateTime? _lastMemberRefreshAt;

  /// Extrait la map `user` depuis une réponse API type login ou GET membre.
  /// Prend en charge : `{ user: {...} }`, `{ member: { user: {...} } }`,
  /// `{ member: { userId: … } }`, `{ data: { userId, profile, … } }` (refresh member),
  /// ou objet plat `GET /protected/users/{id}` avec `userId` + `profile` à la racine.
  Map<String, dynamic>? _extractUserMapFromMemberPayload(Map<String, dynamic> root) {
    if (root['data'] is Map) {
      final d = Map<String, dynamic>.from(root['data'] as Map);
      if (d['user'] is Map) {
        return Map<String, dynamic>.from(d['user'] as Map);
      }
      if (d['userId'] != null) {
        return Map<String, dynamic>.from(d);
      }
    }
    if (root['member'] is Map) {
      final m = root['member'] as Map<String, dynamic>;
      if (m['user'] is Map) {
        return Map<String, dynamic>.from(m['user'] as Map);
      }
      if (m['userId'] != null) {
        return Map<String, dynamic>.from(m);
      }
    }
    if (root['user'] is Map) {
      return Map<String, dynamic>.from(root['user'] as Map);
    }
    if (root['userId'] != null) {
      return Map<String, dynamic>.from(root);
    }
    return null;
  }

  /// Normalise le bloc `profile` renvoyé par `GET /protected/users/{userId}` pour [StockageKeys.profileKey].
  Future<void> _persistProfileFromRefreshRoot(
    Map<String, dynamic> root,
    Map<String, dynamic> mergedUser,
  ) async {
    final profileRaw = root['profile'];
    if (profileRaw is! Map) return;
    final p = Map<String, dynamic>.from(profileRaw);
    final profileForStorage = <String, dynamic>{
      'id': p['id'],
      'firstname': p['firstName'] ?? p['first_name'],
      'lastname': p['lastName'] ?? p['last_name'],
      'fullname': p['fullName'] ?? p['full_name'],
      'address': p['address'],
      'images': p['images'],
      'cardFront': p['cardFront'] ?? p['card_front'],
      'cardBack': p['cardBack'] ?? p['card_back'],
      'numberCard': p['numberCard'] ?? p['number_card'],
      'typeCardId': p['typeCardId'] ?? p['type_card_id'],
      'userId': p['userId'],
    }..removeWhere((_, v) => v == null);

    if (profileForStorage.isEmpty) return;

    final existingProf = stockage?.read(StockageKeys.profileKey);
    if (existingProf is Map) {
      final m = Map<String, dynamic>.from(existingProf);
      m.addAll(profileForStorage);
      await stockage!.write(StockageKeys.profileKey, m);
    } else {
      await stockage!.write(StockageKeys.profileKey, profileForStorage);
    }

    final img = p['images']?.toString().trim();
    if (img != null && img.isNotEmpty && img != 'null') {
      mergedUser['profilePicture'] = img;
    }
    final fn = (p['fullName'] ?? p['full_name'])?.toString().trim();
    if (fn != null && fn.isNotEmpty && fn != 'null') {
      mergedUser['fullName'] = fn;
    }
  }

  /// Recharge premium / certified / profil depuis le serveur (`GET .../protected/users/{userId}`).
  /// Si l’API ne supporte pas GET (erreur « Request method 'GET' is not supported »), tente un **POST** avec corps vide (même chemin).
  /// Secours : `.../protected/members/{userId}` si la route `users` est indisponible.
  /// À utiliser au retour au premier plan ou pour réaligner le stockage local.
  Future<void> refreshMemberFromServer({bool force = false}) async {
    if (stockage == null) return;
    if (token.isEmpty) return;

    if (!force &&
        _lastMemberRefreshAt != null &&
        DateTime.now().difference(_lastMemberRefreshAt!) < const Duration(seconds: 25)) {
      return;
    }

    final uid = _user.userId?.toString() ??
        stockage!.read<Map<String, dynamic>>(StockageKeys.userKey)?['userId']?.toString();
    if (uid == null || uid.isEmpty) return;

    try {
      Future<dynamic> fetchRaw(String basePath) async {
        final url = "$basePath/$uid";
        print("🔄 [AuthentificationCtrl] refreshMemberFromServer: $url");
        dynamic r = await getDataAllowErrorJson(url, token: token);
        if (r is Map) {
          final dm = r['detailMessage']?.toString() ?? '';
          if (dm.contains('GET') && dm.contains('not supported')) {
            print(
              "🔄 [AuthentificationCtrl] GET non supporté — tentative POST sur le même chemin…",
            );
            final postResp = await postData(
              url,
              <String, dynamic>{},
              token: token,
              allowDefaultToken: false,
            );
            if (postResp.status == true && postResp.data != null) {
              r = postResp.data;
            } else {
              print(
                "⚠️ [AuthentificationCtrl] refreshMemberFromServer: POST échoué — ${postResp.errorMsg}",
              );
              return null;
            }
          } else if (r['detailMessage'] != null &&
              r['user'] == null &&
              r['member'] == null &&
              r['userId'] == null) {
            print(
                "⚠️ [AuthentificationCtrl] refreshMemberFromServer: erreur API — ${r['detailMessage']}");
            return null;
          }
        }
        return r;
      }

      dynamic raw = await fetchRaw(Endpoints.protectedUsers);
      if (raw == null || raw is! Map) {
        print(
            "🔄 [AuthentificationCtrl] refreshMemberFromServer: secours members/$uid");
        raw = await fetchRaw(Endpoints.protectedMembers);
      }

      if (raw == null || raw is! Map) {
        print("⚠️ [AuthentificationCtrl] refreshMemberFromServer: réponse vide ou invalide");
        return;
      }

      final root = Map<String, dynamic>.from(raw as Map);
      final userJson = _extractUserMapFromMemberPayload(root);
      if (userJson == null) {
        print("⚠️ [AuthentificationCtrl] refreshMemberFromServer: pas de bloc user dans la réponse");
        return;
      }

      final Map<String, dynamic> previousUser =
          Map<String, dynamic>.from(stockage!.read<Map<String, dynamic>>(StockageKeys.userKey) ?? {});
      final bool oldCertified = previousUser['isCertified'] == true ||
          previousUser['certified'] == true;
      final bool hadWasFlag =
          stockage!.read<bool>('${StockageKeys.wasCertifiedKey}_$uid') ?? false;

      Map<String, dynamic> merged = Map<String, dynamic>.from(previousUser);
      final parsed = UserModel.fromJson(userJson);
      merged.addAll(parsed.toJson());

      final dynamic certRaw = userJson['isCertified'] ?? userJson['certified'];
      if (certRaw != null) {
        final bool c = certRaw == true ||
            certRaw == 1 ||
            certRaw.toString().toLowerCase() == 'true';
        merged['isCertified'] = c;
        merged['certified'] = c;

        // Même sans notification temps réel : si le cache disait « certifié » et l’API « non »,
        // conserver was_certified pour que la garde et l’alerte au lancement fonctionnent.
        if (c == true) {
          await stockage!.write('${StockageKeys.wasCertifiedKey}_$uid', true);
          await UserDatabaseHelper.instance.saveCertificationStatus(uid, true);
          try {
            await stockage!.remove('${StockageKeys.kycDocsSubmittedAtKey}_$uid');
          } catch (_) {}
        } else if (oldCertified || hadWasFlag) {
          await stockage!.write('${StockageKeys.wasCertifiedKey}_$uid', true);
        }
      }

      final dynamic premiumRaw =
          userJson['isPremium'] ?? userJson['premium'] ?? userJson['is_premium'];
      if (premiumRaw != null) {
        final bool p = premiumRaw == true ||
            premiumRaw == 1 ||
            premiumRaw.toString().toLowerCase() == 'true';
        merged['isPremium'] = p;
        merged['premium'] = p;
        merged['is_premium'] = p;
      }

      await _persistProfileFromRefreshRoot(root, merged);

      await stockage!.write(StockageKeys.userKey, merged);
      _user = UserModel.fromJson(merged);
      _lastMemberRefreshAt = DateTime.now();
      notifyListeners();
      print(
        "✅ [AuthentificationCtrl] Membre rechargé — premium=${_user.isPremium}, certified=${_user.isCertified}",
      );
    } catch (e, st) {
      print("❌ [AuthentificationCtrl] refreshMemberFromServer: $e\n$st");
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

      // HTTP 201 Created sur `public/members` : compte créé même sans token (réponse métier ambiguë possible).
      if (response.httpStatus == 201) {
        final data = response.data;
        final msg = data is Map ? data['message']?.toString() : null;
        return HttpResponse(
          status: true,
          data: response.data,
          errorMsg: msg,
          httpStatus: 201,
        );
      }

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
      print("🌐 [deleteAccount] Endpoint: $url");
      print("🌐 [deleteAccount] Base: ${Constantes.BASE_URL}");
      print("🌐 [deleteAccount] URL complète: ${Constantes.BASE_URL}$url");
      print("🔐 [deleteAccount] Token utilisateur présent: ${tkn.trim().isNotEmpty ? 'Oui (${tkn.trim().length} caractères)' : 'Non'}");
      // Habituellement on envoie le userId ou c'est géré via le token
      final response = await deleteData(url, token: tkn);

      if (response.status == true) {
        print("Compte supprimé avec succès sur le serveur");
        await _clearLocalAuthData();
      } else {
        print("❌ Échec de la suppression du compte");
        print("🌐 [deleteAccount] httpStatus: ${response.httpStatus}");
        print("🌐 [deleteAccount] errorMsg: ${response.errorMsg}");
        try {
          print("🌐 [deleteAccount] data: ${response.data}");
        } catch (_) {}
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
      oneSignalLogout();
      NotificationController().clearForLogout();

      _token = "";
      _user = UserModel();
      _userAuth = UserModel();

      // Crashlytics: éviter d'attribuer les erreurs à l'ancien utilisateur après logout.
      FirebaseCrashlytics.instance.setUserIdentifier('');

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
      await stockage?.remove('publication_count_last_update');
      await stockage?.remove('referrals_count');
      await stockage?.remove('user_data'); 

      // Sécurité: supprimer toute variante éventuelle (clé suffixée/prefixée) de ces compteurs.
      try {
        final keys = stockage?.getKeys() ?? <String>{};
        for (final k in keys) {
          if (k.contains('published_properties_count') ||
              k.contains('publication_count_last_update') ||
              k.contains('referrals_count')) {
            await stockage?.remove(k);
          }
        }
      } catch (_) {}

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
          _userAuth = _user; // Sync userAuth as well

          // Sync wasCertified from DB for new sessions or if cache cleared
          if (_user.userId != null) {
              final wasCertified = await UserDatabaseHelper.instance.wasUserCertified(_user.userId.toString());
              if (wasCertified) {
                  await stockage?.write('${StockageKeys.wasCertifiedKey}_${_user.userId}', true);
              }
          }

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
            final Map<String, dynamic> ud =
                Map<String, dynamic>.from(userData as Map);
            if (currentUser != null && currentUser is Map) {
              final merged = Map<String, dynamic>.from(currentUser);
              merged.addAll(ud);
              await stockage?.write(StockageKeys.userKey, merged);
              _user = UserModel.fromJson(merged);
            } else {
              await stockage?.write(StockageKeys.userKey, ud);
              _user = UserModel.fromJson(ud);
            }
            print("User local mis à jour (fusion profil, premium préservé si API partielle)");
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

  /// Réinitialisation après OTP : `PUT` [Endpoints.changePassword] **sans** en-tête `Authorization`.
  Future<HttpResponse> resetPasswordAfterOtp({
    required String newPassword,
    required int userId,
  }) async {
    try {
      loading = true;
      notifyListeners();

      final path = Endpoints.changePassword;
      final resolvedUrl = '${Constantes.BASE_URL}$path';
      print('🔐 [AuthentificationCtrl] resetPasswordAfterOtp — URL: $resolvedUrl');
      print('🔐 [AuthentificationCtrl] userId: $userId (sans Bearer)');

      final data = <String, dynamic>{
        'newPassword': newPassword,
        'userId': userId,
      };

      final response = await putData(path, data, sendBearer: false);

      if (response.status) {
        if (response.data is Map) {
          print(
              '✅ [AuthentificationCtrl] resetPasswordAfterOtp OK — clés: ${(response.data as Map).keys.toList()}');
        } else {
          print('✅ [AuthentificationCtrl] resetPasswordAfterOtp OK');
        }
      } else {
        _logResetPasswordApiFailure(response);
        if (_isInternalServerErrorResponse(response)) {
          loading = false;
          notifyListeners();
          return HttpResponse(
            status: false,
            data: response.data,
            errorMsg:
                'Le serveur rencontre une difficulté temporaire. Veuillez réessayer dans quelques instants.',
            isException: response.isException,
          );
        }
      }

      loading = false;
      notifyListeners();
      return response;
    } catch (e, stack) {
      loading = false;
      notifyListeners();
      print('❌ [AuthentificationCtrl] resetPasswordAfterOtp exception: $e');
      print('❌ [AuthentificationCtrl] stack: $stack');
      return HttpResponse(
        status: false,
        errorMsg:
            'Erreur lors de la réinitialisation. Vérifiez votre connexion.',
        isException: true,
        data: {'message': e.toString()},
      );
    }
  }

  void _logResetPasswordApiFailure(HttpResponse response) {
    print(
        '❌ [AuthentificationCtrl] resetPasswordAfterOtp échec — errorMsg: ${response.errorMsg}');
    if (response.data is Map) {
      final m = response.data as Map;
      print('❌ [AuthentificationCtrl] detailMessage: ${m['detailMessage']}');
      print('❌ [AuthentificationCtrl] message: ${m['message']}');
      print('❌ [AuthentificationCtrl] error: ${m['error']}');
      if (m['errors'] != null) {
        print('❌ [AuthentificationCtrl] errors: ${m['errors']}');
      }
    }
  }

  bool _isInternalServerErrorResponse(HttpResponse response) {
    final em = (response.errorMsg ?? '').toLowerCase();
    if (em.contains('internal server error')) return true;
    if (response.data is Map) {
      final m = response.data as Map;
      final sc = m['status'] ?? m['statusCode'] ?? m['code'];
      if (sc == 500 || sc == '500') return true;
      final joined =
          '${m['message'] ?? ''} ${m['detailMessage'] ?? ''}'.toLowerCase();
      if (joined.contains('internal server error')) return true;
    }
    return false;
  }

  static String userMessageForResetPasswordFailure(HttpResponse response) {
    if (response.status) return '';
    final em = response.errorMsg?.trim();
    if (em != null && em.isNotEmpty) return em;
    if (response.data is Map) {
      final m = response.data as Map;
      final d = m['detailMessage']?.toString().trim();
      if (d != null && d.isNotEmpty) return d;
      final msg = m['message']?.toString().trim();
      if (msg != null && msg.isNotEmpty) return msg;
    }
    return 'Impossible de réinitialiser le mot de passe.';
  }

  // Réinitialisation du mot de passe (flux historique / autre usage)
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
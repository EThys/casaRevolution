import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:http/http.dart' as http;
import 'package:casa/utils/Constantes.dart';
class HttpResponse {
  bool status;
  dynamic data;
  String? errorMsg;
  bool? isException;
  /// Code HTTP brut (ex. 401, 500) quand la réponse vient du serveur.
  int? httpStatus;

  HttpResponse({
    this.data,
    required this.status,
    this.errorMsg,
    this.isException,
    this.httpStatus,
  });
}

/// `token ?? DefaultToken` ne suffit pas : `''` reste vide et supprime le Bearer.
String _authTokenOrDefault(String? token) {
  if (token == null) return Constantes.DefaultToken;
  final t = token.trim();
  return t.isEmpty ? Constantes.DefaultToken : t;
}

Future<dynamic> getData(String url_api, {String? token}) async {
  try {
    var urlStr = url_api.startsWith("http") ? url_api : '${Constantes.BASE_URL}$url_api';
    var url = Uri.parse(urlStr);
    var tkn = _authTokenOrDefault(token);
    var headers = {
      "Content-Type": "application/json",
    };
    if (tkn.isNotEmpty) {
      headers["Authorization"] = "Bearer $tkn";
    }
    var reponse = await http.get(url, headers: headers).timeout(Duration(seconds: 30));

    if (reponse.statusCode == 200 || reponse.statusCode == 201) {
      return jsonDecode(utf8.decode(reponse.bodyBytes));
    }
    print("⚠️ [getData] Erreur API - Status: ${reponse.statusCode} - URL: $url");
    try {
      print("📄 [getData] Body: ${reponse.body}");
    } catch (e) {
      print("📄 [getData] Body (non-printable): ${reponse.bodyBytes.length} bytes");
    }
    return null;
  } catch (e, trace) { 
    if (e.toString().contains('SocketException') || e.toString().contains('ClientException')) {
      print("⚠️ [getData] Erreur réseau (pas de connexion ?): ${e.toString().split('\n').first}");
    } else {
      print("❌ [getData] Exception: $e");
      print(trace.toString());
    }
    return null;
  }
}

/// Comme [getData], mais renvoie le corps JSON pour **401 / 403 / 400** lorsqu’il est décodable
/// (ex. `{ "message": "… compte … certifié" }`). [getData] renvoie `null` dans ces cas.
Future<dynamic> getDataAllowErrorJson(String url_api, {String? token}) async {
  try {
    var urlStr = url_api.startsWith("http") ? url_api : '${Constantes.BASE_URL}$url_api';
    var url = Uri.parse(urlStr);
    var tkn = _authTokenOrDefault(token);
    var headers = {
      "Content-Type": "application/json",
    };
    if (tkn.isNotEmpty) {
      headers["Authorization"] = "Bearer $tkn";
    }
    var reponse = await http.get(url, headers: headers).timeout(Duration(seconds: 30));

    final status = reponse.statusCode;
    dynamic decodedBody;
    try {
      decodedBody = jsonDecode(utf8.decode(reponse.bodyBytes));
    } catch (_) {
      decodedBody = null;
    }

    if (status == 200 || status == 201) {
      return decodedBody;
    }
    // Tout code erreur (4xx / 5xx) avec JSON objet — ex. 403, 500 avec { "message": "… certifié …" }
    if (status >= 400 && decodedBody is Map) {
      if (kDebugMode) {
        print('⚠️ [getDataAllowErrorJson] HTTP $status — $url');
      }
      return decodedBody;
    }
    // Corps texte (HTML ou texte brut) contenant le message métier
    if (status >= 400 && decodedBody == null) {
      final raw = reponse.body.toLowerCase();
      if (raw.contains('certif') && raw.contains('pas')) {
        return {'message': reponse.body};
      }
    }
    print("⚠️ [getDataAllowErrorJson] Status: $status — URL: $url");
    try {
      print("📄 Body: ${reponse.body}");
    } catch (_) {}
    return null;
  } catch (e, trace) {
    if (e.toString().contains('SocketException') || e.toString().contains('ClientException')) {
      print("⚠️ [getDataAllowErrorJson] Erreur réseau: ${e.toString().split('\n').first}");
    } else {
      print("❌ [getDataAllowErrorJson] Exception: $e");
      print(trace.toString());
    }
    return null;
  }
}


/// OTP public (`v1/public/otp/...`) : même base que [postData] (`.../api/`) + Bearer [Constantes.DefaultToken] si [token] absent ou vide.
Future<HttpResponse> postDataOtp(String api_url, Map data, {String? token}) async {
  try {
    var url = Uri.parse("${Constantes.BASE_URL}$api_url");
    String dataStr = json.encode(data);
    final tkn = _authTokenOrDefault(token);
    var headers = {
      "Content-Type": "application/json",
    };
    if (tkn.isNotEmpty) {
      headers["Authorization"] = "Bearer $tkn";
    }

    var response =
        await http.post(url, body: dataStr, headers: headers).timeout(Duration(seconds: 30));

    var successList = [200, 201];
    var msg = json.decode(utf8.decode(response.bodyBytes));
    var st = successList.contains(response.statusCode);
    String? errorMsg;
    if (!st && msg is Map) {
      errorMsg = msg['message'] ??
          msg['error'] ??
          msg['detailMessage'] ??
          msg['errors']?.toString();
    }
    return HttpResponse(status: st, data: msg, errorMsg: errorMsg);
  } catch (e, trace) {
    print("❌ [postDataOtp] Exception: $e");
    return HttpResponse(
        status: false, errorMsg: "Erreur inattendue", isException: true);
  }
}



Future<HttpResponse> putData(String api_url, Map data,
    {String? token, bool sendBearer = true}) async {
  print("🌐 [putData] ========== DÉBUT putData ==========");
  print("🌐 [putData] api_url: $api_url");
  try {
    final urlStr = api_url.startsWith("http") ? api_url : "${Constantes.BASE_URL}$api_url";
    final url = Uri.parse(urlStr);
    print("🌐 [putData] URL complète: $url");

    final dataStr = json.encode(data);
    print("🌐 [putData] Payload JSON: ${dataStr.length} caractères");
    // Afficher le payload (sécurisé) pour debug API: éviter de spammer si base64.
    try {
      if (dataStr.length <= 2000) {
        print("📤 [putData] Payload: $dataStr");
      } else {
        final keys = data.keys.map((e) => e.toString()).toList();
        print("📤 [putData] Payload (tronqué): keys=$keys");
        print("📤 [putData] Payload (tronqué): ${dataStr.substring(0, 900)} … (${dataStr.length} chars)");
      }
    } catch (_) {}

    final headers = <String, String>{
      "Content-Type": "application/json",
    };

    if (sendBearer) {
      final tkn = _authTokenOrDefault(token);
      print("🌐 [putData] Bearer activé: Oui — token: ${tkn.isNotEmpty ? 'Oui (${tkn.length} caractères)' : 'Non'}");
      if (tkn.isNotEmpty) {
        headers["Authorization"] = "Bearer $tkn";
      }
    } else {
      print("🌐 [putData] Bearer activé: Non");
    }

    final response = await http
        .put(url, body: dataStr, headers: headers)
        .timeout(const Duration(seconds: 30));

    final statusCode = response.statusCode;
    final rawBody = utf8.decode(response.bodyBytes);
    final st = statusCode == 200 || statusCode == 201;

    dynamic msg;
    try {
      msg = json.decode(rawBody);
    } catch (_) {
      msg = rawBody;
    }

    if (!st) {
      print("⚠️ [putData] HTTP $statusCode — $url");
      try {
        print("📄 [putData] Body: $rawBody");
      } catch (_) {
        print("📄 [putData] Body: ${response.bodyBytes.length} bytes");
      }
    } else {
      // Garder un log léger en succès (utile en prod quand on chasse un 500 intermittent).
      print("✅ [putData] HTTP $statusCode — OK");
    }

    String? errorMsg;
    if (!st && msg is Map) {
      errorMsg = msg['message'] ??
          msg['error'] ??
          msg['detailMessage'] ??
          msg['errors']?.toString();
    } else if (!st && msg is String) {
      errorMsg = msg.toString();
    }

    return HttpResponse(
      status: st,
      data: msg,
      errorMsg: errorMsg,
      httpStatus: statusCode,
    );
  } catch (e, trace) {
    print("❌ [putData] Exception: $e");
    print(trace.toString());
    return HttpResponse(
      status: false,
      errorMsg: e.toString(),
      isException: true,
    );
  } finally {
    print("🌐 [putData] ========== FIN putData ==========");
  }
}


  Future<HttpResponse> postData(String api_url, Map data,
      {String? token, bool allowDefaultToken = true}) async {
    print("🌐 [postData] ========== DÉBUT postData ==========");
    print("🌐 [postData] api_url: $api_url");
    try {
      var url = Uri.parse("${Constantes.BASE_URL}$api_url");
      print("🌐 [postData] URL complète: $url");
      String dataStr = json.encode(data);
      print("🌐 [postData] Taille des données JSON: ${dataStr.length} caractères");
      final String tkn = allowDefaultToken
          ? _authTokenOrDefault(token)
          : (token?.trim() ?? '');
      if (!allowDefaultToken && tkn.isEmpty) {
        print("🌐 [postData] Abandon : token utilisateur requis (allowDefaultToken=false)");
        return HttpResponse(
          status: false,
          errorMsg:
              'Vous devez être connecté. Reconnectez-vous et réessayez.',
          httpStatus: 401,
        );
      }
      print("🌐 [postData] Token utilisé: ${tkn.isNotEmpty ? 'Oui (${tkn.length} caractères)' : 'Non (Désactivé)'}");
      
      var headers = {
        "Content-Type": "application/json",
      };
      
      if (tkn.isNotEmpty) {
        headers["Authorization"] = "Bearer $tkn";
      }

      print("🌐 [postData] Envoi de la requête POST...");
      var response = await http.post(url, body: dataStr, headers: headers).timeout(Duration(seconds: 60));
      
      print("🌐 [postData] Réponse reçue - Status Code: ${response.statusCode}");
      print("🌐 [postData] Headers: ${response.headers}");
      
     /* if(!kReleaseMode){
        alice.onHttpResponse(response);
      }*/
      var successList = [200, 201];
      var st = successList.contains(response.statusCode);
      print("🌐 [postData] Status dans successList: $st");
      
      // Vérifier le Content-Type pour s'assurer que c'est du JSON
      final contentType = response.headers['content-type'] ?? '';
      print("🌐 [postData] Content-Type: $contentType");
      dynamic msg;
      
      if (contentType.contains('application/json')) {
        try {
          print("🌐 [postData] Parsing du JSON...");
          msg = json.decode(response.body);
          print("🌐 [postData] JSON parsé avec succès");
          if (msg is Map) {
            print("🌐 [postData] Clés dans la réponse: ${msg.keys.toList()}");
            if (msg.containsKey('message')) {
              print("🌐 [postData] Message: ${msg['message']}");
            }
            if (msg.containsKey('error')) {
              print("🌐 [postData] Erreur: ${msg['error']}");
            }
          }
        } catch (e) {
          print("❌ [postData] Erreur de parsing JSON: $e");
          print("📄 [postData] Corps de la réponse (premiers 500 caractères): ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}");
          return HttpResponse(
            status: false,
            errorMsg: "Erreur de format de réponse du serveur (HTML au lieu de JSON). Code: ${response.statusCode}",
            isException: true,
            httpStatus: response.statusCode,
            data: {'statusCode': response.statusCode, 'body': response.body.substring(0, 500)},
          );
        }
      } else {
        // La réponse n'est pas du JSON (probablement HTML d'erreur)
        print("❌ [postData] Réponse serveur n'est pas du JSON. Content-Type: $contentType");
        print("📄 [postData] Status Code: ${response.statusCode}");
        print("📄 [postData] Corps de la réponse (premiers 500 caractères): ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}");
        
        // Essayer de parser comme JSON malgré tout (parfois le Content-Type est incorrect)
        try {
          print("🌐 [postData] Tentative de parsing JSON malgré le Content-Type...");
          msg = json.decode(response.body);
          print("🌐 [postData] Parsing réussi malgré le Content-Type incorrect");
        } catch (e) {
          // Ce n'est vraiment pas du JSON
          print("❌ [postData] Parsing échoué, ce n'est pas du JSON");
          return HttpResponse(
            status: false,
            errorMsg: "Erreur serveur (code ${response.statusCode}). Le serveur a retourné du HTML au lieu de JSON. Veuillez réessayer plus tard.",
            isException: true,
            httpStatus: response.statusCode,
            data: {'statusCode': response.statusCode, 'isHtml': true},
          );
        }
      }

      // HTTP 200/201 mais échec métier (ex. { "success": false, "message": "…" })
      if (st && msg is Map) {
        final body = msg as Map<dynamic, dynamic>;
        if (body['success'] == false ||
            (body['status'] is bool && body['status'] == false)) {
          st = false;
        }
      }

      // Création réussie côté serveur mais corps ambigu (ex. success:false + propertyId présent).
      if (!st && msg is Map && successList.contains(response.statusCode)) {
        final body = msg as Map<dynamic, dynamic>;
        bool hasPropertyId(dynamic v) =>
            v != null && v.toString().trim().isNotEmpty && v.toString() != '0';
        bool created = hasPropertyId(body['propertyId']);
        if (!created && body['data'] is Map) {
          created = hasPropertyId((body['data'] as Map)['propertyId']);
        }
        if (!created && body['properties'] is Map) {
          created = hasPropertyId((body['properties'] as Map)['propertyId']);
        }
        if (created) {
          st = true;
        }
      }

      final errorMsg = st
          ? null
          : (msg is Map
              ? (msg['message'] ??
                  msg['error'] ??
                  msg['detailMessage'] ??
                  (msg['errors']?.toString()) ??
                  "Erreur inconnue")
              : "Erreur inconnue");
      print("🌐 [postData] Création de HttpResponse - status: $st, errorMsg: $errorMsg");
      print("🌐 [postData] ========== FIN postData ==========");
      return HttpResponse(
        status: st,
        data: msg,
        errorMsg: errorMsg,
        httpStatus: response.statusCode,
      );
    } catch (e, trace) {
      // Suppress verbose logging for network errors but show exact error info
      if (e.toString().contains('SocketException') || e.toString().contains('ClientException')) {
        print("⚠️ [postData] Erreur réseau: $e");
      } else {
        print("❌ [postData] ========== EXCEPTION dans postData ==========");
        print("❌ [postData] Exception: $e");
        print("📋 [postData] Stack trace: $trace");
        print("🌐 [postData] ========== FIN postData (avec erreur) ==========");
      }
      
      String errorMessage = "Erreur inattendue";
      
      if (e.toString().contains('TimeoutException')) {
        errorMessage = "Le serveur met trop de temps à répondre. Veuillez réessayer.";
      } else if (e.toString().contains('FormatException')) {
        errorMessage = "Erreur de format de réponse du serveur. Veuillez réessayer.";
      } else if (e.toString().contains('SocketException')) {
        errorMessage = "Impossible de se connecter au serveur. Vérifiez votre connexion internet.";
      }
      
      return HttpResponse(
          status: false, errorMsg: errorMessage, isException: true);
    }
  }

Future<HttpResponse> deleteData(String api_url, {Map<String, dynamic>? data, String? token}) async {
  try {
    final url = Uri.parse("${Constantes.BASE_URL}$api_url");
    final tkn = token ?? Constantes.DefaultToken;

    var headers = {
      "Content-Type": "application/json",
    };
    
    if (tkn.isNotEmpty) {
      headers["Authorization"] = "Bearer $tkn";
    }

    http.Response response;


    if (data != null) {
      String dataStr = json.encode(data);
      response = await http.delete(
          url,
          body: dataStr,
          headers: headers
      ).timeout(Duration(seconds: 30));
    } else {
      // Sinon, requête DELETE sans body
      response = await http.delete(
          url,
          headers: headers
      ).timeout(Duration(seconds: 30));
    }

    /* if(!kReleaseMode){
        alice.onHttpResponse(response);
      }*/

    final successList = [200, 201, 204];
    final st = successList.contains(response.statusCode);

    dynamic msg;
    String? errorMsg;
    if (response.bodyBytes.isNotEmpty) {
      try {
        msg = json.decode(utf8.decode(response.bodyBytes));
      } catch (_) {
        // Certaines erreurs API renvoient du texte/HTML.
        msg = {'message': response.body};
      }
    } else {
      msg = {'message': 'Supprimé avec succès'};
    }

    if (!st && msg is Map) {
      errorMsg = msg['message']?.toString() ??
          msg['error']?.toString() ??
          msg['detailMessage']?.toString() ??
          msg['errors']?.toString();
    }

    if (!st) {
      print("⚠️ [deleteData] HTTP ${response.statusCode} — $url");
      try {
        print("📄 [deleteData] Body: ${utf8.decode(response.bodyBytes)}");
      } catch (_) {
        print("📄 [deleteData] Body: ${response.bodyBytes.length} bytes");
      }
    }

    return HttpResponse(
      status: st,
      data: msg,
      errorMsg: errorMsg,
      httpStatus: response.statusCode,
    );
  } catch (e, trace) {
    print("❌ [deleteData] Exception: $e");
    print(trace.toString());
    return HttpResponse(
        status: false, errorMsg: e.toString(), isException: true);
  }
}

Future<HttpResponse> postDataForAuth(String api_url, Map data,
    {String? token, Map<String, String>? extraHeaders}) async {
  try {
    var url = Uri.parse("${Constantes.URL_AUTH}$api_url");
    String dataStr = json.encode(data);
    var tkn = token ?? Constantes.DefaultToken;
    var headers = <String, String>{
      "Content-Type": "application/json",
      ...?extraHeaders,
    };
    if (tkn.isNotEmpty) {
      headers["Authorization"] = "Bearer $tkn";
    }
    var response = await http.post(url, body: dataStr, headers: headers).timeout(Duration(seconds: 30));
    /* if(!kReleaseMode){
        alice.onHttpResponse(response);
      }*/
    var successList = [200, 201];
    var msg = json.decode(utf8.decode(response.bodyBytes));
    var st = successList.contains(response.statusCode);
    String? errorMsg;
    if (!st && msg is Map) {
      errorMsg = msg['message']?.toString() ??
          msg['detailMessage']?.toString() ??
          msg['error']?.toString();
    }
    return HttpResponse(
      status: st,
      data: msg,
      errorMsg: errorMsg,
      httpStatus: response.statusCode,
    );
  } catch (e, trace) {
    print(e.toString());
    print(trace.toString());
    return HttpResponse(
        status: false, errorMsg: "Erreur inattendue", isException: true);
  }
}

Future<HttpResponse> putDataForAuth(String api_url, Map data, {String? token}) async {
  try {
    var url = Uri.parse("${Constantes.URL_BASE}$api_url");
    String dataStr = json.encode(data);
    var tkn = token ?? Constantes.DefaultToken;
    var headers = {
      "Content-Type": "application/json",
    };
    if (tkn.isNotEmpty) {
      headers["Authorization"] = "Bearer $tkn";
    }

    var response = await http.put(url, body: dataStr, headers: headers).timeout(Duration(seconds: 30));
    
    var successList = [200, 201];
    var msg = json.decode(utf8.decode(response.bodyBytes));
    var st = successList.contains(response.statusCode);
    
    return HttpResponse(status: st, data: msg);
  } catch (e, trace) {
    print("❌ [putDataForAuth] Exception: $e");
    return HttpResponse(
        status: false, errorMsg: "Erreur inattendue", isException: true);
  }
}

Future<HttpResponse> postDataList(String api_url, Map<String, dynamic> data, {String? token}) async {
  try {
    var url = Uri.parse("${Constantes.BASE_URL}$api_url");
    String dataStr = json.encode(data);
    var tkn = token ?? Constantes.DefaultToken;

    var headers = {
      "Content-Type": "application/json",
    };
    if (tkn.isNotEmpty) {
      headers["Authorization"] = "Bearer $tkn";
    }

    var response = await http.post(url, body: dataStr, headers: headers).timeout(Duration(seconds: 5));

    // Vérifiez le statut de la réponse
    if (response.statusCode == 200 || response.statusCode == 201) {
      // Essayez de décoder la réponse
      var msg = json.decode(response.body);

      // Vérifiez si msg est bien une liste
      if (msg is List) {
        return HttpResponse(status: true, data: msg);
      } else {
        // Si ce n'est pas une liste, renvoyez une erreur
        return HttpResponse(
          status: false,
          errorMsg: "La réponse n'est pas une liste.",
          isException: false,
        );
      }
    } else {
      // Si le statut n'est pas 200 ou 201, renvoyez une erreur
      return HttpResponse(
        status: false,
        errorMsg: "Erreur lors de la requête : ${response.statusCode}",
        isException: false,
      );
    }
  } catch (e, trace) {
    print(e.toString());
    print(trace.toString());
    return HttpResponse(
      status: false,
      errorMsg: "Erreur inattendue",
      isException: true,
    );
  }
}


Future<HttpResponse> patchData(String api_url, Map data, {String? token}) async {
  try {
    var url = Uri.parse("${Constantes.BASE_URL}$api_url");
    String dataStr = json.encode(data);
    var tkn = token ?? Constantes.DefaultToken;
    var headers = {
      "Content-Type": "application/json",
    };
    if (tkn.isNotEmpty) {
      headers["Authorization"] = "Bearer $tkn";
    }
    var response = await http.patch(url, body: dataStr, headers: headers).timeout(Duration(seconds: 5));
    var successList = [200, 201];
    var msg = json.decode(response.body);
    var st = successList.contains(response.statusCode);

    String? errorMsg;
    if (!st && msg is Map) {
      errorMsg = msg['message'] ?? msg['error'] ?? msg['errors']?.toString();
    }

    return HttpResponse(status: st, data: msg, errorMsg: errorMsg);
  } catch (e, trace) {
    print(e.toString());
    print(trace.toString());

    return HttpResponse(
        status: false, errorMsg: "Erreur inattendue", isException: true);
  }
}








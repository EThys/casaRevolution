import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:casa/utils/Constantes.dart';
class HttpResponse {
  bool status;
  dynamic data;
  String? errorMsg;
  bool? isException;

  HttpResponse(
      {this.data, required this.status, this.errorMsg, this.isException});
}

Future<dynamic> getData(String url_api, {String? token}) async {
  try {
    var urlStr = url_api.startsWith("http") ? url_api : '${Constantes.BASE_URL}$url_api';
    var url = Uri.parse(urlStr);
    var tkn = token ?? Constantes.DefaultToken;
    var headers = {
      "Content-Type": "application/json",
    };
    if (tkn.isNotEmpty) {
      headers["Authorization"] = "Bearer $tkn";
    }
    var reponse = await http.get(url, headers: headers).timeout(Duration(seconds: 30));

    if (reponse.statusCode == 200) {
      return jsonDecode(utf8.decode(reponse.bodyBytes));
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


Future<HttpResponse> postDataOtp(String api_url, Map data, {String? token}) async {
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
    var response = await http.post(url, body: dataStr, headers: headers).timeout(Duration(seconds: 30));
    /* if(!kReleaseMode){
        alice.onHttpResponse(response);
      }*/
    var successList = [200, 201];
    var msg = json.decode(response.body);
    var st = successList.contains(response.statusCode);
    return HttpResponse(status: st, data: msg);
  } catch (e, trace) {
    print(e.toString());
    print(trace.toString());
    return HttpResponse(
        status: false, errorMsg: "Erreur inattendue", isException: true);
  }
}



Future<HttpResponse> putData(String api_url, Map data, {String? token}) async {
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
    var response = await http.put(url, body: dataStr, headers: headers).timeout(Duration(seconds: 30));
    /* if(!kReleaseMode){
        alice.onHttpResponse(response);
      }*/
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


  Future<HttpResponse> postData(String api_url, Map data, {String? token}) async {
    print("🌐 [postData] ========== DÉBUT postData ==========");
    print("🌐 [postData] api_url: $api_url");
    try {
      var url = Uri.parse("${Constantes.BASE_URL}$api_url");
      print("🌐 [postData] URL complète: $url");
      String dataStr = json.encode(data);
      print("🌐 [postData] Taille des données JSON: ${dataStr.length} caractères");
      var tkn = token ?? Constantes.DefaultToken;
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
            data: {'statusCode': response.statusCode, 'isHtml': true},
          );
        }
      }
      
      final errorMsg = st ? null : (msg['message'] ?? msg['error'] ?? "Erreur inconnue");
      print("🌐 [postData] Création de HttpResponse - status: $st, errorMsg: $errorMsg");
      print("🌐 [postData] ========== FIN postData ==========");
      return HttpResponse(status: st, data: msg, errorMsg: errorMsg);
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
    var url = Uri.parse("${Constantes.BASE_URL}$api_url");
    var tkn = token ?? Constantes.DefaultToken;

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

    var successList = [200, 201, 204];
    var msg = response.body.isNotEmpty ? json.decode(response.body) : {'message': 'Supprimé avec succès'};
    var st = successList.contains(response.statusCode);

    return HttpResponse(status: st, data: msg);
  } catch (e, trace) {
    print(e.toString());
    print(trace.toString());
    return HttpResponse(
        status: false, errorMsg: "Erreur inattendue", isException: true);
  }
}

Future<HttpResponse> postDataForAuth(String api_url, Map data, {String? token}) async {
  try {
    var url = Uri.parse("${Constantes.URL_AUTH}$api_url");
    String dataStr = json.encode(data);
    var tkn = token ?? Constantes.DefaultToken;
    var headers = {
      "Content-Type": "application/json",
    };
    if (tkn.isNotEmpty) {
      headers["Authorization"] = "Bearer $tkn";
    }
    var response = await http.post(url, body: dataStr, headers: headers).timeout(Duration(seconds: 30));
    /* if(!kReleaseMode){
        alice.onHttpResponse(response);
      }*/
    var successList = [200, 201];
    var msg = json.decode(response.body);
    var st = successList.contains(response.statusCode);
    return HttpResponse(status: st, data: msg);
  } catch (e, trace) {
    print(e.toString());
    print(trace.toString());
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








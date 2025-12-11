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
    var url = Uri.parse('${Constantes.BASE_URL}$url_api');
    var tkn = token ?? Constantes.DefaultToken;
    var reponse = await http.get(url, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $tkn"
    }).timeout(Duration(seconds: 10));

    if (reponse.statusCode == 200) {
      return jsonDecode(reponse.body);
    }
    return null;
  } catch (e, trace) {
    print(e.toString());
    print(trace.toString());
    return null;
  }
}


Future<HttpResponse> postDataOtp(String api_url, Map data, {String? token}) async {
  try {
    var url = Uri.parse("${Constantes.URL_BASE}$api_url");
    String dataStr = json.encode(data);
    var tkn = token ?? Constantes.DefaultToken;
    var response = await http.post(url, body: dataStr, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $tkn"
    }).timeout(Duration(seconds: 30));
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
    var response = await http.put(url, body: dataStr, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $tkn"
    }).timeout(Duration(seconds: 30));
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


  Future<HttpResponse> postData(String api_url, Map data, {String? token}) async {
    try {
      var url = Uri.parse("${Constantes.BASE_URL}$api_url");
      String dataStr = json.encode(data);
      var tkn = token ?? Constantes.DefaultToken;
      var response = await http.post(url, body: dataStr, headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $tkn"
      }).timeout(Duration(seconds: 30));
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

Future<HttpResponse> deleteData(String api_url, {Map<String, dynamic>? data, String? token}) async {
  try {
    var url = Uri.parse("${Constantes.BASE_URL}$api_url");
    var tkn = token ?? Constantes.DefaultToken;

    var headers = {
      "Content-Type": "application/json",
      "Authorization": "Bearer $tkn"
    };

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
    var response = await http.post(url, body: dataStr, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $tkn"
    }).timeout(Duration(seconds: 30));
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

    var response = await http.post(url, body: dataStr, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $tkn"
    }).timeout(Duration(seconds: 5));

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
    var response = await http.patch(url, body: dataStr, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $tkn"
    }).timeout(Duration(seconds: 5));
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








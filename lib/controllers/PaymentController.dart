import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
import '../utils/casa_payment_log.dart';
import '../utils/Endpoints.dart';
import '../utils/requetes.dart';

/// Abonnement : POST [Endpoints.paymentSubscription] avec `{ phone, deviseId }`.
class PaymentController with ChangeNotifier {
  PaymentController({this.stockage});

  final GetStorage? stockage;

  bool loading = false;

  Future<HttpResponse> postSubscriptionPayment({
    required String phone,
    required int deviseId,
    required String token,
  }) async {
    CasaPaymentLog.log(
      'API/MM',
      'POST ${Endpoints.paymentSubscription} deviseId=$deviseId phone=${CasaPaymentLog.maskPhone(phone)} tokenLen=${token.length}',
    );
    loading = true;
    notifyListeners();
    try {
      final r = await postData(
        Endpoints.paymentSubscription,
        {
          'phone': phone,
          'deviseId': deviseId,
        },
        token: token,
      );
      CasaPaymentLog.logHttpResponse(
        'API/MM',
        'postSubscriptionPayment',
        ok: r.status,
        httpStatus: r.httpStatus,
        errorMsg: r.errorMsg,
        data: r.data,
      );
      return r;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Paiement carte : session hébergée — réponse contient `url` à ouvrir dans le navigateur.
  Future<HttpResponse> postCardPaymentSession({
    required int deviseId,
    required String token,
  }) async {
    CasaPaymentLog.log(
      'API/Card',
      'POST ${Endpoints.paymentCard} deviseId=$deviseId tokenLen=${token.length}',
    );
    loading = true;
    notifyListeners();
    try {
      final r = await postData(
        Endpoints.paymentCard,
        {'deviseId': deviseId},
        token: token,
        allowDefaultToken: false,
      );
      CasaPaymentLog.logHttpResponse(
        'API/Card',
        'postCardPaymentSession',
        ok: r.status,
        httpStatus: r.httpStatus,
        errorMsg: r.errorMsg,
        data: r.data,
      );
      return r;
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}

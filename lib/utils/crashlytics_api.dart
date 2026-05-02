import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:casa/utils/requetes.dart';

String _truncate(String? s, int max) {
  if (s == null) return '';
  final t = s.trim();
  if (t.length <= max) return t;
  return '${t.substring(0, max)}…';
}

/// Enregistre un échec d’appel API (réponse HTTP métier ou exception) dans Crashlytics (non fatal).
///
/// Utiliser sur les écrans quand `response.status == false`, `isException == true`, ou dans un `catch`.
void reportApiFailureToCrashlytics(
  String screen, {
  HttpResponse? response,
  String? reason,
  Object? error,
  StackTrace? stackTrace,
}) {
  final parts = <String>['screen=$screen'];
  if (reason != null && reason.isNotEmpty) {
    parts.add('reason=$reason');
  }
  if (response != null) {
    parts.add('http=${response.httpStatus}');
    parts.add('apiExc=${response.isException}');
    parts.add('msg=${_truncate(response.errorMsg, 800)}');
    parts.add('data=${_truncate(response.data?.toString(), 2000)}');
  }
  if (error != null) {
    parts.add('throw=${_truncate(error.toString(), 600)}');
  }
  final line = 'API_FAILURE ${parts.join(' | ')}';

  // Custom keys: rendent le tri/filtrage facile dans Crashlytics (Non‑fatal).
  FirebaseCrashlytics.instance.setCustomKey('kind', 'api_failure');
  FirebaseCrashlytics.instance.setCustomKey('screen', screen);
  if (reason != null && reason.isNotEmpty) {
    FirebaseCrashlytics.instance.setCustomKey('reason', reason);
  }
  if (response != null) {
    FirebaseCrashlytics.instance.setCustomKey('httpStatus', response.httpStatus ?? 'null');
    FirebaseCrashlytics.instance.setCustomKey('apiException', response.isException == true);
    FirebaseCrashlytics.instance.setCustomKey('apiMessage', _truncate(response.errorMsg, 800));
    FirebaseCrashlytics.instance.setCustomKey('apiData', _truncate(response.data?.toString(), 2000));
  }
  if (error != null) {
    FirebaseCrashlytics.instance.setCustomKey('throw', _truncate(error.toString(), 600));
  }

  FirebaseCrashlytics.instance.log(line);

  // Prioriser l'erreur réelle si on en a une, sinon utiliser un wrapper.
  final err = error ?? Exception(line);
  FirebaseCrashlytics.instance.recordError(
    err,
    stackTrace ?? StackTrace.current,
    reason: 'api_failure',
    fatal: false,
  );
}

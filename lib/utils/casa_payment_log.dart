import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Journaux structurés pour tests paiement réel (Mobile Money / carte) et optimisation.
/// Préfixe filtrable dans Logcat : `[CasaPay]`
class CasaPaymentLog {
  CasaPaymentLog._();

  static const String tag = '[CasaPay]';

  static String _ts() => DateTime.now().toIso8601String();

  /// Message texte (scope = sous-catégorie : API, STOMP, UI, etc.)
  static void log(String scope, String message) {
    debugPrint('$tag ${_ts()} [$scope] $message');
  }

  /// Objet JSON ou valeur (indenté si Map/List).
  static void logJson(String scope, String label, Object? data) {
    debugPrint('$tag ${_ts()} [$scope] $label:');
    debugPrint('$tag ${_ts()} ${_safeEncode(data)}');
  }

  /// Réponse HTTP métier (masque les secrets évidents).
  static void logHttpResponse(
    String scope,
    String operation, {
    required bool ok,
    int? httpStatus,
    String? errorMsg,
    Object? data,
  }) {
    log(
      scope,
      '$operation → ok=$ok http=${httpStatus ?? '?'} err=${errorMsg ?? '—'}',
    );
    if (data != null) {
      logJson(scope, '$operation body', _redactSecrets(data));
    }
  }

  static Object? _redactSecrets(Object? data) {
    if (data is! Map) return data;
    final m = Map<String, dynamic>.from(data);
    const keys = {'token', 'accessToken', 'refreshToken', 'password', 'authorization'};
    for (final k in m.keys.toList()) {
      if (keys.contains(k.toString().toLowerCase())) {
        m[k] = '***REDACTED***';
      }
    }
    if (m['data'] is Map) {
      m['data'] = _redactSecrets(m['data']);
    }
    return m;
  }

  static String _safeEncode(Object? o) {
    if (o == null) return '  (null)';
    try {
      const enc = JsonEncoder.withIndent('  ');
      if (o is Map) return enc.convert(Map<String, dynamic>.from(o as Map));
      if (o is List) return enc.convert(o);
      return '  $o';
    } catch (e) {
      return '  [encode error: $e] raw=$o';
    }
  }

  /// Numéro partiellement masqué pour les logs (ex. 243******12).
  static String maskPhone(String digits) {
    final d = digits.replaceAll(RegExp(r'\D'), '');
    if (d.length < 6) return '***';
    return '${d.substring(0, 3)}******${d.substring(d.length - 2)}';
  }
}

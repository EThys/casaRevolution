import 'package:casa/utils/requetes.dart';

/// Messages utilisateur lisibles (snackbars / toasts) à partir des réponses API.
class ApiErrorMessages {
  ApiErrorMessages._();

  /// Texte brut renvoyé par le serveur (ou par la couche HTTP) : masque tout ce qui ressemble
  /// à une erreur technique et renvoie une phrase calme, sans le mot « erreur ».
  static String sanitizeServerText(
    String? raw, {
    String fallback =
        'Impossible de finaliser pour le moment. Vous pouvez réessayer dans un instant.',
  }) {
    if (raw == null) return fallback;
    var s = raw.trim();
    if (s.isEmpty) return fallback;

    // Réponses HTML / JSON brutes
    if (s.startsWith('{') && s.contains('"message"')) {
      return fallback;
    }
    if (s.startsWith('<!DOCTYPE') ||
        s.startsWith('<html') ||
        s.toLowerCase().contains('<html')) {
      return fallback;
    }

    final lower = s.toLowerCase();

    if (lower.contains('internal server') ||
        lower.contains('internalserver') ||
        lower.contains('bad gateway') ||
        lower.contains('gateway timeout') ||
        lower.contains('service unavailable') ||
        lower == '500' ||
        lower.contains('http 500')) {
      return 'Le service est momentanément occupé. Merci de réessayer un peu plus tard.';
    }

    if (lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('connection timed out') ||
        lower.contains('timeout') ||
        lower.contains('timed out')) {
      return 'La connexion a pris trop de temps. Vérifiez le réseau et réessayez.';
    }

    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network is unreachable') ||
        lower.contains('no address associated')) {
      return 'Connexion réseau indisponible. Réessayez lorsque vous êtes en ligne.';
    }

    if (lower.contains('format exception') ||
        lower.contains('json') && lower.contains('parse')) {
      return 'Réponse inattendue du service. Réessayez plus tard.';
    }

    // Traces / détails techniques
    if (lower.contains('exception:') ||
        lower.contains('stacktrace') ||
        lower.contains('stack trace') ||
        lower.contains('at ') && lower.contains('.dart:') ||
        lower.contains('caused by:')) {
      return fallback;
    }

    if (s.length > 400) {
      return fallback;
    }

    return s;
  }

  static String fromResponse(HttpResponse response, {bool loginContext = false}) {
    if (response.isException == true) {
      final m = (response.errorMsg ?? '').toLowerCase();
      if (m.contains('timeout')) {
        return 'Le serveur met trop de temps à répondre. Réessayez.';
      }
      if (m.contains('socket') ||
          m.contains('clientexception') ||
          m.contains('connexion')) {
        return 'Connexion impossible. Vérifiez votre réseau.';
      }
      if (m.contains('format')) {
        return 'Réponse inattendue. Réessayez plus tard.';
      }
      return sanitizeServerText(
        response.errorMsg,
        fallback:
            'Connexion interrompue. Vérifiez le réseau et réessayez.',
      );
    }

    String raw = (response.errorMsg ?? '').trim();
    if (raw.isEmpty && response.data is Map) {
      final d = response.data as Map;
      final m = d['message'] ?? d['detailMessage'];
      if (m != null) raw = m.toString().trim();
    }
    final lower = raw.toLowerCase();
    final code = response.httpStatus;

    if (loginContext && raw.isNotEmpty && _looksLikeLoginUserNotFound(lower)) {
      return 'Ce compte n\'existe pas ou l\'identifiant est incorrect.';
    }

    // Sur l’écran de connexion, un 401 signifie en général identifiants incorrects, pas une session expirée.
    if (loginContext && code == 401) {
      return 'Ce compte n\'existe pas ou l\'identifiant est incorrect.';
    }

    if (code == 401 ||
        lower.contains('jwt') ||
        lower.contains('invalid or missing') ||
        lower.contains('unauthorized')) {
      return 'Session expirée. Reconnectez-vous pour continuer.';
    }
    if (code == 403) {
      return 'Cette action n’est pas disponible avec votre compte actuel.';
    }
    if (code == 404) {
      if (loginContext) {
        return 'Ce compte n\'existe pas ou l\'identifiant est incorrect.';
      }
      return 'Cette ressource est introuvable. Actualisez ou réessayez.';
    }
    if (code == 413 ||
        lower.contains('payload too large') ||
        lower.contains('request entity too large')) {
      return 'Fichiers ou données trop volumineux. Réduisez la taille et réessayez.';
    }
    if (code != null && code >= 500) {
      return 'Le service est momentanément indisponible. Réessayez dans quelques minutes.';
    }
    if (lower.contains('internal server') ||
        lower.contains('bad gateway') ||
        lower.contains('gateway timeout')) {
      return 'Le service est momentanément indisponible. Réessayez dans quelques minutes.';
    }
    if (raw.isNotEmpty) {
      return sanitizeServerText(raw);
    }
    return 'Impossible de finaliser pour le moment. Réessayez.';
  }

  /// Phrases API / HTTP typiques quand l’utilisateur n’existe pas ou l’identifiant est refusé.
  static bool _looksLikeLoginUserNotFound(String lower) {
    return lower.contains('introuvable') ||
        lower.contains('not found') ||
        lower.contains('no user') ||
        lower.contains('user not found') ||
        lower.contains('aucun compte') ||
        lower.contains('compte inconnu') ||
        lower.contains('does not exist') ||
        lower.contains('idenfiant invalide') ||
        lower.contains('identifiant invalide') ||
        lower.contains('invalid credentials') ||
        lower.contains('bad credentials');
  }
}

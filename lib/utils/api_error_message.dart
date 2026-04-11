import 'package:casa/utils/requetes.dart';

/// Messages utilisateur lisibles (snackbars) à partir des réponses API.
class ApiErrorMessages {
  ApiErrorMessages._();

  static String fromResponse(HttpResponse response) {
    if (response.isException == true) {
      final m = (response.errorMsg ?? '').toLowerCase();
      if (m.contains('timeout')) {
        return 'Le serveur met trop de temps à répondre. Réessayez.';
      }
      if (m.contains('socket') || m.contains('clientexception') || m.contains('connexion')) {
        return 'Connexion impossible. Vérifiez votre réseau.';
      }
      if (m.contains('format')) {
        return 'Réponse serveur inattendue. Réessayez plus tard.';
      }
      return response.errorMsg?.trim().isNotEmpty == true
          ? response.errorMsg!.trim()
          : 'Une erreur réseau est survenue.';
    }

    String raw = (response.errorMsg ?? '').trim();
    if (raw.isEmpty && response.data is Map) {
      final d = response.data as Map;
      final m = d['message'] ?? d['detailMessage'];
      if (m != null) raw = m.toString().trim();
    }
    final lower = raw.toLowerCase();
    final code = response.httpStatus;

    if (code == 401 ||
        lower.contains('jwt') ||
        lower.contains('invalid or missing') ||
        lower.contains('unauthorized')) {
      return 'Session expirée ou token invalide. Reconnectez-vous.';
    }
    if (code == 403) {
      return 'Accès refusé. Vérifiez vos droits ou reconnectez-vous.';
    }
    if (code == 404) {
      return 'Ressource introuvable.';
    }
    if (code == 413 ||
        lower.contains('payload too large') ||
        lower.contains('request entity too large')) {
      return 'Données trop volumineuses (ex. photos). Réduisez la taille et réessayez.';
    }
    if (code != null && code >= 500) {
      return 'Le serveur est momentanément indisponible. Réessayez dans quelques minutes.';
    }
    if (lower.contains('internal server') ||
        lower.contains('bad gateway') ||
        lower.contains('gateway timeout')) {
      return 'Le serveur rencontre une erreur. Réessayez plus tard.';
    }
    if (raw.isNotEmpty) return raw;
    return 'Une erreur est survenue.';
  }
}

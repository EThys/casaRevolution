import 'package:firebase_analytics/firebase_analytics.dart';

import '../models/UserModel.dart';

/// Statistiques Firebase. Jamais de nom, de téléphone ni d'e-mail.
class CasaAnalytics {
  CasaAnalytics._();

  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  static String _clip(String? value, [int max = 36]) {
    final text = (value ?? '').trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return '';
    return text.length <= max ? text : text.substring(0, max);
  }

  static Map<String, Object> _params(Map<String, Object?> raw) {
    final out = <String, Object>{};
    raw.forEach((key, value) {
      if (value == null) return;
      if (value is num) {
        out[key] = value;
        return;
      }
      final text = _clip(value.toString(), 100);
      if (text.isNotEmpty) out[key] = text;
    });
    return out;
  }

  static Future<void> syncUser(UserModel user) async {
    final id = user.userId;
    if (id == null) return;
    try {
      await _analytics.setUserId(id: id.toString());
      await _analytics.setUserProperty(
        name: 'account_type',
        value: _orNull(_clip(user.typeAccount?.name)),
      );
      await _analytics.setUserProperty(
        name: 'city',
        value: _orNull(_clip(user.city ?? user.cityModel?.name)),
      );
      await _analytics.setUserProperty(
        name: 'premium',
        value: user.isPremium == true ? 'yes' : 'no',
      );
    } catch (_) {}
  }

  static Future<void> clearUser() async {
    try {
      await _analytics.setUserId(id: null);
      await _analytics.setUserProperty(name: 'account_type', value: null);
      await _analytics.setUserProperty(name: 'city', value: null);
      await _analytics.setUserProperty(name: 'premium', value: null);
    } catch (_) {}
  }

  static String? _orNull(String value) => value.isEmpty ? null : value;

  static Future<void> _event(String name, [Map<String, Object?> params = const {}]) async {
    try {
      final cleaned = _params(params);
      await _analytics.logEvent(
        name: name,
        parameters: cleaned.isEmpty ? null : cleaned,
      );
    } catch (_) {}
  }

  static Future<void> login() => _event('login', {'method': 'password'});

  static Future<void> signUp() => _event('sign_up', {'method': 'password'});

  static Future<void> search({
    required String term,
    String? itemType,
    String? city,
    String? commune,
  }) {
    final query = term.trim();
    if (query.isEmpty && (city == null || city.trim().isEmpty) && (itemType == null || itemType == 'Tous')) {
      return Future.value();
    }
    return _event('search', {
      'search_term': query,
      'item_category': itemType,
      'city': city,
      'commune': commune,
    });
  }

  static Future<void> viewItem({
    required String category,
    Object? id,
    String? city,
    String? commune,
    num? price,
  }) {
    return _event('view_item', {
      'item_category': category,
      'item_id': id?.toString(),
      'city': city,
      'commune': commune,
      'price': price,
    });
  }

  static Future<void> favorite({
    required Object id,
    required bool service,
  }) {
    return _event('add_to_wishlist', {
      'item_id': id.toString(),
      'item_category': service ? 'service' : 'property',
    });
  }

  static Future<void> reservationSent({
    required String category,
    Object? id,
  }) {
    return _event('reservation_sent', {
      'item_category': category,
      'item_id': id?.toString(),
    });
  }

  static Future<void> interventionSent({Object? serviceId}) {
    return _event('intervention_sent', {
      'item_category': 'service',
      'item_id': serviceId?.toString(),
    });
  }

  static Future<void> premiumPaid() => _event('premium_paid');

  static Future<void> reviewSent({required num score, Object? solicitationId}) {
    return _event('review_sent', {
      'score': score,
      'item_id': solicitationId?.toString(),
    });
  }
}

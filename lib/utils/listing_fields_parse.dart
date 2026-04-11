/// Parse robuste de champs catalogue (sold / disponible) depuis plusieurs clés et maps JSON.
/// Évite de traiter une clé absente comme `false` (bug fréquent avec `_parseBool(null) => false`).
class ListingFieldsParse {
  ListingFieldsParse._();

  static bool? optionalBool(dynamic v) {
    if (v == null) return null;
    if (v is bool) return v;
    if (v is int) return v != 0;
    if (v is double) return v != 0;
    if (v is String) {
      final s = v.toLowerCase().trim();
      if (s == 'true' || s == '1' || s == 'yes' || s == 'oui' || s == 't') return true;
      if (s == 'false' || s == '0' || s == 'no' || s == 'non' || s == 'f') return false;
    }
    return null;
  }

  /// Premier booléen explicite trouvé dans [maps] pour les clés habituelles API / BDD.
  static bool? soldFromMaps(Iterable<Map<String, dynamic>> maps) {
    const keys = ['sold', 'isSold', 'is_sold', 'soldOut', 'isSoldOut', 'estVendu'];
    bool? scan(Map<String, dynamic> m) {
      for (final key in keys) {
        if (!m.containsKey(key)) continue;
        final b = optionalBool(m[key]);
        if (b != null) return b;
      }
      final nested = m['property'];
      if (nested is Map<String, dynamic>) {
        for (final key in keys) {
          if (!nested.containsKey(key)) continue;
          final b = optionalBool(nested[key]);
          if (b != null) return b;
        }
      }
      return null;
    }
    for (final m in maps) {
      final r = scan(m);
      if (r != null) return r;
    }
    return null;
  }

  static bool? availableFromMaps(Iterable<Map<String, dynamic>> maps) {
    const keys = ['available', 'isAvailable', 'is_available'];
    for (final key in keys) {
      for (final m in maps) {
        if (!m.containsKey(key)) continue;
        final b = optionalBool(m[key]);
        if (b != null) return b;
      }
    }
    return null;
  }

  /// Couches typiques d’un item de liste catalogue (racine + enveloppes API).
  static List<Map<String, dynamic>> listingRawLayers(Map<String, dynamic> raw) {
    final maps = <Map<String, dynamic>>[raw];
    for (final key in [
      'property',
      'funeraire',
      'funeraires',
      'festive',
      'festives',
      'salle',
      'bureau',
      'bureaux',
      'terrain',
      'vacance',
      'vacances',
      'hotel',
      'prestation',
    ]) {
      final v = raw[key];
      if (v is Map<String, dynamic>) {
        maps.add(v);
      } else if (v is Map) {
        maps.add(Map<String, dynamic>.from(v));
      }
    }
    return maps;
  }

  /// [sold] depuis un élément brut de liste (même forme que les favoris / annonces publiques).
  static bool? soldFromListingRaw(Map<String, dynamic> raw) {
    return soldFromMaps(listingRawLayers(raw));
  }

  /// Supprime clés/valeurs `null` en profondeur (évite erreurs Jackson `null` → `boolean` primitif).
  static dynamic deepOmitNull(dynamic value) {
    if (value == null) return null;
    if (value is Map) {
      final out = <String, dynamic>{};
      value.forEach((k, v) {
        if (v == null) return;
        final nested = deepOmitNull(v);
        if (nested != null) out[k.toString()] = nested;
      });
      return out;
    }
    if (value is List) {
      final out = <dynamic>[];
      for (final e in value) {
        if (e == null) continue;
        out.add(deepOmitNull(e));
      }
      return out;
    }
    return value;
  }

  /// Fusion « prudente » : vendu si une source dit oui ; sinon premier non-null.
  static bool? mergeSold(bool? a, bool? b) {
    if (a == true || b == true) return true;
    if (a == false && b == false) return false;
    return a ?? b;
  }

  /// Indisponible si une source dit explicitement non ; sinon disponible si une dit oui.
  static bool? mergeAvailable(bool? a, bool? b) {
    if (a == false || b == false) return false;
    if (a == true || b == true) return true;
    return a ?? b;
  }
}

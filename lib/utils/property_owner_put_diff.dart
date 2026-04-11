/// Construction des PUT `/protected/property/.../owner/{id}` : champs inchangés → valeur « vide »
/// (chaîne vide, 0, 0.0) pour que le backend n’écrase pas les colonnes existantes.
class PropertyOwnerPutDiff {
  PropertyOwnerPutDiff._();

  static String str(String current, String baseline) {
    final c = current.trim();
    final b = baseline.trim();
    return c == b ? '' : c;
  }

  static int integer(int current, int baseline) => current == baseline ? 0 : current;

  static double dbl(double current, double baseline) =>
      (current - baseline).abs() < 1e-9 ? 0.0 : current;

  static bool listStrEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Helpers pour logs sans exposer de secrets (JWT, refresh tokens, etc.).
String describeSecretPresence(String? value, {String name = 'Jeton'}) {
  if (value == null || value.isEmpty) return '$name: absent';
  return '$name: présent (${value.length} caractères)';
}

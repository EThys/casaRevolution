/// Symboles affichés dans l’UI : **$** pour le dollar, **FC** pour le franc congolais (jamais « USD » / « CDF » en libellé utilisateur).
class CurrencyDisplay {
  CurrencyDisplay._();

  static String symbolFromCode(String? code) {
    if (code == null || code.trim().isEmpty) return '\$';
    final c = code.trim().toUpperCase();
    if (c == 'USD' || c == 'DOLLAR' || c == 'DOLLARS') return '\$';
    if (c == 'CDF' || c == 'FC' || c == 'FRANC' || c == 'CDFC') return 'FC';
    return code.trim();
  }

  static String labelForToggle(String apiCode) {
    final c = apiCode.toUpperCase();
    if (c == 'USD') return '\$';
    if (c == 'CDF') return 'FC';
    return apiCode;
  }
}

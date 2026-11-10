/// Règles communes des annonces : propriété, bureau, hôtel, salle, vacance.
class ListingFormRules {
  ListingFormRules._();

  static String? title(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Titre requis';
    if (text.length < 3) return 'Au moins 3 caractères';
    return null;
  }

  static String? price(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Prix requis';
    final amount = double.tryParse(text.replaceAll(',', '.').replaceAll(' ', ''));
    if (amount == null || amount <= 0) return 'Indiquez un montant supérieur à 0';
    return null;
  }

  static String? address(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Adresse requise';
    if (text.length < 5) return 'Adresse trop courte';
    return null;
  }

  static String? description(String? value, {required bool required}) {
    if (!required) return null;
    if ((value?.trim() ?? '').isEmpty) return 'Description requise';
    return null;
  }

  static String? positiveCount(String? value, {required bool required, required String emptyLabel}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return required ? emptyLabel : null;
    final count = int.tryParse(text);
    if (count == null || count < 1) return 'Indiquez un nombre entier supérieur à 0';
    return null;
  }

  static String? optionalCount(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final count = int.tryParse(text);
    if (count == null || count < 0) return 'Indiquez un nombre entier';
    return null;
  }

  static String? positiveAmount(String? value, {required bool required, required String emptyLabel}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return required ? emptyLabel : null;
    final amount = double.tryParse(text.replaceAll(',', '.').replaceAll(' ', ''));
    if (amount == null || amount <= 0) return 'Indiquez un nombre supérieur à 0';
    return null;
  }

  /// Terrain : « 500 » ou « 20x25 ». Un nombre seul doit être supérieur à 0.
  static String? surfaceText(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Superficie requise';
    final numeric = double.tryParse(text.replaceAll(',', '.').replaceAll(' ', ''));
    if (numeric != null && numeric <= 0) return 'Indiquez une surface supérieure à 0';
    return null;
  }
}

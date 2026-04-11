/// Pour un libellé du type « Réseau Orange détecté » → affiche seulement « Orange ».
String carrierLabelFromDetectionPhrase(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return s;
  s = s.replaceFirst(RegExp(r'^réseau\s+', caseSensitive: false), '');
  s = s.replaceFirst(RegExp(r'^reseau\s+', caseSensitive: false), '');
  s = s.replaceFirst(RegExp(r'^network\s+', caseSensitive: false), '');
  s = s.replaceFirst(RegExp(r'\s+détecté\.?$', caseSensitive: false), '');
  s = s.replaceFirst(RegExp(r'\s+detecté\.?$', caseSensitive: false), '');
  s = s.replaceFirst(RegExp(r'\s+detecte\.?$', caseSensitive: false), '');
  s = s.replaceFirst(RegExp(r'\s+detected\.?$', caseSensitive: false), '');
  return s.trim();
}

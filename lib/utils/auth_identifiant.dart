/// Construit l'identifiant attendu par l'API de connexion (email ou téléphone + indicatif).
String buildLoginIdentifiant({
  required String contactTrimmed,
  required String countryCode,
  required bool isPhone,
}) {
  if (!isPhone) return contactTrimmed;

  var digits = contactTrimmed.replaceAll(RegExp(r'[^\d]'), '');
  final code = countryCode;
  final codeDigits = code.replaceAll('+', '');

  if (digits.startsWith('0')) {
    return '$code${digits.substring(1)}';
  }
  if (digits.startsWith(codeDigits)) {
    return '+$digits';
  }
  if ((digits.startsWith('8') || digits.startsWith('9')) && digits.length == 9) {
    return '$code$digits';
  }
  return '$code$digits';
}

bool isLoginApiSuccess(dynamic responseData) {
  if (responseData is! Map) return false;
  final message = responseData['message']?.toString() ?? '';
  return message.toLowerCase().contains('réussie');
}


class StockageKeys{

  static const String tokenKey = 'token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userKey = 'user';
  static const String userPreferenceKey = 'user_preference';
  static const String profileKey = 'profile';
  static const String allUsers="ALLUSERS";
  static const String propreties="propreties";
  static const String propretyVisits="propretyVisits";
  static const String listeCampagnes="listeCampagnes";
  static const String userVisits="userVisits";
  static const String firstLaunchKey="FIRSTLAUNCH";
  static const String themeModeKey="themeMode";
  static const String devisesKey="devises";
  static const String wasCertifiedKey = 'was_certified';
  static const String decertificationReasonKey = 'decertification_reason';
  /// Quand l’utilisateur clique "Plus tard" sur l’écran de décertification.
  /// On ne ré-affiche pas automatiquement l’info tant qu’il ne retente pas une action sensible.
  static const String decertificationSnoozeKey = 'decertification_snooze';

  /// Horodatage (ms depuis epoch) du dernier envoi réussi des documents KYC pour l’utilisateur `{uid}`.
  /// Sert à éviter de ré-empiler l’alerte décertification / un pop intempestif tant que l’analyse est en cours.
  static const String kycDocsSubmittedAtKey = 'kyc_docs_submitted_at';

}
class Constantes {
  // URLs dynamiques basées sur le serveur actif
  static String _activeBaseUrl = "http://91.99.168.226:8083";
  
  // Getters dynamiques qui utilisent le serveur actif
  static String get BASE_URL => "$_activeBaseUrl/api/";
  static String get URL_AUTH => "$_activeBaseUrl/auth/";
  static String get URL_BASE => "$_activeBaseUrl/";
  static String get URL_IMAGES => "$_activeBaseUrl/storage/";
  
  // Constantes qui ne changent pas
  static const String DefaultToken = "7|HPK4TpJQZN4ADqrE4SrM9IcQyCxsXB0dlH2W5MXR";
  static const String kIconPath = 'assets/icons';
  
  // Méthode pour mettre à jour le serveur actif (appelée par ServerHealthService)
  static void setActiveServer(String serverUrl) {
    _activeBaseUrl = serverUrl.endsWith('/') ? serverUrl.substring(0, serverUrl.length - 1) : serverUrl;
    print("🔄 [Constantes] Serveur actif changé: $_activeBaseUrl");
  }
  
  // Méthode pour obtenir le serveur actif
  static String get activeServer => _activeBaseUrl;
}

class Endpoints {
  // Authentication Endpoints
  static const String register = "members";
  static const String login = "login";
  static const String forgotPassword = "forgot-password";
  static const String verifyOTP = "verify-otp";
  static const String resetPassword = "reset-password";
  
  // OTP Endpoints
  static const String otpGenerate = "otp/generate";
  static const String otpVerify = "otp/verify";
  static const String resetPasswordEndpoint = "reset/password";
  static const String profile = "profile";
  static const String reservations = "reservations";

  static const String reservationsByUser = "user";

  static const String updateProfile = "profile";
  static const String logout = "logout";
  static const String changePassword = "change-password";
  static const String deleteAccount = "delete-account";

  static const String bailleur = "bailleurs";
  static const String commissionnaire = "commissionnaires";
  static const String locataire = "locataires";
  static const String majordomes = "majordomes";
  static const String plombiers = "plombiers";
  static const String electriciens = "electriciens";
  static const String salubrites = "salubrites";
  static const String peintres = "peintres";
  static const String carreleurs = "carreleurs";
  static const String menuisiers = "menuisiers";
  static const String frigoristes = "frigoristes";
  static const String ajusteurs = "ajusteurs";
  static const String architectes = "architectes";
  static const String chauffeurs = "chauffeurs";
  static const String demenagements = "demenagements";

  // location Endpoints
  static const String cities = "cities";
  static const String communes = "communes";
  static const String districts = "districts";
  static const String quartiers = "quartiers";

  // Property Endpoints
  static const String properties = "property";
  static const String propertyDetail = "properties/";
  static const String storeProperty = "property";
  static const String updateProperty = "properties/";
  static const String deleteProperty = "properties/";
  static const String propertiesByOwner = "property/owner/";
  static const String propertyBureaux = "property/bureaux";
  static const String propertyFestives = "property/festives";
  static const String propertyFuneraires = "property/funeraires";

  // Property Feature Endpoints
  static const String features = "features";
  static const String featureDetail = "features/";
  static const String featureProperties = "features/";
  static const String storeFeature = "features";
  static const String updateFeature = "features/";
  static const String deleteFeature = "features/";

  // Property Type Endpoints
  static const String propertyTypesList = "property/types";
  static const String propertyTypes = "property";
  static const String propertyTypeDetail = "property/";
  static const String propertiesByType = "propertyType/";
  static const String storePropertyType = "propertyType";
  static const String updatePropertyType = "propertyType/";
  static const String deletePropertyType = "propertyType/";

  // Property favorites Endpoints
  static const String allFavories = "favorite";
  static const String AddFavorite = "favorite";
  static const String getMyfavorites = "favorite/user";
  static const String removeMyfavorites = "favorite/user/delete";

  // Visit Endpoints
  static const String allReservations = "reservations/";
  static const String addReservations= "reservations";

  // Search Endpoints
  static const String propertyFilter = "property/filter";
  static const String propertySearch = "roperty/search";

  // Service Endpoints
  static const String services = "services";
  static const String serviceDetail = "services/";
  static const String storeService = "services";
  static const String updateService = "services/";
  static const String deleteService = "services/";
  static const String servicesByType = "services/type/";
  static const String myServices = "services/my";

  // Service Requests Endpoints
  static const String serviceRequests = "service-requests";
  static const String createServiceRequest = "service-requests";
  static const String getServiceRequests = "service-requests/user"; // Pour le demandeur
  static const String getServiceRequestsForProviders = "service-requests/for-providers"; // Pour les prestataires
  static const String serviceRequestDetail = "service-requests/";
  static const String respondToRequest = "service-requests"; // POST avec requestId dans le body
  static const String acceptResponse = "service-requests"; // PUT avec requestId et responseId
  static const String cancelRequest = "service-requests"; // DELETE avec requestId

  // Notifications Endpoints
  static const String notifications = "notifications";
  static const String markNotificationRead = "notifications/"; // PUT avec id
  static const String markAllNotificationsRead = "notifications/read-all";
  static const String deleteNotification = "notifications/"; // DELETE avec id

}
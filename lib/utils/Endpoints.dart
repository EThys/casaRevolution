class Endpoints {
  // Authentication Endpoints
  static const String register = "register";
  static const String login = "login";
  static const String forgotPassword = "forgot-password";
  static const String resetPassword = "reset-password";
  static const String profile = "profile";
  static const String updateProfile = "profile";
  static const String logout = "logout";
  static const String changePassword = "change-password";
  static const String deleteAccount = "delete-account";

  static const String bailleur = "bailleur";
  static const String commissionnaire = "commissionnaire";
  static const String locataire = "locataire";

  // Property Endpoints
  static const String properties = "properties";
  static const String propertyDetail = "properties/";
  static const String storeProperty = "properties";
  static const String updateProperty = "properties/";
  static const String deleteProperty = "properties/";

  // Property Feature Endpoints
  static const String features = "features";
  static const String featureDetail = "features/";
  static const String featureProperties = "features/";
  static const String storeFeature = "features";
  static const String updateFeature = "features/";
  static const String deleteFeature = "features/";

  // Property Type Endpoints
  static const String propertyTypes = "property";
  static const String propertyTypeDetail = "property/";
  static const String propertiesByType = "propertyType/";
  static const String storePropertyType = "propertyType";
  static const String updatePropertyType = "propertyType/";
  static const String deletePropertyType = "propertyType/";

  // Property favorites Endpoints
  static const String allFavories = "property-favorites";
  static const String AddFavorite = "property-favorites";
  static const String getMyfavorites = "users";
  static const String removeMyfavorites = "property-favorites/remove";

  // Visit Endpoints
  static const String allVisits = "visit/all";
  static const String visitsByStatus = "visits/status/";
  static const String changeVisitStatus = "visits/";
  static const String storeVisit = "visit";
  static const String visits = "visits";
  static const String visitsByUser = "visits/user";

}
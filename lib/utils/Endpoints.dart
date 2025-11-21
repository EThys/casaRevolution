class Endpoints {
  // Authentication Endpoints
  static const String register = "register";
  static const String login = "login";
  static const String forgotPassword = "forgot-password";
  static const String resetPassword = "reset-password";
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

}
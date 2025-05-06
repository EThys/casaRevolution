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

  // Visit Endpoints
  static const String visitsByStatus = "visits/status/";
  static const String changeVisitStatus = "visits/";
  static const String storeVisit = "visit";
}


class Endpoints {
  // Authentication Endpoints
  static const String register = "auth/register";
  static const String login = "auth/login";
  static const String forgotPassword = "forgot-password";
  static const String verifyOTP = "v1/public/otp/verify";
  static const String resetPassword = "reset-password";
  static const String updateProfilePicture = "v1/protected/members/";

  // OTP Endpoints
  static const String otpGenerate = "v1/public/otp/generate";
  static const String otpVerify = "v1/public/otp/verify";
  static const String resetPasswordEndpoint = "v1/protected/reset/password";
  static const String profile = "profile";
  static const String reservations = "v1/protected/reservations";

  static const String reservationsByUser = "user";

  static const String updateProfile = "profile";
  static const String logout = "logout";
  static const String changePassword = "v1/protected/change/password";
  static const String deleteAccount = "v1/protected/users/delete/user";
  static const String accounts = "v1/public/accounts";

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

  // Location Endpoints
  static const String cities = "v1/public/cities";
  static const String communes = "v1/public/communes";
  static const String districts = "v1/public/districts";
  static const String quartiers = "v1/public/quartiers";

  // Property Endpoints
  static const String properties = "v1/public/property";
  static const String propertyDetail = "v1/public/property/";
  static const String storeProperty = "v1/private/property";
  static const String updateProperty = "v1/protected/property/owner/";
  static const String deleteProperty = "properties/";
  static const String propertiesByOwner = "v1/protected/property/owner/";
  static const String propertyBureaux = "v1/public/property/bureaux";
  static const String propertyBureau = "property/bureau";
  static const String propertyFestives = "v1/public/property/festives";
  static const String propertyFuneraires = "v1/public/property/funeraires";
  static const String propertyVacances = "v1/public/property/vacances";
  static const String propertyTerrains = "v1/public/property/terrains";

  // Specialized Property Owner Endpoints
  static const String propertyBureauxByOwner =
      "v1/protected/property/bureaux/owner/";
  static const String propertyFestivesByOwner =
      "v1/protected/property/festives/owner/";
  static const String propertyFunerairesByOwner =
      "v1/protected/property/funeraires/owner/";

  // Property Feature Endpoints
  static const String features = "features";
  static const String featureDetail = "features/";
  static const String featureProperties = "features/";
  static const String storeFeature = "features";
  static const String updateFeature = "features/";
  static const String deleteFeature = "features/";

  // Property Type Endpoints
  static const String propertyTypesList = "v1/public/property/types";
  static const String propertyTypes = "property";
  static const String propertyTypeDetail = "property/";
  static const String propertiesByType = "propertyType/";
  static const String storePropertyType = "propertyType";
  static const String updatePropertyType = "propertyType/";
  static const String deletePropertyType = "propertyType/";

  // Property favorites Endpoints
  static const String allFavories = "v1/protected/favorite";
  static const String AddFavorite = "v1/private/favorite";
  static const String getMyfavorites = "v1/protected/favorite/user/";
  static const String removeMyfavorites = "v1/protected/favorite/user/delete/";

  // Specific Favorites
  static const String favoriteHotel = "v1/private/hotel/favorite";
  static const String favoriteFestive = "v1/private/festive/favorite";
  static const String favoriteVacance = "v1/private/vacance/favorite";
  static const String favoritePrestation = "v1/private/prestation/favorite";
  static const String favoriteFuneraire = "v1/private/funeraire/favorite";
  static const String favoriteTerrain = "v1/private/terrain/favorite";

  // Favorites by User
  static const String favoriteHotelByUser = "v1/protected/hotel/favorite/user/";
  static const String favoriteFestiveByUser = "v1/protected/festive/favorite/user/";
  static const String favoriteVacanceByUser = "v1/protected/vacance/favorite/user/";
  static const String favoritePrestationByUser = "v1/protected/prestation/favorite/user/";
  static const String favoriteFuneraireByUser = "v1/protected/funeraire/favorite/user/";
  static const String favoriteTerrainByUser = "v1/protected/terrain/favorite/user/";

  // Reservations
  static const String allReservations = "v1/protected/reservations";
  static const String addReservations = "v1/private/reservations";
  static const String addReservationVacance = "v1/private/reservations/vacance";
  static const String addReservationTerrain = "v1/private/reservations/terrain";
  static const String addReservationFuneraire = "v1/private/reservations/funeraire";
  static const String addReservationFestive = "v1/private/reservations/festive";
  static const String addReservationBureau = "v1/private/reservations/bureau";
  static const String addReservationHotel = "v1/private/reservations/chambre";
  static const String validateReservationNotification =
      "v1/protected/reservations/notification/state/";

  static const String reservationsVacanceByUser =
      "v1/protected/reservations/vacance/user/";
  static const String reservationsTerrainByUser =
      "v1/protected/reservations/terrain/user/";
  static const String reservationsFuneraireByUser =
      "v1/protected/reservations/funeraire/user/";
  static const String reservationsFestiveByUser =
      "v1/protected/reservations/festive/user/";
  static const String reservationsBureauByUser =
      "v1/protected/reservations/bureau/user/";
  static const String reservationsHotelByUser =
      "v1/protected/reservations/chambre/user/";

  static const String reservationsHost = "v1/protected/reservations/user/host/";
  static const String reservationsVacanceByHost =
      "v1/protected/reservations/vacance/user/host/";
  static const String reservationsTerrainByHost =
      "v1/protected/reservations/terrain/user/host/";
  static const String reservationsFuneraireByHost =
      "v1/protected/reservations/funeraire/user/host/";
  static const String reservationsFestiveByHost =
      "v1/protected/reservations/festive/user/host/";
  static const String reservationsBureauByHost =
      "v1/protected/reservations/bureau/user/host/";
  static const String reservationsHotelByHost =
      "v1/protected/reservations/chambre/user/host/";

  // Search
  static const String propertyFilter = "v1/public/property/filter";
  static const String propertySearch = "roperty/search";

  // Prestations
  static const String prestations = "v1/public/prestations";
  static const String prestationsByServiceId = "v1/public/prestations/service/";
  static const String prestationsByOwner = "v1/protected/prestations/owner/";
  static const String deletePrestation = "prestations/";

  // Service Endpoints
  static const String services = "v1/public/services";
  static const String serviceDetail = "services/";
  static const String storeService = "services";
  static const String updateService = "services/";
  static const String deleteService = "services/";
  static const String servicesByType = "services/type/";
  static const String myServices = "services/my";

  static const String serviceRequests = "service-requests";
  static const String createServiceRequest = "service-requests";
  static const String getServiceRequests = "service-requests/user";
  static const String getServiceRequestsForProviders = "service-requests/for-providers";
  static const String serviceRequestDetail = "service-requests/";
  static const String respondToRequest = "service-requests";
  static const String acceptResponse = "service-requests";
  static const String cancelRequest = "service-requests";

  // Sollicitation
  static const String sollicitation = "v1/private/sollicitation";
  static const String sollicitationsByUser = "v1/protected/sollicitation/user/";
  static const String sollicitationsByHost =
      "v1/protected/sollicitation/user/host/";

  static const String updateSollicitation =
      "v1/protected/sollicitation/update/status/";

  // Cards & Agencies
  static const String cards = "v1/public/cards";
  static const String agences = "v1/public/agences";
  static const String agencesByOwner = "v1/protected/agences/owner/";
  static const String devises = "v1/public/devises";
}
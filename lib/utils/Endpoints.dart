class Endpoints {
  static const String version = "v1";

  // ntication Endpoints
  static const String register = "$version/public/members";

  static const String allUsers = "users";
  static const String login = "login";
  static const String refreshToken = "$version/protected/token/refresh";
  static const String forgotPassword = "forgot-password";
  static const String resetPassword = "$version/protected/reset/password";
  static const String updateProfilePicture = "$version/protected/members";
  static const String protectedMembers = "$version/protected/members";


  // OTP Endpoints
  static const String otpGenerate = "$version/public/otp/generate";
  static const String otpVerify = "$version/public/otp/verify";
  static const String resetPasswordEndpoint = "$version/protected/reset/password";
  static const String profile = "profile";
  static const String reservations = "$version/private/reservations";
  static const String reservationsByUser = "user";

  static const String updateProfile = "profile";
  static const String logout = "logout";
  static const String changePassword = "$version/protected/change/password";
  static const String deleteAccount = "delete/user";
  static const String accounts = "$version/public/accounts";
  static const String accountTypes = "$version/public/accounts/type";

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

  // Countries Endpoints
  static const String countries = "$version/public/countries";

  // location Endpoints
  static const String cities = "$version/public/cities"; // No specific update requested for cities, keeping as is
  static const String communes = "$version/public/communes";
  static const String districts = "$version/public/districts";
  static const String quartiers = "$version/public/quartiers";

  // Property Endpoints
  static const String properties = "$version/public/property";
  static const String propertyDetail = "properties/";
  static const String storeProperty = "$version/private/property";
  static const String updateProperty = "properties/";
  static const String deleteProperty = "properties/";
  static const String propertiesByOwner = "$version/private/property/owner";
  static const String propertyBureaux = "$version/private/property/bureaux";
  static const String propertyBureau = "property/bureau";
  static const String propertyFestives = "$version/private/property/festives";
  static const String propertyFuneraires = "$version/private/property/funeraires";
  static const String propertyVacances = "$version/private/property/vacances";
  static const String propertyTerrains = "$version/private/property/terrains";
  static const String propertyHotels = "$version/private/property/hotels";
  static const String propertyHotelsByOwner = "$version/private/property/hotels/owner";
  static const String propertyHotelRoom = "$version/private/property/hotels/chambre";

  // Property Management Endpoints
  static const String enableProperty = "$version/protected/property/enable/"; // {propertyId}
  static const String soldProperty = "$version/protected/property/sold/"; // {propertyId}
  static const String updatePropertyOwner = "$version/protected/property/owner/"; // {userId}/{propertyId}

  // Property Image Management
  static const String updatePropertyImage = "$version/protected/property/image/"; // {propertyId}
  static const String deletePropertyImage = "$version/protected/property/image/"; // {propertyId}

  // Terrains Management
  static const String soldTerrain = "$version/protected/property/terrains/sold/"; // {propertyId}
  static const String updateTerrainOwner = "$version/protected/property/terrains/owner/"; // {terrainId}
  static const String enableTerrain = "$version/protected/property/terrains/enable/"; // {propertyId}

  // Bureaux Management
  static const String soldBureau = "$version/protected/property/bureaux/sold/"; // {propertyId}
  static const String updateBureauOwner = "$version/protected/property/bureaux/owner/"; // {bureauId}
  static const String updateBureauImage = "$version/protected/property/bureaux/image/"; // {bureauId}
  static const String deleteBureauImage = "$version/protected/property/bureaux/image/"; // {bureauId}
  static const String enableBureau = "$version/protected/property/bureaux/enable/"; // {propertyId}

  // Salles Festives Management
  static const String soldFestive = "$version/protected/property/festives/sold/"; // {propertyId}
  static const String updateFestiveOwner = "$version/protected/property/festives/owner/"; // {festiveId}
  static const String updateFestiveImage = "$version/protected/property/festives/image/"; // {festiveId}
  static const String deleteFestiveImage = "$version/protected/property/festives/image/"; // {festiveId}
  static const String enableFestive = "$version/protected/property/festives/enable/"; // {propertyId}

  // Funéraires Management
  static const String soldFuneraire = "$version/protected/property/funeraires/sold/"; // {propertyId}
  static const String updateFuneraireOwner = "$version/protected/property/funeraires/owner/"; // {funeraireId}
  static const String updateFuneraireImage = "$version/protected/property/funeraires/image/"; // {funeraireId}
  static const String deleteFuneraireImage = "$version/protected/property/funeraires/image/"; // {funeraireId}
  static const String enableFuneraire = "$version/protected/property/funeraires/enable/"; // {propertyId}

  // Specialized properties by owner
  static const String propertyBureauxByOwner = "property/bureaux/owner/";
  static const String propertyFestivesByOwner = "property/festives/owner/";
  static const String propertyFunerairesByOwner = "property/funeraires/owner/";

  // Property Feature Endpoints
  static const String features = "$version/private/property/features";
  static const String featureDetail = "features/";
  static const String featureProperties = "features/";
  static const String storeFeature = "features";
  static const String updateFeature = "features/";
  static const String deleteFeature = "features/";

  // Property Type Endpoints
  static const String propertyTypesList = "$version/public/property/types";
  static const String propertyTypes = "property";
  static const String propertyTypeDetail = "property/";
  static const String propertiesByType = "propertyType/";
  static const String storePropertyType = "propertyType";
  static const String updatePropertyType = "propertyType/";
  static const String deletePropertyType = "propertyType/";

  // Property favorites Endpoints (standard)
  static const String allFavories = "$version/protected/favorite";
  static const String AddFavorite = "$version/private/favorite";
  static const String getMyfavorites = "$version/protected/favorite/user";
  static const String removeMyfavorites = "$version/protected/favorite/delete";
  static const String removeAllFavories = "$version/protected/favorite/delete/all";
  static const String favoriteProperty = "$version/protected/favorite/property";
  static const String favoritesUserDelete = "$version/protected/favorite/user/delete";

  // Hotel Favorites
  static const String favoriteHotel = "$version/protected/hotel/favorite";
  static const String favoriteHotelDelete = "$version/protected/hotel/favorite/delete";
  static const String favoriteHotelDeleteAll = "$version/protected/hotel/favorite/delete/all";
  static const String favoriteHotelByUser = "$version/protected/hotel/favorite/user";
  static const String favoriteHotelUserDelete = "$version/protected/hotel/favorite/user/delete";

  // Festive Favorites
  static const String favoriteFestive = "$version/protected/festive/favorite";
  static const String favoriteFestiveDelete = "$version/protected/festive/favorite/delete";
  static const String favoriteFestiveDeleteAll = "$version/protected/festive/favorite/delete/all";
  static const String favoriteFestiveByUser = "$version/protected/festive/favorite/user";
  static const String favoriteFestiveUserDelete = "$version/protected/festive/favorite/user/delete";

  // Vacance Favorites
  static const String favoriteVacance = "$version/private/vacance/favorite";
  static const String favoriteVacanceByUser = "vacance/favorite/user";
  static const String favoriteVacanceDelete = "vacance/favorite/delete";

  // Funeraire Favorites
  static const String favoriteFuneraire = "$version/protected/funeraire/favorite";
  static const String favoriteFuneraireDelete = "$version/protected/funeraire/favorite/delete";
  static const String favoriteFuneraireDeleteAll = "$version/protected/funeraire/favorite/delete/all";
  static const String favoriteFuneraireByUser = "$version/protected/funeraire/favorite/user";
  static const String favoriteFuneraireUserDelete = "$version/protected/funeraire/favorite/user/delete";

  // Bureau Favorites
  static const String favoriteBureau = "$version/protected/bureau/favorite";
  static const String favoriteBureauDelete = "$version/protected/bureau/favorite/delete";
  static const String favoriteBureauDeleteAll = "$version/protected/bureau/favorite/delete/all";
  static const String favoriteBureauByUser = "$version/protected/bureau/favorite/user";
  static const String favoriteBureauUserDelete = "$version/protected/bureau/favorite/user/delete";

  // Terrain Favorites (keeping as-is, no route provided)
  static const String favoriteTerrain = "$version/private/terrain/favorite";
  static const String favoriteTerrainByUser = "terrain/favorite/user";
  static const String favoriteTerrainDelete = "terrain/favorite/delete";

  // Prestation Favorites
  static const String favoritePrestation = "$version/protected/prestation/favorite";
    static const String AddfavoritePrestation = "$version/private/prestation/favorite";
  static const String favoritePrestationByPrestation = "$version/protected/prestation/favorite/prestation";
  static const String favoritePrestationDeleteAll = "$version/protected/prestation/favorite/delete/all";
  static const String favoritePrestationByUser = "$version/protected/prestation/favorite/user";
  static const String favoritePrestationDelete = "$version/protected/prestation/favorite"; // + /{id}

  // Visit/Reservations Endpoints
  static const String allReservations = "$version/private/reservations/";
  static const String addReservations = "$version/private/reservations";
  static const String addReservationVacance = "$version/private/reservations/vacance";
  static const String addReservationTerrain = "$version/private/reservations/terrain";
  static const String addReservationFuneraire = "$version/private/reservations/funeraire";
  static const String addReservationFestive = "$version/private/reservations/festive";
  static const String addReservationRoom = "$version/private/reservations/chambre";
  static const String addReservationBureau = "$version/private/reservations/bureau";
  static const String addReservationHotel = "$version/private/reservations/hotel"; // Still keeping original if needed, but updated version preferred

  // Reservations Status Management
  static const String updateReservationStatus = "$version/protected/reservations/update/status/"; // {id}
  static const String updateReservationVacanceStatus = "$version/protected/reservations/vacance/update/status/"; // {id}
  static const String updateReservationTerrainStatus = "$version/protected/reservations/terrain/update/status/"; // {id}
  static const String updateReservationFuneraireStatus = "$version/protected/reservations/funeraire/update/status/"; // {id}
  static const String updateReservationFestiveStatus = "$version/protected/reservations/festive/update/status/"; // {id}
  static const String updateReservationRoomStatus = "$version/protected/reservations/chambre/update/status/"; // {id}
  static const String updateReservationBureauStatus = "$version/protected/reservations/bureau/update/status/"; // {id}

  // Reservation Notifications
  static const String validateReservationNotification = "$version/protected/reservations/notification/state/"; // {reservationId}/{state}
  static const String partnersReservationNotification = "$version/protected/reservations/notification/partners/"; // {reservationId}
  static const String cancelReservationNotification = "$version/protected/reservations/notification/cancel/"; // {reservationId}

  // Get specialized reservations by user
  static const String reservationsVacanceByUser = "$version/private/reservations/vacance/user/";
  static const String reservationsTerrainByUser = "$version/private/reservations/terrain/user/";
  static const String reservationsFuneraireByUser = "$version/private/reservations/funeraire/user/";
  static const String reservationsFestiveByUser = "$version/private/reservations/festive/user/";
  static const String reservationsBureauByUser = "$version/private/reservations/bureau/user/";
  static const String reservationsHotelByUser = "$version/private/reservations/hotel/user/";

  // Get specialized reservations by host (property owner)
  static const String reservationsHost = "$version/private/reservations/host/";
  static const String reservationsVacanceByHost = "$version/private/reservations/vacance/host/";
  static const String reservationsTerrainByHost = "$version/private/reservations/terrain/host/";
  static const String reservationsFuneraireByHost = "$version/private/reservations/funeraire/host/";
  static const String reservationsFestiveByHost = "$version/private/reservations/festive/host/";
  static const String reservationsBureauByHost = "$version/private/reservations/bureau/host/";
  static const String reservationsHotelByHost = "$version/private/reservations/hotel/host/";

  // Search Endpoints
  static const String propertyFilter = "property/filter";
  static const String propertySearch = "property/search";

  // Service Endpoints
  static const String services = "services";
  static const String serviceDetail = "services/";
  static const String storeService = "services";
  static const String updateService = "services/";
  static const String deleteService = "services/";
  static const String servicesByType = "services/type/";
  static const String myServices = "services/my";

  // Prestation Endpoints
  static const String prestations = "$version/private/prestations";
  static const String publicPrestations = "$version/public/prestations";
  static const String prestationsByServiceId = "prestations/service/";
  static const String prestationsByOwner = "$version/protected/prestations/owner";
  static const String deletePrestation = "prestations/";

  // Cotation Endpoints
  static const String cotation = "$version/private/cotation";
  static const String deleteCotation = "$version/protected/cotation/delete";

  // Service Requests Endpoints
  static const String serviceRequests = "service-requests";
  static const String createServiceRequest = "service-requests";
  static const String getServiceRequests = "service-requests/user"; // Pour le demandeur
  static const String getServiceRequestsForProviders = "service-requests/for-providers"; // Pour les prestataires
  static const String serviceRequestDetail = "service-requests/";
  static const String respondToRequest = "service-requests"; // POST avec requestId dans le body
  static const String acceptResponse = "service-requests"; // PUT avec requestId et responseId
  static const String cancelRequest = "service-requests"; // DELETE avec requestId

  static const String sollicitation = "$version/private/sollicitation"; // For creating service solicitations
  static const String sollicitationsByUser = "sollicitation/user/";
  static const String sollicitationsByHost = "$version/protected/sollicitation/user/host"; // For service providers
  static const String updateSollicitation = "$version/protected/sollicitation/update/status/"; // PATCH /{id} with status

  // Notifications Endpoints
  static const String notifications = "$version/private/notifications";
  static const String notificationsOwner = "$version/protected/notifications/owner";
  static const String markNotificationRead = "notifications/"; // PUT avec id
  static const String markAllNotificationsRead = "notifications/read-all";
  static const String deleteNotification = "notifications/"; // DELETE avec id

  // Card Types Endpoint
  static const String cards = "$version/public/cards";

  // Agency Endpoints
  static const String agences = "$version/private/agences";
  static const String agencesByOwner = "agences/owner/";
  static const String protectedAgencesByOwner = "$version/protected/agences/owner";

  static const String devises = "$version/public/devises";

  // Publicités Endpoints
  static const String advertising = "$version/protected/pub";
  static const String updateActiveAds = "$version/protected/pub/update/active/"; // {id}

  // WebSocket Endpoint
  static const String webSocket = "websocket";

}

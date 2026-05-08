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
  /// Détail membre connecté / refresh profil — `GET .../protected/users/{userId}`.
  static const String protectedUsers = "$version/protected/users";


  // OTP Endpoints
  static const String otpGenerate = "$version/public/otp/generate";
  static const String otpVerify = "$version/public/otp/verify";
  static const String resetPasswordEndpoint = "$version/protected/reset/password";
  /// Alias explicite pour le flux OTP + PUT (même chemin que [resetPasswordEndpoint]).
  static const String resetPasswordProtected = "$version/protected/reset/password";
  static const String profile = "profile";
  /// Écritures réservation (statut, annulation, etc.) — **private** (création et mutations côté private).
  static const String reservations = "$version/private/reservations";
  /// Lectures (listes, détail) — **protected** sur l’API migration.
  static const String reservationsProtected = "$version/protected/reservations";
  static const String reservationsByUser = "user";

  static const String updateProfile = "profile";
  static const String logout = "logout";
  static const String changePassword = "$version/protected/change/password";
  // Suppression du compte (API migration). Constantes.BASE_URL ajoute déjà `/api/`.
  static const String deleteAccount = "$version/protected/users/delete/user";
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
  /// Compte API `coiffure` (remplace l’ancien segment carreleurs).
  static const String carreleurs = "coiffure";
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
  static const String propertiesByOwner = "$version/private/property/owner/";
  static const String propertyBureaux = "$version/public/property/bureaux";
  static const String propertyBureau = "property/bureau";
  static const String propertyFestives = "$version/public/property/festives";
  static const String propertyFuneraires = "$version/public/property/funeraires";
  static const String propertyVacances = "$version/public/property/vacances";
  static const String propertyTerrains = "$version/public/property/terrains";
  static const String propertyHotels = "$version/private/property/hotels";
  /// Liste publique (catalogue / visiteurs) — même forme `{ data | hotels }` que le private.
  static const String propertyHotelsPublic = "$version/public/property/hotels";
  static const String propertyHotelsByOwner = "$version/private/property/hotels/owner/";
  static const String propertyHotelRoom = "$version/private/property/hotels/chambre";
  /// Liste publique des chambres (filtrer côté client par hôtel si besoin).
  static const String propertyHotelRoomsPublic = "$version/public/property/hotels/chambre";
  /// POST réservation chambre : `…/chambre/{c hambreId}` (corps : userId, chambreId, dates, message, type, reservationHeure).
  static const String publicPropertyHotelChambreReservation = "$version/public/property/hotels/chambre";

  // Creation Endpoints (Private POST)
  static const String storeTerrain = "$version/private/property/terrains";
  static const String storeBureau = "$version/private/property/bureaux";
  static const String storeFestive = "$version/private/property/festives";
  static const String storeFuneraire = "$version/private/property/funeraires";
  static const String storeVacance = "$version/private/property/vacances";
  static const String soldVacance = "$version/protected/property/vacances/sold/"; // {vacanceId}
  /// Sold/indisponible pour une vacance (nouvel endpoint direct, sans `property/`).
  /// URL attendue: `/api/{version}/protected/vacances/sold/{vacanceId}`.
  static const String soldVacanceDirect = "$version/protected/vacances/sold/"; // {vacanceId}
  static const String updateVacanceOwner = "$version/protected/property/vacances/owner/"; // {vacanceId}
  static const String storeAgence = "$version/private/agences";

  // Property Management Endpoints
  static const String enableProperty = "$version/protected/property/enable/"; // {propertyId}
  static const String soldProperty = "$version/protected/property/sold/"; // {propertyId}
  /// Sold/indisponible pour un hôtel.
  /// URL attendue: `/api/{version}/protected/property/hotels/sold/{hotelId}`.
  static const String soldHotel = "$version/protected/property/hotels/sold/"; // {hotelId}
  /// Sold/indisponible pour une chambre (chambreId).
  /// URL attendue: `/api/{version}/protected/property/chambres/sold/{chambreId}`.
  static const String soldHotelRoom = "$version/protected/property/chambres/sold/"; // {chambreId}
  /// PUT propriété standard : `/owner/{userId}/{propertyId}`
  static const String updatePropertyOwner = "$version/protected/property/owner/"; // {userId}/{propertyId}

  // Property Image Management
  static const String updatePropertyImage = "$version/protected/property/image/"; // {propertyId}
  static const String deletePropertyImage = "$version/protected/property/image/"; // {propertyId}

  // Terrains Management
  static const String soldTerrain = "$version/protected/property/terrains/sold/"; // {propertyId}
  static const String updateTerrainOwner = "$version/protected/property/terrains/owner/"; // {terrainId}
  static const String updateTerrainImage = "$version/protected/property/terrains/image/"; // {terrainId}
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
  static const String propertyBureauxByOwner = "$version/protected/property/bureaux/owner/";
  static const String propertyFestivesByOwner = "$version/protected/property/festives/owner/";
  static const String propertyFunerairesByOwner = "$version/protected/property/funeraires/owner/";
  static const String propertyVacancesByOwner = "$version/protected/property/vacances/owner/";
  static const String propertyTerrainsByOwner = "$version/protected/property/terrains/owner/";

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
  static const String favoriteHotel = "$version/private/hotel/favorite";
  static const String favoriteHotelDelete = "$version/protected/hotel/favorite/delete";
  static const String favoriteHotelDeleteAll = "$version/protected/hotel/favorite/delete/all";
  static const String favoriteHotelByUser = "$version/protected/hotel/favorite/user";
  static const String favoriteHotelUserDelete = "$version/protected/hotel/favorite/user/delete";

  // Festive Favorites
  static const String favoriteFestive = "$version/private/festive/favorite";
  static const String favoriteFestiveDelete = "$version/protected/festive/favorite/delete";
  static const String favoriteFestiveDeleteAll = "$version/protected/festive/favorite/delete/all";
  static const String favoriteFestiveByUser = "$version/protected/festive/favorite/user";
  static const String favoriteFestiveUserDelete = "$version/protected/festive/favorite/user/delete";

  // Vacance Favorites
  static const String favoriteVacance = "$version/private/vacance/favorite";
  static const String favoriteVacanceByUser = "$version/protected/vacance/favorite/user";
  static const String favoriteVacanceDelete = "$version/protected/vacance/favorite/delete";

  // Funeraire Favorites
  static const String favoriteFuneraire = "$version/private/funeraire/favorite";
  static const String favoriteFuneraireDelete = "$version/protected/funeraire/favorite/delete";
  static const String favoriteFuneraireDeleteAll = "$version/protected/funeraire/favorite/delete/all";
  static const String favoriteFuneraireByUser = "$version/protected/funeraire/favorite/user";
  static const String favoriteFuneraireUserDelete = "$version/protected/funeraire/favorite/user/delete";

  // Bureau Favorites

  static const String favoriteBureau = "$version/private/bureau/favorite";
  static const String favoriteBureauDelete = "$version/protected/bureau/favorite/delete";
  static const String favoriteBureauDeleteAll = "$version/protected/bureau/favorite/delete/all";
  static const String favoriteBureauByUser = "$version/protected/bureau/favorite/user";
  static const String favoriteBureauUserDelete = "$version/protected/bureau/favorite/user/delete";

  // Terrain Favorites (keeping as-is, no route provided)
  static const String favoriteTerrain = "$version/private/terrain/favorite";
  static const String favoriteTerrainByUser = "$version/protected/terrain/favorite/user";
  static const String favoriteTerrainDelete = "$version/protected/terrain/favorite/delete";

  // Prestation Favorites
  static const String favoritePrestation = "$version/protected/prestation/favorite";
  static const String AddfavoritePrestation = "$version/private/prestation/favorite";
  static const String favoritePrestationByPrestation = "$version/protected/prestation/favorite/prestation";
  static const String favoritePrestationDeleteAll = "$version/protected/prestation/favorite/delete/all";
  static const String favoritePrestationByUser = "$version/protected/prestation/favorite/user";
  static const String favoritePrestationDelete = "$version/protected/prestation/favorite"; // + /{id}

  // Visit/Reservations — création / POST = **private** ; listes / GET = voir [reservationsProtected] et variantes ci‑dessous
  static const String allReservations = reservationsProtected;
  static const String addReservations = "$version/private/reservations";
  static const String createReservation = "$version/private/reservations";
  static const String addReservationVacance = "$version/private/reservations/vacance";
  static const String addReservationTerrain = "$version/private/reservations/terrain";
  static const String addReservationFuneraire = "$version/private/reservations/funeraire";
  static const String addReservationFestive = "$version/private/reservations/festive";
  static const String addReservationRoom = "$version/private/reservations/chambre";
  static const String addReservationBureau = "$version/private/reservations/bureau";
  /// Alias hôtel → même POST que [addReservationRoom] (**chambre**, private).
  static const String addReservationHotel = addReservationRoom;

  // Reservations Status Management (private)
  static const String updateReservationStatus = "$version/private/reservations/update/status/"; // {id}
  static const String updateReservationVacanceStatus = "$version/private/reservations/vacance/update/status/"; // {id}
  static const String updateReservationTerrainStatus = "$version/private/reservations/terrain/update/status/"; // {id}
  static const String updateReservationFuneraireStatus = "$version/private/reservations/funeraire/update/status/"; // {id}
  static const String updateReservationFestiveStatus = "$version/private/reservations/festive/update/status/"; // {id}
  static const String updateReservationRoomStatus = "$version/private/reservations/chambre/update/status/"; // {id}
  static const String updateReservationBureauStatus = "$version/private/reservations/bureau/update/status/"; // {id}

  /// Mise à jour statut réservations — **protected** (PUT `{ status, reason, userId }` ; annulation = `CANCELLED`).
  static const String updateReservationTerrainStatusProtected =
      "$version/protected/reservations/terrain/update/status/";
  static const String updateReservationFestiveStatusProtected =
      "$version/protected/reservations/festive/update/status/";
  static const String updateReservationFuneraireStatusProtected =
      "$version/protected/reservations/funeraire/update/status/";
  static const String updateReservationVacanceStatusProtected =
      "$version/protected/reservations/vacance/update/status/";
  static const String updateReservationChambreStatusProtected =
      "$version/protected/reservations/chambre/update/status/";
  static const String updateReservationBureauStatusProtected =
      "$version/protected/reservations/bureau/update/status/";

  /// Réservation « classique » (bien standard) — PUT `{ status, reason, userId }`.
  static const String updateReservationStandardStatusProtected =
      "$version/protected/reservations/update/status/";

  /// Sollicitation — **protected** (PUT `{ userId, status }` ; annulation = `CANCELLED`).
  static const String updateSollicitationStatusProtected =
      "$version/protected/sollicitation/update/status/";

  // Reservation Notifications — validation exposée en **protected** sur migration ; le reste en private
  static const String validateReservationNotification = "$version/protected/reservations/notification/state/"; // {reservationId}/{state}
  static const String partnersReservationNotification = "$version/private/reservations/notification/partners/"; // {reservationId}
  static const String cancelReservationNotification = "$version/private/reservations/notification/cancel/"; // {reservationId}

  /// Sollicitation — notifier l’autre partie (WebSocket / push), même schéma que les réservations.
  /// À implémenter côté API si absent : `PUT` corps vide, Bearer = l’utilisateur qui vient de changer le statut.
  static const String sollicitationNotificationState =
      "$version/protected/sollicitation/notification/state/"; // {sollicitationId}/{true|false}
  static const String sollicitationNotificationCancel =
      "$version/private/sollicitation/notification/cancel/"; // {sollicitationId}

  // Get specialized reservations by user (protected)
  static const String reservationsVacanceByUser = "$version/protected/reservations/vacance/user/";
  static const String reservationsTerrainByUser = "$version/protected/reservations/terrain/user/";
  static const String reservationsFuneraireByUser = "$version/protected/reservations/funeraire/user/";
  static const String reservationsFestiveByUser = "$version/protected/reservations/festive/user/";
  static const String reservationsBureauByUser = "$version/protected/reservations/bureau/user/";
  static const String reservationsChambreByUser = "$version/protected/reservations/chambre/user/";

  // Get specialized reservations by host (property owner) (protected)
  static const String reservationsHost = "$version/protected/reservations/user/host/";
  static const String reservationsVacanceByHost = "$version/protected/reservations/vacance/user/host/";
  static const String reservationsTerrainByHost = "$version/protected/reservations/terrain/user/host/";
  static const String reservationsFuneraireByHost = "$version/protected/reservations/funeraire/user/host/";
  static const String reservationsFestiveByHost = "$version/protected/reservations/festive/user/host/";
  static const String reservationsBureauByHost = "$version/protected/reservations/bureau/user/host/";
  static const String reservationsChambreByHost = "$version/protected/reservations/chambre/user/host/";
  /// Réservations liées à une chambre — `GET …/chambre/chambre/{chambreId}` (Bearer).
  static const String reservationsChambreByChambreEntity =
      "$version/protected/reservations/chambre/chambre/";

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
  static const String prestationsByOwner = "$version/protected/prestations/owner/";
  static const String deletePrestation = "prestations/";
  static const String updatePrestation = "$version/private/prestations/update/";

  // Cotation Endpoints
  static const String cotation = "$version/private/cotation";
  static const String cotationPublic = "$version/public/cotation";
  /// Liste publique des utilisateurs (noms / userId) — ex. suggestions parrain.
  static const String publicUsers = "$version/public/users";
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
  static const String sollicitationsByUser = "$version/protected/sollicitation/user/";
  static const String sollicitationsByHost = "$version/protected/sollicitation/user/host/"; // For service providers
  static const String updateSollicitation = "$version/private/sollicitation/update/status/"; // legacy private

  // Notifications Endpoints
  static const String notifications = "$version/private/notifications";
  static const String notificationsOwner = "$version/protected/notifications/owner";
  static const String markNotificationRead = "notifications/"; // PUT avec id
  static const String markAllNotificationsRead = "notifications/read-all";
  static const String deleteNotification = "notifications/"; // DELETE avec id

  // Card Types Endpoint
  static const String cards = "$version/public/cards";
  static const String paymentSubscription = "$version/protected/payment/subscription";
  /// POST `{ deviseId }` → JSON avec `url` (checkout HTTPS hébergé).
  static const String paymentCard = "$version/protected/payment/card";
  static const String paymentHistory = "$version/protected/payment/owner/";

  // Agency Endpoints
  static const String agences = "$version/public/agences";
  static const String agencesByOwner = "$version/protected/agences/owner/";
  static const String protectedAgencesByOwner = "$version/protected/agences/owner";

  static const String devises = "$version/public/devises";

  // Publicités Endpoints
  static const String advertising = "$version/protected/pub";
  static const String updateActiveAds = "$version/protected/pub/update/active/"; // {id}

  // WebSocket Endpoint
  static const String webSocket = "websocket";

}

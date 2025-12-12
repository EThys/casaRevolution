// favorite_state.dart

class FavoriteState {
  final Map<String, bool> favoriteStatus; // propertyId -> isFavorite
  final Set<String> loadingProperties; // propertyId en cours de chargement
  final bool isLoading; // Chargement global (pour l'initialisation)
  final String? error;

  FavoriteState({
    required this.favoriteStatus,
    Set<String>? loadingProperties,
    this.isLoading = false,
    this.error,
  }) : loadingProperties = loadingProperties ?? <String>{};

  FavoriteState copyWith({
    Map<String, bool>? favoriteStatus,
    Set<String>? loadingProperties,
    bool? isLoading,
    String? error,
  }) {
    return FavoriteState(
      favoriteStatus: favoriteStatus ?? this.favoriteStatus,
      loadingProperties: loadingProperties ?? this.loadingProperties,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  bool isFavorite(String propertyId) {
    return favoriteStatus[propertyId] ?? false;
  }

  bool isLoadingProperty(String propertyId) {
    return loadingProperties.contains(propertyId);
  }
}
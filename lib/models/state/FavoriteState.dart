// favorite_state.dart

class FavoriteState {
  final Map<String, bool> favoriteStatus; // propertyId -> isFavorite
  final bool isLoading;
  final String? error;

  FavoriteState({
    required this.favoriteStatus,
    this.isLoading = false,
    this.error,
  });

  FavoriteState copyWith({
    Map<String, bool>? favoriteStatus,
    bool? isLoading,
    String? error,
  }) {
    return FavoriteState(
      favoriteStatus: favoriteStatus ?? this.favoriteStatus,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  bool isFavorite(String propertyId) {
    return favoriteStatus[propertyId] ?? false;
  }
}
import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';

import '../models/CotationModel.dart';
import '../utils/Endpoints.dart';
import '../utils/StockageKeys.dart';
import '../utils/requetes.dart';

class CotationController with ChangeNotifier {
  CotationController({this.stockage});

  final GetStorage? stockage;
  bool loading = false;

  // Public cotations cache (GET /public/cotation)
  List<CotationModel> _publicCotations = [];
  List<CotationModel> get publicCotations => _publicCotations;

  static const String _publicCacheKey = 'cached_public_cotations';

  /// POST `/api/v1/private/cotation` (create or update côté backend)
  Future<HttpResponse> upsertCotation({
    required int userId,
    required int sollicitationId,
    required String commentaire,
    required double cote,
  }) async {
    loading = true;
    notifyListeners();
    try {
      final token = stockage?.read<String>(StockageKeys.tokenKey);
      final payload = <String, dynamic>{
        'userId': userId,
        'sollicitationId': sollicitationId,
        'commentaire': commentaire.trim(),
        'cote': cote,
      };
      final response = await postData(
        Endpoints.cotation,
        payload,
        token: token,
        allowDefaultToken: false,
      );
      return response;
    } catch (e) {
      return HttpResponse(
        status: false,
        errorMsg: e.toString(),
        isException: true,
      );
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Backward compat: old name used by UI.
  Future<HttpResponse> createCotation({
    required int userId,
    required int sollicitationId,
    required String commentaire,
    required double cote,
  }) {
    return upsertCotation(
      userId: userId,
      sollicitationId: sollicitationId,
      commentaire: commentaire,
      cote: cote,
    );
  }

  /// Load cotations list (public). Cached in GetStorage for instant UI.
  Future<List<CotationModel>> fetchPublicCotations({bool forceRefresh = false}) async {
    if (!forceRefresh && _publicCotations.isEmpty) {
      _loadPublicFromCache();
    }
    try {
      final responseData = await getData(Endpoints.cotationPublic, token: "");
      if (responseData == null) return _publicCotations;

      final List<dynamic> raw = (responseData is Map)
          ? (responseData['cotation'] ?? responseData['cotations'] ?? [])
          : (responseData as List);

      final parsed = raw
          .whereType<Map>()
          .map((e) => CotationModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      _publicCotations = parsed;
      _savePublicToCache();
      notifyListeners();
      return _publicCotations;
    } catch (_) {
      return _publicCotations;
    }
  }

  List<CotationModel> cotationsForSollicitation(int sollicitationId) {
    final list = _publicCotations.where((c) => c.sollicitationId == sollicitationId).toList();
    list.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
    return list;
  }

  /// Avis publics dont `prestationId` correspond (si renvoyé par l’API).
  List<CotationModel> cotationsForPrestation(int prestationId) {
    final list = _publicCotations
        .where((c) => c.prestationId != null && c.prestationId == prestationId)
        .toList();
    list.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
    return list;
  }

  /// Filtre les avis publics par `sollicitationId` (ex. écran lié à une sollicitation précise).
  /// La liste principale par prestation utilise [cotationsForPrestation].
  List<CotationModel> cotationsForSollicitations(Set<int> sollicitationIds) {
    if (sollicitationIds.isEmpty) return [];
    final list = _publicCotations
        .where((c) => c.sollicitationId != null && sollicitationIds.contains(c.sollicitationId))
        .toList();
    list.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
    return list;
  }

  void _loadPublicFromCache() {
    try {
      final cached = stockage?.read(_publicCacheKey);
      if (cached is List) {
        _publicCotations = cached
            .whereType<Map>()
            .map((e) => CotationModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
  }

  void _savePublicToCache() {
    try {
      final data = _publicCotations
          .map((c) => {
                'id': c.id,
                'userId': c.userId,
                'sollicitationId': c.sollicitationId,
                'prestationId': c.prestationId,
                'commentaire': c.commentaire,
                'cote': c.cote,
                'createdAt': c.createdAt,
                // user optional; public endpoint sample doesn't include user
              })
          .toList();
      stockage?.write(_publicCacheKey, data);
    } catch (_) {}
  }
}

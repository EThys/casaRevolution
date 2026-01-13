import 'package:flutter/material.dart';
import '../models/AgenceModel.dart';
import '../utils/Endpoints.dart';
import '../utils/requetes.dart';
import '../utils/StockageKeys.dart';
import '../utils/AgenceDatabaseHelper.dart';
import 'package:get_storage/get_storage.dart';

class AgenceController extends ChangeNotifier {
  List<AgenceModel> _agences = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<AgenceModel> get agences => _agences;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Create a new agency
  /// [payload] should contain: userId, name, description, phone1, phone2, address, logo (base64)
  Future<HttpResponse> createAgence(Map<String, dynamic> payload) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await postData(
        Endpoints.agences,
        payload,
      );

      _isLoading = false;

      if (response.status == true && response.data != null) {
        // Parse the created agency and add to list
        try {
          final agenceData = response.data['data'] ?? response.data;
          final newAgence = AgenceModel.fromJson(agenceData);
          _agences.insert(0, newAgence);
        } catch (e) {
          print('Error parsing created agency: $e');
        }
      }
      notifyListeners();

      return response;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return HttpResponse(
        status: false,
        errorMsg: 'Erreur lors de la création de l\'agence: $e',
      );
    }
  }

  // --- CACHING ---
  final _storage = GetStorage();
  final String _agencesKey = 'cached_agences_list';

  /// Load agencies from local cache
  void _loadAgencesFromCache() {
      try {
          final cached = _storage.read(_agencesKey);
          if (cached != null && cached is List) {
              _agences = cached.map((json) => AgenceModel.fromJson(json)).toList();
              notifyListeners();
          }
      } catch (e) {
          print('Error loading agencies from cache: $e');
      }
  }

  /// Save agencies to local cache
  void _saveAgencesToCache() {
      try {
          final data = _agences.map((a) => a.toJson()).toList();
          _storage.write(_agencesKey, data);
      } catch (e) {
          print('Error saving agencies to cache: $e');
      }
  }

  /// Fetch all agencies
  Future<void> fetchAgences() async {
    // 1. Load from cache first for immediate display
    if (_agences.isEmpty) {
        _loadAgencesFromCache();
    }
    
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // getData returns the JSON body directly (dynamic) or null
      final responseData = await getData(Endpoints.agences);

      _isLoading = false;

      if (responseData != null) {
        final List<dynamic> data = responseData is List 
            ? responseData 
            : (responseData['data'] ?? []);
            
        _agences = data.map((json) {
            AgenceModel agence;
            List<AgenceSiteModel> sites = [];

            // Handle nested structure {"agence": {...}, "site": [...]}
            if (json is Map && json['agence'] != null) {
                agence = AgenceModel.fromJson(json['agence']);
                // Extract sites if available
                if (json['site'] != null && json['site'] is List) {
                   sites = (json['site'] as List).map((s) => AgenceSiteModel.fromJson(s)).toList();
                }
            } else {
                agence = AgenceModel.fromJson(json);
            }
            
            // Assign sites to agence
            agence.sites = sites;
            return agence;
        }).toList();
        
        // Update cache (GetStorage)
        _saveAgencesToCache();
        
        // Update SQL database for offline access
        try {
          await AgenceDatabaseHelper.instance.insertAgencies(_agences);
          print('✅ [AgenceController] Agencies saved to SQL database');
        } catch (e) {
          print('❌ [AgenceController] Error saving to SQL database: $e');
        }
        
      } else {
        _errorMessage = 'Erreur lors du chargement des agences';
      }

      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      print('Error fetching agencies: $e');
    }
  }

  /// Fetch agencies by user ID with offline fallback
  Future<void> fetchAgencesByUser(int userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Endpoint: /api/agences/owner/{userId}
      final url = '${Endpoints.agences}/owner/$userId';
      print("🔍 [AgenceController] Fetching agencies for user $userId from: $url");
      
      // Get user token from storage (token is stored at root level, not in user object)
      final storage = GetStorage();
      final token = storage.read(StockageKeys.tokenKey) as String?;
      
      if (token == null || token.isEmpty) {
        print("⚠️ [AgenceController] No token found in storage");
        _isLoading = false;
        _agences = [];
        _errorMessage = 'Token non trouvé';
        notifyListeners();
        return;
      }
      
      print("🔑 [AgenceController] Using token: ${token.substring(0, 20)}...");
      
      try {
        final responseData = await getData(url, token: token);
        
        print("📥 [AgenceController] API Response: ${responseData != null ? 'Received' : 'NULL'}");
        if (responseData != null) {
          print("📥 [AgenceController] Response type: ${responseData.runtimeType}");
          print("📥 [AgenceController] Response content: $responseData");
        }

        _isLoading = false;

        if (responseData != null) {
          final List<dynamic> data = responseData is List 
              ? responseData 
              : (responseData['data'] ?? []);
          
          print("✅ [AgenceController] Found ${data.length} agency/agencies for user $userId");
          if (data.isNotEmpty) {
            print("📋 [AgenceController] First agency data: ${data[0]}");
          }
          
          // Parse agencies (flat structure from this endpoint)
          _agences = data.map((json) => AgenceModel.fromJson(json)).toList();
        } else {
          print("⚠️ [AgenceController] No agencies found for user $userId");
          _agences = [];
          _errorMessage = 'Aucune agence trouvée';
        }

        notifyListeners();
      } catch (networkError) {
        // Network error - fallback to SQL database
        print("🔌 [AgenceController] Network error, falling back to SQL database: $networkError");
        
        try {
          _agences = await AgenceDatabaseHelper.instance.getAgenciesByUserId(userId);
          _isLoading = false;
          
          if (_agences.isNotEmpty) {
            print("✅ [AgenceController] Found ${_agences.length} agencies from SQL database");
            _errorMessage = null; // Clear error since we found data locally
          } else {
            print("⚠️ [AgenceController] No agencies in SQL database for user $userId");
            _errorMessage = 'Aucune agence trouvée (mode hors ligne)';
          }
          
          notifyListeners();
        } catch (dbError) {
          print("❌ [AgenceController] SQL database error: $dbError");
          _isLoading = false;
          _errorMessage = 'Erreur de chargement des agences';
          _agences = [];
          notifyListeners();
        }
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      _agences = [];
      notifyListeners();
      print('❌ [AgenceController] Error fetching user agencies: $e');
    }
  }

  /// Clear agencies list
  void clearAgences() {
    _agences = [];
    _errorMessage = null;
    notifyListeners();
  }

  /// Clear local SQL database (call on logout)
  Future<void> clearLocalAgencies() async {
    try {
      await AgenceDatabaseHelper.instance.clearAgencies();
      print('✅ [AgenceController] Local agencies cleared from SQL database');
    } catch (e) {
      print('❌ [AgenceController] Error clearing local agencies: $e');
    }
  }
}

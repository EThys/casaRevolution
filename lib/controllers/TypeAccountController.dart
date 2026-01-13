import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:casa/utils/StockageKeys.dart';
import '../utils/requetes.dart';
import '../utils/Endpoints.dart';

import '../utils/database/AccountTypeDatabaseHelper.dart';
import '../models/TypeAccountModel.dart';

class TypeAccountController with ChangeNotifier {
  List<dynamic> allAccounts = [];
  List<dynamic> clientTypes = [];
  List<dynamic> ownerTypes = [];
  List<dynamic> serviceTypes = [];
  bool loading = false;
  final _box = GetStorage();
  final _dbHelper = AccountTypeDatabaseHelper.instance;

  // Méthode principale appelée par HomePage en arrière-plan
  Future<void> fetchAndCacheAccountTypes() async {
    print("🔄 [TypeAccountController] Démarrage du cache en arrière-plan...");
    try {
      final response = await getData(Endpoints.accounts, token: "");
      
      if (response != null && response is Map<String, dynamic> && response['accounts'] != null) {
        final rawList = response['accounts'] as List;
        allAccounts = rawList;
        
        // Convertir en modèles pour la DB
        List<TypeAccountModel> models = [];
        for (var item in rawList) {
          try {
             if (item is Map<String, dynamic>) {
               // Normalisation des clés si nécessaire (certaines APIs retournent TypeAccountId ou typeAccountId)
               final id = item['typeAccountId'] ?? item['TypeAccountId'] ?? item['id'];
               final name = item['name'] ?? item['Name'] ?? item['libelle'];
               
               if (id != null) {
                  models.add(TypeAccountModel(typeAccountId: int.tryParse(id.toString()), name: name));
               }
             }
          } catch (e) {
            print("Erreur parsing item: $e");
          }
        }

        // Sauvegarder en DB locale
        if (models.isNotEmpty) {
          await _dbHelper.insertAccountTypes(models);
          print("✅ [TypeAccountController] ${models.length} types de comptes mis en cache SQL.");
        }
        
        _populateLists();
        notifyListeners();
      }
    } catch (e) {
      print("❌ [TypeAccountController] Erreur cache background: $e");
    }
  }

  // Méthode appelée par RegisterScreen (lecture locale uniquement)
  Future<void> loadFromLocalDb() async {
    loading = true;
    notifyListeners();
    
    try {
      // 1. Lire depuis SQL
      final types = await _dbHelper.getAllAccountTypes();
      
      if (types.isNotEmpty) {
        // Convertir en format dynamique pour compatibilité existante
        allAccounts = types.map((e) => e.toJson()).toList();
        print("📂 [TypeAccountController] Chargé depuis SQL: ${allAccounts.length}");
        _populateLists();
      } else {
        print("⚠️ [TypeAccountController] SQL vide, fallback sur cache legacy");
        _loadFromLegacyCache();
      }
    } catch (e) {
      print("❌ [TypeAccountController] Erreur lecture SQL: $e");
      _loadFromLegacyCache();
    } finally {
      loading = false;
      notifyListeners();
    }
  }
  
  // Backward compatibility method
  Future<void> fetchTypeAccounts() async {
     // Rediriger vers la méthode locale par défaut pour éviter les appels réseaux superflus
     await loadFromLocalDb();
  }

  // Legacy GetStorage cache (fallback)
  void _loadFromLegacyCache() {
    try {
      final cached = _box.read<List<dynamic>>('cached_account_types');
      if (cached != null && cached.isNotEmpty) {
        allAccounts = cached;
        _populateLists();
        print("✅ [TypeAccountController] Loaded from Legacy Cache");
      }
    } catch (e) {
      print("Erreur lecture cache local: $e");
    }
  }

  void _populateLists() {
    // Adapter le filtrage pour supporter à la fois les Maps brutes (legacy) et les Maps fromJson (SQL)
    clientTypes = allAccounts.where((a) => _isAccountType(a, 1)).toList();
    ownerTypes = allAccounts.where((a) => _isAccountType(a, 2)).toList();
    serviceTypes = allAccounts.where((a) => _isAccountType(a, 3)).toList();
  }

  bool _isAccountType(dynamic account, int typeId) {
    if (account == null || account is! Map) return false;
    
    // Check nested structure
    if (account['typeAccount'] != null && account['typeAccount'] is Map) {
      if (account['typeAccount']['typeAccountId'] == typeId) return true;
    }
    
    // Check flat structure (fallback & SQL)
    final accId = account['typeAccountId'] ?? account['TypeAccountId'];
    if (accId != null && accId.toString() == typeId.toString()) return true;
    
    return false;
  }
}








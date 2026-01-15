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
               
               final categoryId = (item['typeAccount'] != null && item['typeAccount'] is Map)
                   ? (item['typeAccount']['typeAccountId'] ?? item['typeAccount']['TypeAccountId'])
                   : null;

               if (id != null) {
                  models.add(TypeAccountModel(
                    typeAccountId: int.tryParse(id.toString()), 
                    name: name,
                    categoryId: categoryId != null ? int.tryParse(categoryId.toString()) : null
                  ));
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
        allAccounts = types.map((e) {
          var json = e.toJson();
          json['id'] = json['typeAccountId']; // Compatibilité avec RegisterScreen qui attend 'id'
          return json;
        }).toList();
        print("📂 [TypeAccountController] Chargé depuis SQL: ${allAccounts.length} types.");
        if (allAccounts.isNotEmpty) {
           print("DATA SAMPLE: ${allAccounts.first}");
           
           // Check V1 vs V2 data
           bool isV1 = allAccounts.any((a) => a['categoryId'] == null);
           if (isV1) {
             print("⚠️ [TypeAccountController] Données V1 détectées (sans categoryId). Forçage nettoyage SQL.");
             allAccounts = []; // Force refresh
             await _dbHelper.insertAccountTypes([]); // Vide la table via helper (j'ai ajouté delete avant insert dans helper)
           }
        }
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
     // D'abord charger localement
     await loadFromLocalDb();
     
     // Si vide OU si une des listes obligatoires est vide, charger depuis l'API
     if (allAccounts.isEmpty || ownerTypes.isEmpty || serviceTypes.isEmpty) {
       print("⚠️ [TypeAccountController] Données incomplètes (Owners: ${ownerTypes.length}, Services: ${serviceTypes.length})... Force API Refresh.");
       await fetchAndCacheAccountTypes();
     }
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
    
    // 1. Check direct categoryId (from SQL/Model)
    if (account['categoryId'] != null) {
      return account['categoryId'].toString() == typeId.toString();
    }
    
    // 2. Check nested structure (Raw API)
    if (account['typeAccount'] != null && account['typeAccount'] is Map) {
      final nestedId = account['typeAccount']['typeAccountId'] ?? account['typeAccount']['TypeAccountId'];
      if (nestedId != null && nestedId.toString() == typeId.toString()) return true;
    }
    
    // 3. Fallback: try to guess if the ID itself matches (rarely correct for sub-types but kept for legacy)
    final accId = account['typeAccountId'] ?? account['TypeAccountId'];
    if (accId != null && accId.toString() == typeId.toString()) return true;
    
    return false;
  }
}








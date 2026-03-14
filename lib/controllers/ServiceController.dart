import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../models/ServiceModel.dart';
import '../models/PrestationModel.dart';
import '../models/SollicitationModel.dart';
import '../models/DeviseModel.dart';
import '../utils/Endpoints.dart';
import '../utils/StockageKeys.dart';
import '../utils/Constantes.dart';
import '../utils/requetes.dart' show getData, postData, patchData, deleteData, HttpResponse;
import '../utils/database/PrestationDatabaseHelper.dart';

class ServiceController with ChangeNotifier {
  ServiceController({this.stockage});

  GetStorage? stockage;
  bool loading = false;
  int currentPage = 0;
  bool hasMoreData = true;
  List<ServiceModel> services = [];
  ServiceModel? currentService;
  PrestationModel? currentPrestation;
  Map<int, String> serviceIdToNameMap = {};

  // Récupérer le nom du service depuis son ID (ex: 16 -> "Plombier")
  String getServiceName(int? serviceId) {
    if (serviceId == null) return 'Prestation';
    final name = serviceIdToNameMap[serviceId];
    if (name != null && name.trim().isNotEmpty) {
      // Capitalize first letter, rest lowercase
      final cleanName = name.trim().toLowerCase();
      return cleanName[0].toUpperCase() + cleanName.substring(1);
    }
    // Fallback: try to find generic name if map is empty (maybe reload?)
    return 'Prestation';
  }

  // Charger les comptes de service (API accounts)
  Future<void> fetchServiceAccounts() async {
    try {
      final url = Endpoints.accounts; // Ensure this endpoint exists in Endpoints.dart
      // If Endpoints.accounts is not defined, use specific string or define it. 
      // Assuming it maps to /api/accounts or similar as per user request context.
      // Based on user provided JSON, it's likely just 'accounts' if using base URL.
      // Checking HomePage uses Endpoints.accounts.
      
      var response = await getData(url);
      
      if (response != null && response is Map<String, dynamic>) {
        final accounts = response['accounts'] as List<dynamic>?;
        
        if (accounts != null) {
          serviceIdToNameMap.clear();
          for (var acc in accounts) {
            final id = acc['id'];
            final name = acc['name'];
            final typeAccount = acc['typeAccount'];
            // Check typeAccountId (can be nested or flat depending on parsing, user showed nested)
            final typeAccountId = typeAccount is Map ? typeAccount['typeAccountId'] : null;
            
            // Filter: typeAccountId == 3 (Prestataire de service)
            if (id != null && name != null && typeAccountId == 3) {
              serviceIdToNameMap[id] = name.toString();
            }
          }
          print("✅ [ServiceController] Mapping services chargé: ${serviceIdToNameMap.length} entrées");
          notifyListeners();
        }
      }
    } catch (e) {
      print("❌ [ServiceController] Erreur chargement comptes services: $e");
    }
  }

  // Récupérer tous les services
  Future<void> fetchServices() async {
    loading = true;
    notifyListeners();

    try {
      final url = "${Endpoints.services}";
      var response = await getData(url);

      if (response != null && response is Map<String, dynamic>) {
        dynamic servicesData;

        if (response.containsKey('services')) {
          servicesData = response['services'];
        } else if (response.containsKey('data')) {
          servicesData = response['data'];
        } else {
          servicesData = response;
        }

        if (servicesData is List) {
          services = servicesData
              .where((e) => e != null)
              .map<ServiceModel>((e) {
            try {
              return ServiceModel.fromJson(e);
            } catch (e) {
              print("Erreur lors du parsing d'un service: $e");
              return ServiceModel();
            }
          })
              .where((service) => service.serviceId != null)
              .toList();
          
          // Trier par serviceId décroissant (plus récent en premier)
          services.sort((a, b) => (b.serviceId ?? 0).compareTo(a.serviceId ?? 0));
        }
      }
    } catch (e) {
      print("Erreur lors de la récupération des services: $e");
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // Récupérer un service par ID
  Future<ServiceModel?> fetchServiceById(int serviceId) async {
    loading = true;
    notifyListeners();

    try {
      final url = "${Endpoints.serviceDetail}$serviceId";
      var response = await getData(url);

      if (response != null && response is Map<String, dynamic>) {
        currentService = ServiceModel.fromJson(response);
        return currentService;
      }
    } catch (e) {
      print("Erreur lors de la récupération du service: $e");
    } finally {
      loading = false;
      notifyListeners();
    }
    return null;
  }

  Future<PrestationModel?> getPrestationById(int prestationId) async {
    loading = true;
    notifyListeners();

    try {
      final url = "${Endpoints.prestations}/$prestationId";
      var response = await getData(url);

      if (response != null && response is Map<String, dynamic>) {
        // Prestation structure check
        // Check if response is the wrapped object {"prestation": ..., "image": ...}
        PrestationModel? result;
        if (response.containsKey('prestation')) {
           final prestationData = response['prestation'] as Map<String, dynamic>;
           result = PrestationModel.fromJson(prestationData);
           
           if (response.containsKey('image') && response['image'] is List) {
             final images = (response['image'] as List).map((img) {
               if (img is String) return img;
               if (img is Map) return img['path'] ?? img['url'] ?? '';
               return '';
             }).where((path) => path.isNotEmpty).cast<String>().toList();
             result.images = images;
           }
        } else {
           final data = response.containsKey('data') ? response['data'] : response;
           if (data is Map<String, dynamic>) {
              result = PrestationModel.fromJson(data);
           }
        }

        if (result != null) {
          currentPrestation = result;
          notifyListeners();
          return result;
        }
      }
    } catch (e) {
      print("Erreur lors de la récupération de la prestation: $e");
    } finally {
      loading = false;
      notifyListeners();
    }
    return null;
  }

  // Récupérer le type de compte de l'utilisateur connecté
  String? _getUserTypeAccount() {
    print("🔍 [ServiceController] Début _getUserTypeAccount()");
    if (stockage == null) {
      print("❌ [ServiceController] stockage est null");
      return null;
    }
    try {
      final dynamic userData = stockage?.read(StockageKeys.userKey);
      print("📦 [ServiceController] userData récupéré: ${userData != null ? 'non null' : 'null'}");
      if (userData != null && userData is Map) {
        print("📋 [ServiceController] userData est une Map, clés: ${userData.keys.toList()}");
        final typeAccount = userData['typeAccount'];
        print("👤 [ServiceController] typeAccount: ${typeAccount != null ? 'non null' : 'null'}");
        if (typeAccount != null && typeAccount is Map) {
          final typeName = typeAccount['name']?.toString().toLowerCase();
          print("✅ [ServiceController] Type de compte trouvé: $typeName");
          return typeName;
        } else {
          print("⚠️ [ServiceController] typeAccount n'est pas une Map ou est null");
        }
      } else {
        print("⚠️ [ServiceController] userData n'est pas une Map");
      }
    } catch (e, stackTrace) {
      print("❌ [ServiceController] Erreur lors de la récupération du type de compte: $e");
      print("📚 Stack trace: $stackTrace");
    }
    print("❌ [ServiceController] Aucun type de compte trouvé");
    return null;
  }

  // Créer un nouveau service
  Future<HttpResponse> createService(Map<String, dynamic> data, {List<XFile>? images}) async {
    print("🚀 [ServiceController] ========== DÉBUT createService ==========");
    print("📊 [ServiceController] Nombre de clés dans data: ${data.keys.length}");
    print("📋 [ServiceController] Clés dans data: ${data.keys.toList()}");
    
    loading = true;
    notifyListeners();

    try {
      // Récupérer le type de compte de l'utilisateur connecté
      print("🔍 [ServiceController] Récupération du type de compte...");
      final typeAccountName = _getUserTypeAccount();
      
      if (typeAccountName == null || typeAccountName.isEmpty) {
        print("❌ [ServiceController] Type de compte non trouvé ou vide");
        return HttpResponse(
          status: false,
          errorMsg: "Type de compte non trouvé. Veuillez vous reconnecter.",
          isException: true,
        );
      }

      // Construire l'endpoint dynamiquement : {typeAccount}s/service
      // Exemple: peintre -> peintres/service, ajusteur -> ajusteurs/service
      final typeAccountPlural = '${typeAccountName}s';
      final url = "$typeAccountPlural/service";
      
      print("🔗 [ServiceController] Endpoint de création de service: $url");
      print("📋 [ServiceController] Type de compte: $typeAccountName -> $typeAccountPlural");
      
      // Récupérer le token
      print("🔑 [ServiceController] Récupération du token...");
      final token = stockage?.read<String>(StockageKeys.tokenKey);
      if (token != null && token.isNotEmpty) {
        print("✅ [ServiceController] Token trouvé (longueur: ${token.length})");
      } else {
        print("⚠️ [ServiceController] Token non trouvé ou vide");
      }
      
      // Afficher un résumé des données (sans les images en base64 pour ne pas surcharger)
      final dataSummary = Map<String, dynamic>.from(data);
      if (dataSummary.containsKey('images') && dataSummary['images'] is List) {
        final imagesList = dataSummary['images'] as List;
        dataSummary['images'] = '[${imagesList.length} images en base64]';
      }
      if (dataSummary.containsKey('realisation') && dataSummary['realisation'] is List) {
        final realisationsList = dataSummary['realisation'] as List;
        dataSummary['realisation'] = '[${realisationsList.length} réalisations]';
      }
      print("📦 [ServiceController] Données à envoyer (résumé): $dataSummary");
      
      // Si des images sont fournies, vous devrez utiliser FormData
      // Pour l'instant, on envoie juste les données JSON
      print("📡 [ServiceController] Appel à postData avec URL: $url");
      print("⏳ [ServiceController] En attente de la réponse...");
      
      final startTime = DateTime.now();
      HttpResponse response = await postData(url, data, token: token);
      final duration = DateTime.now().difference(startTime);
      
      print("⏱️ [ServiceController] Réponse reçue après ${duration.inMilliseconds}ms");
      print("📥 [ServiceController] Status de la réponse: ${response.status}");
      print("📥 [ServiceController] errorMsg: ${response.errorMsg ?? 'null'}");
      print("📥 [ServiceController] isException: ${response.isException}");
      
      if (response.data != null) {
        print("📥 [ServiceController] Response.data existe");
        if (response.data is Map) {
          final responseData = response.data as Map;
          print("📥 [ServiceController] Response.data clés: ${responseData.keys.toList()}");
          if (responseData.containsKey('message')) {
            print("📥 [ServiceController] Message: ${responseData['message']}");
          }
          if (responseData.containsKey('error')) {
            print("❌ [ServiceController] Erreur dans response.data: ${responseData['error']}");
          }
        } else {
          print("📥 [ServiceController] Response.data type: ${response.data.runtimeType}");
        }
      } else {
        print("⚠️ [ServiceController] Response.data est null");
      }

      if (response.status == true) {
        print("✅ [ServiceController] Service créé avec succès, rechargement de la liste...");
        // Recharger la liste des services
        await fetchServices();
        print("✅ [ServiceController] Liste des services rechargée");
      } else {
        print("❌ [ServiceController] Échec de la création du service");
      }

      print("🏁 [ServiceController] ========== FIN createService ==========");
      return response;
    } catch (e, stackTrace) {
      print("❌ [ServiceController] ========== EXCEPTION dans createService ==========");
      print("❌ [ServiceController] Erreur: $e");
      print("📚 [ServiceController] Stack trace: $stackTrace");
      print("🏁 [ServiceController] ========== FIN createService (avec erreur) ==========");
      return HttpResponse(
        status: false,
        errorMsg: e.toString(),
        isException: true,
      );
    } finally {
      loading = false;
      notifyListeners();
      print("🔄 [ServiceController] loading mis à false, notifyListeners() appelé");
    }
  }

  // Mettre à jour un service
  Future<HttpResponse> updateService(int serviceId, Map<String, dynamic> data) async {
    loading = true;
    notifyListeners();

    try {
      final url = "${Endpoints.updateService}$serviceId";
      HttpResponse response = await patchData(url, data);

      if (response.status == true) {
        await fetchServices();
      }

      return response;
    } catch (e) {
      print("Erreur lors de la mise à jour du service: $e");
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

  // Supprimer un service
  Future<HttpResponse> deleteService(int serviceId) async {
    loading = true;
    notifyListeners();

    try {
      final url = "${Endpoints.deleteService}$serviceId";
      HttpResponse response = await deleteData(url);

      if (response.status == true) {
        services.removeWhere((s) => s.serviceId == serviceId);
      }

      return response;
    } catch (e) {
      print("Erreur lors de la suppression du service: $e");
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

  // Récupérer les services par type
  Future<void> fetchServicesByType(ServiceType type) async {
    loading = true;
    notifyListeners();

    try {
      final url = "${Endpoints.servicesByType}${type.value}";
      var response = await getData(url);

      if (response != null && response is Map<String, dynamic>) {
        dynamic servicesData;

        if (response.containsKey('services')) {
          servicesData = response['services'];
        } else if (response.containsKey('data')) {
          servicesData = response['data'];
        } else {
          servicesData = response;
        }

        if (servicesData is List) {
          services = servicesData
              .where((e) => e != null)
              .map<ServiceModel>((e) {
            try {
              return ServiceModel.fromJson(e);
            } catch (e) {
              print("Erreur lors du parsing d'un service: $e");
              return ServiceModel();
            }
          })
              .where((service) => service.serviceId != null)
              .toList();
        }
      }
    } catch (e) {
      print("Erreur lors de la récupération des services par type: $e");
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // Récupérer les services de l'utilisateur connecté
  Future<void> fetchMyServices() async {
    loading = true;
    notifyListeners();

    try {
      final token = stockage?.read<String>(StockageKeys.tokenKey) ?? '';
      final url = Endpoints.myServices;
      var response = await getData(url, token: token);

      if (response != null && response is Map<String, dynamic>) {
        dynamic servicesData;

        if (response.containsKey('services')) {
          servicesData = response['services'];
        } else if (response.containsKey('data')) {
          servicesData = response['data'];
        } else {
          servicesData = response;
        }

        if (servicesData is List) {
          services = servicesData
              .where((e) => e != null)
              .map<ServiceModel>((e) {
            try {
              return ServiceModel.fromJson(e);
            } catch (e) {
              print("Erreur lors du parsing d'un service: $e");
              return ServiceModel();
            }
          })
              .where((service) => service.serviceId != null)
              .toList();
        }
      }
    } catch (e) {
      print("Erreur lors de la récupération de mes services: $e");
    } finally {
      loading = false;
      notifyListeners();
    }
  }
  // Créer une nouvelle prestation (Nouveau endpoint /api/prestations)
  Future<HttpResponse> createPrestation(Map<String, dynamic> data) async {
    loading = true;
    notifyListeners();

    try {
      final token = stockage?.read<String>(StockageKeys.tokenKey);
      final url = "${Endpoints.prestations}";
      
      HttpResponse response = await postData(url, data, token: token);

      if (response.status == true) {
        await fetchMyServices();
      }

      return response;
    } catch (e) {
      print("Erreur lors de la création de la prestation: $e");
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

  // Liste des prestations
  List<PrestationModel> prestations = [];
  List<SollicitationModel> solicitations = [];
  List<DeviseModel> devisesList = [];
  
  // Récupérer les prestations de l'utilisateur connecté (avec cache SQLite)
  Future<List<PrestationModel>> getMyPrestations() async {
    loading = true;
    notifyListeners();
    
    try {
      final userData = stockage?.read(StockageKeys.userKey);
      String? userId;
      
      if (userData is Map) {
        if (userData.containsKey('user') && userData['user'] is Map && userData['user']?['userId'] != null) {
          userId = userData['user']?['userId']?.toString();
        } else if (userData.containsKey('userId') && userData['userId'] != null) {
          userId = userData['userId']?.toString();
        }
      }
      
      if (userId == null || userId.isEmpty) {
        print("❌ [ServiceController] Aucun user ID trouvé pour récupérer les prestations");
        // Charger depuis le cache local
        final dbHelper = PrestationDatabaseHelper.instance;
        final cachedPrestations = await dbHelper.getAllPrestations();
        loading = false;
        notifyListeners();
        return cachedPrestations;
      }

      print("✅ [ServiceController] UserId récupéré: $userId");
      final dbHelper = PrestationDatabaseHelper.instance;
      
      // D'abord, charger depuis le cache local pour affichage immédiat
      List<PrestationModel> cachedPrestations = await dbHelper.getAllPrestations();
      final userCachedPrestations = cachedPrestations.where((p) => p.userId?.toString() == userId).toList();
      
      // Ensuite, charger depuis l'API et mettre à jour le cache en arrière-plan
      try {
        final url = "${Endpoints.prestationsByOwner}$userId";
        var response = await getData(url);

        if (response != null && response is Map<String, dynamic>) {
          dynamic prestationsData;

          if (response.containsKey('prestations')) {
            prestationsData = response['prestations'];
          } else if (response.containsKey('data')) {
            prestationsData = response['data'];
          } else if (response is List) {
            prestationsData = response;
          }

          if (prestationsData is List) {
            final apiPrestations = prestationsData
                .where((e) => e != null)
                .map<PrestationModel>((e) {
              try {
                Map<String, dynamic> prestationData;
                List<String> images = [];
                
                if (e is Map<String, dynamic> && e.containsKey('prestation')) {
                  prestationData = e['prestation'] as Map<String, dynamic>;
                  // Injecter postBy dans les données de prestation si présent à la racine
                  if (e.containsKey('postBy')) {
                    prestationData['postBy'] = e['postBy'];
                  }
                  if (e.containsKey('image') && e['image'] is List) {
                    images = (e['image'] as List).map((img) {
                      if (img is String) return img;
                      if (img is Map) return img['path'] ?? img['url'] ?? '';
                      return '';
                    }).where((path) => path.isNotEmpty).cast<String>().toList();
                  }
                } else {
                  prestationData = e as Map<String, dynamic>;
                }
                
                final prestation = PrestationModel.fromJson(prestationData);
                prestation.images = images.isNotEmpty ? images : null;
                return prestation;
              } catch (e) {
                print("❌ [ServiceController] Erreur parsing prestation: $e");
                return PrestationModel();
              }
            })
                .where((p) => p.id != null && p.userId?.toString() == userId)
                .toList();

            // Mettre à jour le cache SQLite
            // IMPORTANT: Pour garantir la sync (cas suppression de compte), on vide le cache spécifique avant d'insérer
            // Cependant, deleteByOwnerId n'existe pas, donc on utilise clearAll ou on remplace tout
            // Dans getMyPrestations, on peut filtrer par userId en mémoire et supprimer ceux qui ne sont plus là
            final existing = await dbHelper.getAllPrestations();
            for(var p in existing) {
              if (p.userId?.toString() == userId && !apiPrestations.any((a) => a.id == p.id)) {
                await dbHelper.deletePrestation(p.id!);
              }
            }
            
            await dbHelper.insertOrUpdatePrestations(apiPrestations);
            
            loading = false;
            notifyListeners();
            return apiPrestations;
          }
        }
      } catch (e) {
        print("⚠️ [ServiceController] Erreur API, utilisation du cache: $e");
      }
      
      // Retourner les données du cache si l'API échoue
      loading = false;
      notifyListeners();
      return userCachedPrestations;
    } catch (e) {
      print("❌ [ServiceController] Erreur lors de la récupération des prestations: $e");
      // En cas d'erreur, charger depuis le cache
      final dbHelper = PrestationDatabaseHelper.instance;
      final cachedPrestations = await dbHelper.getAllPrestations();
      final userData = stockage?.read(StockageKeys.userKey);
      String? userId;
      if (userData is Map) {
        if (userData.containsKey('user') && userData['user'] is Map && userData['user']?['userId'] != null) {
          userId = userData['user']?['userId']?.toString();
        }
      }
      final userCachedPrestations = userId != null 
          ? cachedPrestations.where((p) => p.userId?.toString() == userId).toList()
          : <PrestationModel>[];
      loading = false;
      notifyListeners();
      return userCachedPrestations;
    }
  }

  // Récupérer les prestations par serviceId (avec cache SQLite)
  Future<List<PrestationModel>> fetchPrestationsByServiceId(int serviceId) async {
    try {
      final dbHelper = PrestationDatabaseHelper.instance;
      
      // D'abord, charger depuis le cache local
      List<PrestationModel> cachedPrestations = await dbHelper.getPrestationsByServiceId(serviceId);
      
      // Ensuite, charger depuis l'API et mettre à jour le cache
      final url = "${Endpoints.prestationsByServiceId}$serviceId";
      var response = await getData(url);

      if (response != null && response is Map<String, dynamic>) {
        dynamic prestationsData;

        if (response.containsKey('prestations')) {
          prestationsData = response['prestations'];
        } else if (response.containsKey('data')) {
          prestationsData = response['data'];
        } else if (response is List) {
          prestationsData = response;
        }

        if (prestationsData is List) {
          final apiPrestations = prestationsData
              .where((e) => e != null)
              .map<PrestationModel>((e) {
            try {
              // La structure API est : {"prestation": {...}, "image": [...]}
              Map<String, dynamic> prestationData;
              List<String> images = [];
              
              if (e is Map<String, dynamic> && e.containsKey('prestation')) {
                prestationData = e['prestation'] as Map<String, dynamic>;
                // Injecter postBy dans les données de prestation si présent à la racine
                if (e.containsKey('postBy')) {
                  prestationData['postBy'] = e['postBy'];
                }
                // Extraire les images
                if (e.containsKey('image') && e['image'] is List) {
                  images = (e['image'] as List).map((img) {
                    if (img is String) return img;
                    if (img is Map) return img['path'] ?? img['url'] ?? '';
                    return '';
                  }).where((path) => path.isNotEmpty).cast<String>().toList();
                }
              } else {
                prestationData = e as Map<String, dynamic>;
              }
              
              final prestation = PrestationModel.fromJson(prestationData);
              prestation.images = images.isNotEmpty ? images : null;
              
              // Debug: vérifier les images
              if (prestation.images != null && prestation.images!.isNotEmpty) {
                print("✅ [ServiceController] Prestation ${prestation.id} a ${prestation.images!.length} image(s): ${prestation.images!.take(2).join(', ')}");
              } else {
                print("⚠️ [ServiceController] Prestation ${prestation.id} n'a pas d'images (extracted: ${images.length})");
              }
              
              return prestation;
            } catch (e) {
              print("Erreur lors du parsing d'une prestation: $e");
              return PrestationModel();
            }
          })
              .where((prestation) => prestation.id != null && prestation.serviceId == serviceId)
              .toList();
          
          // Mettre à jour le cache
          // Pour assurer la disparition des éléments supprimés (compte supprimé), on vide le cache spécifique
          await dbHelper.clearPrestationsByServiceId(serviceId);
          await dbHelper.insertOrUpdatePrestations(apiPrestations);
          return apiPrestations;
        }
      }
      
      // Retourner le cache si l'API n'a pas retourné de données
      return cachedPrestations;
    } catch (e) {
      print("Erreur lors de la récupération des prestations par serviceId: $e");
      // En cas d'erreur, retourner le cache
      try {
        final dbHelper = PrestationDatabaseHelper.instance;
        return await dbHelper.getPrestationsByServiceId(serviceId);
      } catch (e2) {
        print("Erreur lors du chargement du cache: $e2");
        return [];
      }
    }
  }

  PrestationModel _parsePrestation(dynamic e) {
    try {
      // La structure API est : {"prestation": {...}, "image": [...]}
      Map<String, dynamic> prestationData;
      List<String> images = [];
      
      if (e is Map<String, dynamic> && e.containsKey('prestation')) {
        prestationData = e['prestation'] as Map<String, dynamic>;
        // Injecter postBy dans les données de prestation si présent à la racine
        if (e.containsKey('postBy')) {
          prestationData['postBy'] = e['postBy'];
        }
        // Extraire les images
        if (e.containsKey('image') && e['image'] is List) {
          images = (e['image'] as List).map((img) {
            if (img is String) return img;
            if (img is Map) return img['path'] ?? img['url'] ?? '';
            return '';
          }).where((path) => path.isNotEmpty).cast<String>().toList();
        }
      } else {
        prestationData = e as Map<String, dynamic>;
      }
      
      final prestation = PrestationModel.fromJson(prestationData);
      prestation.images = images.isNotEmpty ? images : null;
      return prestation;
    } catch (e) {
      print("Erreur lors du parsing d'une prestation: $e");
      return PrestationModel();
    }
  }

  // Récupérer toutes les prestations (avec cache SQLite)
  Future<List<PrestationModel>> fetchAllPrestations({int page = 0, int size = 15, bool isLoadMore = false}) async {
    try {
      if (!isLoadMore) {
        currentPage = 0;
        hasMoreData = true;
      }

      final dbHelper = PrestationDatabaseHelper.instance;
      
      // D'abord, charger depuis le cache local (uniquement au premier chargement)
      if (!isLoadMore && page == 0) {
        List<PrestationModel> cachedPrestations = await dbHelper.getAllPrestations();
        if (cachedPrestations.isNotEmpty) {
          prestations = cachedPrestations;
          notifyListeners();
        }
      }
      
      // Ensuite, charger depuis l'API avec l'endpoint public (pas besoin de token)
      final url = "${Endpoints.publicPrestations}?page=${isLoadMore ? currentPage + 1 : page}&size=$size";
      var response = await getData(url);

      if (response != null && response is Map<String, dynamic>) {
        dynamic prestationsData;

        if (response.containsKey('prestations')) {
          prestationsData = response['prestations'];
        } else if (response.containsKey('data')) {
          prestationsData = response['data'];
        } else if (response.containsKey('content')) {
          prestationsData = response['content'];
        } else if (response is List) {
          prestationsData = response;
        }

        if (prestationsData is List) {
          final apiPrestations = prestationsData
              .where((e) => e != null)
              .map<PrestationModel>((e) => _parsePrestation(e))
              .where((prestation) => prestation.id != null)
              .toList();
          
          if (isLoadMore) {
             final existingIds = prestations.map((p) => p.id).toSet();
             final newItems = apiPrestations.where((p) => !existingIds.contains(p.id)).toList();
             prestations.addAll(newItems);
             currentPage++;
          } else {
             // Mettre à jour le cache uniquement sur le refresh complet (page 0)
             await dbHelper.clearAllPrestations();
             await dbHelper.insertOrUpdatePrestations(apiPrestations);
             prestations = apiPrestations;
          }

          // Gérer le hasMoreData (format Spring Pageable)
          if (response is Map && response.containsKey('last')) {
            hasMoreData = !(response['last'] as bool);
          } else {
            hasMoreData = apiPrestations.length >= size;
          }

          notifyListeners();
          return apiPrestations;
        } else {
          print("⚠️ [ServiceController] prestationsData n'est pas une List");
          hasMoreData = false;
        }
      }
      return prestations;
    } catch (e) {
      print("Erreur lors de la récupération des prestations: $e");
      return prestations;
    } finally {
      notifyListeners();
    }
  }

  // Convertir PrestationModel en ServiceModel pour l'affichage
  ServiceModel prestationToServiceModel(PrestationModel prestation, ServiceType? serviceType) {
    // Utiliser profile en premier, puis les images de portfolio
    List<String>? imagesList = [];
    
    // Ajouter la photo de profil en premier si elle existe
    if (prestation.profile != null && prestation.profile!.isNotEmpty) {
      imagesList.add(prestation.profile!);
      print("📸 [ServiceController] Prestation ${prestation.id} a une photo de profil");
    }
    
    // Ajouter les images de portfolio après
    if (prestation.images != null && prestation.images!.isNotEmpty) {
      imagesList.addAll(prestation.images!);
      print("📸 [ServiceController] Prestation ${prestation.id} a ${prestation.images!.length} image(s) de portfolio");
    }
    
    if (imagesList.isEmpty) {
      imagesList = null;
      print("⚠️ [ServiceController] Prestation ${prestation.id} n'a pas d'images");
    } else {
      print("✅ [ServiceController] Prestation ${prestation.id} a ${imagesList.length} image(s) total (profil + portfolio)");
    }
    
    // Mapper le serviceId vers ServiceType si non fourni
    final finalServiceType = serviceType ?? _mapServiceIdToServiceType(prestation.serviceId);
    
    return ServiceModel()
      ..serviceId = prestation.id
      ..title = prestation.title ?? ''
      ..description = prestation.description ?? ''
      ..price = prestation.minPrice ?? prestation.maxPrice
      ..serviceType = finalServiceType
      ..address = prestation.address ?? ''
      ..cityValue = prestation.cityValue ?? ''
      ..communeValue = prestation.communeValue ?? ''
      ..quartierValue = prestation.quartierValue ?? ''
      ..isAvailable = prestation.isActive ?? true
      ..isVerified = prestation.isCertified ?? false
      ..username = prestation.username // AJOUT
      ..createdAt = prestation.dateCreated?.toIso8601String() // AJOUT
      ..availableDays = prestation.plageJourPrestation != null && prestation.plageJourPrestation!.isNotEmpty
          ? prestation.plageJourPrestation!.split(',').map((e) => e.trim()).toList()
          : null // AJOUT
      ..availableHours = prestation.plageHeurePrestation // AJOUT
      ..images = imagesList; // Transférer les images (profil en premier)
  }

  // Mapper serviceId (ID du compte) vers ServiceType basé sur le nom du compte
  ServiceType? _mapServiceIdToServiceType(int? serviceId) {
    if (serviceId == null) return null;
    
    // Cette méthode sera complétée avec le mapping depuis user_accounts
    // Pour l'instant, on retourne null et on laissera HomePage faire le mapping
    return null;
  }

  // =============================================
  // SERVICE SOLICITATION
  // =============================================

  Future<HttpResponse> createSolicitation(Map<String, dynamic> data) async {
    loading = true;
    notifyListeners();
    
    try {
      print("📤 Création de sollicitation...");
      String? token = stockage?.read(StockageKeys.tokenKey);
      final response = await postData(Endpoints.sollicitation, data, token: token);
      
      print("📥 Réponse sollicitation: ${response.status} - ${response.data}");
      
      if (response.status) {
        // Success logic if needed
      }
      
      return response;
    } catch (e) {
      print("❌ Erreur lors de la création de la sollicitation: $e");
      return HttpResponse(status: false, errorMsg: "Une erreur est survenue: $e");
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // Récupérer les sollicitations de l'utilisateur
  Future<List<SollicitationModel>> fetchUserSollicitations() async {
    loading = true;
    notifyListeners();

    try {
      final userData = stockage?.read(StockageKeys.userKey);
      String? userId;
      
      if (userData is Map) {
        if (userData.containsKey('user') && userData['user'] is Map && userData['user']?['userId'] != null) {
          userId = userData['user']?['userId']?.toString();
        } else if (userData.containsKey('userId') && userData['userId'] != null) {
          userId = userData['userId']?.toString();
        }
      }

      if (userId == null) {
        print("❌ [ServiceController] UserId non trouvé pour récupérer les sollicitations");
        return [];
      }

      final url = "${Endpoints.sollicitationsByUser}$userId";
      print("🔍 [ServiceController] Récupération des sollicitations depuis: $url");
      
      String? token = stockage?.read(StockageKeys.tokenKey);
      var response = await getData(url, token: token);

      if (response != null && response is Map<String, dynamic>) {
        dynamic data;
        if (response.containsKey('data')) {
          data = response['data'];
        } else {
           data = response;
        }

        if (data is List) {
           solicitations = data.map((e) => SollicitationModel.fromJson(e)).toList();
           print("✅ [ServiceController] ${solicitations.length} sollicitations récupérées");
        }
      }
      
      return solicitations;

    } catch (e) {
      print("❌ [ServiceController] Erreur lors de la récupération des sollicitations: $e");
      return [];
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<List<DeviseModel>> fetchDevises() async {
    try {
      final localData = stockage?.read(StockageKeys.devisesKey);
      if (localData != null && localData is Map && localData['devises'] != null) {
          devisesList = (localData['devises'] as List).map((e) => DeviseModel.fromJson(e)).toList();
          notifyListeners();
      }

      final token = stockage?.read(StockageKeys.tokenKey);
      var response = await getData("${Constantes.URL_BASE}${Endpoints.devises}", token: token);
      if (response != null && response is Map && response['devises'] != null) {
          devisesList = (response['devises'] as List).map((e) => DeviseModel.fromJson(e)).toList();
          stockage?.write(StockageKeys.devisesKey, response);
          notifyListeners();
      }
      return devisesList;
    } catch (e) {
      print("Error fetching devises: $e");
      return devisesList;
    }
  }

  // Supprimer une prestation
  Future<HttpResponse> deletePrestation(int prestationId) async {
    loading = true;
    notifyListeners();

    try {
      final token = stockage?.read<String>(StockageKeys.tokenKey);
      final url = "${Endpoints.deletePrestation}$prestationId";
      
      HttpResponse response = await deleteData(url, token: token);

      if (response.status == true) {
        // Supprimer du cache local
        final dbHelper = PrestationDatabaseHelper.instance;
        await dbHelper.deletePrestation(prestationId);
        
        // Recharger les prestations
        await getMyPrestations();
      }

      return response;
    } catch (e) {
      print("Erreur lors de la suppression de la prestation: $e");
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

  // Récupérer les sollicitations reçues par le propriétaire (host)
  Future<List<SollicitationModel>> fetchHostSollicitations() async {
    loading = true;
    notifyListeners();

    try {
      final userData = stockage?.read(StockageKeys.userKey);
      String? userId;
      
      if (userData is Map) {
        if (userData.containsKey('user') && userData['user'] is Map && userData['user']?['userId'] != null) {
          userId = userData['user']?['userId']?.toString();
        } else if (userData.containsKey('userId') && userData['userId'] != null) {
          userId = userData['userId']?.toString();
        }
      }

      if (userId == null) {
        print("❌ [ServiceController] UserId non trouvé pour récupérer les sollicitations host");
        return [];
      }

      final url = "${Endpoints.sollicitationsByHost}$userId";
      print("🔍 [ServiceController] Récupération des sollicitations host depuis: $url");
      
      String? token = stockage?.read(StockageKeys.tokenKey);
      var response = await getData(url, token: token);

      if (response != null && response is Map<String, dynamic>) {
        dynamic data;
        
        // The API returns {reservation: [...]}
        if (response.containsKey('reservation')) {
          data = response['reservation'];
        } else if (response.containsKey('data')) {
          data = response['data'];
        } else {
          data = response;
        }

        if (data is List) {
           final hostSolicitations = data.map((e) => SollicitationModel.fromJson(e)).toList();
           print("✅ [ServiceController] ${hostSolicitations.length} sollicitations host récupérées");
           return hostSolicitations;
        }
      }
      
      return [];

    } catch (e) {
      print("❌ [ServiceController] Erreur lors de la récupération des sollicitations host: $e");
      return [];
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // Mettre à jour le statut d'une sollicitation (ACCEPT ou REJECT)
  Future<HttpResponse> updateSollicitationStatus(int sollicitationId, String status) async {
    loading = true;
    notifyListeners();

    try {
      print("📤 Mise à jour sollicitation $sollicitationId vers $status");
      String? token = stockage?.read(StockageKeys.tokenKey);
      
      final url = "${Endpoints.updateSollicitation}$sollicitationId";
      final data = {'status': status};
      
      final response = await patchData(url, data, token: token);
      
      print("📥 Réponse mise à jour sollicitation: ${response.status}");
      
      return response;
    } catch (e) {
      print("❌ Erreur lors de la mise à jour de la sollicitation: $e");
      return HttpResponse(status: false, errorMsg: "Une erreur est survenue: $e");
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}


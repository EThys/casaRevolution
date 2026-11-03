import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:get_storage/get_storage.dart';
import '../models/ServiceModel.dart';
import '../models/PrestationModel.dart';
import '../controllers/ServiceController.dart';
import '../utils/StockageKeys.dart';
import '../utils/Endpoints.dart';
import '../utils/requetes.dart' show getData;
import '../utils/database/ServiceCategoryDatabaseHelper.dart';
import 'ServiceCategoryPage.dart';
import 'CategoryPropertiesPage.dart'; // fallback legacy import

class AllServiceCategoriesPage extends StatefulWidget {
  /// `true` : section « Autres services » (sans majordome ni déménagement).
  final bool otherServicesOnly;

  const AllServiceCategoriesPage({super.key, this.otherServicesOnly = false});

  static const Color primaryColor = Color(0xFF1976D2);
  static const Color accentColor = Color(0xFF64B5F6);
  static const Color darkBlue = Color(0xFF0D47A1);

  // Liste des catégories de services (sera remplie dynamiquement depuis l'API)
  static List<Map<String, dynamic>> serviceCategories = [
    {
      'name': 'Plombier',
      'value': 'plomberie',
      'icon': Icons.plumbing_rounded,
      'color': Color(0xFF2196F3),
    },
    {
      'name': 'Ajusteur',
      'value': 'reparation',
      'icon': Icons.build_rounded,
      'color': Color(0xFF4CAF50),
    },
    {
      'name': 'Architecte',
      'value': 'renovation',
      'icon': Icons.architecture_rounded,
      'color': Color(0xFFFF9800),
    },
    {
      'name': 'Coiffure',
      'value': 'coiffure',
      'icon': Icons.content_cut_rounded,
      'color': Color(0xFF9C27B0),
    },
    {
      'name': 'Chauffeur',
      'value': 'transport',
      'icon': Icons.drive_eta_rounded,
      'color': Color(0xFFF44336),
    },
    {
      'name': 'Électricien',
      'value': 'electricite',
      'icon': Icons.electrical_services_rounded,
      'color': Color(0xFFFFEB3B),
    },
    {
      'name': 'Frigoriste',
      'value': 'climatisation',
      'icon': Icons.ac_unit_rounded,
      'color': Color(0xFF00BCD4),
    },
    {
      'name': 'Maçon',
      'value': 'renovation',
      'icon': Icons.construction_rounded,
      'color': Color(0xFF795548),
    },
    {
      'name': 'Majordome',
      'value': 'majordhomme',
      'icon': Icons.cleaning_services_rounded,
      'color': Color(0xFF607D8B),
    },
    {
      'name': 'Menuisier',
      'value': 'reparation',
      'icon': Icons.carpenter_rounded,
      'color': Color(0xFF8D6E63),
    },
    {
      'name': 'Salubrité',
      'value': 'nettoyage',
      'icon': Icons.cleaning_services_rounded,
      'color': Color(0xFF4CAF50),
    },
    {
      'name': 'Peintre',
      'value': 'peinture',
      'icon': Icons.format_paint_rounded,
      'color': Color(0xFFFF5722),
    },
  ];

  @override
  State<AllServiceCategoriesPage> createState() => _AllServiceCategoriesPageState();
}

class _AllServiceCategoriesPageState extends State<AllServiceCategoriesPage> {
  Color get primaryColor => AllServiceCategoriesPage.primaryColor;
  Color get accentColor => AllServiceCategoriesPage.accentColor;
  Color get darkBlue => AllServiceCategoriesPage.darkBlue;
  
  final GetStorage storage = GetStorage();
  Map<String, int> accountNameToIdMap = {};
  List<Map<String, dynamic>> serviceProviderCategories = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAccountMapping();
  }

  Future<void> _loadAccountMapping() async {
    try {
      // D'abord, charger depuis le cache local SQLite (rapide)
      final categoryDB = ServiceCategoryDatabaseHelper.instance;
      final cachedCategories = await categoryDB.getAllCategories();
      
      if (cachedCategories.isNotEmpty) {
        print("📦 [AllServiceCategories] ${cachedCategories.length} catégories chargées depuis le cache local");
        
        accountNameToIdMap.clear();
        serviceProviderCategories.clear();
        
        // Mapping des icônes depuis les noms stockés
        final iconNameToIcon = {
          'plumbing_rounded': Icons.plumbing_rounded,
          'electrical_services_rounded': Icons.electrical_services_rounded,
          'cleaning_services_rounded': Icons.cleaning_services_rounded,
          'format_paint_rounded': Icons.format_paint_rounded,
          'square_foot_rounded': Icons.square_foot_rounded,
          'carpenter_rounded': Icons.carpenter_rounded,
          'ac_unit_rounded': Icons.ac_unit_rounded,
          'build_rounded': Icons.build_rounded,
          'architecture_rounded': Icons.architecture_rounded,
          'drive_eta_rounded': Icons.drive_eta_rounded,
          'construction_rounded': Icons.construction_rounded,
          'local_shipping_rounded': Icons.local_shipping_rounded,
        };
        
        for (var category in cachedCategories) {
          final accountName = category['accountName']?.toString().toLowerCase();
          final accountId = category['accountId'];
          final iconName = category['iconName']?.toString() ?? 'build_rounded';
          final colorValue = category['colorValue'] as int?;
          
          if (accountName != null &&
              accountId != null &&
              _shouldIncludeCategory(accountName)) {
            accountNameToIdMap[accountName] = accountId;
            
            serviceProviderCategories.add({
              'name': category['name'] ?? accountName[0].toUpperCase() + accountName.substring(1),
              'value': category['value'] ?? '',
              'accountName': accountName,
              'accountId': accountId,
              'icon': iconNameToIcon[iconName] ?? Icons.build_rounded,
              'color': colorValue != null ? Color(colorValue) : primaryColor,
            });
          }
        }
        
        // Trier par ordre alphabétique pour éviter le sautillement
        serviceProviderCategories.sort((a, b) => 
          (a['name'] as String).compareTo(b['name'] as String));

        if (mounted) {
          setState(() {});
        }
        
        // Charger depuis l'API en arrière-plan pour mettre à jour le cache
        _loadAccountMappingFromAPI();
        return;
      }
      
      // Si pas de cache, charger depuis l'API
      await _loadAccountMappingFromAPI();
    } catch (e) {
      print("❌ [AllServiceCategories] Erreur lors du chargement depuis le cache: $e");
      // Fallback sur l'API
      await _loadAccountMappingFromAPI();
    }
  }

  Future<void> _loadAccountMappingFromAPI() async {
    try {
      // Charger depuis l'API /api/accounts
      final url = Endpoints.accounts;
      final token = storage.read<String>(StockageKeys.tokenKey);
      var response = await getData(url, token: token);
      
      if (response != null && response is Map<String, dynamic>) {
        // L'API retourne "accounts" dans la réponse (pas "user_accounts")
        final accounts = response['accounts'] as List<dynamic>?;
        
        if (accounts != null && accounts.isNotEmpty) {
          accountNameToIdMap.clear();
          serviceProviderCategories.clear();
          
          // Mapping des icônes et couleurs par nom de compte
          // Note: Les noms doivent correspondre exactement à ceux retournés par l'API (en minuscules)
          final iconMap = {
            'plombier': Icons.plumbing_rounded,
            'electricien': Icons.electrical_services_rounded,
            'salubrité': Icons.cleaning_services_rounded,
            'salubrite':  Icons.cleaning_services_rounded, // Variante sans accent
            'peintre': Icons.format_paint_rounded,
            'carrelleur': Icons.content_cut_rounded,
            'carreleur': Icons.content_cut_rounded,
            'coiffure': Icons.content_cut_rounded,
            'coiffeur': Icons.content_cut_rounded,
            'menusier': Icons.carpenter_rounded,
            'menuisier': Icons.carpenter_rounded, // Variante avec 'u'
            'frigoriste': Icons.ac_unit_rounded,
            'ajusteur': Icons.build_rounded,
            'architect': Icons.architecture_rounded,
            'architecte': Icons.architecture_rounded, // Variante avec 'e'
            'chauffeur': Icons.drive_eta_rounded,
            'maçon': Icons.construction_rounded,
            'macon': Icons.construction_rounded, // Variante sans accent
            'majordome': Icons.cleaning_services_rounded,
            'demenagement': Icons.local_shipping_rounded,
          };
          
          final colorMap = {
            'plombier': Color(0xFF2196F3),
            'electricien': Color(0xFFFFEB3B),
            'salubrité': Color(0xFF4CAF50),
            'salubrite': Color(0xFF4CAF50), // Variante sans accent
            'peintre': Color(0xFFFF5722),
            'carrelleur': Color(0xFF9C27B0),
            'carreleur': Color(0xFF9C27B0),
            'coiffure': Color(0xFF9C27B0),
            'coiffeur': Color(0xFF9C27B0),
            'menusier': Color(0xFF8D6E63),
            'menuisier': Color(0xFF8D6E63), // Variante avec 'u'
            'frigoriste': Color(0xFF00BCD4),
            'ajusteur': Color(0xFF4CAF50),
            'architect': Color(0xFFFF9800),
            'architecte': Color(0xFFFF9800), // Variante avec 'e'
            'chauffeur': Color(0xFFF44336),
            'maçon': Color(0xFF795548),
            'macon': Color(0xFF795548), // Variante sans accent
            'majordome': Color(0xFF607D8B),
            'demenagement': Color(0xFF3F51B5),
          };
          
          final List<Map<String, dynamic>> categoriesToCache = [];
          
          for (var acc in accounts) {
            final accountName = acc['name']?.toString().toLowerCase();
            final accountId = acc['id'];
            final typeAccount = acc['typeAccount'];
            final typeAccountId = typeAccount?['typeAccountId'];
            
            // Filtrer uniquement les prestataires de service (typeAccountId == 3)
            if (accountName != null &&
                accountId != null &&
                typeAccountId == 3 &&
                _shouldIncludeCategory(accountName)) {
              accountNameToIdMap[accountName] = accountId;
              
              // Créer la catégorie pour l'affichage
              final displayName = accountName[0].toUpperCase() + accountName.substring(1);
              final serviceType = _mapAccountNameToServiceType(accountName);
              
              if (serviceType != null) {
                final categoryData = {
                  'name': displayName,
                  'value': serviceType.value,
                  'accountName': accountName,
                  'accountId': accountId,
                  'icon': iconMap[accountName] ?? Icons.build_rounded,
                  'color': colorMap[accountName] ?? primaryColor,
                };
                
                serviceProviderCategories.add(categoryData);
                
                // Préparer pour le cache (convertir IconData en String)
                final iconName = iconMap[accountName] != null 
                    ? _iconDataToName(iconMap[accountName]!)
                    : 'build_rounded';
                
                categoriesToCache.add({
                  'name': displayName,
                  'value': serviceType.value,
                  'accountName': accountName,
                  'accountId': accountId,
                  'iconName': iconName,
                  'colorValue': (colorMap[accountName] ?? primaryColor).value,
                });
              }
              
              print("📋 [AllServiceCategories] Prestataire: $accountName -> $accountId");
            }
          }
          
          // Trier par ordre alphabétique pour la stabilité visuelle
          serviceProviderCategories.sort((a, b) => 
            (a['name'] as String).compareTo(b['name'] as String));

          // Stocker dans le cache SQLite
          if (categoriesToCache.isNotEmpty) {
            final categoryDB = ServiceCategoryDatabaseHelper.instance;
            // Vider le cache avant d'insérer pour éviter les doublons (547 catégories)
            await categoryDB.clearAllCategories();
            await categoryDB.insertOrUpdateCategories(categoriesToCache);
            print("💾 [AllServiceCategories] ${categoriesToCache.length} catégories stockées dans SQLite");
          }
          
          print("✅ [AllServiceCategories] ${accountNameToIdMap.length} prestataires chargés depuis l'API");
          if (mounted) {
            setState(() {});
          }
        } else {
          print("⚠️ [AllServiceCategories] Aucun accounts dans la réponse API ou liste vide");
        }
      } else {
        print("⚠️ [AllServiceCategories] Réponse API invalide ou null");
      }
    } catch (e) {
      print("❌ [AllServiceCategories] Erreur lors du chargement du mapping depuis l'API: $e");
      // Fallback sur le stockage local si l'API échoue
      try {
        final userData = storage.read<Map<String, dynamic>>(StockageKeys.userKey);
        final userAccounts = userData?['user_accounts'] as List<dynamic>?;
        
        if (userAccounts != null) {
          accountNameToIdMap.clear();
          for (var acc in userAccounts) {
            final accountName = acc['name']?.toString().toLowerCase();
            final accountId = acc['id'];
            if (accountName != null && accountId != null) {
              accountNameToIdMap[accountName] = accountId;
            }
          }
        }
      } catch (e2) {
        print("❌ [AllServiceCategories] Erreur lors du chargement du mapping local: $e2");
      }
    }
  }

  // Convertir IconData en nom de string pour le stockage
  String _iconDataToName(IconData iconData) {
    // Mapping simple basé sur les icônes utilisées
    if (iconData == Icons.plumbing_rounded) return 'plumbing_rounded';
    if (iconData == Icons.electrical_services_rounded) return 'electrical_services_rounded';
    if (iconData == Icons.cleaning_services_rounded) return 'cleaning_services_rounded';
    if (iconData == Icons.format_paint_rounded) return 'format_paint_rounded';
    if (iconData == Icons.square_foot_rounded) return 'square_foot_rounded';
    if (iconData == Icons.carpenter_rounded) return 'carpenter_rounded';
    if (iconData == Icons.ac_unit_rounded) return 'ac_unit_rounded';
    if (iconData == Icons.build_rounded) return 'build_rounded';
    if (iconData == Icons.architecture_rounded) return 'architecture_rounded';
    if (iconData == Icons.drive_eta_rounded) return 'drive_eta_rounded';
    if (iconData == Icons.construction_rounded) return 'construction_rounded';
    if (iconData == Icons.local_shipping_rounded) return 'local_shipping_rounded';
    return 'build_rounded';
  }

  bool _isExcludedOtherServicesCategory(String accountName) {
    final n = accountName.toLowerCase().trim();
    return n == 'majordome' || n == 'majordhomme';
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  bool _shouldIncludeCategory(String accountName) {
    if (!widget.otherServicesOnly) return true;
    return !_isExcludedOtherServicesCategory(accountName);
  }

  // Mapper le nom du compte vers ServiceType
  ServiceType? _mapAccountNameToServiceType(String accountName) {
    final normalizedName = accountName.toLowerCase().trim();
    final map = {
      'majordome': ServiceType.majordhomme,
      'majordhomme': ServiceType.majordhomme,
      'plombier': ServiceType.plomberie,
      'plombiers': ServiceType.plomberie,
      'electricien': ServiceType.electricite,
      'electriciens': ServiceType.electricite,
      'salubrité': ServiceType.nettoyage,
      'salubrites': ServiceType.nettoyage,
      'peintre': ServiceType.peinture,
      'peintres': ServiceType.peinture,
      'coiffure': ServiceType.coiffure,
      'coiffeur': ServiceType.coiffure,
      'carreleur': ServiceType.coiffure,
      'carrelleur': ServiceType.coiffure,
      'carreleurs': ServiceType.coiffure,
      'carrelage': ServiceType.coiffure,
      'menuisier': ServiceType.reparation,
      'menusier': ServiceType.reparation, // Variante sans 'u' (API retourne "menusier")
      'menuisiers': ServiceType.reparation,
      'frigoriste': ServiceType.climatisation,
      'frigoristes': ServiceType.climatisation,
      'ajusteur': ServiceType.reparation,
      'ajusteurs': ServiceType.reparation,
      'architecte': ServiceType.renovation,
      'architect': ServiceType.renovation, // Note: l'API retourne "architect" sans 'e'
      'architectes': ServiceType.renovation,
      'maçon': ServiceType.renovation, // Note: l'API retourne "maçon" avec accent
      'macon': ServiceType.renovation,
      'chauffeur': ServiceType.transport,
      'chauffeurs': ServiceType.transport,
      'demenagement': ServiceType.demenagement,
      'demenagements': ServiceType.demenagement,
    };
    return map[normalizedName];
  }

  // Charger les prestations pour une catégorie donnée (avec filtrage par serviceId)
  Future<List<PrestationModel>> _loadServicesForCategory(int accountId) async {
    try {
      final serviceCtrl = Provider.of<ServiceController>(context, listen: false);
      
      // Charger les prestations depuis l'API (avec cache SQLite)
      // L'API va filtrer automatiquement où serviceId == accountId
      final prestations = await serviceCtrl.fetchPrestationsByServiceId(accountId);
      
      if (prestations.isNotEmpty) {
        // Filtrer pour s'assurer que serviceId correspond bien
        return prestations.where((p) => p.serviceId == accountId).toList();
      }
      
      return [];
    } catch (e) {
      print("❌ [AllServiceCategories] Erreur lors du chargement des prestations: $e");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AllServiceCategoriesPage.primaryColor,
                AllServiceCategoriesPage.darkBlue,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.otherServicesOnly
              ? 'Catégories de services'
              : 'Toutes les catégories',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        color: primaryColor,
        onRefresh: _loadAccountMappingFromAPI,
        child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 16, 16, 28 + MediaQuery.viewPaddingOf(context).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 8),
            Text(
              widget.otherServicesOnly
                  ? 'Choisissez une catégorie de service'
                  : 'Découvrez tous nos services',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 24),
            serviceProviderCategories.isEmpty
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Chargement des catégories...',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _groupedCategorySections(context),
                  ),
          ],
        ),
      ),
      ),
    );
  }

  List<Widget> _groupedCategorySections(BuildContext context) {
    final sorted = List<Map<String, dynamic>>.from(serviceProviderCategories)
      ..sort((a, b) => (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase()));
    final sections = <Widget>[];
    String? currentLetter;
    for (final category in sorted) {
      final name = (category['name'] as String?)?.trim() ?? '';
      final letter = name.isEmpty ? '#' : name[0].toUpperCase();
      if (letter != currentLetter) {
        currentLetter = letter;
        sections.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 6),
            child: Text(
              letter,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: primaryColor,
              ),
            ),
          ),
        );
      }
      sections.add(_buildCategoryCard(context, category));
    }
    return sections;
  }

  Widget _buildCategoryCard(BuildContext context, Map<String, dynamic> category) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
          final accountId = _asInt(category['accountId']);
          if (accountId == null || !mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Cette catégorie est indisponible pour le moment.')),
            );
            return;
          }
          final serviceType = ServiceTypeExtension.fromString(category['value']?.toString());
          
          setState(() => isLoading = true);
          
          // Charger les prestations depuis l'API avec filtrage par serviceId
          final services = await _loadServicesForCategory(accountId);
          
          if (!mounted) return;
          setState(() => isLoading = false);
          
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ServiceCategoryPage(
                  serviceType: serviceType,
                  services: services,
                ),
              ),
            );
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.all(Radius.circular(16)),
            border: Border.fromBorderSide(
              BorderSide(color: Color(0xFFE5E7EB)),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  category['icon'] as IconData? ?? Icons.build_rounded,
                  color: primaryColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  category['name'] as String,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: darkBlue,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
            ],
          ),
        ),
    );
  }
}


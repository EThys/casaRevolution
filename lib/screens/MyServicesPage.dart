import 'package:casa/controllers/CotationController.dart';
import 'package:casa/controllers/ServiceController.dart';
import 'package:casa/models/PrestationModel.dart';
import 'package:casa/models/UserModel.dart';
import 'package:casa/models/ServiceModel.dart';
import 'package:casa/models/SollicitationModel.dart';
import 'package:casa/screens/ServiceDetailPage.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/crashlytics_api.dart';
import 'package:casa/utils/Routes.dart';
import 'package:casa/utils/StockageKeys.dart';
import 'package:casa/utils/decertification_access_guard.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:google_fonts/google_fonts.dart';
import '../controllers/AuthentificationCtrl.dart';
import '../utils/database/DatabaseHelper.dart';
import '../utils/UserInfoBottomSheet.dart';
import '../widgets/ModernCustomDialog.dart'; // Import du nouveau modal
import 'FullScreenImageViewer.dart'; // Pour le zoom image
// Détails: on reste sur ServiceDetailPage (avec cotations sollicitationId).
import 'package:casa/utils/SubscriptionHelper.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:casa/utils/export_directory.dart';
import '../utils/realtime_refresh_hub.dart';
import '../utils/status_labels_fr.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';

class MyServicesPage extends StatefulWidget {
  /// 0 = Mes annonces, 1 = Mes demandes, 2 = Demandes reçues (ex. deep link notification).
  final int? initialTabIndex;

  const MyServicesPage({Key? key, this.initialTabIndex}) : super(key: key);

  @override
  _MyServicesPageState createState() => _MyServicesPageState();
}

class _MyServicesPageState extends State<MyServicesPage>
    with SingleTickerProviderStateMixin {
  // View mode: 0 = Mes Annonces, 1 = Mes Demandes, 2 = Demandes reçues
  int _viewMode = 0;
  bool _isLoadingData = true;
  bool _isRefreshing = false;
  final Set<int> _loadedTabs = {}; // Suivi des onglets déjà chargés via API

  late TabController _tabController;
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy', 'fr_FR');
  final GetStorage _stockage = GetStorage();

  // Couleurs modernes
  final Color _primaryColor = Color(0xFF1976D2);
  final Color _secondaryColor = Color(0xFF64B5F6);
  final Color _darkColor = Color(0xFF1A1D26);
  final Color _lightGrey = Color(0xFFF5F6FA);
  final Color _mediumGrey = Color(0xFF7F8C8D);
  final Color _successColor = Color(0xFF00B894);
  final Color _warningColor = Color(0xFFFDCB6E);
  final Color _errorColor = Color(0xFFD63031);
  final Color _cardBackground = Colors.white;

  List<PrestationModel> _myPrestations = [];
  List<SollicitationModel> _mySolicitations = []; // Sent by user
  List<SollicitationModel> _hostSolicitations = []; // Received by provider
  List<int> _deletingIds = [];
  static const String _ratedCotationStorageKey =
      'cotation_rated_sollicitation_ids';
  Set<int> _ratedSolicitationIds = {};
  bool _isGridView = false;
  bool _isProcessingAction = false; // Pour les overlays de chargement
  pw.MemoryImage? _logoImage;
  StreamSubscription<String>? _realtimeRefreshSub;

  bool _isNonLocataireAccount() {
    final userAccounts = _stockage.read('user_accounts');
    if (userAccounts == null || userAccounts is! List) return false;

    bool hasOwner = false;
    bool hasService = false;

    for (final acc in userAccounts) {
      if (acc is! Map) continue;
      final catId = acc['categoryId'];
      if (catId != null) {
        final s = catId.toString();
        if (s == '2') hasOwner = true;
        if (s == '3') hasService = true;
      }
      final typeAccount = acc['typeAccount'];
      if (typeAccount != null && typeAccount is Map) {
        final nestedCat = typeAccount['categoryId'];
        if (nestedCat != null) {
          final s = nestedCat.toString();
          if (s == '2') hasOwner = true;
          if (s == '3') hasService = true;
        }
      }
    }

    // Si l'utilisateur est bailleur/commissionnaire/gérant (owner) ou prestataire, ce n'est pas un locataire.
    return hasOwner || hasService;
  }

  @override
  void initState() {
    super.initState();
    _loadRatedSolicitationIds();
    _realtimeRefreshSub = RealtimeRefreshHub.instance.stream.listen((channel) {
      if (!mounted) return;
      if (channel == RealtimeRefreshHub.serviceSolicitations) {
        _loadData(forceRefresh: true);
      }
    });
    final initialTab = widget.initialTabIndex;
    final int idx;
    if (initialTab != null && initialTab >= 0 && initialTab < 3) {
      idx = initialTab;
    } else {
      // UX: si le compte n'est pas locataire, ouvrir directement "Demandes reçues".
      idx = _isNonLocataireAccount() ? 2 : 0;
    }
    _viewMode = idx;
    _tabController = TabController(length: 3, vsync: this, initialIndex: idx);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final newIndex = _tabController.index;
        if (newIndex != _viewMode) {
          setState(() {
            _viewMode = newIndex;
            // Si l'onglet n'a pas encore été chargé, on déclenche le shimmer
            if (!_loadedTabs.contains(newIndex)) {
              _isLoadingData = true;
            }
          });
          _loadData();
        }
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (await DecertificationAccessGuard.redirectIfInactiveDecertified(
        context,
      )) {
        return;
      }
      if (!mounted) return;
      _loadData();
      _loadLogo();
    });
  }

  Future<void> _loadLogo() async {
    try {
      final data = await rootBundle.load('assets/images/logoCasa.png');
      setState(() {
        _logoImage = pw.MemoryImage(data.buffer.asUint8List());
      });
    } catch (_) {}
  }

  /// Plus récent en premier (date de création, sinon id).
  int _compareSolicitationsNewestFirst(
      SollicitationModel a, SollicitationModel b) {
    DateTime? da;
    DateTime? db;
    if (a.createdAt != null && a.createdAt!.isNotEmpty) {
      da = DateTime.tryParse(a.createdAt!);
    }
    if (b.createdAt != null && b.createdAt!.isNotEmpty) {
      db = DateTime.tryParse(b.createdAt!);
    }
    if (da != null && db != null && da != db) return db.compareTo(da);
    if (da != null && db == null) return -1;
    if (da == null && db != null) return 1;
    return (b.id ?? 0).compareTo(a.id ?? 0);
  }

  @override
  void dispose() {
    _realtimeRefreshSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _loadRatedSolicitationIds() {
    final raw = _stockage.read(_ratedCotationStorageKey);
    if (raw is List) {
      final next = <int>{};
      for (final e in raw) {
        final v = int.tryParse(e.toString());
        if (v != null && v > 0) next.add(v);
      }
      _ratedSolicitationIds = next;
    }
  }

  int? _currentUserIdFromStorage() {
    final raw = _stockage.read(StockageKeys.userKey);
    if (raw is Map) {
      return UserModel.fromJson(Map<String, dynamic>.from(raw)).userId;
    }
    return null;
  }

  /// Onglet « Mes demandes » : seul le demandeur peut noter (pas le propriétaire de l’annonce).
  bool _canShowCotationButton(SollicitationModel item) {
    if (_viewMode != 1 || item.id == null) return false;
    final me = _currentUserIdFromStorage();
    if (me == null || item.userId != me) return false;
    if (_ratedSolicitationIds.contains(item.id!)) return false;
    final st = item.status?.toUpperCase() ?? '';
    // Règle cible: pas PENDING / pas CANCELLED. Mais pour tests, on autorise aussi PENDING.
    if (st == 'CANCELLED' || st == 'REJECTED') return false;
    return st == 'COMPLETED' ||
        st == 'APPROVED' ||
        st == 'ACCEPTED' ||
        st == 'PENDING';
  }

  Future<void> _showCotationDialog(SollicitationModel item) async {
    final me = _currentUserIdFromStorage();
    if (me == null || item.id == null) {
      FancyNotification.show(
        context,
        'Session invalide. Reconnectez-vous.',
        type: NotificationType.error,
      );
      return;
    }

    final commentCtrl = TextEditingController();
    double cote = 4.5;
    bool submitted = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: Consumer<CotationController>(
            builder: (ctx, cotationCtrl, _) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                ),
                child: SafeArea(
                  top: false,
                  child: StatefulBuilder(
                    builder: (ctx, setLocal) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Container(
                                width: 46,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE5E7EB),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF1976D2),
                                        Color(0xFF64B5F6)
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.rate_review_rounded,
                                      color: Colors.white),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Votre avis',
                                        style: GoogleFonts.inter(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Sollicitation #${item.id}',
                                        style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: const Color(0xFF6B7280)),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: cotationCtrl.loading
                                      ? null
                                      : () => Navigator.pop(ctx),
                                  icon: const Icon(Icons.close_rounded),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(16),
                                border:
                                    Border.all(color: const Color(0xFFF1F5F9)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF1976D2),
                                              Color(0xFF64B5F6)
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          '★ ${cote.toStringAsFixed(1)} / 5',
                                          style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Glissez pour ajuster',
                                        style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: const Color(0xFF6B7280)),
                                      ),
                                    ],
                                  ),
                                  Slider(
                                    value: cote,
                                    min: 0.5,
                                    max: 5.0,
                                    divisions: 9,
                                    label: cote.toStringAsFixed(1),
                                    activeColor: _primaryColor,
                                    onChanged: cotationCtrl.loading
                                        ? null
                                        : (v) => setLocal(() => cote = v),
                                  ),
                                  TextField(
                                    controller: commentCtrl,
                                    maxLines: 4,
                                    enabled: !cotationCtrl.loading,
                                    decoration: InputDecoration(
                                      hintText:
                                          'Ex: Service rapide, pro, respect du délai…',
                                      hintStyle: GoogleFonts.inter(
                                          color: const Color(0xFF9CA3AF)),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(14)),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(
                                          color: _primaryColor,
                                          width: 1.2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: cotationCtrl.loading
                                        ? null
                                        : () => Navigator.pop(ctx),
                                    style: OutlinedButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14)),
                                      side: const BorderSide(
                                          color: Color(0xFFE5E7EB)),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                    ),
                                    child: Text('Annuler',
                                        style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w800)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded( 
                                  child: FilledButton(
                                    onPressed: cotationCtrl.loading
                                        ? null
                                        : () async {
                                            final text =
                                                commentCtrl.text.trim();
                                            if (text.length < 3) {
                                              FancyNotification.show(
                                                ctx,
                                                'Le commentaire doit contenir au moins 3 caractères.',
                                                type: NotificationType.warning,
                                              );
                                              return;
                                            }
                                            final resp = await cotationCtrl
                                                .createCotation(
                                              userId: me,
                                              sollicitationId: item.id!,
                                              commentaire: text,
                                              cote: cote,
                                            );
                                            if (!ctx.mounted) return;
                                            if (resp.status) {
                                              submitted = true;
                                              FocusScope.of(ctx).unfocus();
                                              Navigator.pop(ctx);
                                            } else {
                                              final msg = resp.errorMsg ??
                                                  (resp.data is Map
                                                      ? (resp.data['message']
                                                          ?.toString())
                                                      : null) ??
                                                  'Impossible d\'enregistrer l\'avis.';
                                              FancyNotification.show(
                                                ctx,
                                                msg,
                                                type: NotificationType.error,
                                              );
                                            }
                                          },
                                    style: FilledButton.styleFrom(
                                      backgroundColor: _primaryColor,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14)),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                    ),
                                    child: cotationCtrl.loading
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white),
                                          )
                                        : Text('Envoyer',
                                            style: GoogleFonts.inter(
                                                fontWeight: FontWeight.w900)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        );
      },
    );
    commentCtrl.dispose();

    // Mettre à jour l'UI uniquement après fermeture complète du bottomsheet
    if (!submitted || !mounted) return;
    setState(() {
      _ratedSolicitationIds.add(item.id!);
    });
    _stockage.write(
      _ratedCotationStorageKey,
      _ratedSolicitationIds.toList(),
    );
    FancyNotification.show(
      context,
      'Merci pour votre avis.',
      type: NotificationType.success,
    );
    await _loadMySolicitations(forceRefresh: true);
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    // Si on a déjà chargé l'onglet et qu'on ne force pas le refresh, on ne fait rien
    if (_loadedTabs.contains(_viewMode) && !forceRefresh) {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
          _isRefreshing = false;
        });
      }
      return;
    }

    setState(() {
      _isLoadingData = true;
      _isRefreshing = true;
    });

    // Load based on current view
    if (_viewMode == 0) {
      // Mes Annonces
      await _loadMyPrestations();
    } else if (_viewMode == 1) {
      // Mes Demandes
      await _loadMySolicitations(forceRefresh: forceRefresh);
    } else if (_viewMode == 2) {
      // Demandes reçues
      await _loadHostSolicitations(forceRefresh: forceRefresh);
    }

    if (mounted) {
      setState(() {
        _isLoadingData = false;
        _isRefreshing = false;
        if (!forceRefresh) _loadedTabs.add(_viewMode);
      });
    }
  }

  Future<void> _loadMyPrestations() async {
    try {
      final serviceController =
          Provider.of<ServiceController>(context, listen: false);
      final prestations = await serviceController.getMyPrestations();
      if (mounted) {
        setState(() {
          _myPrestations = prestations;
        });
      }
    } catch (e) {
      print("❌ Erreur lors du chargement des prestations: $e");
    }
  }

  Future<void> _loadMySolicitations({bool forceRefresh = false}) async {
    try {
      // 1. Charger le cache d'abord
      final db = DatabaseHelper.instance;
      final cachedSolicitations = await db.getAllUserSolicitations();

      if (cachedSolicitations.isNotEmpty && mounted) {
        final sorted = List<SollicitationModel>.from(cachedSolicitations)
          ..sort(_compareSolicitationsNewestFirst);
        setState(() {
          _mySolicitations = sorted;
          // Si on a des données en cache et qu'on n'est pas en force refresh, on peut arrêter le shimmer
          if (!forceRefresh) _isLoadingData = false;
        });
        print(
            "📁 [MyServicesPage] ${_mySolicitations.length} sollicitations chargées depuis le cache");
      }

      // 2. Appel API
      final serviceController =
          Provider.of<ServiceController>(context, listen: false);
      final solicitations = await serviceController.fetchUserSollicitations();

      if (mounted) {
        // 3. Comparer et mettre à jour si différent
        bool hasChanges =
            forceRefresh || _mySolicitations.length != solicitations.length;
        if (!hasChanges) {
          for (int i = 0; i < solicitations.length; i++) {
            if (i >= _mySolicitations.length ||
                solicitations[i].id != _mySolicitations[i].id ||
                solicitations[i].status != _mySolicitations[i].status) {
              hasChanges = true;
              break;
            }
          }
        }

        if (hasChanges) {
          solicitations.sort(_compareSolicitationsNewestFirst);
          setState(() {
            _mySolicitations = solicitations;
          });
          // 4. Mettre à jour le cache
          await db.clearUserSolicitations();
          await db.insertMultipleUserSolicitations(solicitations);
          print(
              "💾 [MyServicesPage] Cache des sollicitations utilisateur mis à jour");
        }
      }
    } catch (e) {
      print("❌ Erreur lors du chargement des sollicitations: $e");
    }
  }

  Future<void> _loadHostSolicitations({bool forceRefresh = false}) async {
    try {
      // 1. Charger le cache d'abord
      final db = DatabaseHelper.instance;
      final cachedSolicitations = await db.getAllHostSolicitations();

      if (cachedSolicitations.isNotEmpty && mounted) {
        final sorted = List<SollicitationModel>.from(cachedSolicitations)
          ..sort(_compareSolicitationsNewestFirst);
        setState(() {
          _hostSolicitations = sorted;
          if (!forceRefresh) _isLoadingData = false;
        });
        print(
            "📁 [MyServicesPage] ${_hostSolicitations.length} sollicitations host chargées depuis le cache");
      }

      // 2. Appel API
      final serviceController =
          Provider.of<ServiceController>(context, listen: false);
      final solicitations = await serviceController.fetchHostSollicitations();

      if (mounted) {
        // 3. Comparer et mettre à jour
        bool hasChanges =
            forceRefresh || _hostSolicitations.length != solicitations.length;
        if (!hasChanges) {
          for (int i = 0; i < solicitations.length; i++) {
            if (i >= _hostSolicitations.length ||
                solicitations[i].id != _hostSolicitations[i].id ||
                solicitations[i].status != _hostSolicitations[i].status) {
              hasChanges = true;
              break;
            }
          }
        }

        if (hasChanges) {
          solicitations.sort(_compareSolicitationsNewestFirst);
          setState(() {
            _hostSolicitations = solicitations;
          });
          // 4. Mettre à jour le cache
          await db.clearHostSolicitations();
          await db.insertMultipleHostSolicitations(solicitations);
          print("💾 [MyServicesPage] Cache des sollicitations host mis à jour");
        }
      }
    } catch (e) {
      print("❌ Erreur lors du chargement des sollicitations host: $e");
    }
  }

  Future<void> _deletePrestation(PrestationModel prestation) async {
    if (prestation.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: _errorColor, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Supprimer',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: _darkColor,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer "${prestation.title}" ?\n\nCette action est irréversible.',
          style: TextStyle(
            color: _mediumGrey,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler', style: TextStyle(color: _mediumGrey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _errorColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      if (prestation.id != null) {
        _deletingIds.add(prestation.id!);
      }
    });

    try {
      final serviceController =
          Provider.of<ServiceController>(context, listen: false);
      final response = await serviceController.deletePrestation(prestation.id!);

      if (response.status == true) {
        if (mounted) {
          FancyNotification.show(
            context,
            "Service supprimé avec succès",
            type: NotificationType.success,
          );
          await _loadMyPrestations();
        }
      } else {
        if (mounted) {
          reportApiFailureToCrashlytics(
            'MyServicesPage',
            response: response,
            reason: 'delete_prestation',
          );
          FancyNotification.show(
            context,
            response.errorMsg ??
                "La suppression du service n’a pas abouti. Réessayez.",
            isError: true,
          );
        }
      }
    } catch (e, st) {
      reportApiFailureToCrashlytics(
        'MyServicesPage',
        error: e,
        stackTrace: st,
        reason: 'delete_prestation_exception',
      );
      if (mounted) {
        FancyNotification.show(
          context,
          "La suppression a été interrompue. Vérifiez la connexion et réessayez.",
          isError: true,
        );
      }
    } finally {
      if (mounted && prestation.id != null) {
        setState(() {
          _deletingIds.remove(prestation.id!);
        });
      }
    }
  }

  Future<void> _togglePrestationActive(PrestationModel prestation) async {
    final id = prestation.id;
    if (id == null) return;
    final me = _currentUserIdFromStorage();
    if (me == null || prestation.userId != me) return;

    final nextActive = !(prestation.isActive == true);

    setState(() {
      final idx = _myPrestations.indexWhere((p) => p.id == id);
      if (idx != -1) _myPrestations[idx].isActive = nextActive;
    });

    try {
      final serviceCtrl = context.read<ServiceController>();
      final resp = await serviceCtrl.updatePrestationPut(id, {
        // API migration: disponibilité via `status`
        // (on garde aussi les anciens champs en fallback si backend mixte).
        'status': nextActive,
        'active': nextActive,
        'isActive': nextActive,
      });

      if (resp.status == true) {
        FancyNotification.show(
          context,
          nextActive ? "Service rendu disponible" : "Service rendu indisponible",
          type: NotificationType.success,
        );
      } else {
        setState(() {
          final idx = _myPrestations.indexWhere((p) => p.id == id);
          if (idx != -1) _myPrestations[idx].isActive = !nextActive;
        });
        FancyNotification.show(
          context,
          resp.errorMsg ?? "Impossible de changer le statut. Réessayez.",
          isError: true,
        );
      }
    } catch (_) {
      setState(() {
        final idx = _myPrestations.indexWhere((p) => p.id == id);
        if (idx != -1) _myPrestations[idx].isActive = !nextActive;
      });
      FancyNotification.show(
        context,
        "Erreur réseau. Réessayez.",
        isError: true,
      );
    }
  }

  bool _isOwnerPrestation(PrestationModel p) {
    final me = _currentUserIdFromStorage();
    if (me == null) return false;
    return p.userId != null && p.userId == me;
  }

  void _navigateToCreateService() {
    SubscriptionHelper.checkCertifiedThenProceed(
      context: context,
      onProceed: () {
        Navigator.pushNamed(context, Routes.createServicePostRoute)
            .then((_) => _loadData());
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightGrey,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return TabBarView(
      controller: _tabController,
      children: [
        // Tab 0: Mes Annonces
        _buildPrestationList(_myPrestations),
        // Tab 1: Mes Demandes
        _buildSolicitationList(_mySolicitations),
        // Tab 2: Demandes Reçues
        _buildSolicitationList(_hostSolicitations),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      iconTheme: IconThemeData(color: Colors.white),
      elevation: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_primaryColor, _secondaryColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      title: Text(
        'Mes activités',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
      bottom: TabBar(
        controller: _tabController,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withOpacity(0.6),
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
        tabs: [
          Tab(text: 'Mes Annonces '),
          Tab(text: 'Mes Demandes '),
          Tab(text: 'Demandes Reçues)'),
        ],
      ),
      actions: [
        if (_viewMode == 0) ...[
          Tooltip(
            message: _isGridView ? 'Vue liste' : 'Vue grille',
            child: IconButton(
              icon: Icon(
                _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _isGridView = !_isGridView;
                });
              },
            ),
          ),
        ],
        Tooltip(
          message: 'Actualiser',
          child: Stack(
            children: [
              IconButton(
                icon: Icon(Icons.refresh, color: Colors.white),
                onPressed:
                    _isRefreshing ? null : () => _loadData(forceRefresh: true),
              ),
              if (_isRefreshing)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: _navigateToCreateService,
      backgroundColor: _primaryColor,
      icon: Icon(Icons.add_rounded, color: Colors.white),
      label: Text(
        'Créer un service',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPrestationList(List<PrestationModel> prestations) {
    return AnimatedSwitcher(
      duration: Duration(milliseconds: 300),
      child: prestations.isEmpty && !_isLoadingData
          ? _buildEmptyState()
          : _buildPrestationListContent(prestations),
    );
  }

  Widget _buildPrestationListContent(List<PrestationModel> prestations) {
    return RefreshIndicator(
      color: _primaryColor,
      backgroundColor: Colors.white,
      onRefresh: _loadData,
      child: _isGridView
          ? _buildGridView(prestations)
          : ListView.separated(
              padding: EdgeInsets.all(20),
              itemCount: prestations.length,
              separatorBuilder: (_, __) => SizedBox(height: 20),
              itemBuilder: (context, index) {
                final prestation = prestations[index];
                return _buildPrestationCard(prestation, isGrid: false);
              },
            ),
    );
  }

  Widget _buildSolicitationList(List<SollicitationModel> items) {
    if (_isLoadingData) return _buildShimmerEffect();
    if (items.isEmpty) return _buildEmptyStateSolicitation();

    return RefreshIndicator(
      color: _primaryColor,
      backgroundColor: Colors.white,
      onRefresh: () => _loadData(forceRefresh: true),
      child: ListView.separated(
        padding: EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => SizedBox(height: 16),
        itemBuilder: (context, index) => _buildSolicitationCard(items[index]),
      ),
    );
  }

  Widget _buildShimmerEffect() {
    return ListView.separated(
      padding: EdgeInsets.all(20),
      itemCount: 4,
      separatorBuilder: (_, __) => SizedBox(height: 20),
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.work_outline,
              size: 60, color: _mediumGrey.withOpacity(0.3)),
          SizedBox(height: 20),
          Text('Aucun service publié',
              style: TextStyle(
                  color: _mediumGrey,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _navigateToCreateService,
            icon: Icon(Icons.add_rounded, size: 20),
            label: Text('Créer un service'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateSolicitation() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined,
              size: 60, color: _mediumGrey.withOpacity(0.3)),
          SizedBox(height: 20),
          Text('Aucune demande trouvée',
              style: TextStyle(
                  color: _mediumGrey,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildGridView(List<PrestationModel> prestations) {
    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: prestations.length,
      itemBuilder: (context, index) {
        final prestation = prestations[index];
        return _buildPrestationCard(prestation, isGrid: true);
      },
    );
  }

  Widget _buildPrestationCard(PrestationModel prestation,
      {required bool isGrid}) {
    final isDeleting =
        prestation.id != null && _deletingIds.contains(prestation.id);
    final imageUrl = prestation.profile ??
        (prestation.images != null && prestation.images!.isNotEmpty
            ? prestation.images!.first
            : null);

    return GestureDetector(
      onTap: isDeleting
          ? null
          : () {
              if (prestation.id != null) {
                final serviceController =
                    Provider.of<ServiceController>(context, listen: false);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ServiceDetailPage(
                      service: prestation,
                      serviceTypeName: serviceController
                          .getServiceName(prestation.serviceId),
                    ),
                  ),
                );
              }
            },
      child: Opacity(
        opacity: isDeleting ? 0.5 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: _cardBackground,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          // Fix: Enforce height in ListView so Expanded works inside Column
          height: isGrid ? null : 320,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              Expanded(
                flex: isGrid ? 3 : 2,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(16)),
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: _lightGrey,
                                child:
                                    Center(child: CircularProgressIndicator()),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: _lightGrey,
                                child: Icon(Icons.image_not_supported,
                                    color: _mediumGrey),
                              ),
                            )
                          : Container(
                              color: _lightGrey,
                              child: Icon(Icons.work_outline,
                                  size: 50, color: _mediumGrey),
                            ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _buildStatusBadge(prestation, isGrid: isGrid),
                    ),
                    if (prestation.minPrice != null)
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${NumberFormat('#,###').format(prestation.minPrice)} ${prestation.currency}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    if (prestation.cityValue != null &&
                        prestation.cityValue!.isNotEmpty)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.location_on,
                                  size: 12, color: Colors.white),
                              SizedBox(width: 4),
                              ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: 100),
                                child: Text(
                                  prestation.cityValue!,
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Contenu
              Expanded(
                flex: isGrid ? 2 : 1,
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prestation.title ?? 'Sans titre',
                        style: GoogleFonts.inter(
                          fontSize: isGrid ? 14 : 16,
                          fontWeight: FontWeight.w600,
                          color: _darkColor,
                        ),
                        maxLines: isGrid ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      SizedBox(height: 8),
                      // Action Buttons
                      if (!isGrid && _isOwnerPrestation(prestation)) // owner only
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _togglePrestationActive(prestation),
                                icon: Icon(
                                  (prestation.isActive == true)
                                      ? Icons.toggle_off_rounded
                                      : Icons.toggle_on_rounded,
                                  size: 16,
                                  color: _primaryColor,
                                ),
                                label: Text(
                                  (prestation.isActive == true)
                                      ? "Rendre indisponible"
                                      : "Rendre disponible",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _primaryColor,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  alignment: Alignment.center,
                                  padding: EdgeInsets.symmetric(
                                      vertical: 0, horizontal: 8),
                                  side: BorderSide(
                                      color: _primaryColor.withOpacity(0.5)),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ),
                          ],
                        )
                      else if (isGrid && _isOwnerPrestation(prestation)) // owner only
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            InkWell(
                              onTap: () => _togglePrestationActive(prestation),
                              child: Container(
                                padding: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: _primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  (prestation.isActive == true)
                                      ? Icons.toggle_off_rounded
                                      : Icons.toggle_on_rounded,
                                  size: 18,
                                  color: _primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSolicitationCard(SollicitationModel item) {
    // Logic for currency based on deviseId (1 = FC, 2 = $)
    final String currency = (item.deviseId == 1) ? "FC" : "\$";

    final canCancel = _viewMode == 1 &&
        (item.status?.toUpperCase() == 'PENDING') &&
        item.id != null;
    final createdAtText = (item.createdAt != null && item.createdAt!.isNotEmpty)
        ? _dateFormat.format(DateTime.parse(item.createdAt!))
        : null;
    final String periodText = () {
      final s = _formatDate(item.startDate).trim();
      final e = _formatDate(item.endDate).trim();
      if (e.isEmpty) return s;
      if (s.isEmpty) return e;
      return '$s - $e';
    }();

    return GestureDetector(
      onTap: () {
        if (_viewMode == 2) {
          // Si on est dans "Demandes reçues", on affiche le BottomSheet de gestion
          _showSolicitationActionBottomSheet(item);
        } else {
          // Détails du service (et avis liés à cette sollicitation)
          if (item.prestation != null) {
            final serviceController =
                Provider.of<ServiceController>(context, listen: false);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ServiceDetailPage(
                  service: item.prestation!,
                  serviceTypeName: serviceController
                      .getServiceName(item.prestation!.serviceId),
                  sollicitationId: item.id,
                ),
              ),
            );
          }
        }
      },
      child: Stack(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardBackground,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 4))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(item.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        frSolicitationStatus(item.status),
                        style: TextStyle(
                            color: _getStatusColor(item.status),
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                    ),
                    Row(
                      children: [
                        if (_viewMode == 2 && item.user != null) ...[
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                            icon: Icon(Icons.person_pin_rounded,
                                size: 20, color: _primaryColor),
                            onPressed: () =>
                                UserInfoBottomSheet.show(context, item.user!),
                            tooltip: "Voir le demandeur",
                          ),
                          SizedBox(width: 8),
                        ],
                        Text(
                          createdAtText ?? '',
                          style: TextStyle(color: _mediumGrey, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 12),
                if (item.prestation != null) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_viewMode == 2 && item.user != null) ...[
                        GestureDetector(
                          onTap: () {
                            final url = item.user!.profilePicture;
                            if (url != null && url.isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      FullScreenImageViewer(imagePath: url),
                                ),
                              );
                            }
                          },
                          child: CircleAvatar(
                            radius: 26,
                            backgroundColor: _primaryColor.withOpacity(0.15),
                            backgroundImage: ((item.userImage ??
                                            item.user!.profilePicture) !=
                                        null &&
                                    (item.userImage ??
                                            item.user!.profilePicture)!
                                        .isNotEmpty)
                                ? CachedNetworkImageProvider((item.userImage ??
                                    item.user!.profilePicture)!)
                                : null,
                            child: ((item.userImage ??
                                            item.user!.profilePicture) ==
                                        null ||
                                    (item.userImage ??
                                            item.user!.profilePicture)!
                                        .isEmpty)
                                ? Icon(Icons.person_rounded,
                                    color: _primaryColor, size: 28)
                                : null,
                          ),
                        ),
                        SizedBox(width: 10),
                      ],
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: _lightGrey,
                          image: (item.prestation!.profile != null ||
                                  (item.prestation!.images?.isNotEmpty ??
                                      false))
                              ? DecorationImage(
                                  image: CachedNetworkImageProvider(
                                    item.prestation!.profile ??
                                        item.prestation!.images!.first,
                                  ),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: (item.prestation!.profile == null &&
                                (item.prestation!.images?.isEmpty ?? true))
                            ? Icon(Icons.build, color: _mediumGrey)
                            : null,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.prestation!.title ?? 'Service',
                              style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: _darkColor),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4),
                            Text(
                              item.prestation!.cityValue ?? '',
                              style:
                                  TextStyle(fontSize: 12, color: _mediumGrey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                ],
                Divider(color: Colors.grey[200]),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 16, color: _primaryColor),
                    SizedBox(width: 8),
                    Text(
                      periodText,
                      style: TextStyle(fontSize: 13, color: _darkColor),
                    ),
                  ],
                ),
                if (createdAtText != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.history_toggle_off_rounded,
                          size: 16, color: _mediumGrey),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Demande faite le $createdAtText',
                          style: TextStyle(
                              fontSize: 12,
                              color: _mediumGrey,
                              fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.payments_rounded,
                        size: 16, color: _primaryColor),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Budget: ${NumberFormat('#,###').format(item.budget)} $currency',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _darkColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 10),
                    _buildIconButton(
                      icon: Icons.share_rounded,
                      color: _primaryColor,
                      onTap: () => _shareSolicitationPdf(item),
                      tooltip: "Partager",
                    ),
                    SizedBox(width: 10),
                    _buildIconButton(
                      icon: Icons.download_rounded,
                      color: _primaryColor,
                      onTap: () => _downloadSolicitationPdf(item),
                      tooltip: "Télécharger",
                    ),
                    if (_canShowCotationButton(item)) ...[
                      SizedBox(width: 10),
                      _buildIconButton(
                        icon: Icons.rate_review_rounded,
                        color: _primaryColor,
                        onTap: () => _showCotationDialog(item),
                        tooltip: "Mettre un avis",
                      ),
                    ],
                  ],
                ),
                if (item.description != null &&
                    item.description!.isNotEmpty) ...[
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _lightGrey,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      item.description!,
                      style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],

                if (_viewMode == 1 &&
                    (item.status?.toUpperCase() == 'PENDING')) ...[
                  const SizedBox(height: 4),
                ],

                // Actions déplacées sur la ligne Budget (plus compact)
              ],
            ),
          ),

          // Annuler (overlay) - action secondaire, non intrusive
          if (canCancel)
            Positioned(
              top: 10,
              right: 10,
              child: Material(
                color: Colors.white.withOpacity(0.92),
                shape: const CircleBorder(),
                elevation: 2,
                shadowColor: Colors.black.withOpacity(0.12),
                child: IconButton(
                  onPressed: _isProcessingAction
                      ? null
                      : () => _confirmCancelUserSolicitation(item),
                  tooltip: 'Annuler la demande',
                  iconSize: 20,
                  icon: Icon(Icons.close_rounded, color: _errorColor),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIconButton(
      {required IconData icon,
      required Color color,
      required VoidCallback onTap,
      required String tooltip}) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(10),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM', 'fr_FR').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  void _showSolicitationActionBottomSheet(SollicitationModel item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildSolicitationBottomSheetContent(item),
    );
  }

  Widget _buildSolicitationBottomSheetContent(SollicitationModel item) {
    final String currency = (item.deviseId == 1) ? "FC" : "\$";
    final isPending = item.status?.toUpperCase() == 'PENDING';

    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 12, 24, 24 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          SizedBox(height: 24),
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle),
                child: Icon(Icons.assignment_ind_rounded,
                    color: _primaryColor, size: 28),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Détail de la demande",
                        style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _darkColor)),
                    Text("Gérer la sollicitation reçue",
                        style: TextStyle(color: _mediumGrey, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          if (item.user != null) ...[
            Text("Demandeur",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: _darkColor)),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: _lightGrey,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      final img = (item.userImage ?? item.user?.profilePicture);
                      if (img != null && img.trim().isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FullScreenImageViewer(
                                imagePath: img),
                          ),
                        );
                      }
                    },
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: _primaryColor.withOpacity(0.2),
                      backgroundImage: ((item.userImage ?? item.user?.profilePicture) != null &&
                              (item.userImage ?? item.user?.profilePicture)!.isNotEmpty)
                          ? CachedNetworkImageProvider(
                              (item.userImage ?? item.user!.profilePicture!)!)
                          : null,
                      child: ((item.userImage ?? item.user?.profilePicture) == null ||
                              (item.userImage ?? item.user?.profilePicture)!.isEmpty)
                          ? Icon(Icons.person, color: _primaryColor)
                          : null,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.user!.username ?? "Utilisateur",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: _darkColor)),
                        SizedBox(height: 4),
                        // Téléphone
                        if (item.user!.phone != null &&
                            item.user!.phone!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              children: [
                                Icon(Icons.phone_iphone_rounded,
                                    size: 14, color: _mediumGrey),
                                SizedBox(width: 4),
                                Text(item.user!.phone!,
                                    style: TextStyle(
                                        color: _darkColor, fontSize: 13)),
                              ],
                            ),
                          ),
                        // Email (si disponible)
                        if (item.user!.email != null &&
                            item.user!.email!.isNotEmpty &&
                            item.user!.email != 'null')
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              children: [
                                Icon(Icons.email_outlined,
                                    size: 14, color: _mediumGrey),
                                SizedBox(width: 4),
                                Expanded(
                                    child: Text(item.user!.email!,
                                        style: TextStyle(
                                            color: _darkColor, fontSize: 13),
                                        overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          ),
                        // Localisation (si disponible)
                        if (item.user!.formattedLocation.isNotEmpty)
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined,
                                  size: 14, color: _mediumGrey),
                              SizedBox(width: 4),
                              Expanded(
                                  child: Text(item.user!.formattedLocation,
                                      style: TextStyle(
                                          color: _darkColor, fontSize: 13),
                                      overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
          ],
          Text("Service concerné",
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: _darkColor)),
          SizedBox(height: 8),
          InkWell(
            onTap: () {
              Navigator.pop(context); // Fermer le bottom sheet
              if (item.prestation != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          ServiceDetailPage(service: item.prestation!)),
                ).then((_) {
                  // Au retour, on reste sur l'onglet "Demandes Reçues" car setState n'a pas changé _viewMode
                  // Mais on peut forcer un refresh si besoin
                });
              }
            },
            child: Text(
              item.prestation?.title ?? "Service",
              style: TextStyle(
                fontSize: 16,
                color: _primaryColor,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline, // Souligné comme demandé
              ),
              maxLines: 1, // Une seule ligne
              overflow: TextOverflow.ellipsis, // Couper si trop long
            ),
          ),
          SizedBox(height: 4),
          if (item.budget != null) ...[
            SizedBox(height: 4),
            Text(
                "Budget proposé: ${NumberFormat('#,###').format(item.budget)} $currency",
                style: TextStyle(
                    color: _successColor, fontWeight: FontWeight.bold)),
          ],
          if (item.description != null && item.description!.isNotEmpty) ...[
            SizedBox(height: 16),
            Text("Description",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: _mediumGrey)),
            SizedBox(height: 4),
            Text(item.description!,
                style: TextStyle(color: _darkColor, height: 1.4)),
          ],
          SizedBox(height: 32),
          if (isPending) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        _handleSolicitationAction(item, 'CANCELLED'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _errorColor.withOpacity(0.1),
                      foregroundColor: _errorColor,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side:
                              BorderSide(color: _errorColor.withOpacity(0.2))),
                    ),
                    child: Text("REFUSER",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        _handleSolicitationAction(item, 'APPROVED'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _successColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      elevation: 4,
                      shadowColor: _successColor.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text("VALIDER",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                  ),
                ),
              ],
            ),
          ] else ...[
            Center(
              child: Text(
                "Statut actuel : ${frSolicitationStatus(item.status)}",
                style: TextStyle(
                    color: _getStatusColor(item.status),
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
          SizedBox(height: 12),
        ],
      ),
    );
  }

  Future<void> _confirmCancelUserSolicitation(SollicitationModel item) async {
    ModernCustomDialog.show(
      context,
      title: 'Annuler la demande',
      message:
          'Voulez-vous vraiment annuler cette sollicitation ? Cette action est définitive.',
      confirmText: 'ANNULER LA DEMANDE',
      cancelText: 'RETOUR',
      isDanger: true,
      onConfirm: () => _processUserSolicitationCancel(item),
    );
  }

  Future<void> _processUserSolicitationCancel(SollicitationModel item) async {
    if (item.id == null) return;
    setState(() => _isProcessingAction = true);
    try {
      final serviceCtrl =
          Provider.of<ServiceController>(context, listen: false);
      final response =
          await serviceCtrl.updateSollicitationStatus(item.id!, 'CANCELLED');
      if (response.status == true) {
        await _loadMySolicitations(forceRefresh: true);
        if (mounted) {
          FancyNotification.show(
            context,
            'Demande annulée',
            type: NotificationType.success,
          );
        }
      } else {
        if (mounted) {
          reportApiFailureToCrashlytics(
            'MyServicesPage',
            response: response,
            reason: 'user_cancel_sollicitation',
          );
          FancyNotification.show(
            context,
            response.errorMsg ??
                "L’annulation n’a pas abouti. Réessayez dans un instant.",
            isError: true,
          );
        }
      }
    } catch (e, st) {
      reportApiFailureToCrashlytics(
        'MyServicesPage',
        error: e,
        stackTrace: st,
        reason: 'user_cancel_sollicitation_exception',
      );
      if (mounted) {
        FancyNotification.show(
          context,
          "L’annulation n’a pas pu être enregistrée. Réessayez.",
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _handleSolicitationAction(
      SollicitationModel item, String status) async {
    Navigator.pop(context); // Fermer le BottomSheet

    final bool isAccept =
        status == 'APPROVED' || status.toUpperCase() == 'ACCEPTED';

    // Demander confirmation via le nouveau ModernCustomDialog pour le refus
    if (!isAccept) {
      ModernCustomDialog.show(
        context,
        title: "Refuser la demande",
        message:
            "Êtes-vous sûr de vouloir refuser cette demande ? Cette action est irréversible.",
        confirmText: "REFUSER",
        cancelText: "ANNULER",
        isDanger: true,
        onConfirm: () async {
          // Logique de refus
          await _processSolicitationStatusUpdate(item, status, isAccept);
        },
      );
      return;
    }

    // Pour l'acceptation, on lance directement
    await _processSolicitationStatusUpdate(item, status, isAccept);
  }

  Future<void> _processSolicitationStatusUpdate(
      SollicitationModel item, String status, bool isAccept) async {
    setState(() => _isProcessingAction = true);

    try {
      final serviceCtrl =
          Provider.of<ServiceController>(context, listen: false);
      final response =
          await serviceCtrl.updateSollicitationStatus(item.id!, status);

      if (response.status == true) {
        await _loadHostSolicitations(forceRefresh: true);

        if (mounted && isAccept) {
          _showActionSuccessDialog(item);
        } else if (mounted) {
          FancyNotification.show(
            context,
            "La demande a été refusée.",
            type: NotificationType.success,
          );
        }
      } else {
        if (mounted) {
          reportApiFailureToCrashlytics(
            'MyServicesPage',
            response: response,
            reason: 'host_sollicitation_status_$status',
          );
          FancyNotification.show(
            context,
            response.errorMsg ?? "La mise à jour n’a pas abouti. Réessayez.",
            isError: true,
          );
        }
      }
    } catch (e, st) {
      reportApiFailureToCrashlytics(
        'MyServicesPage',
        error: e,
        stackTrace: st,
        reason: 'host_sollicitation_status_exception',
      );
      if (mounted) {
        FancyNotification.show(
          context,
          "L’action n’a pas pu être enregistrée. Vérifiez la connexion et réessayez.",
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  void _showActionSuccessDialog(SollicitationModel item) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: _successColor.withOpacity(0.1),
                    shape: BoxShape.circle),
                child: Icon(Icons.check_circle_rounded,
                    color: _successColor, size: 60),
              ),
              SizedBox(height: 24),
              Text("Félicitations !",
                  style: GoogleFonts.inter(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              Text(
                "Vous avez validé cette demande de service. Vous pouvez maintenant télécharger le bon de validation ou le partager avec le client.",
                textAlign: TextAlign.center,
                style: TextStyle(color: _mediumGrey, height: 1.5),
              ),
              SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _shareSolicitationPdf(item),
                      icon: Icon(Icons.share_rounded, size: 18),
                      label: Text("PARTAGER"),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _downloadSolicitationPdf(item),
                      icon: Icon(Icons.download_rounded, size: 18),
                      label: Text("TÉLÉCHARGER"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("FERMER",
                    style: TextStyle(
                        color: _mediumGrey, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- PDF Logic for Services ---

  // --- PDF Logic for Services (Premium Redesign) ---

  Future<Uint8List> _buildSolicitationPdfBytes(SollicitationModel item) async {
    final doc = pw.Document();

    pw.Font? ttf;
    try {
      final fontData =
          await rootBundle.load('assets/fonts/Outfit-SemiBold.ttf');
      ttf = pw.Font.ttf(fontData);
    } catch (_) {}

    final now = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(DateTime.now());
    final prestation = item.prestation;
    final String currency = (item.deviseId == 1) ? "FC" : "\$";

    // Helper pour les lignes de détails
    pw.Widget _buildDetailRow(String label, String value) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label,
                style:
                    pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
            pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      );
    }

    doc.addPage(
      pw.Page(
        theme: ttf != null ? pw.ThemeData.withFont(base: ttf, bold: ttf) : null,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // --- HEADER PREMIUM ---
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#1976D2'),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'SOLLICITATION DE SERVICE',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Identifiant : #SOL-${item.id}',
                        style: pw.TextStyle(
                          color: PdfColor.fromInt(0xE6FFFFFF),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  if (_logoImage != null)
                    pw.Container(
                      width: 45,
                      height: 45,
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.white,
                        shape: pw.BoxShape.circle,
                      ),
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Image(_logoImage!),
                    ),
                ],
              ),
            ),

            pw.SizedBox(height: 24),

            // --- STATUT ET DATE ---
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Document Officiel CasaNayo',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    pw.Text('Généré le $now',
                        style: pw.TextStyle(
                            fontSize: 9, color: PdfColors.grey700)),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Text(frSolicitationStatus(item.status),
                      style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#1976D2'))),
                ),
              ],
            ),

            pw.SizedBox(height: 24),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 16),

            // --- SECTION 1: PRESTATAIRE & SERVICE ---
            pw.Text('1. DÉTAILS DU SERVICE & PRESTATAIRE',
                style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#1976D2'))),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(4))),
              child: pw.Column(
                children: [
                  _buildDetailRow('Service sollicité',
                      prestation?.title ?? 'Service CasaNayo'),
                  _buildDetailRow('Prestataire',
                      prestation?.username ?? 'Partenaire CasaNayo'),
                  _buildDetailRow(
                    'Téléphone prestataire',
                    () {
                      final pt = item.postByTel?.trim();
                      if (pt != null && pt.isNotEmpty && pt != 'null')
                        return pt;
                      final ph = prestation?.phone?.trim();
                      if (ph != null && ph.isNotEmpty && ph != 'null')
                        return ph;
                      return 'Non renseigné';
                    }(),
                  ),
                  _buildDetailRow(
                      'Localisation', prestation?.cityValue ?? 'Non spécifiée'),
                ],
              ),
            ),

            pw.SizedBox(height: 24),

            // --- SECTION 2: CLIENT ---
            pw.Text('2. DÉTAILS DU DEMANDEUR (CLIENT)',
                style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#1976D2'))),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(4))),
              child: pw.Column(
                children: [
                  _buildDetailRow('Nom du Client',
                      item.user?.username ?? 'Utilisateur CasaNayo'),
                  _buildDetailRow(
                      'Téléphone', item.user?.phone ?? 'Non renseigné'),
                  _buildDetailRow('Email', item.user?.email ?? 'Non renseigné'),
                ],
              ),
            ),

            pw.SizedBox(height: 24),

            // --- SECTION 3: OBJET ET BUDGET ---
            pw.Text('3. OBJET ET PÉRIODE DE LA DEMANDE',
                style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#1976D2'))),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey200),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(4))),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Période souhaitée',
                      '${_formatDate(item.startDate)} - ${_formatDate(item.endDate)}'),
                  _buildDetailRow('Budget proposé',
                      '${NumberFormat('#,###').format(item.budget)} $currency'),
                  if (item.description != null &&
                      item.description!.isNotEmpty) ...[
                    pw.SizedBox(height: 8),
                    pw.Divider(color: PdfColors.grey200),
                    pw.SizedBox(height: 8),
                    pw.Text('Description / Instructions :',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    pw.SizedBox(height: 4),
                    pw.Text(item.description!,
                        style: const pw.TextStyle(fontSize: 10),
                        textAlign: pw.TextAlign.justify),
                  ],
                ],
              ),
            ),

            pw.Spacer(),

            // --- FOOTER ---
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 8),
            pw.Text(
              "IMPORTANT : Ce document est une preuve de sollicitation de service via CasaNayo. Il ne constitue pas un contrat final tant qu'il n'est pas validé par l'acceptation formelle du prestataire. Pour toute assistance : +243 836 323 805.",
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              textAlign: pw.TextAlign.justify,
            ),
            pw.SizedBox(height: 12),
            pw.Center(
                child: pw.Text(
                    'Document généré par CasaNayo - www.casanayo.com',
                    style: const pw.TextStyle(fontSize: 8))),
          ],
        ),
      ),
    );
    return doc.save();
  }

  Future<void> _shareSolicitationPdf(SollicitationModel item) async {
    try {
      final bytes = await _buildSolicitationPdfBytes(item);
      final generationDate =
          DateFormat('dd_MMMM_yyyy_HH_mm', 'fr_FR').format(DateTime.now());
      final fileName =
          'Sollicitation_Service_Ref_${item.id}_du_$generationDate.pdf';

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(bytes);

      final xfile =
          XFile(tempFile.path, mimeType: 'application/pdf', name: fileName);
      await Share.shareXFiles([xfile],
          text: "Sollicitation de service CasaNayo - Ref: ${item.id}");
    } catch (e) {
      FancyNotification.show(context, "Impossible de partager le PDF");
    }
  }

  Future<void> _downloadSolicitationPdf(SollicitationModel item) async {
    try {
      final dir = await pickExportDirectoryOrNull();
      if (dir == null) {
        if (mounted) {
          FancyNotification.show(
            context,
            "Enregistrement annulé : aucun dossier sélectionné.",
            type: NotificationType.info,
          );
        }
        return;
      }

      final bytes = await _buildSolicitationPdfBytes(item);

      final generationDate =
          DateFormat('dd_MMMM_yyyy_HH_mm', 'fr_FR').format(DateTime.now());
      final fileName =
          'Sollicitation_Service_Ref_${item.id}_du_$generationDate.pdf';
      final file = File('${dir.path}/$fileName');

      await file.writeAsBytes(bytes);
      if (!mounted) return;
      FancyNotification.show(
        context,
        "PDF enregistré dans : ${describePickedDirectoryPathForUser(dir.path)}",
        type: NotificationType.success,
      );
    } catch (e) {
      FancyNotification.show(
        context,
        "Le PDF n’a pas pu être enregistré. Vérifiez l’espace disque et réessayez.",
        isError: true,
      );
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toUpperCase()) {
      case 'APPROVED':
      case 'ACCEPTED':
      case 'CONFIRMED':
        return _successColor;
      case 'PENDING':
        return _warningColor;
      case 'REJECTED':
      case 'CANCELLED':
        return _errorColor;
      default:
        return _mediumGrey;
    }
  }

  Widget _buildStatusBadge(PrestationModel prestation, {bool isGrid = false}) {
    Color bgColor;
    String text;

    if (prestation.isActive == true) {
      bgColor = _successColor;
      text = 'Actif';
    } else {
      bgColor = _mediumGrey;
      text = 'Inactif';
    }

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isGrid ? 8 : 12, vertical: isGrid ? 4 : 6),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(isGrid ? 12 : 20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: isGrid ? 10 : 12,
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart'; // Added for date formatting
import 'package:casa/utils/offline_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../controllers/CotationController.dart';
import '../models/CotationModel.dart';
import '../models/PrestationModel.dart';
import '../models/SollicitationModel.dart';
import '../utils/database/DatabaseHelper.dart';
import '../utils/review_eligibility.dart';
import 'CotationsListPage.dart';
import '../utils/FancyNotification.dart';
import 'package:casa/utils/casanayo_share_copy.dart';
import '../utils/FavoriteEartIcon.dart';
import 'ServiceFullScreenImageViewer.dart';


import 'RequestInterventionPage.dart';
import 'package:get_storage/get_storage.dart';
import 'package:casa/utils/StockageKeys.dart';
import '../utils/SubscriptionHelper.dart';
import '../controllers/ServiceController.dart'; // Added
import 'package:provider/provider.dart'; // Added
import 'auth/LoginScreen.dart';

class ServiceDetailPage extends StatefulWidget {
  final PrestationModel service;
  final String? serviceTypeName;

  /// Si on vient d'une sollicitation (MyServices -> Mes demandes), on peut afficher/ajouter l'avis lié à cette sollicitation.
  final int? sollicitationId;

  const ServiceDetailPage({
    Key? key,
    required this.service,
    this.serviceTypeName,
    this.sollicitationId,
  }) : super(key: key);

  @override
  _ServiceDetailPageState createState() => _ServiceDetailPageState();
}

class _ServiceDetailPageState extends State<ServiceDetailPage> {
  static const Color primaryColor = Color(0xFF1976D2);
  static const Color accentColor = Color(0xFF64B5F6);
  static const Color darkBlue = Color(0xFF0D47A1);

  late PageController _imageController;
  int _currentImageIndex = 0;
  Timer? _autoScrollTimer;
  ServiceController? _serviceCtrl;
  String? _lastGalleryKey;
  bool _loadingSollicitationCotations = false;
  bool _loadingPublicCotationsForPrestation = false;
  bool _loadingHostSollicitationCotationsForPrestation = false;
  /// `true` une fois le flux GET /public/cotation terminé — avant cela, on n’affiche pas
  /// seulement les cotations embarquées sur la prestation (souvent un sous-ensemble) : tout
  /// le monde, y compris non connecté, voit d’abord la liste filtrée par [prestationId] côté public.
  bool _publicCotationsLoadSettled = false;
  /// Copie des avis publics pour cette prestation (backup si cache pas encore notifié).
  List<CotationModel> _hostDerivedCotationsForPrestation = const [];
  static const String _ratedSolicitationsKey =
      'cotation_rated_sollicitation_ids';
  List<SollicitationModel> _mySolicitations = [];
  Set<int> _ratedSolicitationIds = {};
  bool _reviewContextReady = false;
  final TextEditingController _reviewCommentCtrl = TextEditingController();
  double _reviewScore = 5;
  bool _sendingReview = false;
  CotationController? _cotCtrl;

  static List<CotationModel> _mergeCotationsDedupe(
    List<CotationModel> a,
    List<CotationModel> b,
  ) {
    final byId = <int, CotationModel>{};
    final withoutId = <CotationModel>[];
    void take(CotationModel c) {
      final id = c.id;
      if (id != null) {
        byId[id] = c;
      } else {
        withoutId.add(c);
      }
    }

    for (final c in a) {
      take(c);
    }
    for (final c in b) {
      take(c);
    }
    final out = [...byId.values, ...withoutId];
    out.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
    return out;
  }

  /// Avis affichés : liste **publique** (même utilisateur non connecté) filtrée par
  /// `prestationId` == id prestation, puis fusion dédupliquée avec les cotations embarquées
  /// sur l’objet prestation **uniquement après** chargement public terminé (évite d’afficher
  /// seulement un sous-ensemble « embarqué » le temps du fetch).
  ///
  /// [sollicitationId] ne filtre pas la liste ; il sert uniquement au formulaire « Noter ».
  List<CotationModel> _displayCotations(
    PrestationModel service,
    CotationController cotCtrl,
  ) {
    final pid = service.id;
    final local = service.cotations ?? <CotationModel>[];

    if (pid != null) {
      final fromPublic = cotCtrl.cotationsForPrestation(pid);
      if (!_publicCotationsLoadSettled) {
        if (fromPublic.isNotEmpty) return fromPublic;
        if (_hostDerivedCotationsForPrestation.isNotEmpty) {
          return List<CotationModel>.from(_hostDerivedCotationsForPrestation);
        }
        return const [];
      }

      final merged = _mergeCotationsDedupe(fromPublic, local);
      if (merged.isNotEmpty) return merged;

      if (_hostDerivedCotationsForPrestation.isNotEmpty) {
        return _mergeCotationsDedupe(
          List<CotationModel>.from(_hostDerivedCotationsForPrestation),
          local,
        );
      }
      if (local.isNotEmpty) return local;
    } else {
      if (local.isNotEmpty) return local;
    }

    if (_hostDerivedCotationsForPrestation.isNotEmpty) {
      return List<CotationModel>.from(_hostDerivedCotationsForPrestation);
    }
    return const [];
  }

  List<Widget> _buildStarIcons(double rating, {double size = 16}) {
    // Clamp and convert to half-step (0.0, 0.5, 1.0 ...)
    final r = rating.isNaN ? 0.0 : rating.clamp(0.0, 5.0);
    final halfSteps = (r * 2).round(); // 4.5 -> 9
    final full = halfSteps ~/ 2;
    final hasHalf = halfSteps % 2 == 1;
    final empty = 5 - full - (hasHalf ? 1 : 0);

    final stars = <Widget>[];
    for (var i = 0; i < full; i++) {
      stars.add(Icon(Icons.star_rounded, color: Colors.amber, size: size));
    }
    if (hasHalf) {
      stars.add(Icon(Icons.star_half_rounded, color: Colors.amber, size: size));
    }
    for (var i = 0; i < empty; i++) {
      stars.add(
          Icon(Icons.star_border_rounded, color: Colors.amber, size: size));
    }
    return stars;
  }

  int? _currentUserIdFromStorage() {
    try {
      final raw = GetStorage().read(StockageKeys.userKey);
      if (raw is! Map) return null;
      final map = Map<String, dynamic>.from(raw);
      final nested = map['user'];
      final source = nested is Map ? Map<String, dynamic>.from(nested) : map;
      final value = source['userId'] ?? source['id'] ?? map['userId'] ?? map['id'];
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? '');
    } catch (_) {
      return null;
    }
  }

  Set<int> _ratedIdsIncludingPublic() {
    final ids = {..._ratedSolicitationIds};
    final me = _currentUserIdFromStorage();
    final cot = _cotCtrl;
    if (me == null || cot == null) return ids;
    for (final review in cot.publicCotations) {
      if (review.userId == me && review.sollicitationId != null) {
        ids.add(review.sollicitationId!);
      }
    }
    return ids;
  }

  SollicitationModel? get _eligibleSolicitation {
    return firstReviewableSolicitation(
      _mySolicitations,
      userId: _currentUserIdFromStorage(),
      prestationId: widget.service.id,
      alreadyRated: _ratedIdsIncludingPublic(),
      preferredId: widget.sollicitationId,
    );
  }

  bool get _alreadyReviewedThisService {
    final me = _currentUserIdFromStorage();
    final serviceId = widget.service.id;
    if (me == null || serviceId == null) return false;
    final rated = _ratedIdsIncludingPublic();
    for (final item in _mySolicitations) {
      final linked = item.prestationId ?? item.prestation?.id;
      if (linked != serviceId || item.id == null || !rated.contains(item.id)) {
        continue;
      }
      if (solicitationCanBeReviewed(item, userId: me)) return true;
    }
    return false;
  }

  Future<void> _loadReviewContext() async {
    final storage = GetStorage();
    final raw = storage.read(_ratedSolicitationsKey);
    final rated = <int>{};
    if (raw is List) {
      for (final entry in raw) {
        final id = int.tryParse(entry.toString());
        if (id != null && id > 0) rated.add(id);
      }
    }
    var mine = <SollicitationModel>[];
    if (_currentUserIdFromStorage() != null) {
      try {
        mine = await DatabaseHelper.instance.getAllUserSolicitations();
      } catch (_) {}
      if (mounted && mine.isNotEmpty) {
        setState(() {
          _ratedSolicitationIds = rated;
          _mySolicitations = mine;
          _reviewContextReady = true;
        });
      }
      try {
        final fresh = await context
            .read<ServiceController>()
            .fetchUserSollicitations(silent: true);
        if (fresh.isNotEmpty) mine = fresh;
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _ratedSolicitationIds = rated;
      _mySolicitations = mine;
      _reviewContextReady = true;
    });
  }

  Future<void> _rememberRatedSolicitation(int sollicitationId) async {
    _ratedSolicitationIds.add(sollicitationId);
    await GetStorage().write(
      _ratedSolicitationsKey,
      _ratedSolicitationIds.toList(),
    );
  }

  Future<void> _submitInlineReview() async {
    final me = _currentUserIdFromStorage();
    if (me == null) {
      FancyNotification.show(
        context,
        'Connectez-vous pour publier un avis.',
        type: NotificationType.info,
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
      );
      return;
    }
    final item = _eligibleSolicitation;
    final sid = item?.id;
    if (sid == null) {
      FancyNotification.show(
        context,
        'L’avis s’ouvre une fois la demande acceptée et la date de fin passée.',
        type: NotificationType.info,
      );
      return;
    }
    final text = _reviewCommentCtrl.text.trim();
    if (text.length < 3) {
      FancyNotification.show(
        context,
        'Écrivez au moins quelques mots.',
        type: NotificationType.warning,
      );
      return;
    }
    setState(() => _sendingReview = true);
    final response = await context.read<CotationController>().createCotation(
          userId: me,
          sollicitationId: sid,
          commentaire: text,
          cote: _reviewScore,
        );
    if (!mounted) return;
    setState(() => _sendingReview = false);
    if (response.status) {
      await _rememberRatedSolicitation(sid);
      _reviewCommentCtrl.clear();
      if (!mounted) return;
      setState(() => _reviewScore = 5);
      FancyNotification.show(
        context,
        'Merci pour votre avis.',
        type: NotificationType.success,
      );
      await context.read<CotationController>().fetchPublicCotations(
            forceRefresh: true,
          );
    } else if (mounted) {
      FancyNotification.show(
        context,
        response.errorMsg ?? 'Impossible d’enregistrer l’avis.',
        type: NotificationType.error,
      );
    }
  }

  Widget _buildReviewComposer() {
    final me = _currentUserIdFromStorage();
    final eligible = _eligibleSolicitation != null;
    if (me == null) {
      return _reviewNotice(
        title: 'Donner un avis',
        message: 'Connectez-vous pour noter ce service après l’intervention.',
        actionLabel: 'Se connecter',
        onAction: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => LoginScreen()),
          );
          if (mounted) _loadReviewContext();
        },
      );
    }
    if (!_reviewContextReady) {
      return _reviewNotice(
        title: 'Donner un avis',
        message: 'Vérification de vos demandes…',
      );
    }
    if (_alreadyReviewedThisService) {
      return _reviewNotice(
        title: 'Avis publié',
        message: 'Merci, votre avis sur ce service est déjà enregistré.',
      );
    }
    if (!eligible) {
      return _reviewNotice(
        title: 'Donner un avis',
        message:
            'L’avis s’ouvre ici une fois votre demande acceptée et la date de fin passée.',
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primaryColor.withOpacity(0.16)),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Donner un avis',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: darkBlue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'L’intervention est terminée. Vous pouvez noter ici, sans repasser par vos demandes.',
            style: GoogleFonts.inter(
              fontSize: 12.5,
              height: 1.35,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (index) {
              final filled = _reviewScore >= index + 1;
              return IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: _sendingReview
                    ? null
                    : () => setState(() => _reviewScore = (index + 1).toDouble()),
                icon: Icon(
                  filled ? Icons.star_rounded : Icons.star_border_rounded,
                  color: const Color(0xFFFFB300),
                  size: 32,
                ),
              );
            }),
          ),
          TextField(
            controller: _reviewCommentCtrl,
            minLines: 3,
            maxLines: 5,
            enabled: !_sendingReview,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Comment s’est passée l’intervention ?',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _sendingReview ? null : _submitInlineReview,
              style: FilledButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _sendingReview
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Publier l’avis',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewNotice({
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: darkBlue,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.4,
              color: const Color(0xFF64748B),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(backgroundColor: primaryColor),
              child: Text(
                actionLabel,
                style: GoogleFonts.inter(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Photo de profil du prestataire en premier, puis les autres visuels (sans doublon profil).
  List<String> _orderedGallery(PrestationModel s) {
    final profile = s.profile?.trim();
    final raw = List<String>.from(s.images ?? []);
    final rest = <String>[];
    for (final u in raw) {
      final t = u.trim();
      if (t.isEmpty) continue;
      if (profile != null &&
          profile.isNotEmpty &&
          t.toLowerCase() == profile.toLowerCase()) {
        continue;
      }
      if (!rest.contains(u)) rest.add(u);
    }
    final out = <String>[];
    if (profile != null && profile.isNotEmpty) {
      out.add(profile);
    }
    out.addAll(rest);
    if (out.isEmpty) {
      for (final u in raw) {
        if (u.trim().isNotEmpty) out.add(u);
      }
    }
    return out;
  }

  PrestationModel _serviceForCarousel(ServiceController ctrl) {
    final cur = ctrl.currentPrestation;
    if (cur != null && cur.id == widget.service.id) return cur;
    return widget.service;
  }

  void _syncAutoCarousel(ServiceController ctrl) {
    final imgs = _orderedGallery(_serviceForCarousel(ctrl));
    final key = imgs.join('\u0001');
    if (key == _lastGalleryKey) return;
    _lastGalleryKey = key;

    _autoScrollTimer?.cancel();
    if (imgs.length <= 1) return;

    _autoScrollTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted || !_imageController.hasClients) {
        timer.cancel();
        return;
      }
      final latest = _orderedGallery(_serviceForCarousel(ctrl));
      if (latest.isEmpty) return;
      final nextIndex = (_currentImageIndex + 1) % latest.length;
      _imageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  void _onServiceControllerNotify() {
    if (!mounted) return;
    final c = _serviceCtrl;
    if (c == null) return;
    _syncAutoCarousel(c);
  }

  void _onCotationControllerNotify() {
    if (!mounted || widget.service.id == null) return;
    final cotCtrl = _cotCtrl;
    if (cotCtrl == null) return;
    final pid = widget.service.id!;
    final list = cotCtrl.cotationsForPrestation(pid);
    list.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
    setState(() => _hostDerivedCotationsForPrestation = list);
  }

  /// Après GET /public/cotation : avis dont `prestationId` sur chaque cotation = id prestation.
  Future<void> _syncPrestationReviewsFromPublic(
    CotationController cotCtrl,
  ) async {
    if (!mounted || widget.service.id == null) return;
    final pid = widget.service.id!;

    final cotations = cotCtrl.cotationsForPrestation(pid);
    cotations.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
    if (!mounted) return;
    setState(() {
      _hostDerivedCotationsForPrestation = cotations;
      _loadingHostSollicitationCotationsForPrestation = false;
    });
  }

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR', null);
    _imageController = PageController(initialPage: 0);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final c = context.read<ServiceController>();
      _serviceCtrl = c;
      c.addListener(_onServiceControllerNotify);
      _syncAutoCarousel(c);
      if (widget.service.id != null) {
        c.getPrestationById(widget.service.id!);
      }

      final cotCtrl = context.read<CotationController>();

      // Avis : liste publique complète filtrée par prestation (pas seulement « mes » sollicitations).
      if (widget.service.id != null) {
        _cotCtrl = cotCtrl;
        cotCtrl.addListener(_onCotationControllerNotify);

        setState(() {
          _loadingPublicCotationsForPrestation = true;
          _loadingHostSollicitationCotationsForPrestation = true;
          if (widget.sollicitationId != null) {
            _loadingSollicitationCotations = true;
          }
        });

        Future<void> loadPublicReviews() async {
          try {
            await cotCtrl.fetchPublicCotations(forceRefresh: false);
            if (!mounted) return;
            setState(() {
              _loadingPublicCotationsForPrestation = false;
              if (widget.sollicitationId != null) {
                _loadingSollicitationCotations = false;
              }
            });
            await cotCtrl.fetchPublicCotations(forceRefresh: true);
            if (!mounted) return;
            await _syncPrestationReviewsFromPublic(cotCtrl);
          } finally {
            if (mounted) {
              setState(() => _publicCotationsLoadSettled = true);
            }
          }
        }

        loadPublicReviews();
      } else if (widget.sollicitationId != null) {
        setState(() => _loadingSollicitationCotations = true);
        cotCtrl.fetchPublicCotations(forceRefresh: false).whenComplete(() {
          if (!mounted) return;
          setState(() {
            _loadingSollicitationCotations = false;
            _publicCotationsLoadSettled = true;
          });
        });
        cotCtrl.fetchPublicCotations(forceRefresh: true);
      } else {
        setState(() => _publicCotationsLoadSettled = true);
      }
      _loadReviewContext();
    });
  }

  @override
  void dispose() {
    _cotCtrl?.removeListener(_onCotationControllerNotify);
    _serviceCtrl?.removeListener(_onServiceControllerNotify);
    _autoScrollTimer?.cancel();
    _reviewCommentCtrl.dispose();
    _imageController.dispose();
    super.dispose();
  }

  Future<void> _shareService(PrestationModel service) async {
    final priceText = _getPriceRange(service);

    final lines = <String>[
      '🔧 ${service.title ?? 'Service professionnel'} — ${service.cityValue}, ${service.communeValue}',
      '',
      '💰 $priceText',
    ];
    final desc = service.description?.trim();
    if (desc != null && desc.isNotEmpty) {
      lines.add('');
      lines.add(desc);
    }
    lines.add('');
    lines.add('Découvrez ce service sur CasaNayo !');
    final shareText =
        '${lines.join('\n')}\n\n${CasanayoShareCopy.listingShareFooter(listingId: service.id, kindLabel: 'service')}';

    try {
      final box = context.findRenderObject() as RenderBox?;
      if (box != null) {
        await Share.share(
          shareText,
          subject: 'Service ${service.title ?? ''}',
          sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
        );
      } else {
        await Share.share(
          shareText,
          subject: 'Service ${service.title ?? ''}',
        );
      }
    } catch (e) {
      if (mounted) {
        FancyNotification.show(
          context,
          'Erreur lors du partage: ${e.toString()}',
          type: NotificationType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // SILENT LOADING: Ecouter le controller pour mettre à jour les données dès qu'elles arrivent
    final serviceCtrl = context.watch<ServiceController>();
    final bool hasFullData =
        serviceCtrl.currentPrestation?.id == widget.service.id;
    final PrestationModel service =
        hasFullData ? serviceCtrl.currentPrestation! : widget.service;

    final images = _orderedGallery(service);
    final hasImages = images.isNotEmpty;
    final firstImage = hasImages ? images.first : null;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // AppBar avec carrousel d'images
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  hasImages && images.length > 1
                  ? _buildImageCarousel(images)
                  : firstImage != null
                      ? GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ServiceFullScreenImageViewer(
                                  imageUrls: images,
                                  initialIndex: 0,
                                ),
                              ),
                            );
                          },
                          child: OfflineNetworkImage(
                            imageUrl: firstImage,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: primaryColor.withOpacity(0.1),
                              child: Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      primaryColor),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: primaryColor.withOpacity(0.1),
                              child: Icon(
                                Icons.build,
                                size: 64,
                                color: primaryColor.withOpacity(0.3),
                              ),
                            ),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [primaryColor, darkBlue],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.build,
                              size: 64,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ),
                  Positioned(
                    left: 16,
                    bottom: 18,
                    child: _serviceTypeOverlay(service),
                  ),
                ],
              ),
            ),
            leading: IconButton(
              icon: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 16),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              // Bouton favoris
              Container(
                margin: EdgeInsets.only(right: 8),
                child: FavoriteHeartIcon(
                  propertyId: service.id.toString(),
                  isPrestation: true,
                  size: 24,
                  activeColor: Colors.red,
                  inactiveColor: Colors.white,
                ),
              ),
              // Bouton partager
              IconButton(
                icon: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.share, color: Colors.white, size: 18),
                ),
                onPressed: () => _shareService(service),
              ),
            ],
          ),

          // Contenu
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge Vérifié
                  if (service.isCertified == true)
                    Container(
                      margin: EdgeInsets.only(bottom: 16),
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Vérifié',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Titre et note
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              service.title ?? 'Service sans titre',
                              style: GoogleFonts.inter(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: darkBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // if (service.rating != null) ...[
                      //   // Rating removed as it is not present in PrestationModel
                      // ],
                    ],
                  ),
                  SizedBox(height: 24),

                  // Prix
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryColor, accentColor],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Prix',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          _getPriceRange(service),
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),

                  // Description
                  if (service.description != null) ...[
                    Text(
                      'Description',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: darkBlue,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      service.description!,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: Colors.grey[700],
                        height: 1.6,
                      ),
                    ),
                    SizedBox(height: 24),
                  ],

                  // Expérience professionnelle
                  if (service.experience != null &&
                      service.experience!.isNotEmpty) ...[
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  primaryColor.withOpacity(0.1),
                                  accentColor.withOpacity(0.1)
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.work_history,
                              color: primaryColor,
                              size: 28,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Expérience professionnelle',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  _formatExperience(service.experience),
                                  style: GoogleFonts.inter(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: darkBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),
                  ],

                  // Informations du publicateur
                  _buildPublicationInfoSectionFor(service),
                  SizedBox(height: 24),

                  // Informations de contact
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Informations de contact',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: darkBlue,
                          ),
                        ),
                        SizedBox(height: 16),
                        if (service.address != null &&
                            service.address!.isNotEmpty)
                          _buildInfoRow(
                            Icons.location_on,
                            "${service.cityValue}, ${service.communeValue}",
                            Colors.red,
                          ),
                        SizedBox(height: 12),
                        _buildInfoRow(
                          Icons.lock,
                          'Les contacts seront partagés après validation de votre demande.',
                          Colors.orange,
                          onTap: null,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),

                  // Disponibilité
                  if (service.plageJourPrestation != null ||
                      service.plageHeurePrestation != null)
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Disponibilité',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: darkBlue,
                            ),
                          ),
                          SizedBox(height: 12),
                          if (service.plageJourPrestation != null &&
                              service.plageJourPrestation!.isNotEmpty)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: service.plageJourPrestation!
                                  .split(',')
                                  .map((day) {
                                return Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    day.trim(),
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: primaryColor,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          if (service.plageHeurePrestation != null &&
                              service.plageHeurePrestation!.isNotEmpty) ...[
                            SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.access_time,
                                    size: 16, color: primaryColor),
                                SizedBox(width: 8),
                                Text(
                                  service.plageHeurePrestation!,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  SizedBox(height: 24),

                  // Réalisations précédentes (galerie)
                  if (hasImages && images.length > 1) ...[
                    SizedBox(height: 24),
                    Text(
                      'Réalisations précédentes',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: darkBlue,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Quelques travaux déjà réalisés par ce prestataire.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 12),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: images.length,
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ServiceFullScreenImageViewer(
                                    imageUrls: images,
                                    initialIndex: index,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              width: 120,
                              margin: EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: primaryColor.withOpacity(0.2),
                                  width: 2,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: OfflineNetworkImage(
                                  imageUrl: images[index],
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: primaryColor.withOpacity(0.1),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                primaryColor),
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                    color: primaryColor.withOpacity(0.1),
                                    child: Icon(
                                      Icons.image,
                                      color: primaryColor.withOpacity(0.3),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  // Avis clients (API `cotation`)
                  SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Avis des clients',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: darkBlue,
                        ),
                      ),
                      Builder(builder: (context) {
                        final cotCtrl = context.watch<CotationController>();
                        final activeList = _displayCotations(service, cotCtrl);

                        return TextButton.icon(
                          onPressed: activeList.isEmpty
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CotationsListPage(
                                        cotations: activeList,
                                        title: service.title ?? 'Avis clients',
                                      ),
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.arrow_forward_ios, size: 14),
                          label: Text(
                            'Voir tous',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: primaryColor,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                  SizedBox(height: 12),
                  Builder(builder: (context) {
                    final hasSollicitation = widget.sollicitationId != null;
                    final cotCtrl = context.watch<CotationController>();
                    final list = _displayCotations(service, cotCtrl);
                    final reviewsLoading = widget.service.id != null
                        ? (_loadingPublicCotationsForPrestation ||
                            _loadingHostSollicitationCotationsForPrestation)
                        : (hasSollicitation && _loadingSollicitationCotations);
                    final awaitingPublicReviews = widget.service.id != null &&
                        !_publicCotationsLoadSettled;

                    // Liste publique complète (invités inclus) : ne pas conclure trop tôt.
                    if (awaitingPublicReviews && list.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: primaryColor.withOpacity(0.10)),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)),
                            const SizedBox(width: 10),
                            Text(
                              'Chargement des avis...',
                              style: GoogleFonts.inter(
                                  fontSize: 13, color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      );
                    }

                    // Quand on ouvre la page depuis "partout", la prestation détaillée arrive en async.
                    // Éviter d'afficher "Aucun avis" trop tôt si on n'a pas encore reçu les cotations.
                    if (reviewsLoading && list.isEmpty && hasFullData) {
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: primaryColor.withOpacity(0.10)),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)),
                            const SizedBox(width: 10),
                            Text(
                              'Chargement des avis...',
                              style: GoogleFonts.inter(
                                  fontSize: 13, color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      );
                    }

                    if (!hasSollicitation &&
                        !hasFullData &&
                        service.cotations == null) {
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: primaryColor.withOpacity(0.10)),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Chargement des avis...',
                              style: GoogleFonts.inter(
                                  fontSize: 13, color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      );
                    }

                    if (list.isEmpty) {
                      return Text(
                        'Aucun avis pour le moment.',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      );
                    }
                    final preview = list.length > 3 ? list.sublist(0, 3) : list;
                    final widgets = <Widget>[];
                    for (var i = 0; i < preview.length; i++) {
                      if (i > 0) widgets.add(const SizedBox(height: 8));
                      widgets.add(_buildReviewCardFromCotation(preview[i]));
                    }
                    return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: widgets);
                  }),

                  const SizedBox(height: 16),
                  _buildReviewComposer(),

                  // Bouton principal : Demander une intervention
                  SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final storage = GetStorage();
                        final token = storage.read(StockageKeys.tokenKey);

                        if (token == null) {
                          FancyNotification.show(context,
                              "Vous devez être connecté pour demander une intervention",
                              type: NotificationType.info);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => LoginScreen()),
                          );
                        } else {
                          SubscriptionHelper
                              .checkCertifiedPremiumForSensitiveAction(
                            context: context,
                            onProceed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RequestInterventionPage(
                                    service: service,
                                  ),
                                ),
                              );
                            },
                          );
                        }
                      },
                      icon: Icon(Icons.handshake),
                      label: Text('Demander une intervention'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Les coordonnées seront partagées après validation de votre demande.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 24 + MediaQuery.viewPaddingOf(context).bottom),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _serviceTypeOverlay(PrestationModel service) {
    return Consumer<ServiceController>(
      builder: (context, serviceController, _) {
        final resolvedName = (widget.serviceTypeName ??
                serviceController.getServiceName(service.serviceId))
            .trim();
        if (resolvedName.isEmpty) return const SizedBox.shrink();
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.62),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              resolvedName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageCarousel(List<String> images) {
    return Stack(
      children: [
        PageView.builder(
          controller: _imageController,
          itemCount: images.length,
          onPageChanged: (index) {
            setState(() {
              _currentImageIndex = index;
            });
          },
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ServiceFullScreenImageViewer(
                      imageUrls: images,
                      initialIndex: index,
                    ),
                  ),
                );
              },
              child: Hero(
                tag: 'service_image_$index',
                child: OfflineNetworkImage(
                  imageUrl: images[index],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  placeholder: (context, url) => Container(
                    color: primaryColor.withOpacity(0.1),
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: primaryColor.withOpacity(0.1),
                    child: Icon(
                      Icons.build,
                      size: 64,
                      color: primaryColor.withOpacity(0.3),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        // Indicateur de page
        if (images.length > 1)
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentImageIndex + 1} / ${images.length}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String text, Color color,
      {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ),
          if (onTap != null)
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
        ],
      ),
    );
  }

  String _formatPrice(num price) {
    if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(1)}M';
    }
    // Logic for 'K' removed as per request
    return price.toStringAsFixed(0);
  }

  String _getPriceRange(PrestationModel service) {
    if (service.minPrice == null) return 'Prix sur demande';

    final double minPrice = service.minPrice!;
    // Max price ignored for display as per request ("À partir de")

    final displayCurrency = service.currency;

    return 'À partir de ${_formatPrice(minPrice)} $displayCurrency';
  }

  String _formatExperience(String? experience) {
    if (experience == null || experience.isEmpty) {
      return 'Non spécifié';
    }
    // Assuming experience is a number string representing years
    try {
      final int years = int.parse(experience);
      if (years > 0) {
        return '$years ${years > 1 ? 'ans' : 'an'}';
      }
    } catch (e) {
      // Not a number, return as is
    }
    return experience;
  }

  void _makePhoneCall(BuildContext context, String phone) {
    FancyNotification.show(
      context,
      'Numéro: $phone',
      type: NotificationType.info,
    );
    // TODO: Implémenter l'appel téléphonique avec url_launcher
  }

  void _openWhatsApp(BuildContext context, String phone) {
    FancyNotification.show(
      context,
      'Numéro WhatsApp: $phone',
      type: NotificationType.info,
    );
    // TODO: Implémenter l'ouverture WhatsApp avec url_launcher
  }

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'À l\'instant';
        }
        return 'Il y a ${difference.inMinutes} ${difference.inMinutes > 1 ? 'minutes' : 'minute'}';
      }
      return 'Aujourd\'hui à ${date.hour.toString().padLeft(2, '0')}h${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Hier à ${date.hour.toString().padLeft(2, '0')}h${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays} ${difference.inDays > 1 ? 'jours' : 'jour'}';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return 'Il y a ${weeks} ${weeks > 1 ? 'semaines' : 'semaine'}';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return 'Il y a ${months} ${months > 1 ? 'mois' : 'mois'}';
    } else {
      final years = (difference.inDays / 365).floor();
      return 'Il y a ${years} ${years > 1 ? 'ans' : 'an'}';
    }
  }

  Widget _buildReviewCardFromCotation(CotationModel c) {
    final directName = c.name?.trim();
    final name = (directName != null && directName.isNotEmpty)
        ? directName
        : (c.user?.displayFullName ?? 'Client');
    final directPhoto = c.profile?.trim();
    final datePosted =
        c.createdAt != null ? DateTime.tryParse(c.createdAt!) : null;
    return _buildReviewCard(
      name: name,
      avatarUrl: (directPhoto != null && directPhoto.isNotEmpty)
          ? directPhoto
          : c.user?.profilePicture,
      rating: c.cote ?? 0,
      comment: (c.commentaire != null && c.commentaire!.trim().isNotEmpty)
          ? c.commentaire!.trim()
          : '—',
      datePosted: datePosted,
    );
  }

  Widget _buildReviewCard({
    required String name,
    String? avatarUrl,
    required double rating,
    required String comment,
    DateTime? datePosted,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: primaryColor.withOpacity(0.1),
                backgroundImage:
                    (avatarUrl != null && avatarUrl.trim().isNotEmpty)
                        ? OfflineImageProvider(avatarUrl.trim())
                        : null,
                child: (avatarUrl != null && avatarUrl.trim().isNotEmpty)
                    ? null
                    : Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(
                            color: primaryColor, fontWeight: FontWeight.bold),
                      ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: darkBlue,
                      ),
                    ),
                    Row(
                      children: [
                        ..._buildStarIcons(rating, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          rating.toStringAsFixed(1),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        if (datePosted != null) ...[
                          SizedBox(width: 8),
                          Text(
                            '• ${_getTimeAgo(datePosted)}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            comment,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.grey[700],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPublicationInfoSectionFor(PrestationModel service) {
    // Modified to use properties available in PrestationModel only
    final String? username = service.username;
    final String? postBy = service.postBy;
    final String? profilePicture = service.profile;

    String publisherName = '';

    // Essayer postBy d'abord car souvent plus fiable (ex: @LéaReckiel)
    if (postBy != null && postBy.isNotEmpty && postBy != 'null') {
      publisherName = postBy.replaceAll('@', '').trim();
    }
    // Sinon essayer username
    else if (username != null && username.isNotEmpty && username != 'null') {
      publisherName = username.replaceAll('@', '').trim();
    }

    if (publisherName.isEmpty) publisherName = 'Prestataire';

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Publié par',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: darkBlue,
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryColor.withOpacity(0.2),
                      accentColor.withOpacity(0.2)
                    ],
                  ),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                      color: primaryColor.withOpacity(0.3), width: 2),
                ),
                child: GestureDetector(
                  onTap: () {
                    if (profilePicture != null && profilePicture.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ServiceFullScreenImageViewer(
                            imageUrls: [profilePicture],
                            initialIndex: 0,
                          ),
                        ),
                      );
                    }
                  },
                  child: Hero(
                    tag: 'service_profile_${service.id}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(23),
                      child: profilePicture != null && profilePicture.isNotEmpty
                          ? OfflineNetworkImage(
                              imageUrl: profilePicture,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Center(
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                              errorWidget: (context, url, error) => Center(
                                  child: Text(
                                publisherName.isNotEmpty
                                    ? publisherName[0].toUpperCase()
                                    : 'A',
                                style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor),
                              )),
                            )
                          : Center(
                              child: Text(
                                publisherName.isNotEmpty
                                    ? publisherName[0].toUpperCase()
                                    : 'A',
                                style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            publisherName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 6),
                        if (service.isCertified ?? false)
                          Icon(Icons.verified, size: 16, color: Colors.blue),
                      ],
                    ),
                    if (service.dateCreated != null)
                      Text(
                        'Publié le ${DateFormat('dd MMM yyyy', 'fr_FR').format(service.dateCreated!)}',
                        style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:casa/controllers/PropertyCtrl.dart';
import 'package:casa/models/PropertyModel.dart';
import 'package:casa/screens/HotelRoomDetailPage.dart';
import 'package:casa/screens/auth/LoginScreen.dart';
import 'package:casa/utils/hotel_room_price.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/Routes.dart';
import 'package:casa/utils/SubscriptionHelper.dart';
import 'package:casa/utils/StockageKeys.dart';
import 'package:casa/utils/database/DatabaseHelper.dart';
import 'package:casa/utils/property_snapshot_merge.dart';
import 'package:casa/utils/cache/HotelImageCache.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:get_storage/get_storage.dart';
import 'package:provider/provider.dart';
import 'dart:async';

/// Détail hôtel : présentation « agence », liste des chambres et accès réservation.
class HotelDetailPage extends StatefulWidget {
  final PropertyModel property;
  final String? heroTag;

  const HotelDetailPage({
    Key? key,
    required this.property,
    this.heroTag,
  }) : super(key: key);

  @override
  State<HotelDetailPage> createState() => _HotelDetailPageState();
}

class _HotelDetailPageState extends State<HotelDetailPage> {
  static const Color _primary = Color(0xFF1976D2);
  static const Color _bg = Color(0xFFF9FAFB);
  static const Color _surface = Colors.white;
  static const Color _muted = Color(0xFF6B7280);
  static const Color _text = Color(0xFF111827);
  static const Color _border = Color(0xFFE5E7EB);

  final GetStorage _storage = GetStorage();

  PropertyModel? _model;
  bool _roomsLoading = true;
  final PageController _heroController = PageController();
  int _heroIndex = 0;
  Timer? _heroTimer;
  PropertyController? _propertyCtrl;
  VoidCallback? _propertyCtrlListener;

  @override
  void initState() {
    super.initState();
    _model = widget.property;
    _roomsLoading = widget.property.hotelStructure?.isEmpty ?? true;
    // Afficher immédiatement le snapshot (même partiel), puis rafraîchir (SWR) en arrière-plan.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDetail());
  }
  
  @override
  void dispose() {
    final c = _propertyCtrl;
    final l = _propertyCtrlListener;
    if (c != null && l != null) {
      c.removeListener(l);
    }
    _heroTimer?.cancel();
    _heroController.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    final id = widget.property.propertyId;
    if (id == null) {
      if (mounted) setState(() => _roomsLoading = false);
      return;
    }

    // Écouter les mises à jour du controller (enrichissement chambres en arrière-plan).
    _propertyCtrl ??= context.read<PropertyController>();
    _propertyCtrlListener ??= () async {
      if (!mounted) return;
      try {
        final cached = await DatabaseHelper.instance
            .getCategoryPropertyById(DatabaseHelper.tableHotels, id);
        if (!mounted || cached == null) return;
        final current = _model ?? widget.property;
        final hydrated = await DatabaseHelper.instance.hydrateHotelFromRoomCache(cached);
        final merged = PropertySnapshotMerge.mergeFillMissing(current, hydrated);
        if (_roomSignature(current) != _roomSignature(merged)) {
          setState(() {
            _model = merged;
            if ((merged.hotelStructure?.isNotEmpty ?? false)) _roomsLoading = false;
          });
          _restartHeroAutoScroll();
        }
      } catch (_) {}
    };
    _propertyCtrl!.removeListener(_propertyCtrlListener!);
    _propertyCtrl!.addListener(_propertyCtrlListener!);

    // 1) Charger immédiatement depuis SQLite (stale) si disponible.
    try {
      final cached = await DatabaseHelper.instance
          .getCategoryPropertyById(DatabaseHelper.tableHotels, id);
      if (mounted && cached != null) {
        final hydrated = await DatabaseHelper.instance.hydrateHotelFromRoomCache(cached);
        if (!mounted) return;
        setState(() {
          _model = PropertySnapshotMerge.mergeFillMissing(widget.property, hydrated);
          if ((_model?.hotelStructure?.isNotEmpty ?? false)) _roomsLoading = false;
        });
        _restartHeroAutoScroll();
      }
    } catch (_) {}

    // 2) Rafraîchir en arrière-plan depuis l’API (et cache DB mis à jour dans le controller).
    final c = _propertyCtrl ?? context.read<PropertyController>();
    final fresh = await c.getPropertyById(
      id,
      propertyTypeId: 5,
      mergeWith: widget.property,
    );
    if (!mounted) return;
    setState(() {
      _model = fresh ?? widget.property;
      _roomsLoading = false;
    });
    _restartHeroAutoScroll();
  }
  
  List<String> _heroImages(PropertyModel p) {
    final urls = <String>[];
    final fromList = p.propertyImage ?? [];
    for (final i in fromList) {
      final u = _imgUrl(i.path);
      if (u.isNotEmpty) urls.add(u);
    }
    final fallback = _imgUrl(p.image);
    if (fallback.isNotEmpty && !urls.contains(fallback)) urls.insert(0, fallback);
    return urls;
  }
  
  void _restartHeroAutoScroll() {
    _heroTimer?.cancel();
    final p = _model ?? widget.property;
    final imgs = _heroImages(p);
    if (!mounted || imgs.length < 2) return;
    _heroTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final next = (_heroIndex + 1) % imgs.length;
      _heroController.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }
  
  String _roomSignature(PropertyModel p) {
    final rooms = p.hotelStructure ?? const <HotelRoomStructure>[];
    return rooms.map((s) {
      final id = s.chambre?.id ?? 0;
      final imgs = s.images?.length ?? 0;
      final title = s.chambre?.title ?? '';
      final price = s.chambre?.price ?? 0;
      return '$id:$imgs:$title:$price';
    }).join('|');
  }

  List<String> _galleryImages(PropertyModel p) {
    final urls = <String>[];
    urls.addAll(_heroImages(p));
    final rooms = p.hotelStructure ?? [];
    for (final s in rooms) {
      final imgs = s.images ?? [];
      for (final i in imgs) {
        final u = _imgUrl(i.path);
        if (u.isNotEmpty) urls.add(u);
      }
    }
    // de-dup en gardant l'ordre
    final seen = <String>{};
    final out = <String>[];
    for (final u in urls) {
      if (seen.add(u)) out.add(u);
    }
    return out;
  }
  
  void _openGalleryViewer(List<String> urls, {int initialIndex = 0}) {
    if (urls.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final c = PageController(initialPage: initialIndex);
        final top = MediaQuery.viewPaddingOf(ctx).top;
        final bottom = MediaQuery.viewPaddingOf(ctx).bottom;
        return Dialog(
          insetPadding: EdgeInsets.fromLTRB(12, 12 + top, 12, 12 + bottom),
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              PageView.builder(
                controller: c,
                itemCount: urls.length,
                itemBuilder: (_, i) => HotelCachedImage(
                  url: urls[i],
                  fit: BoxFit.contain,
                  placeholderColor: Colors.black,
                  error: const Center(
                    child: Icon(Icons.broken_image_rounded, color: Colors.white70, size: 56),
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _imgUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    return path.startsWith('http') ? path : path;
  }

  void _openBooking(PropertyModel hotel, HotelRoomModel room) {
    final token = _storage.read(StockageKeys.tokenKey);
    if (token == null) {
      FancyNotification.show(
        context,
        'Connectez-vous pour réserver une chambre',
        type: NotificationType.info,
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
      );
      return;
    }
    if (room.id == null) {
      FancyNotification.show(
        context,
        'Chambre indisponible pour la réservation',
        type: NotificationType.error,
      );
      return;
    }
    SubscriptionHelper.checkPremiumForPropertyReservation(
      context: context,
      onProceed: () {
        Navigator.pushNamed(
          context,
          Routes.bookingVisitPageRoute,
          arguments: {
            'property': hotel,
            'chambreId': room.id,
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _model ?? widget.property;
    final heroImages = _heroImages(p);
    final rooms = p.hotelStructure ?? [];
    final gallery = _galleryImages(p);
    // Barre système (gestes ou boutons, ex. Samsung A17) : le corps défile dessous.
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      backgroundColor: _bg,
      body: RefreshIndicator(
        color: _primary,
        onRefresh: _loadDetail,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 288,
              pinned: true,
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  p.title ?? 'Hôtel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    shadows: [
                      Shadow(blurRadius: 6, color: Colors.black38),
                    ],
                  ),
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (heroImages.isNotEmpty)
                      Hero(
                        tag: widget.heroTag ?? 'hotel_hero_${p.propertyId ?? 0}',
                        child: PageView.builder(
                          controller: _heroController,
                          itemCount: heroImages.length,
                          onPageChanged: (i) => setState(() => _heroIndex = i),
                          itemBuilder: (context, i) => HotelCachedImage(
                            url: heroImages[i],
                            fit: BoxFit.cover,
                            placeholderColor: _border,
                            error: Container(
                              color: _border,
                              child: Icon(Icons.hotel, color: _muted.withValues(alpha: 0.5), size: 64),
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        color: _primary.withValues(alpha: 0.25),
                        child: Center(
                          child: Icon(Icons.hotel_rounded, color: _primary.withValues(alpha: 0.6), size: 72),
                        ),
                      ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.05),
                            Colors.black.withValues(alpha: 0.55),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      bottom: heroImages.length > 1 ? 36 : 18,
                      child: _HotelTransactionChip(property: p),
                    ),
                    if (heroImages.length > 1)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 18,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(heroImages.length, (i) {
                            final active = i == _heroIndex;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: active ? 14 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: active ? Colors.white : Colors.white70,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            );
                          }),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 28 + bottomSafe),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HotelAddressBlock(property: p),
                    const SizedBox(height: 16),
                    Text(
                      p.description?.trim().isNotEmpty == true
                          ? p.description!.trim()
                          : 'Découvrez cet établissement et ses chambres.',
                      style: const TextStyle(
                        color: _text,
                        height: 1.55,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 22,
                          decoration: BoxDecoration(
                            color: _primary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Chambres',
                          style: TextStyle(
                            color: _text,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _primary.withValues(alpha: 0.25)),
                          ),
                          child: Text(
                            '${rooms.length} offre${rooms.length > 1 ? 's' : ''}',
                            style: const TextStyle(
                              color: _primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (rooms.isEmpty && _roomsLoading)
                      const _HotelRoomsShimmer()
                    else if (rooms.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Text(
                          'Les chambres seront affichées dès qu’elles seront publiées.',
                          style: TextStyle(color: _muted, height: 1.4),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ...rooms.asMap().entries.map((e) {
                        final idx = e.key;
                        final structure = e.value;
                        return Padding(
                          padding: EdgeInsets.only(bottom: idx == rooms.length - 1 ? 0 : 14),
                          child: _RoomCard(
                            structure: structure,
                            hotel: p,
                            accent: _primary,
                            surface: _surface,
                            text: _text,
                            muted: _muted,
                            border: _border,
                            onOpenDetail: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => HotelRoomDetailPage(
                                    hotel: p,
                                    structure: structure,
                                    onReserveRoom: (r) => _openBooking(p, r),
                                  ),
                                ),
                              );
                            },
                            onReserve: () {
                              final ch = structure.chambre;
                              if (ch != null) _openBooking(p, ch);
                            },
                          ),
                        );
                      }),
                    if (gallery.isNotEmpty) ...[
                      const SizedBox(height: 26),
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 22,
                            decoration: BoxDecoration(
                              color: _primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Galerie',
                            style: TextStyle(
                              color: _text,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => _openGalleryViewer(gallery, initialIndex: 0),
                            child: const Text('Tout voir'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _HotelGalleryGrid(
                        images: gallery,
                        border: _border,
                        muted: _muted,
                        onOpen: (index) => _openGalleryViewer(gallery, initialIndex: index),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  final HotelRoomStructure structure;
  final PropertyModel hotel;
  final Color accent;
  final Color surface;
  final Color text;
  final Color muted;
  final Color border;
  final VoidCallback onOpenDetail;
  final VoidCallback onReserve;

  const _RoomCard({
    required this.structure,
    required this.hotel,
    required this.accent,
    required this.surface,
    required this.text,
    required this.muted,
    required this.border,
    required this.onOpenDetail,
    required this.onReserve,
  });

  @override
  Widget build(BuildContext context) {
    final room = structure.chambre;
    final imgs = structure.images ?? [];
    if (room == null) return const SizedBox.shrink();

    final photos = imgs
        .map((img) => (img.path ?? '').trim())
        .where((url) => url.isNotEmpty)
        .toList();
    final priceView = hotelRoomPriceView(room, hotel);

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: onOpenDetail,
            behavior: HitTestBehavior.opaque,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (photos.isNotEmpty)
                  Stack(
                    children: [
                      SizedBox(
                        height: 188,
                        width: double.infinity,
                        child: HotelCachedImage(
                          url: photos.first,
                          fit: BoxFit.cover,
                          height: 188,
                          placeholderColor: border,
                          error: Container(
                            color: border,
                            child: Icon(Icons.bed,
                                color: muted.withValues(alpha: 0.4), size: 48),
                          ),
                        ),
                      ),
                      if (photos.length > 1)
                        Positioned(
                          right: 10,
                          bottom: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${photos.length} photos',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  )
                else
                  Container(
                    height: 120,
                    color: border,
                    child: Icon(Icons.bed_outlined,
                        color: muted.withValues(alpha: 0.45), size: 40),
                  ),
                if (photos.length > 1)
                  SizedBox(
                    height: 72,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                      itemCount: photos.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: HotelCachedImage(
                          url: photos[i],
                          width: 72,
                          height: 62,
                          fit: BoxFit.cover,
                          placeholderColor: border,
                          error: Container(
                            width: 72,
                            height: 62,
                            color: border,
                            child: Icon(Icons.image_not_supported_rounded, color: muted, size: 18),
                          ),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              room.title ?? 'Chambre',
                              style: TextStyle(
                                color: text,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                priceView.amount,
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (priceView.period.isNotEmpty)
                                Text(
                                  priceView.period,
                                  style: TextStyle(
                                    color: muted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      if (room.description != null &&
                          room.description!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          room.description!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: muted, height: 1.4, fontSize: 13),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _chip(Icons.king_bed_outlined,
                              '${room.numberPiece ?? 1} pièce(s)'),
                          const SizedBox(width: 8),
                          _chip(
                            Icons.circle,
                            room.available == false
                                ? 'Complet'
                                : 'Disponible',
                            dot: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onReserve,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Réserver cette chambre',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, letterSpacing: 0.2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, {bool dot = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: label == 'Complet' ? Colors.redAccent : Colors.greenAccent,
                shape: BoxShape.circle,
              ),
            )
          else
            Icon(icon, size: 14, color: muted),
          if (!dot) const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _HotelTransactionChip extends StatelessWidget {
  final PropertyModel property;

  const _HotelTransactionChip({required this.property});

  @override
  Widget build(BuildContext context) {
    final sale = property.isSaleListing;
    final label = property.publicTransactionLabel.toUpperCase();
    final color = sale ? const Color(0xFF047857) : const Color(0xFF1565C0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _HotelRoomsShimmer extends StatelessWidget {
  const _HotelRoomsShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(3, (index) {
        return Padding(
          padding: EdgeInsets.only(bottom: index == 2 ? 0 : 14),
          child: Shimmer.fromColors(
            baseColor: const Color(0xFFE5E7EB),
            highlightColor: const Color(0xFFF9FAFB),
            child: Container(
              height: 210,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _HotelAddressBlock extends StatelessWidget {
  final PropertyModel property;

  const _HotelAddressBlock({required this.property});

  static const Color _primary = Color(0xFF1976D2);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _text = Color(0xFF111827);
  static const Color _border = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    final street = _clean(property.address);
    final placeParts = <String>[
      _clean(property.quartierValue ?? property.quartier),
      _clean(property.communeValue),
      _clean(property.cityValue),
      _clean(property.countryValue),
    ].where((part) => part.isNotEmpty).toList();
    final extra = placeParts.where((part) {
      if (street.isEmpty) return true;
      return !street.toLowerCase().contains(part.toLowerCase());
    }).toList();
    final uniqueExtra = _joinUnique(extra);
    final headline = street.isNotEmpty ? street : uniqueExtra;
    final subtitle = street.isNotEmpty ? uniqueExtra : '';

    if (headline.isEmpty) {
      return const Row(
        children: [
          Icon(Icons.place_rounded, color: _primary, size: 18),
          SizedBox(width: 6),
          Text('Localisation', style: TextStyle(color: _muted, fontSize: 14)),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.place_rounded, color: _primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Adresse',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  headline,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _clean(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return '';
    return text;
  }

  static String _joinUnique(List<String?> values) {
    final parts = <String>[];
    for (final raw in values) {
      final text = _clean(raw);
      if (text.isEmpty) continue;
      if (parts.any((part) => part.toLowerCase() == text.toLowerCase())) continue;
      parts.add(text);
    }
    return parts.join(', ');
  }
}

class _HotelGalleryGrid extends StatelessWidget {
  final List<String> images;
  final Color border;
  final Color muted;
  final void Function(int index) onOpen;

  const _HotelGalleryGrid({
    required this.images,
    required this.border,
    required this.muted,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    const maxVisible = 6;
    final visible = images.length > maxVisible ? maxVisible : images.length;
    final extra = images.length - maxVisible;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: visible,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        final showMore = extra > 0 && index == visible - 1;
        return GestureDetector(
          onTap: () => onOpen(index),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                HotelCachedImage(
                  url: images[index],
                  fit: BoxFit.cover,
                  placeholderColor: border,
                  error: Container(
                    color: border,
                    child: Icon(Icons.image_not_supported_rounded, color: muted.withValues(alpha: 0.5)),
                  ),
                ),
                if (showMore)
                  ColoredBox(
                    color: Colors.black.withValues(alpha: 0.5),
                    child: Center(
                      child: Text(
                        '+$extra',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

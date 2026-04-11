import 'package:casa/controllers/PropertyCtrl.dart';
import 'package:casa/models/PropertyModel.dart';
import 'package:casa/screens/HotelRoomDetailPage.dart';
import 'package:casa/screens/auth/LoginScreen.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/Routes.dart';
import 'package:casa/utils/StockageKeys.dart';
import 'package:casa/utils/SubscriptionHelper.dart';
import 'package:casa/utils/database/DatabaseHelper.dart';
import 'package:casa/utils/property_snapshot_merge.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:provider/provider.dart';

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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _model = widget.property;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDetail());
  }

  Future<void> _loadDetail() async {
    final id = widget.property.propertyId;
    if (id == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final c = context.read<PropertyController>();
    final fresh = await c.getPropertyById(
      id,
      propertyTypeId: 5,
      mergeWith: widget.property,
    );
    if (!mounted) return;
    setState(() {
      _model = fresh ?? widget.property;
      _loading = false;
    });
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
    final images = p.propertyImage ?? [];
    final cover = images.isNotEmpty ? _imgUrl(images.first.path) : (p.image ?? '');
    final rooms = p.hotelStructure ?? [];

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
                    if (cover.isNotEmpty)
                      Hero(
                        tag: widget.heroTag ??
                            'hotel_hero_${p.propertyId ?? 0}',
                        child: CachedNetworkImage(
                          imageUrl: cover,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: _border),
                          errorWidget: (_, __, ___) => Container(
                            color: _border,
                            child: Icon(Icons.hotel, color: _muted.withValues(alpha: 0.5), size: 64),
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
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _primary,
                            ),
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        Icon(Icons.place_rounded, color: _primary, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            () {
                              final parts = <String>[];
                              if (p.communeValue?.isNotEmpty == true) {
                                parts.add(p.communeValue!);
                              }
                              if (p.cityValue?.isNotEmpty == true) {
                                parts.add(p.cityValue!);
                              }
                              return parts.isEmpty
                                  ? 'Localisation'
                                  : parts.join(' · ');
                            }(),
                            style: const TextStyle(color: _muted, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
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
                    if (rooms.isEmpty)
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

    final price = room.price?.toStringAsFixed(0) ?? '—';
    final cur = hotel.currency ?? '';

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
                if (imgs.isNotEmpty)
                  SizedBox(
                    height: 168,
                    child: PageView.builder(
                      itemCount: imgs.length,
                      itemBuilder: (context, i) {
                        final u = imgs[i].path ?? '';
                        final url = u.startsWith('http') ? u : u;
                        return CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: border),
                          errorWidget: (_, __, ___) => Container(
                            color: border,
                            child: Icon(Icons.bed,
                                color: muted.withValues(alpha: 0.4), size: 48),
                          ),
                        );
                      },
                    ),
                  )
                else
                  Container(
                    height: 120,
                    color: border,
                    child: Icon(Icons.bed_outlined,
                        color: muted.withValues(alpha: 0.45), size: 40),
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
                          Text(
                            '$price $cur',
                            style: TextStyle(
                              color: accent,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
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

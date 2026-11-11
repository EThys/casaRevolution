import 'package:casa/controllers/PropertyCtrl.dart';
import 'package:casa/models/PropertyModel.dart';
import 'package:casa/screens/HotelImageZoomPage.dart';
import 'package:casa/utils/cache/HotelImageCache.dart';
import 'package:casa/utils/database/DatabaseHelper.dart';
import 'package:casa/utils/casa_analytics.dart';
import 'package:casa/utils/hotel_room_price.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

/// Détail d’une chambre : galerie, texte complet, réservation.
class HotelRoomDetailPage extends StatefulWidget {
  final PropertyModel hotel;
  final HotelRoomStructure structure;
  final void Function(HotelRoomModel room) onReserveRoom;

  static const Color _primary = Color(0xFF1976D2);
  static const Color _bg = Color(0xFFF9FAFB);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _text = Color(0xFF111827);
  static const Color _border = Color(0xFFE5E7EB);

  const HotelRoomDetailPage({
    Key? key,
    required this.hotel,
    required this.structure,
    required this.onReserveRoom,
  }) : super(key: key);

  @override
  State<HotelRoomDetailPage> createState() => _HotelRoomDetailPageState();
}

class _HotelRoomDetailPageState extends State<HotelRoomDetailPage> {
  static const Color _primary = HotelRoomDetailPage._primary;
  static const Color _bg = HotelRoomDetailPage._bg;
  static const Color _muted = HotelRoomDetailPage._muted;
  static const Color _text = HotelRoomDetailPage._text;
  static const Color _border = HotelRoomDetailPage._border;

  late HotelRoomModel? _room;
  List<String> _photos = [];
  bool _loadingPhotos = false;

  @override
  void initState() {
    super.initState();
    _room = widget.structure.chambre;
    CasaAnalytics.viewItem(
      category: 'chambre',
      id: _room?.id,
      city: widget.hotel.cityValue,
      commune: widget.hotel.communeValue,
      price: _room?.price,
    );
    _photos = _photoUrls(widget.structure);
    _loadingPhotos = _photos.isEmpty && _room?.id != null;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRoom());
  }

  List<String> _photoUrls(HotelRoomStructure? structure) {
    final out = <String>[];
    final images = structure?.images;
    if (images == null) return out;
    for (final image in images) {
      final url = (image.path ?? '').trim();
      if (url.isNotEmpty && !out.contains(url)) out.add(url);
    }
    return out;
  }

  Future<void> _loadRoom() async {
    final id = _room?.id;
    if (id == null) {
      if (mounted) setState(() => _loadingPhotos = false);
      return;
    }

    try {
      final cached = await DatabaseHelper.instance.getHotelRoomById(id);
      final cachedPhotos = _photoUrls(cached);
      if (mounted && cachedPhotos.isNotEmpty && _photos.isEmpty) {
        setState(() {
          _photos = cachedPhotos;
          _room = cached?.chambre ?? _room;
          _loadingPhotos = false;
        });
      }
    } catch (_) {}

    if (!mounted) return;
    final fresh = await context.read<PropertyController>().fetchAndCacheHotelRoom(id);
    if (!mounted) return;
    final freshPhotos = _photoUrls(fresh);
    setState(() {
      if (freshPhotos.isNotEmpty) _photos = freshPhotos;
      if (fresh?.chambre != null) _room = fresh!.chambre;
      _loadingPhotos = false;
    });
  }

  void _openZoom(int index) {
    HotelImageZoomPage.open(
      context,
      _photos,
      initialIndex: index,
      title: _room?.title,
    );
  }

  @override
  Widget build(BuildContext context) {
    final room = _room;
    final imgs = _photos;
    if (room == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chambre')),
        body: const Center(child: Text('Données indisponibles')),
      );
    }

    final priceView = hotelRoomPriceView(room, widget.hotel);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: imgs.isEmpty ? (_loadingPhotos ? 220 : 120) : 320,
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                room.title ?? 'Chambre',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  shadows: [Shadow(color: Colors.black45, blurRadius: 8)],
                ),
              ),
              background: imgs.isEmpty
                  ? Container(
                      color: _primary,
                      alignment: Alignment.center,
                      child: _loadingPhotos
                          ? const _RoomPhotoShimmer(height: 220)
                          : const Icon(Icons.bed_outlined,
                              color: Colors.white54, size: 64),
                    )
                  : PageView.builder(
                      itemCount: imgs.length,
                      itemBuilder: (context, i) {
                        return GestureDetector(
                          onTap: () => _openZoom(i),
                          child: HotelCachedImage(
                            url: imgs[i],
                            fit: BoxFit.cover,
                            placeholderColor: _primary.withValues(alpha: 0.3),
                            error: const ColoredBox(
                              color: _primary,
                              child: Icon(Icons.bed, color: Colors.white38, size: 72),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          room.title ?? 'Chambre',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: _text,
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            priceView.amount,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: _primary,
                            ),
                          ),
                          if (priceView.period.isNotEmpty)
                            Text(
                              priceView.period,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _muted,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.place_rounded, color: _primary, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _hotelAddressLine(widget.hotel),
                          style: const TextStyle(
                            color: _text,
                            fontSize: 14,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _chip(Icons.king_bed_outlined,
                          '${room.numberPiece ?? 1} pièce(s)'),
                      _chip(
                        Icons.circle,
                        room.available == false ? 'Complet' : 'Disponible',
                        dot: true,
                      ),
                    ],
                  ),
                  if (room.description != null &&
                      room.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      room.description!,
                      style: const TextStyle(
                        color: _text,
                        height: 1.55,
                        fontSize: 15,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
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
                        'Photos de la chambre',
                        style: TextStyle(
                          color: _text,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_loadingPhotos && imgs.isEmpty)
                    const _RoomPhotoShimmer(height: 160)
                  else if (imgs.isEmpty)
                    const Text(
                      'Aucune photo pour cette chambre.',
                      style: TextStyle(color: _muted, height: 1.4),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: imgs.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                      ),
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () => _openZoom(index),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                HotelCachedImage(
                                  url: imgs[index],
                                  fit: BoxFit.cover,
                                  placeholderColor: _border,
                                  error: const ColoredBox(
                                    color: _border,
                                    child: Icon(Icons.image_not_supported_rounded),
                                  ),
                                ),
                                const Positioned(
                                  right: 6,
                                  bottom: 6,
                                  child: Icon(
                                    Icons.zoom_out_map_rounded,
                                    color: Colors.white,
                                    size: 16,
                                    shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: ColoredBox(
        color: _bg,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            12 + MediaQuery.viewPaddingOf(context).bottom,
          ),
          child: FilledButton(
            onPressed: () => widget.onReserveRoom(room),
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Réserver cette chambre',
              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, {bool dot = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: label == 'Complet'
                    ? Colors.redAccent
                    : Colors.greenAccent,
                shape: BoxShape.circle,
              ),
            )
          else
            Icon(icon, size: 16, color: _muted),
          if (!dot) const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: _text,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomPhotoShimmer extends StatelessWidget {
  final double height;

  const _RoomPhotoShimmer({required this.height});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFD6DEE8),
      highlightColor: const Color(0xFFF4F7FB),
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

String _hotelAddressLine(PropertyModel hotel) {
  final parts = <String>[];
  void add(String? raw) {
    final text = (raw ?? '').trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return;
    if (parts.any((part) => part.toLowerCase() == text.toLowerCase())) return;
    parts.add(text);
  }

  add(hotel.address);
  add(hotel.quartierValue ?? hotel.quartier);
  add(hotel.communeValue);
  add(hotel.cityValue);
  add(hotel.countryValue);
  return parts.isEmpty ? 'Adresse non renseignée' : parts.join(', ');
}


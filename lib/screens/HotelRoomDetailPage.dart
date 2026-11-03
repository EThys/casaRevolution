import 'package:casa/models/PropertyModel.dart';
import 'package:casa/utils/cache/HotelImageCache.dart';
import 'package:casa/utils/hotel_room_price.dart';
import 'package:casa/screens/FullScreenImageViewer.dart';
import 'package:flutter/material.dart';

/// Détail d’une chambre : galerie, texte complet, réservation.
class HotelRoomDetailPage extends StatelessWidget {
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

  String _imgUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    return path.startsWith('http') ? path : path;
  }

  @override
  Widget build(BuildContext context) {
    final room = structure.chambre;
    final imgs = structure.images ?? [];
    if (room == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chambre')),
        body: const Center(child: Text('Données indisponibles')),
      );
    }

    final priceView = hotelRoomPriceView(room, hotel);
    final media = MediaQuery.of(context);
    // Le Scaffold remonte déjà la barre si padding.bottom est renseigné.
    // Sur certains téléphones (Samsung A17, barre gestes ou boutons), seul
    // viewPadding.bottom est non nul : on ajoute uniquement l'écart manquant.
    final extraBottom = (media.viewPadding.bottom - media.padding.bottom)
        .clamp(0.0, 96.0);

    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: imgs.isEmpty ? 120 : 320,
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
                      child: const Icon(Icons.bed_outlined,
                          color: Colors.white54, size: 64),
                    )
                  : PageView.builder(
                      itemCount: imgs.length,
                      itemBuilder: (context, i) {
                        final url = _imgUrl(imgs[i].path);
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FullScreenImageViewer(
                                  images: imgs,
                                  initialIndex: i,
                                  categoryName: room.title,
                                ),
                              ),
                            );
                          },
                          child: HotelCachedImage(
                            url: url,
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
                          _hotelAddressLine(hotel),
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
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: ColoredBox(
        color: _bg,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + extraBottom),
          child: FilledButton(
            onPressed: () => onReserveRoom(room),
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


import 'dart:convert';
import 'dart:io';

import 'package:casa/controllers/AuthentificationCtrl.dart';
import 'package:casa/controllers/PropertyCtrl.dart';
import 'package:casa/controllers/ReservationController.dart';
import 'package:casa/models/PropertyModel.dart';
import 'package:casa/models/ReservationModel.dart';
import 'package:casa/screens/forms/HotelRoomFormFields.dart';
import 'package:casa/screens/hotel_room_reservations_page.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/database/DatabaseHelper.dart';
import 'package:casa/utils/database/PropertyDatabaseHelper.dart';
import 'package:casa/utils/status_labels_fr.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

/// Gestion d’un hôtel : chambres + réservations reçues sur les chambres.
class HotelManageDetailPage extends StatefulWidget {
  final PropertyModel initialHotel;

  const HotelManageDetailPage({Key? key, required this.initialHotel}) : super(key: key);

  @override
  State<HotelManageDetailPage> createState() => _HotelManageDetailPageState();
}

class _HotelManageDetailPageState extends State<HotelManageDetailPage> {
  late PropertyModel _hotel;
  bool _syncing = false;
  List<ReservationModel> _reservations = [];
  final Set<int> _expandedRoomIds = <int>{};

  static const Color _primaryColor = Color(0xFF1976D2);
  static const Color _secondaryColor = Color(0xFF64B5F6);
  static const Color _lightGrey = Color(0xFFF5F6FA);
  static const Color _mediumGrey = Color(0xFF7F8C8D);
  static const Color _darkColor = Color(0xFF1A1D26);

  int get _hotelId => _hotel.propertyId ?? 0;

  String? _ownerUserId() {
    final auth = context.read<AuthentificationCtrl>();
    return auth.user.userId?.toString();
  }

  Set<int> _roomIdSet(PropertyModel h) {
    final ids = <int>{};
    for (final row in h.hotelStructure ?? []) {
      final id = row.chambre?.id;
      if (id != null) ids.add(id);
    }
    return ids;
  }

  List<ReservationModel> _filterReservations(PropertyModel h, List<ReservationModel> all) {
    final roomIds = _roomIdSet(h);
    final filtered = all.where((r) {
      final cid = r.chambreId;
      return cid != null && roomIds.contains(cid);
    }).toList();
    filtered.sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
    return filtered;
  }

  @override
  void initState() {
    super.initState();
    _hotel = widget.initialHotel;
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshAll());
  }

  Future<void> _refreshAll() async {
    final db = DatabaseHelper.instance;
    final userDb = PropertyDatabaseHelper.instance;
    final uid = _ownerUserId();

    if (_hotelId > 0) {
      try {
        final cached = await userDb.getPropertyById(_hotelId.toString());
        if (cached != null && mounted) {
          setState(() => _hotel = cached);
        }
      } catch (_) {}
    }

    try {
      final cachedHost = await db.getAllHostReservations();
      if (mounted) {
        setState(() {
          _reservations = _filterReservations(_hotel, cachedHost);
        });
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() => _syncing = true);

    try {
      final prop = context.read<PropertyController>();
      final hotels = await prop.fetchHotelsByOwner();
      PropertyModel updated = _hotel;
      if (hotels.isNotEmpty) {
        for (final h in hotels) {
          if (h.propertyId == _hotelId) {
            updated = h;
            break;
          }
        }
        if (uid != null && uid.isNotEmpty) {
          for (final h in hotels) {
            await userDb.insertOrUpdateProperty(h, uid);
            final hydrated = await db.hydrateHotelFromRoomCache(h);
            await db.insertOrUpdateInCategory(DatabaseHelper.tableHotels, hydrated);
            await db.persistHotelRoomRows(hydrated);
            if (h.propertyId == _hotelId) updated = hydrated;
          }
        }
      }

      final resCtrl = context.read<ReservationController>();
      final hostAll = await resCtrl.getHostReservations();
      List<ReservationModel> nextRes = _reservations;
      if (hostAll.isNotEmpty) {
        await db.clearHostReservations();
        await db.insertMultipleHostReservations(hostAll);
        nextRes = _filterReservations(updated, hostAll);
      } else {
        try {
          final again = await db.getAllHostReservations();
          nextRes = _filterReservations(updated, again);
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _hotel = updated;
        _reservations = nextRes;
      });
    } catch (e) {
      print('HotelManageDetailPage sync: $e');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  String? _roomCover(HotelRoomStructure row) {
    final imgs = row.images;
    if (imgs != null && imgs.isNotEmpty) {
      final p = imgs.first.path;
      if (p != null && p.isNotEmpty) return p;
    }
    return null;
  }

  String _roomTitle(HotelRoomStructure row) => row.chambre?.title ?? 'Chambre';

  void _openAddRoom() {
    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddHotelRoomPage(hotelId: _hotelId),
      ),
    ).then((created) {
      if (created == true) _refreshAll();
    });
  }

  Future<void> _toggleHotelAvailability() async {
    final hid = _hotelId;
    if (hid <= 0) return;

    final nextSold = !(_hotel.sold == true); // sold=true => indisponible
    setState(() {
      _hotel = _hotel.copyWith(sold: nextSold);
    });

    try {
      final ctrl = context.read<PropertyController>();
      final resp = await ctrl.syncPropertySoldFlag(hid, 5, sold: nextSold);
      if (!mounted) return;
      if (resp.status == true) {
        FancyNotification.show(
          context,
          nextSold ? "Hôtel rendu indisponible." : "Hôtel rendu disponible.",
          type: NotificationType.success,
        );
        await _refreshAll();
      } else {
        // rollback
        setState(() => _hotel = _hotel.copyWith(sold: !nextSold));
        FancyNotification.show(
          context,
          "Impossible de changer la disponibilité de l'hôtel. Réessayez.",
          isError: true,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _hotel = _hotel.copyWith(sold: !nextSold));
      FancyNotification.show(
        context,
        "Connexion instable. Réessayez dans un instant.",
        isError: true,
      );
    }
  }

  String? _hotelCoverUrl() {
    final firstImage = _hotel.propertyImage?.isNotEmpty == true ? _hotel.propertyImage!.first.path : null;
    return firstImage ??
        _hotel.image ??
        (_hotel.allImageUrls.isNotEmpty ? _hotel.allImageUrls.first : null);
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _primaryColor, size: 20),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: _darkColor),
        ),
      ],
    );
  }

  Color _statusColor(String st) {
    switch (st) {
      case 'PENDING':
        return const Color(0xFFE67E22);
      case 'CONFIRMED':
      case 'APPROVED':
        return const Color(0xFF00B894);
      case 'CANCELLED':
        return const Color(0xFFD63031);
      default:
        return _mediumGrey;
    }
  }

  void _openRoomReservations({
    required int roomId,
    required String roomTitle,
    required List<ReservationModel> reservations,
  }) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => HotelRoomReservationsPage(
          roomId: roomId,
          roomTitle: roomTitle,
          reservations: reservations,
          onParentRefresh: _refreshAll,
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    final cover = _hotelCoverUrl();
    final roomsCount = (_hotel.hotelStructure ?? const <HotelRoomStructure>[]).length;
    final totalResCount = _reservations.length;
    final hotelAvailable = _hotel.sold != true;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 160,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (cover != null && cover.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: cover,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: _lightGrey,
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: _lightGrey,
                      child: Icon(Icons.hotel_rounded, size: 48, color: _mediumGrey),
                    ),
                  )
                else
                  Container(
                    color: _lightGrey,
                    alignment: Alignment.center,
                    child: Icon(Icons.hotel_rounded, size: 48, color: _mediumGrey),
                  ),
                // Gradient pour lisibilité + look premium
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.05),
                          Colors.black.withOpacity(0.55),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 12,
                  child: Row(
                    children: [
                      _MetricPill(
                        icon: Icons.bed_rounded,
                        label: '$roomsCount chambre(s)',
                      ),
                      const SizedBox(width: 10),
                      _MetricPill(
                        icon: Icons.event_available_rounded,
                        label: totalResCount == 0 ? '0 réservation' : '$totalResCount réservation(s)',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(18),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _hotel.title ?? 'Hôtel',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _darkColor),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: hotelAvailable ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: (hotelAvailable ? const Color(0xFF2E7D32) : const Color(0xFFC62828)).withOpacity(0.22),
                        ),
                      ),
                      child: Text(
                        hotelAvailable ? 'Hôtel disponible' : 'Hôtel indisponible',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: hotelAvailable ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                        ),
                      ),
                    ),
                    const Spacer(),
                    FilledButton.tonalIcon(
                      onPressed: _syncing ? null : _toggleHotelAvailability,
                      style: FilledButton.styleFrom(
                        foregroundColor: _primaryColor,
                        backgroundColor: _primaryColor.withOpacity(0.12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                      ),
                      icon: Icon(hotelAvailable ? Icons.toggle_off_rounded : Icons.toggle_on_rounded),
                      label: Text(hotelAvailable ? 'Rendre indispo' : 'Rendre dispo'),
                    ),
                  ],
                ),
                if ((_hotel.address ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.location_on_outlined, size: 18, color: _mediumGrey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _hotel.address ?? '',
                          style: TextStyle(fontSize: 14, color: _mediumGrey, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ],
                if ((_hotel.cityValue ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _hotel.cityValue ?? '',
                    style: TextStyle(fontSize: 13, color: _mediumGrey.withOpacity(0.9)),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _hotelId <= 0 ? null : _openAddRoom,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _primaryColor,
                          side: BorderSide(color: _primaryColor.withOpacity(0.25)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          textStyle: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Ajouter une chambre'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton.filledTonal(
                      onPressed: _syncing ? null : _refreshAll,
                      style: IconButton.styleFrom(
                        backgroundColor: _primaryColor.withOpacity(0.12),
                        foregroundColor: _primaryColor,
                      ),
                      icon: Icon(_syncing ? Icons.hourglass_top : Icons.refresh_rounded),
                      tooltip: 'Actualiser',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Pastille métrique sur cover (header)
  Widget _MetricPill({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomTile(HotelRoomStructure row) {
    final cover = _roomCover(row);
    final ch = row.chambre;
    final price = ch?.price;
    final dev = ch?.deviseId == 1 ? 'CDF' : 'USD';
    final roomId = ch?.id;
    final isAvailable = ch?.available != false;
    final roomRes = roomId == null
        ? const <ReservationModel>[]
        : _reservations.where((r) => r.chambreId == roomId).toList()
      ..sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
    final isExpanded = roomId != null && _expandedRoomIds.contains(roomId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.black.withOpacity(0.045)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: roomId == null
                ? null
                : () {
                    setState(() {
                      if (isExpanded) {
                        _expandedRoomIds.remove(roomId);
                      } else {
                        _expandedRoomIds.add(roomId);
                      }
                    });
                  },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 82,
                      height: 82,
                      child: cover != null && cover.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: cover,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(color: _lightGrey),
                              errorWidget: (_, __, ___) => Container(
                                color: _lightGrey,
                                child: const Icon(Icons.bed_rounded),
                              ),
                            )
                          : Container(
                              color: _lightGrey,
                              alignment: Alignment.center,
                              child: const Icon(Icons.bed_rounded),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _roomTitle(row),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: _darkColor),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isAvailable ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: (isAvailable ? const Color(0xFF2E7D32) : const Color(0xFFC62828)).withOpacity(0.22),
                                ),
                              ),
                              child: Text(
                                isAvailable ? 'Disponible' : 'Indisponible',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: isAvailable ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                '${price != null ? price.toStringAsFixed(0) : '—'} $dev',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 13, color: _darkColor.withOpacity(0.72), fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'ID: ${ch?.id ?? '—'}',
                          style: TextStyle(fontSize: 12, color: _mediumGrey, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: roomRes.isNotEmpty ? _primaryColor.withOpacity(0.10) : Colors.grey.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          roomRes.isNotEmpty ? '${roomRes.length} réservation(s)' : '0 réservation',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: roomRes.isNotEmpty ? _primaryColor : _mediumGrey,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        child: Icon(Icons.keyboard_arrow_down_rounded, color: _mediumGrey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: roomId == null
                        ? null
                        : () async {
                            final rid = roomId;
                            final nextAvailable = !(ch?.available != false);
                            final nextSold = !nextAvailable;

                            setState(() {
                              final list = List<HotelRoomStructure>.from(
                                  _hotel.hotelStructure ?? const <HotelRoomStructure>[]);
                              final idx = list.indexWhere((e) => e.chambre?.id == rid);
                              if (idx != -1) {
                                final cur = list[idx];
                                final r = cur.chambre;
                                if (r != null) {
                                  final updatedRoom = HotelRoomModel(
                                    id: r.id,
                                    hotelId: r.hotelId,
                                    deviseId: r.deviseId,
                                    title: r.title,
                                    description: r.description,
                                    numberPiece: r.numberPiece,
                                    price: r.price,
                                    priceHeure: r.priceHeure,
                                    createdAt: r.createdAt,
                                    updatedAt: r.updatedAt,
                                    available: nextAvailable,
                                  );
                                  list[idx] = HotelRoomStructure(
                                    chambre: updatedRoom,
                                    images: cur.images,
                                  );
                                  _hotel = _hotel.copyWith(hotelStructure: list);
                                }
                              }
                            });

                            try {
                              final ctrl = context.read<PropertyController>();
                              final resp = await ctrl.syncHotelRoomSoldFlag(rid, sold: nextSold);
                              if (resp.status == true) {
                                FancyNotification.show(
                                  context,
                                  nextAvailable ? 'Chambre rendue disponible.' : 'Chambre rendue indisponible.',
                                  type: NotificationType.success,
                                );
                                await _refreshAll();
                              } else {
                                setState(() {
                                  final list = List<HotelRoomStructure>.from(
                                      _hotel.hotelStructure ?? const <HotelRoomStructure>[]);
                                  final idx = list.indexWhere((e) => e.chambre?.id == rid);
                                  if (idx != -1) {
                                    final cur = list[idx];
                                    final r = cur.chambre;
                                    if (r != null) {
                                      final rolled = HotelRoomModel(
                                        id: r.id,
                                        hotelId: r.hotelId,
                                        deviseId: r.deviseId,
                                        title: r.title,
                                        description: r.description,
                                        numberPiece: r.numberPiece,
                                        price: r.price,
                                        priceHeure: r.priceHeure,
                                        createdAt: r.createdAt,
                                        updatedAt: r.updatedAt,
                                        available: !nextAvailable,
                                      );
                                      list[idx] = HotelRoomStructure(
                                        chambre: rolled,
                                        images: cur.images,
                                      );
                                      _hotel = _hotel.copyWith(hotelStructure: list);
                                    }
                                  }
                                });
                                FancyNotification.show(
                                  context,
                                  'Impossible de changer le statut. Réessayez.',
                                  isError: true,
                                );
                              }
                            } catch (_) {
                              FancyNotification.show(
                                context,
                                'Connexion instable. Réessayez dans un instant.',
                                isError: true,
                              );
                            }
                          },
                    style: FilledButton.styleFrom(
                      foregroundColor: _primaryColor,
                      backgroundColor: _primaryColor.withOpacity(0.12),
                      textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: Icon(isAvailable ? Icons.toggle_off_rounded : Icons.toggle_on_rounded),
                    label: Text(isAvailable ? 'Rendre indispo' : 'Rendre dispo'),
                  ),
                ),
                const SizedBox(width: 10),
                if (roomRes.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: roomId == null
                        ? null
                        : () => _openRoomReservations(
                              roomId: roomId,
                              roomTitle: _roomTitle(row),
                              reservations: roomRes,
                            ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primaryColor,
                      side: BorderSide(color: _primaryColor.withOpacity(0.25)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                    ),
                    icon: const Icon(Icons.list_alt_rounded),
                    label: const Text('Réservations'),
                  ),
              ],
            ),
          ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: !isExpanded
                    ? const SizedBox.shrink()
                    : Column(
                        children: [
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: _lightGrey,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.black.withOpacity(0.04)),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: roomRes.isEmpty
                                ? Center(
                                    child: Text(
                                      'Aucune réservation reçue pour cette chambre.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: _mediumGrey, fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                  )
                                : Column(
                                    children: roomRes.take(3).map((r) {
                            final st = (r.status ?? '—').toUpperCase();
                            final chipColor = _statusColor(st);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _primaryColor.withOpacity(0.10)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: chipColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      r.user?.fullName ?? r.user?.email ?? 'Voyageur',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: _darkColor),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    frReservationStatus(r.status),
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: chipColor),
                                  ),
                                ],
                              ),
                            );
                                    }).toList(),
                                  ),
                          ),
                          if (roomRes.length > 3) ...[
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                '+ ${roomRes.length - 3} autre(s)…',
                                style: TextStyle(color: _primaryColor, fontWeight: FontWeight.w800, fontSize: 12),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightGrey,
      appBar: AppBar(
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, _secondaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Text(
          _hotel.title ?? 'Mon hôtel',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: Icon(_syncing ? Icons.hourglass_top : Icons.refresh_rounded, color: Colors.white),
            onPressed: _syncing ? null : _refreshAll,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 18,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: _hotelId <= 0 ? null : _openAddRoom,
              style: FilledButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Ajouter une chambre'),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              color: _primaryColor,
              backgroundColor: Colors.white,
              onRefresh: _refreshAll,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeaderCard(),
                    const SizedBox(height: 24),
                    _sectionTitle('Chambres', Icons.bed_rounded),
                    const SizedBox(height: 6),
                    Text(
                      'Gérez les chambres publiées pour cet hôtel.',
                      style: TextStyle(fontSize: 13, color: _mediumGrey),
                    ),
                    const SizedBox(height: 14),
                    if ((_hotel.hotelStructure ?? []).isEmpty && _syncing)
                      const _ManageRoomsShimmer()
                    else if ((_hotel.hotelStructure ?? []).isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.black.withOpacity(0.05)),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: _primaryColor.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.bedroom_parent_rounded, color: _primaryColor),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Aucune chambre pour le moment',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: _darkColor),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Ajoutez votre première chambre pour commencer à recevoir des réservations.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: _mediumGrey, height: 1.35),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _hotelId <= 0 ? null : _openAddRoom,
                                style: FilledButton.styleFrom(
                                  backgroundColor: _primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Ajouter une chambre'),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...(_hotel.hotelStructure ?? []).map(_buildRoomTile),
                    const SizedBox(height: 28),
                    _sectionTitle('Réservations reçues', Icons.event_note_rounded),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _primaryColor.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.notifications_active_rounded, color: _primaryColor),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _reservations.isEmpty
                                  ? 'Aucune réservation pour l’instant.'
                                  : '${_reservations.length} réservation(s) au total — ouvrez une chambre pour voir le détail.',
                              style: TextStyle(color: _darkColor, fontWeight: FontWeight.w700, height: 1.25),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AddHotelRoomPage extends StatefulWidget {
  final int hotelId;

  const AddHotelRoomPage({Key? key, required this.hotelId}) : super(key: key);

  @override
  State<AddHotelRoomPage> createState() => _AddHotelRoomPageState();
}

class _AddHotelRoomPageState extends State<AddHotelRoomPage> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _numberPiece = TextEditingController(text: '1');
  final _price = TextEditingController();
  final _priceHeure = TextEditingController();
  int _deviseId = 2;
  bool _isAvailable = true;
  bool _listingActive = true;
  final List<XFile> _images = [];
  final _picker = ImagePicker();
  bool _submitting = false;
  String? _titleError;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _numberPiece.dispose();
    _price.dispose();
    _priceHeure.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final list = await _picker.pickMultiImage(imageQuality: 82);
    if (list.isNotEmpty) {
      setState(() {
        _images.addAll(list);
      });
    }
  }

  Future<void> _capture() async {
    final x = await _picker.pickImage(source: ImageSource.camera, imageQuality: 82);
    if (x != null) {
      setState(() => _images.add(x));
    }
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Titre obligatoire');
      return;
    }
    if (_images.isEmpty) {
      FancyNotification.show(context, 'Ajoutez au moins une photo de la chambre.', type: NotificationType.warning);
      return;
    }

    final auth = context.read<AuthentificationCtrl>();
    final uid = auth.user.userId ?? 0;
    if (uid <= 0) {
      FancyNotification.show(context, 'Session expirée. Reconnectez-vous.', isError: true);
      return;
    }

    setState(() {
      _titleError = null;
      _submitting = true;
    });

    try {
      final imageEntries = <Map<String, String>>[];
      for (final x in _images) {
        final file = File(x.path);
        if (await file.exists()) {
          final b64 = base64Encode(await file.readAsBytes());
          imageEntries.add({'image': b64});
        }
      }
      if (imageEntries.isEmpty) {
        FancyNotification.show(context, 'Impossible de lire les images.', isError: true);
        setState(() => _submitting = false);
        return;
      }

      final body = {
        'userId': uid,
        'hotelId': widget.hotelId,
        'deviseId': _deviseId,
        'title': title,
        'description': _desc.text.trim(),
        'numberPiece': int.tryParse(_numberPiece.text.trim()) ?? 1,
        'price': double.tryParse(_price.text.trim()) ?? 0,
        'priceHeure': _priceHeure.text.trim(),
        'isAvailable': _isAvailable,
        'images': imageEntries,
        'available': _listingActive,
      };

      final res = await context.read<PropertyController>().createHotelRoom(body);
      if (!mounted) return;
      if (res.status == true) {
        FancyNotification.show(context, 'Chambre ajoutée', type: NotificationType.success);
        Navigator.pop(context, true);
      } else {
        FancyNotification.show(
          context,
          res.errorMsg ?? 'Création impossible',
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        FancyNotification.show(context, 'Erreur: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _title.text.trim().isNotEmpty && _images.isNotEmpty && !_submitting;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1976D2), Color(0xFF64B5F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
          'Créer une chambre',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 18,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: _submitting ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1976D2),
                      side: const BorderSide(color: Color(0xFF1976D2)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Annuler', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: canSubmit ? _submit : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1976D2),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: _submitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(
                      _submitting ? 'Enregistrement…' : 'Enregistrer',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Intro card (premium)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF1976D2).withOpacity(0.12),
                    const Color(0xFF64B5F6).withOpacity(0.10),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF1976D2).withOpacity(0.10)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1976D2), Color(0xFF64B5F6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF1976D2),
                          blurRadius: 18,
                          offset: Offset(0, 10),
                          spreadRadius: -10,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.meeting_room_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Nouvelle chambre',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1A1D26)),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Ajoutez des photos et remplissez les informations pour publier la chambre.',
                          style: TextStyle(color: Colors.grey.shade700, height: 1.25, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.photo_library_rounded, color: Color(0xFF1976D2)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Photos',
                          style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1A1D26), fontSize: 16),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1976D2).withOpacity(0.10),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${_images.length} photo(s)',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF1976D2)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pick,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1976D2),
                            side: const BorderSide(color: Color(0xFF1976D2)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Galerie'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _capture,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1976D2),
                            side: const BorderSide(color: Color(0xFF1976D2)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: const Text('Caméra'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_images.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F6FA),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF1976D2).withOpacity(0.15)),
                      ),
                      child: Text(
                        'Ajoutez au moins une photo (obligatoire).',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1,
                      ),
                      itemCount: _images.length,
                      itemBuilder: (context, i) {
                        final x = _images[i];
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.file(
                                File(x.path),
                                fit: BoxFit.cover,
                              ),
                              Positioned(
                                top: 6,
                                right: 6,
                                child: InkWell(
                                  onTap: () => setState(() => _images.removeAt(i)),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.60),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: HotelRoomFormFields(
                titleController: _title,
                descriptionController: _desc,
                numberPieceController: _numberPiece,
                priceController: _price,
                priceHeureController: _priceHeure,
                deviseId: _deviseId,
                onDeviseChanged: (v) => setState(() => _deviseId = v),
                isAvailable: _isAvailable,
                listingActive: _listingActive,
                onIsAvailableChanged: (v) => setState(() => _isAvailable = v),
                onListingActiveChanged: (v) => setState(() => _listingActive = v),
                titleError: _titleError,
              ),
            ),
            const SizedBox(height: 14),
            if (!canSubmit)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1976D2).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1976D2).withOpacity(0.12)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Color(0xFF1976D2)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Pour enregistrer, ajoutez au moins 1 photo et un titre.',
                        style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w700, height: 1.25),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _ManageRoomsShimmer extends StatelessWidget {
  const _ManageRoomsShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(3, (index) {
        return Padding(
          padding: EdgeInsets.only(bottom: index == 2 ? 0 : 12),
          child: Shimmer.fromColors(
            baseColor: const Color(0xFFE5E7EB),
            highlightColor: const Color(0xFFF8FAFC),
            child: Container(
              height: 92,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        );
      }),
    );
  }
}

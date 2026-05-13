import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:casa/controllers/ReservationController.dart';
import 'package:casa/models/ReservationModel.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/FavoriteEartIcon.dart';
import 'package:casa/utils/ModernModal.dart';
import 'package:casa/utils/UserInfoBottomSheet.dart';
import 'package:casa/utils/crashlytics_api.dart';
import 'package:casa/utils/export_directory.dart';
import 'package:casa/utils/networkCheck.dart';
import 'package:casa/utils/requetes.dart' show HttpResponse;
import 'package:casa/utils/reservation_pdf_bytes.dart';
import 'package:casa/utils/status_labels_fr.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/PropertyModel.dart';

/// Liste des réservations d’une chambre d’hôtel (onglets + actions hôte alignés sur [BookingHistoryPage]).
class HotelRoomReservationsPage extends StatefulWidget {
  final int roomId;
  final String roomTitle;
  final List<ReservationModel> reservations;
  final VoidCallback? onParentRefresh;

  const HotelRoomReservationsPage({
    Key? key,
    required this.roomId,
    required this.roomTitle,
    required this.reservations,
    this.onParentRefresh,
  }) : super(key: key);

  @override
  State<HotelRoomReservationsPage> createState() =>
      _HotelRoomReservationsPageState();
}

class _HotelRoomReservationsPageState extends State<HotelRoomReservationsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<ReservationModel> _items;
  pw.MemoryImage? _logoImage;
  bool _busy = false;
  bool _showingCancelSheet = false;
  final List<String> _cancellingIds = [];

  static const Color _primaryColor = Color(0xFF1976D2);
  static const Color _secondaryColor = Color(0xFF64B5F6);
  static const Color _darkColor = Color(0xFF1A1D26);
  static const Color _lightGrey = Color(0xFFF5F6FA);
  static const Color _mediumGrey = Color(0xFF7F8C8D);
  static const Color _successColor = Color(0xFF00B894);
  static const Color _warningColor = Color(0xFFFDCB6E);
  static const Color _errorColor = Color(0xFFD63031);
  static const Color _cardBackground = Colors.white;
  static const Color _chipBackground = Color(0xFFE8F4F8);

  @override
  void initState() {
    super.initState();
    _items = List<ReservationModel>.from(widget.reservations);
    _tabController = TabController(length: 3, vsync: this);
    _loadLogo();
  }

  @override
  void didUpdateWidget(covariant HotelRoomReservationsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reservations != oldWidget.reservations) {
      setState(() {
        _items = List<ReservationModel>.from(widget.reservations);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLogo() async {
    try {
      final data = await rootBundle.load('assets/images/logoCasa.png');
      if (mounted) {
        setState(() {
          _logoImage = pw.MemoryImage(data.buffer.asUint8List());
        });
      }
    } catch (_) {}
  }

  String _norm(String? s) => (s ?? '').toUpperCase().trim();

  List<ReservationModel> get _pending =>
      _items.where((r) => _norm(r.status) == 'PENDING').toList();

  List<ReservationModel> get _confirmed => _items
      .where((r) =>
          _norm(r.status) == 'CONFIRMED' || _norm(r.status) == 'APPROVED')
      .toList();

  List<ReservationModel> get _cancelled => _items.where((r) {
        final t = _norm(r.status);
        return t == 'CANCELLED' || t == 'CANCELED';
      }).toList();

  String? _getImageUrl(ReservationModel reservation) {
    if (reservation.property?.propertyImage != null &&
        reservation.property!.propertyImage!.isNotEmpty) {
      final firstImage = reservation.property!.propertyImage!.first;
      if (firstImage.path != null) return firstImage.path!;
    }
    return null;
  }

  Color _getStatusColor(String? status) {
    switch (_norm(status)) {
      case 'PENDING':
        return _warningColor;
      case 'CONFIRMED':
      case 'APPROVED':
        return _successColor;
      case 'COMPLETED':
        return _primaryColor;
      case 'CANCELLED':
      case 'CANCELED':
        return _errorColor;
      default:
        return _mediumGrey;
    }
  }

  String _getStatusText(String? status) => frReservationStatus(status);

  String? _formatDate(String? dateString) {
    if (dateString == null) return null;
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (_) {
      return dateString;
    }
  }

  List<Widget> _buildFeatureChips(PropertyModel? propertyData) {
    final features = <Widget>[];

    if (propertyData?.bedrooms != null) {
      features.add(_buildFeatureChip('${propertyData!.bedrooms} chambres'));
    }
    if (propertyData?.bathroom != null) {
      features.add(_buildFeatureChip('${propertyData!.bathroom} sdb'));
    }
    if (propertyData?.surface != null) {
      features.add(_buildFeatureChip('${propertyData!.surface}m²'));
    }
    if (propertyData?.rooms != null) {
      features.add(_buildFeatureChip('${propertyData!.rooms} pièces'));
    }

    return features;
  }

  Widget _buildFeatureChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _chipBackground,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: _darkColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _patchLocalStatus(int? id, String status) {
    if (id == null) return;
    setState(() {
      final i = _items.indexWhere((e) => e.reservationId == id);
      if (i >= 0) _items[i].status = status;
    });
  }

  Future<void> _downloadReservationPdf(ReservationModel reservation) async {
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
      final bytes = await buildReservationPdfBytes(reservation, _logoImage);
      final generationDate =
          DateFormat('dd_MMMM_yyyy_HH_mm', 'fr_FR').format(DateTime.now());
      final filePath =
          '${dir.path}/Bon_Reservation_Ref_${reservation.reservationId}_du_$generationDate.pdf';
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);
      try {
        await OpenFile.open(filePath);
      } catch (_) {}
      if (!mounted) return;
      FancyNotification.show(
        context,
        "PDF enregistré dans : ${describePickedDirectoryPathForUser(dir.path)}",
        isError: false,
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

  Future<void> _shareReservationPdf(ReservationModel reservation) async {
    try {
      final bytes = await buildReservationPdfBytes(reservation, _logoImage);
      final generationDate =
          DateFormat('dd_MMMM_yyyy_HH_mm', 'fr_FR').format(DateTime.now());
      final fileName =
          'Bon_Reservation_Ref_${reservation.reservationId}_du_$generationDate.pdf';
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(bytes);
      final xfile =
          XFile(tempFile.path, mimeType: 'application/pdf', name: fileName);
      await Share.shareXFiles(
        [xfile],
        text:
            "Confirmation de réservation - ${reservation.property?.title ?? 'Propriété'}",
      );
    } catch (e) {
      FancyNotification.show(context, "Partage du PDF impossible");
    }
  }

  void _showHostActionSuccessDialog(ReservationModel reservation) {
    // Uniformisation UX: utiliser le même modèle que le bottomsheet (Partager / Télécharger).
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + MediaQuery.of(sheetContext).padding.bottom),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  "Réservation validée",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _darkColor),
                ),
                const SizedBox(height: 6),
                Text(
                  "Vous avez confirmé cette réservation de chambre. Le client a été notifié. Vous pouvez partager ou télécharger le bon maintenant.",
                  style: TextStyle(color: _mediumGrey, height: 1.35),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async => await _shareReservationPdf(reservation),
                        icon: const Icon(Icons.ios_share_rounded, color: _primaryColor),
                        label: Text(
                          "Partager le bon",
                          style: TextStyle(
                            color: _darkColor.withOpacity(0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: _primaryColor.withOpacity(0.3),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async => await _downloadReservationPdf(reservation),
                        icon: const Icon(Icons.download_rounded, color: _primaryColor),
                        label: Text(
                          "Télécharger (PDF)",
                          style: TextStyle(
                            color: _darkColor.withOpacity(0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: _primaryColor.withOpacity(0.3),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text(
                      "Fermer",
                      style: TextStyle(color: _mediumGrey, fontWeight: FontWeight.w700),
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

  Future<void> _handleReservationAction(
    ReservationModel reservation,
    String action, {
    bool fromBottomSheet = false,
  }) async {
    final ctrl = Provider.of<ReservationController>(context, listen: false);
    if (reservation.reservationId == null) return;

    bool confirm = false;
    String? reason;

    if (action == 'CANCELLED') {
      // Important: éviter les bottom sheets imbriqués (host management sheet -> cancel reason sheet),
      // ça peut déclencher des erreurs Overlay/GlobalKey sur certains devices.
      if (fromBottomSheet && mounted) {
        Navigator.pop(context);
        // Laisser une frame au Navigator/Overlay pour se stabiliser.
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
      final result = await _showHostRefuseDialog();
      if (result != null && result['confirmed'] == true) {
        confirm = true;
        reason = result['reason'] as String?;
      }
    } else {
      final result = await _showHostValidateDialog();
      confirm = result ?? false;
    }

    if (!confirm) return;

    // Si on venait du bottom sheet, on l'a déjà fermé au-dessus avant d'ouvrir le dialog de raison.

    setState(() => _busy = true);
    final rid = reservation.reservationId!.toString();
    _cancellingIds.add(rid);

    final ok = await NetworkUtils.checkInternetConnectivity();
    if (!ok) {
      FancyNotification.show(context, "Pas de connexion internet");
      setState(() {
        _busy = false;
        _cancellingIds.remove(rid);
      });
      return;
    }

    try {
      HttpResponse? lastResp;
      bool success = false;

      // Logs UX: endpoint/payload/réponse détaillés sont loggés par putData().
      print('📌 [HotelRoomReservationsPage] action=$action reservationId=${reservation.reservationId} roomId=${widget.roomId}');
      try {
        print('📌 [HotelRoomReservationsPage] status=${reservation.status} type=${reservation.type} hotelId=${reservation.hotelId} chambreId=${reservation.chambreId}');
      } catch (_) {}

      if (action == 'CANCELLED') {
        final usedReason = reason ?? "Refusé par l'hôte";
        print('📤 [HotelRoomReservationsPage] cancelReservation payload: {"status":"CANCELLED","reason":"$usedReason","userId":...}');
        lastResp = await ctrl.cancelReservation(
          reservation.reservationId!,
          usedReason,
          reservation: reservation,
        );
        success = lastResp.status == true;
        if (success) {
          _patchLocalStatus(reservation.reservationId, 'CANCELLED');
          if (mounted) {
            FancyNotification.show(
              context,
              "Action effectuée avec succès",
              type: NotificationType.success,
            );
            _tabController.animateTo(2);
          }
        }
      } else {
        print('📤 [HotelRoomReservationsPage] validateReservation isValid=true');
        lastResp = await ctrl.validateReservation(
          reservation.reservationId!,
          true,
          reservation: reservation,
        );
        success = lastResp.status == true;
        if (success) {
          _patchLocalStatus(reservation.reservationId, 'APPROVED');
          if (mounted) {
            _showHostActionSuccessDialog(reservation);
            _tabController.animateTo(1);
          }
        }
      }

      try {
        print('📌 [HotelRoomReservationsPage] result ok=$success httpStatus=${lastResp?.httpStatus} errorMsg=${lastResp?.errorMsg}');
        print('📌 [HotelRoomReservationsPage] data=${lastResp?.data}');
      } catch (_) {}

      if (success) {
        widget.onParentRefresh?.call();
      } else if (mounted) {
        final err = lastResp;
        if (err == null) return;
        reportApiFailureToCrashlytics(
          'HotelRoomReservationsPage',
          response: err,
          reason: 'host_room_reservation_$action',
        );
        FancyNotification.show(
          context,
          err.errorMsg ??
              "L’action n’a pas abouti. Réessayez dans un instant.",
          isError: true,
        );
      }
    } catch (e, st) {
      reportApiFailureToCrashlytics(
        'HotelRoomReservationsPage',
        error: e,
        stackTrace: st,
        reason: 'host_room_reservation_exception',
      );
      FancyNotification.show(
        context,
        "L’action n’a pas abouti. Réessayez dans un instant.",
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _cancellingIds.remove(rid);
        });
      }
    }
  }

  Future<Map<String, dynamic>?> _showHostRefuseDialog() async {
    if (_showingCancelSheet) return null;
    _showingCancelSheet = true;
    try {
      return await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => const _HostRoomCancelReasonSheet(),
      );
    } finally {
      _showingCancelSheet = false;
    }
  }


  Future<bool?> _showHostValidateDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F5E9),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Center(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE8F5E9).withOpacity(0.5),
                            blurRadius: 10,
                            spreadRadius: 5,
                          )
                        ],
                      ),
                      child: const Icon(Icons.check_circle_outline,
                          color: Color(0xFF00B894), size: 36),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Column(
                    children: [
                      const Text(
                        'Valider la réservation ?',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9).withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFF00B894).withOpacity(0.2)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Color(0xFF00B894), size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Le client recevra une notification de confirmation.',
                                style: TextStyle(
                                  color: Color(0xFF2D5016),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00B894),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Confirmer la validation',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            'Annuler',
                            style: TextStyle(
                              color: Color(0xFF666666),
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showHostManagementBottomSheet(ReservationModel reservation) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildHostManagementContent(reservation),
    );
  }

  Widget _buildHostManagementContent(ReservationModel reservation) {
    final status = reservation.status?.toUpperCase() ?? '';
    final isPending = status == 'PENDING';

    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
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
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.manage_accounts_rounded,
                    color: _primaryColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Gérer la réservation",
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _darkColor,
                      ),
                    ),
                    Text(
                      "Chambre · ${widget.roomTitle}",
                      style: TextStyle(color: _mediumGrey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (reservation.user != null) ...[
            const Text(
              "Client",
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15, color: _darkColor),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () {
                if (reservation.userImage != null &&
                    reservation.userImage!.isNotEmpty) {
                  reservation.user!.profilePicture = reservation.userImage;
                }
                UserInfoBottomSheet.show(context, reservation.user!);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _lightGrey,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: _primaryColor.withOpacity(0.2),
                      backgroundImage: (reservation.userImage != null &&
                              reservation.userImage!.isNotEmpty)
                          ? CachedNetworkImageProvider(reservation.userImage!)
                              as ImageProvider
                          : null,
                      child: (reservation.userImage != null &&
                              reservation.userImage!.isNotEmpty)
                          ? null
                          : Icon(Icons.person, color: _primaryColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reservation.user!.username ?? "Client",
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                          Text(
                            (() {
                              final raw =
                                  reservation.user?.phone?.toString().trim() ??
                                      '';
                              if (raw.isEmpty || raw.toLowerCase() == 'null') {
                                return 'Pas de téléphone';
                              }
                              return raw;
                            })(),
                            style: TextStyle(color: _mediumGrey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: _mediumGrey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          const Text(
            "Bien immobilier",
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15, color: _darkColor),
          ),
          const SizedBox(height: 8),
          Text(
            reservation.property?.title ?? "Propriété",
            style: const TextStyle(
                fontSize: 16, color: _darkColor, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded,
                  size: 14, color: _primaryColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Du ${_formatDate(reservation.startDate) ?? 'N/A'} au ${_formatDate(reservation.endDate) ?? 'N/A'}',
                  style: TextStyle(fontSize: 13, color: _mediumGrey),
                ),
              ),
            ],
          ),

          if (reservation.message != null &&
              reservation.message!.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              "Message du client",
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: _mediumGrey),
            ),
            const SizedBox(height: 4),
            Text(
              reservation.message!,
              style: const TextStyle(color: _darkColor, height: 1.4),
            ),
          ],

          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async =>
                      await _shareReservationPdf(reservation),
                  icon: Icon(Icons.ios_share_rounded, color: _primaryColor),
                  label: Text(
                    "Partager le bon",
                    style: TextStyle(
                      color: _darkColor.withOpacity(0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(
                      color: _primaryColor.withOpacity(0.3),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async =>
                      await _downloadReservationPdf(reservation),
                  icon: Icon(Icons.download_rounded, color: _primaryColor),
                  label: Text(
                    "Télécharger (PDF)",
                    style: TextStyle(
                      color: _darkColor.withOpacity(0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(
                      color: _primaryColor.withOpacity(0.3),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),
          if (isPending) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _busy
                        ? null
                        : () => _handleReservationAction(
                              reservation,
                              'CANCELLED',
                              fromBottomSheet: true,
                            ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _errorColor.withOpacity(0.1),
                      foregroundColor: _errorColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: _errorColor.withOpacity(0.2)),
                      ),
                    ),
                    child: const Text(
                      "REFUSER",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, letterSpacing: 1.1),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _busy
                        ? null
                        : () => _handleReservationAction(
                              reservation,
                              'APPROVED',
                              fromBottomSheet: true,
                            ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _successColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 4,
                      shadowColor: _successColor.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      "VALIDER",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, letterSpacing: 1.1),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Center(
              child: Text(
                "Statut actuel: ${_getStatusText(reservation.status)}",
                style: TextStyle(
                  color: _getStatusColor(reservation.status),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildEmptyStateForTab(int tabIndex) {
    final emptyMessages = [
      "Aucune réservation en attente de confirmation pour cette chambre",
      "Aucune réservation confirmée pour le moment",
      "Aucune réservation annulée",
    ];
    final emptyIcons = [
      Icons.pending_actions,
      Icons.check_circle_outline,
      Icons.cancel_outlined,
    ];

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                color: _lightGrey,
                shape: BoxShape.circle,
              ),
              child: Icon(
                emptyIcons[tabIndex],
                size: 60,
                color: _mediumGrey.withOpacity(0.3),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Aucune réservation',
              style: TextStyle(
                color: _mediumGrey,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                emptyMessages[tabIndex],
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _mediumGrey.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReservationCard(ReservationModel reservation) {
    final status = reservation.status?.toUpperCase() ?? '';
    final isPending = status == 'PENDING';
    final isCancelled = status == 'CANCELLED' || status == 'CANCELED';
    final isConfirmed = status == 'CONFIRMED' || status == 'APPROVED';
    final isCompleted = status == 'COMPLETED';
    final rid = reservation.reservationId?.toString() ?? '';
    final isCancelling =
        rid.isNotEmpty && _cancellingIds.contains(rid);
    final imageUrl = _getImageUrl(reservation);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _showHostManagementBottomSheet(reservation),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: _cardBackground,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              spreadRadius: 1,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Container(
                      height: 180,
                      decoration: BoxDecoration(
                        borderRadius:
                            const BorderRadius.vertical(top: Radius.circular(20)),
                        color: _lightGrey,
                      ),
                      child: imageUrl != null
                          ? ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(20)),
                              child: CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                placeholder: (context, url) => Container(
                                  color: _lightGrey,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: _primaryColor,
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) {
                                  return Container(
                                    color: _lightGrey,
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.hotel,
                                              size: 50, color: _mediumGrey),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Image non disponible',
                                            style: TextStyle(
                                              color: _mediumGrey,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            )
                          : Container(
                              color: _lightGrey,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.hotel,
                                        size: 50, color: _mediumGrey),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Aucune image',
                                      style: TextStyle(
                                        color: _mediumGrey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ),
                    Positioned(
                      bottom: 15,
                      left: 15,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getStatusColor(reservation.status)
                              .withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _getStatusText(reservation.status),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    if (reservation.user != null)
                      Positioned(
                        bottom: 15,
                        right: 15,
                        child: GestureDetector(
                          onTap: () =>
                              UserInfoBottomSheet.show(context, reservation.user!),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: const Icon(Icons.person_pin_rounded,
                                color: _primaryColor, size: 24),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 15,
                      right: 15,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_formatDate(reservation.createdAt)?.split(' ')[0] ?? 'N/A'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (reservation.property?.propertyId != null)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: FavoriteHeartIcon(
                                propertyId: reservation.property!.propertyId
                                    .toString(),
                                propertyTypeId:
                                    reservation.property!.propertyTypeId,
                                size: 20,
                                splashRadius: 18,
                                activeColor: Colors.red,
                                inactiveColor: _mediumGrey,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${reservation.property?.title ?? widget.roomTitle}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: _darkColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: _mediumGrey,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              "${reservation.property?.address ?? 'Adresse non disponible'}",
                              style: const TextStyle(
                                color: _mediumGrey,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _buildFeatureChips(reservation.property),
                      ),
                      const SizedBox(height: 15),
                      Divider(height: 1, color: _lightGrey),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 16, color: _primaryColor),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Du ${_formatDate(reservation.startDate) ?? 'N/A'}',
                                  style: const TextStyle(
                                    color: _darkColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Au ${_formatDate(reservation.endDate) ?? 'N/A'}',
                                  style: const TextStyle(
                                    color: _darkColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isPending)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: () {
                                    if (_busy || isCancelling) return;
                                    _handleReservationAction(
                                      reservation,
                                      'CANCELLED',
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      color: _errorColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color:
                                              _errorColor.withOpacity(0.3)),
                                    ),
                                    child: Icon(Icons.close,
                                        size: 16, color: _errorColor),
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    if (_busy || isCancelling) return;
                                    _handleReservationAction(
                                      reservation,
                                      'APPROVED',
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _successColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color:
                                              _successColor.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.check,
                                            size: 16, color: _successColor),
                                        const SizedBox(width: 4),
                                        Text(
                                          "Valider",
                                          style: TextStyle(
                                            color: _successColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else if (isConfirmed)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _successColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: _successColor.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle,
                                      size: 16, color: _successColor),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Confirmée',
                                    style: TextStyle(
                                      color: _successColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (isCompleted)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: _primaryColor.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.done_all,
                                      size: 16, color: _primaryColor),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Terminée',
                                    style: TextStyle(
                                      color: _primaryColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (isCancelled)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _errorColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: _errorColor.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.cancel,
                                      size: 16, color: _errorColor),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Annulée',
                                    style: TextStyle(
                                      color: _errorColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isCancelling)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBody(List<ReservationModel> list, int tabIndex) {
    if (list.isEmpty) return _buildEmptyStateForTab(tabIndex);
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 20),
      itemBuilder: (_, i) => _buildReservationCard(list[i]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _pending.length;
    final c = _confirmed.length;
    final a = _cancelled.length;

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
          'Réservations · ${widget.roomTitle}',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: true,
          tabs: [
            Tab(text: 'En attente${p > 0 ? ' ($p)' : ''}'),
            Tab(text: 'Confirmées${c > 0 ? ' ($c)' : ''}'),
            Tab(text: 'Annulées${a > 0 ? ' ($a)' : ''}'),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildTabBody(_pending, 0),
              _buildTabBody(_confirmed, 1),
              _buildTabBody(_cancelled, 2),
            ],
          ),
          if (_busy)
            const ModalBarrier(
              dismissible: false,
              color: Color(0x22000000),
            ),
          if (_busy)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}

/// Bottom sheet « annuler » (même principe que [BookingHistoryPage]) : le [TextEditingController]
/// vit dans l’état du sheet et n’est disposé qu’à la destruction de la route (évite IME / focus après dispose).
class _HostRoomCancelReasonSheet extends StatefulWidget {
  const _HostRoomCancelReasonSheet();

  @override
  State<_HostRoomCancelReasonSheet> createState() => _HostRoomCancelReasonSheetState();
}

class _HostRoomCancelReasonSheetState extends State<_HostRoomCancelReasonSheet> {
  final TextEditingController _reasonController = TextEditingController();
  bool _isSheetLoading = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _onConfirm() {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      FancyNotification.show(context, "Veuillez entrer une raison simple");
      return;
    }
    setState(() => _isSheetLoading = true);
    Navigator.pop(context, {
      'confirmed': true,
      'reason': reason,
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 24,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 22),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Center(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFEBEE).withOpacity(0.55),
                            blurRadius: 10,
                            spreadRadius: 5,
                          )
                        ],
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFD32F2F),
                        size: 36,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(
                        child: Text(
                          'Annuler la réservation ?',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF9C4).withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFFBC02D).withOpacity(0.2),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Color(0xFFFBC02D), size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Attention : Cette action est définitive.',
                                style: TextStyle(
                                  color: Color(0xFF5D4037),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Pourquoi souhaitez-vous annuler ?',
                        style: TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _reasonController,
                        enabled: !_isSheetLoading,
                        maxLines: 3,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Ex: empêchement de dernière minute…',
                          hintStyle: const TextStyle(
                            color: Color(0xFFAAAAAA),
                            fontSize: 14,
                          ),
                          fillColor: const Color(0xFFF5F5F5),
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSheetLoading ? null : _onConfirm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD32F2F),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isSheetLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Confirmer l\'annulation',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: _isSheetLoading ? null : () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            'Garder la réservation',
                            style: TextStyle(
                              color: Color(0xFF666666),
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
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
    );
  }
}

import 'package:casa/controllers/ReservationController.dart';
import 'package:casa/screens/auth/DecertificationInfoPage.dart';
import 'package:casa/screens/auth/IdentityVerificationPage.dart';
import 'package:casa/screens/auth/LoginScreen.dart';
import 'package:casa/models/PropertyModel.dart';
import 'package:casa/models/PropertyTypeModel.dart';
import 'package:casa/models/TerrainModel.dart';
import 'package:casa/models/ReservationModel.dart';
import 'package:casa/models/UserModel.dart';
import 'package:casa/utils/Endpoints.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/StockageKeys.dart';
import 'package:casa/utils/decertification_access_guard.dart';
import 'package:casa/utils/networkCheck.dart';
import 'package:casa/utils/export_directory.dart';
import 'package:casa/utils/SubscriptionHelper.dart';
import 'package:casa/utils/currency_display.dart';
import 'package:casa/utils/api_error_message.dart';
import 'package:casa/utils/crashlytics_api.dart';
import 'package:casa/utils/property_availability_ui.dart';
import 'package:casa/utils/reservation_pdf_bytes.dart';
import 'package:casa/widgets/property_sold_badge.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart' as picker;
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:io';
import 'dart:typed_data';

class BookingVisitPage extends StatefulWidget {
  final dynamic property;
  /// Réservation hôtel : id chambre (`POST …/public/property/hotels/chambre/{id}`).
  /// La validation hôte de ces demandes passe par `ReservationController.validateReservation` (statut API **APPROVED**).
  final int? chambreId;
  /// Site agence : `POST …/private/reservations/vacance` (corps VIP : vacanceId, dates, reservationHeure).
  /// Idem : acceptation hôte = **APPROVED** sur l’endpoint `…/vacance/update/status/{id}`.
  final bool agenceVacanceBooking;
  final String? initialVacanceDate;
  final String? initialVacanceHeure;

  const BookingVisitPage({
    Key? key,
    required this.property,
    this.chambreId,
    this.agenceVacanceBooking = false,
    this.initialVacanceDate,
    this.initialVacanceHeure,
  }) : super(key: key);

  @override
  _BookingVisitPageState createState() => _BookingVisitPageState();
}

class _BookingVisitPageState extends State<BookingVisitPage> {
  final Color _primaryColor = Color(0xFF1976D2);
  final Color _primaryDark = Color(0xFF1565C0);
  final Color _primaryLight = Color(0xFF42A5F5);
  final Color _accentColor = Color(0xFFE3F2FD);
  final Color _surfaceColor = Color(0xFFFAFBFD);
  final Color _cardColor = Colors.white;
  final Color _borderColor = Color(0xFFEEEEEE);
  final Color _textPrimary = Color(0xFF1A1A1A);
  final Color _textSecondary = Color(0xFF666666);
  final Color _textLight = Color(0xFF999999);

  final _formKey = GlobalKey<FormState>();
  final GetStorage storage = GetStorage();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final TextEditingController _notesController = TextEditingController();
  bool _isLoading = false;
  bool _showFullAddress = false;

  String _userName = ''; 
  String _userEmail = '';
  String _userPhone = '';
  int? _userId;
  String? _userProfilePhotoUrl;
  Map<String, dynamic>? _lastReservationSummary;
  pw.MemoryImage? _logoImage;

  String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[àâä]'), 'a')
        .replaceAll(RegExp(r'[îï]'), 'i')
        .replaceAll(RegExp(r'[ôö]'), 'o')
        .replaceAll(RegExp(r'[ùûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c');
  }

  String _toFrenchError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains("you already have a pending reservation")) {
      return "Vous avez déjà une réservation en attente pour ce bien.";
    }
    if (lower.contains("you can't reserve your own") ||
        lower.contains("you can\'t reserve your own") ||
        lower.contains("cant reserve your own")) {
      return "Vous ne pouvez pas réserver votre propre bien.";
    }
    if (lower.contains("already") && lower.contains("book")) {
      return "Ce créneau est déjà réservé. Choisissez un autre horaire.";
    }
    if (lower.contains("not available") || lower.contains("unavailable")) {
      return "Ce créneau n’est plus disponible. Choisissez un autre horaire.";
    }
    return ApiErrorMessages.sanitizeServerText(
      message,
      fallback:
          'La réservation n’a pas pu être enregistrée. Réessayez dans un instant.',
    );
  }

  bool _isSuccessMessage(String? message) {
    if (message == null) return false;
    final normalized = _normalize(message);
    return normalized.contains("a ete cree avec succes") ||
        normalized.contains("a ete creee avec succes") ||
        normalized.contains("a ete creer avec succes") ||
        normalized.contains("a ete creee avec succes");
  }

  // Helper pour normaliser l'accès aux données entre PropertyModel et TerrainModel
  /// [property] peut être un [PropertyModel], un [TerrainModel], ou `Map { 'property': …, 'chambreId': … }`.
  dynamic get _rawProperty {
    final p = widget.property;
    if (p is Map && p['property'] != null) return p['property'];
    return p;
  }

  int? get _effectiveChambreId {
    if (widget.chambreId != null) return widget.chambreId;
    final p = widget.property;
    if (p is Map && p['chambreId'] != null) {
      final v = p['chambreId'];
      if (v is int) return v;
      return int.tryParse(v.toString());
    }
    return null;
  }

  bool get _isTerrain => _rawProperty is TerrainModel;

  int? get _propertyId {
    if (_isTerrain) return (_rawProperty as TerrainModel).terrain?.id;
    return (_rawProperty as PropertyModel).propertyId;
  }

  String get _propertyTitle {
    if (_isTerrain) return (_rawProperty as TerrainModel).terrain?.title ?? "";
    return (_rawProperty as PropertyModel).title ?? "";
  }

  String get _propertyAddress {
    if (_isTerrain) {
      final t = _rawProperty as TerrainModel;
      return "${t.address?.cityValue ?? ''}, ${t.address?.communeValue ?? ''}";
    }
    final p = _rawProperty as PropertyModel;
    return "${p.cityValue ?? ''}, ${p.communeValue ?? ''}";
  }

  int? get _propertyOwnerId {
    if (_isTerrain) return (_rawProperty as TerrainModel).terrain?.userId;
    final p = _rawProperty as PropertyModel;
    return p.userId ?? p.user?.userId;
  }

  String? get _propertyImageUrl {
    if (_isTerrain) {
      final t = _rawProperty as TerrainModel;
      return t.images?.isNotEmpty == true ? t.images!.first.path : null;
    }
    final p = _rawProperty as PropertyModel;
    return p.propertyImage?.isNotEmpty == true ? p.propertyImage!.first.path : null;
  }

  String get _propertyType {
    if (_isTerrain) return "Terrain";
    return (_rawProperty as PropertyModel).propertyType?.name ?? "Propriété";
  }

  String get _reservationEndpoint {
    if (_isTerrain) return Endpoints.addReservationTerrain;
    if (_rawProperty is! PropertyModel) return Endpoints.createReservation;
    final p = _rawProperty as PropertyModel;

    // Hôtel + chambre : POST private/reservations/chambre (corps JSON avec chambreId).
    if (p.propertyTypeId == 5 && _effectiveChambreId != null) {
      return Endpoints.addReservationRoom;
    }

    // Utiliser propertyTypeId directement du modèle
    final typeId = p.propertyTypeId;

    if (typeId == 4) return Endpoints.addReservationBureau;
    if (typeId == 7) return Endpoints.addReservationFuneraire;
    if (typeId == 8) return Endpoints.addReservationFestive;
    if (typeId == 5) return Endpoints.addReservationRoom;
    if (typeId == 6 || typeId == 11 || typeId == 10) return Endpoints.addReservationVacance;
    
    // Gérer explicitement les chambres (si identifiées par le nom ou un ID spécifique)
    final typeName = p.propertyType?.name?.toLowerCase() ?? '';
    if (typeName.contains('chambre')) return Endpoints.addReservationRoom;
    
    return Endpoints.createReservation;
  }

  String get _propertyPriceText {
    if (_isTerrain) {
       final t = _rawProperty as TerrainModel;
       return "${t.terrain?.price?.toInt() ?? 0} ${CurrencyDisplay.symbolFromCode(t.devise?.code)}";
    }
    final p = _rawProperty as PropertyModel;
    final isForRent = p.transactionType?.toLowerCase().contains('location') ?? false;
    final price = p.price?.toInt() ?? 0;
    final sym = CurrencyDisplay.symbolFromCode(p.currency);
    return isForRent ? '$price $sym / mois' : '$price $sym';
  }

  Future<Uint8List> _buildReservationPdfBytes() async {
    final summary = _lastReservationSummary;
    // Uniformiser le document: utiliser le même générateur que BookingHistoryPage (bottomsheet).
    // On tente d'abord de reconstruire un ReservationModel depuis la réponse API.
    try {
      final responseData = summary?['responseData'];
      if (responseData is Map) {
        final parsed = ReservationModel.fromJson(
          Map<String, dynamic>.from(responseData as Map),
        );

        // Garder les mêmes props qu'avant (BookingVisitPage) pour les champs PDF:
        // adresse, type de propriété, annonceur (propriétaire).
        final rd = Map<String, dynamic>.from(responseData as Map);
        final reservationData = rd['reservation'] is Map
            ? Map<String, dynamic>.from(rd['reservation'] as Map)
            : <String, dynamic>{};
        final innerReservation = reservationData['reservation'] is Map
            ? Map<String, dynamic>.from(reservationData['reservation'] as Map)
            : <String, dynamic>{};

        Map<String, dynamic>? propertyData;
        for (final k in ['property', 'chambre', 'terrain', 'vacance', 'bureau', 'festive', 'funeraire']) {
          final v = reservationData[k];
          if (v is Map) {
            propertyData = Map<String, dynamic>.from(v);
            break;
          }
        }

        final proprietaireData =
            rd['proprietaire'] is Map ? Map<String, dynamic>.from(rd['proprietaire'] as Map) : null;
        final publisherData = proprietaireData ??
            (propertyData?['user'] is Map ? Map<String, dynamic>.from(propertyData?['user'] as Map) : null);

        String cleanAddress(dynamic raw) {
          if (raw == null) return '';
          final str = raw.toString();
          if (str.contains('{') && str.contains('}')) {
            final match = RegExp(r'(?:adresse|address)\\s?[:=]\\s?([^,}]+)').firstMatch(str);
            if (match != null) {
              return (match.group(1) ?? '')
                  .trim()
                  .replaceAll('"', '')
                  .replaceAll("'", '');
            }
          }
          return str.trim();
        }

        String? pickTypeName(dynamic raw) {
          if (raw == null) return null;
          if (raw is Map) {
            final m = Map<String, dynamic>.from(raw);
            final n = m['name']?.toString().trim();
            if (n != null && n.isNotEmpty) return n;
          }
          final s = raw.toString().trim();
          return s.isEmpty ? null : s;
        }

        // Adresse (priorités BookingVisitPage: adresseVacance / adresseHotel / address + commune/city)
        final adresseVacance = rd['adresseVacance'] ?? reservationData['adresseVacance'] ?? propertyData?['adresseVacance'];
        final adresseHotel = rd['adresseHotel'] ?? reservationData['adresseHotel'] ?? propertyData?['adresseHotel'];
        final baseAddr = cleanAddress(adresseVacance ?? adresseHotel ?? propertyData?['address']);

        final communeName = (propertyData?['commune'] is Map)
                ? (propertyData?['commune']['name']?.toString() ?? '')
                : (propertyData?['communeValue']?.toString() ?? '');
        final cityName = (propertyData?['city'] is Map)
                ? (propertyData?['city']['name']?.toString() ?? '')
                : (propertyData?['cityValue']?.toString() ?? '');
        final countryName = (propertyData?['country'] is Map)
                ? (propertyData?['country']['name']?.toString() ?? '')
                : (propertyData?['countryValue']?.toString() ?? '');
        final quartierName = (propertyData?['quartier'] is Map)
                ? (propertyData?['quartier']['name']?.toString() ?? '')
                : (propertyData?['quartierValue']?.toString() ?? '');
        final fullAddr = [baseAddr, communeName, cityName].where((e) => e.trim().isNotEmpty).join(', ');

        final typeName = pickTypeName(rd['typeProperty']) ??
            pickTypeName(reservationData['typeProperty']) ??
            pickTypeName(propertyData?['typeProperty']);

        // Annonceur: name + phone comme avant
        final postByStr = propertyData?['postBy']?.toString();
        final publisherName = (postByStr != null && postByStr.trim().isNotEmpty)
            ? postByStr.trim()
            : (publisherData?['username']?.toString() ??
                publisherData?['email']?.toString() ??
                'Non renseigné');
        final publisherPhone = rd['postByTel']?.toString() ??
            reservationData['postByTel']?.toString() ??
            propertyData?['postByTel']?.toString() ??
            publisherData?['phone']?.toString();

        final baseProp = parsed.property ??
            (widget.property is PropertyModel ? widget.property as PropertyModel : null);

        final nextProperty = baseProp?.copyWith(
              address: fullAddr.isNotEmpty ? fullAddr : null,
              communeValue: communeName.isNotEmpty ? communeName : null,
              cityValue: cityName.isNotEmpty ? cityName : null,
              countryValue: countryName.isNotEmpty ? countryName : null,
              quartierValue: quartierName.isNotEmpty ? quartierName : null,
              postBy: publisherName?.toString(),
              user: publisherData != null ? UserModel.fromJson(publisherData) : null,
              propertyType: typeName != null ? PropertyTypeModel(name: typeName) : null,
            );

        final patched = ReservationModel(
          reservationId: parsed.reservationId,
          user: parsed.user,
          proprietaire: parsed.proprietaire,
          property: nextProperty ?? parsed.property,
          message: parsed.message,
          status: parsed.status,
          type: parsed.type,
          reservationHeure: parsed.reservationHeure,
          cancellationReason: parsed.cancellationReason,
          startDate: parsed.startDate,
          endDate: parsed.endDate,
          createdAt: parsed.createdAt,
          active: parsed.active,
          terrainId: parsed.terrainId,
          bureauId: parsed.bureauId,
          vacanceId: parsed.vacanceId,
          festiveId: parsed.festiveId,
          funeraireId: parsed.funeraireId,
          hotelId: parsed.hotelId,
          chambreId: parsed.chambreId,
          userImage: parsed.userImage,
          postByTel: (publisherPhone != null && publisherPhone.toString().trim().isNotEmpty)
              ? publisherPhone.toString()
              : parsed.postByTel,
        );

        return await buildReservationPdfBytes(patched, null);
      }
    } catch (_) {
      // Fallback sur l'ancien PDF spécifique à BookingVisitPage si parsing impossible.
    }

    final doc = pw.Document();
    
    pw.Font? ttf;
    try {
      final fontData = await rootBundle.load('assets/fonts/Outfit-SemiBold.ttf');
      ttf = pw.Font.ttf(fontData);
    } catch (_) {}

    final now = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(DateTime.now());

    // Extraire les données de la réponse API si disponibles
    final responseData = summary?['responseData'] as Map<String, dynamic>?;
    final reservationData = responseData?['reservation'] as Map<String, dynamic>?;

    // Selon l’endpoint: la réponse peut contenir `property`, ou `chambre`, ou `terrain`, etc.
    // Pour les chambres d’hôtel: `reservation.chambre` + `proprietaire` au top-level.
    final propertyData = (reservationData?['property'] as Map<String, dynamic>?) ??
        (reservationData?['chambre'] as Map<String, dynamic>?) ??
        (reservationData?['terrain'] as Map<String, dynamic>?) ??
        (reservationData?['vacance'] as Map<String, dynamic>?) ??
        (reservationData?['bureau'] as Map<String, dynamic>?) ??
        (reservationData?['festive'] as Map<String, dynamic>?) ??
        (reservationData?['funeraire'] as Map<String, dynamic>?);

    // Annonceur: priorité à `proprietaire` (nouveau payload API), sinon fallback sur `property.user`.
    final proprietaireData = responseData?['proprietaire'] as Map<String, dynamic>?;
    final publisherData =
        proprietaireData ?? (propertyData?['user'] as Map<String, dynamic>?);
    final typeAccountData = publisherData?['typeAccount'] as Map<String, dynamic>?;

    // Infos propriétaire/commissionnaire depuis la réponse API
    // PRIORITÉ au postBy comme demandé par l'utilisateur
    final publisherEmail = publisherData?['email']?.toString();
    final publisherName = (propertyData?['postBy']?.toString()) ??
        publisherData?['username']?.toString() ??
        (publisherEmail != null ? publisherEmail.split('@').first : null) ??
        'Non renseigné';
    String? _pickPostByTel(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      if (s.isEmpty || s == 'null') return null;
      return s;
    }

    final publisherPhone = _pickPostByTel(responseData?['postByTel']) ??
        _pickPostByTel(reservationData?['postByTel']) ??
        _pickPostByTel(propertyData?['postByTel']) ??
        publisherData?['phone']?.toString() ??
        'Non renseigné';
    final typeAccountName = (typeAccountData?['name']?.toString() ?? '').toLowerCase();
    final publisherRole = typeAccountName.contains('bailleur')
        ? 'Bailleur'
        : (typeAccountName.contains('commission') || typeAccountName.contains('commissionnaire')
            ? 'Commissionnaire'
            : 'Annonceur');

    // Localisation enrichie
    final cityObj = propertyData?['city'] as Map<String, dynamic>?;
    final communeObj = propertyData?['commune'] as Map<String, dynamic>?;
    
    final communeName = communeObj?['name']?.toString() ?? propertyData?['communeValue']?.toString() ?? '';
    final cityName = cityObj?['name']?.toString() ?? propertyData?['cityValue']?.toString() ?? '';

    // Nettoyage de l'adresse si c'est un Map/String-Map (cas API)
    String _getCleanAddress(dynamic raw) {
      if (raw == null) return '';
      final str = raw.toString();
      if (str.contains('{') && str.contains('}')) {
        try {
          // Chercher 'adresse' (fr) ou 'address' (en)
          final match = RegExp(r'(?:adresse|address)\s?[:=]\s?([^,}]+)').firstMatch(str);
          if (match != null) {
            return match.group(1)?.trim().replaceAll('"', '').replaceAll("'", "") ?? '';
          }
        } catch (_) {}
      }
      return str;
    }

    // Selon le type: l’API peut renvoyer une adresse dédiée (`adresseHotel`, `adresseVacance`, ...)
    final adresseVacance = responseData?['adresseVacance'] ??
        reservationData?['adresseVacance'] ??
        propertyData?['adresseVacance'];
    final adresseHotel = responseData?['adresseHotel'] ??
        reservationData?['adresseHotel'] ??
        propertyData?['adresseHotel'];

    final cleanedAddress = _getCleanAddress(
      adresseVacance ?? adresseHotel ?? propertyData?['address'],
    );
    final fullAddress = [cleanedAddress, communeName, cityName]
        .where((e) => e.isNotEmpty)
        .join(', ');

    // Type de propriété depuis la réponse API
    String? _pickTypePropertyName(dynamic raw) {
      if (raw == null) return null;
      if (raw is Map) {
        final m = Map<String, dynamic>.from(raw);
        final n = m['name']?.toString().trim();
        if (n != null && n.isNotEmpty) return n;
      }
      return raw.toString().trim().isEmpty ? null : raw.toString().trim();
    }

    final propTypeName = _pickTypePropertyName(responseData?['typeProperty']) ??
        _pickTypePropertyName(reservationData?['typeProperty']) ??
        _pickTypePropertyName(propertyData?['typeProperty']) ??
        _propertyType;

    // Helper pour les lignes de détails
    pw.Widget _buildDetailRow(String label, String value) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
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
              padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
                         'BON DE RÉSERVATION',
                         style: pw.TextStyle(
                           color: PdfColors.white,
                           fontSize: 18,
                           fontWeight: pw.FontWeight.bold,
                         ),
                       ),
                       pw.Text(
                         'Confirmation de Demande de Visite',
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
                    pw.Text('Document Officiel CasaNayo', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    pw.Text('Généré le $now', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Text(
                    'EN ATTENTE DE VALIDATION', 
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1976D2'))
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 24),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 16),

            // --- SECTION 1: LA PROPRIÉTÉ ---
            pw.Text('1. DÉTAILS DE LA PROPRIÉTÉ', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1976D2'))),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(summary?['propertyTitle'] ?? widget.property.title ?? 'Propriété', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 8),
                  _buildDetailRow('Adresse', fullAddress.isNotEmpty ? fullAddress : 'Non spécifiée'),
                  _buildDetailRow('Type', propTypeName),
                ],
              ),
            ),

            pw.SizedBox(height: 24),

            // --- SECTION 2: LA VISITE ---
            // --- SECTION 2: LA VISITE ---
            pw.Text('2. RENDEZ-VOUS DE VISITE', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1976D2'))),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey200), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
              child: pw.Column(
                children: [
                  _buildDetailRow('Date de Visite', summary?['startDate'] ?? ''),
                  _buildDetailRow('Heure du RDV', summary?['startTime'] ?? ''),
                  _buildDetailRow('Fin Estimée', '${summary?['endDate'] ?? ''} à ${summary?['endTime'] ?? ''}'),
                ],
              ),
            ),

            pw.SizedBox(height: 24),

            // --- SECTION 3: LES PARTIES ---
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('3. CLIENT', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 4),
                      pw.Text(summary?['userName'] ?? safeUsername, style: const pw.TextStyle(fontSize: 9)),
                      pw.Text(_userPhone, style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('4. ANNONCEUR ($publisherRole)', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 4),
                      pw.Text(publisherName, style: const pw.TextStyle(fontSize: 9)),
                      pw.Text(publisherPhone, style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ),
              ],
            ),

            pw.Spacer(),

            // --- FOOTER ---
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 8),
            pw.Text(
              "IMPORTANT : Ce document est une preuve de demande de visite via CasaNayo. Il doit être validé par l'annonceur. Présentez ce PDF le jour du rendez-vous. Pour toute assistance : +243 836 323 805.",
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              textAlign: pw.TextAlign.justify,
            ),
            pw.SizedBox(height: 12),
            pw.Center(child: pw.Text('Document généré par CasaNayo - www.casanayo.com', style: const pw.TextStyle(fontSize: 8))),
          ],
        ),
      ),
    );

    return doc.save();
  }

  Future<void> _downloadPdf() async {
    final summary = _lastReservationSummary;
    if (summary == null) {
      FancyNotification.show(context, "Aucune réservation à exporter");
      return;
    }
    try {
      final dir = await pickExportDirectoryOrNull();
      if (dir == null) {
        if (!mounted) return;
        FancyNotification.show(
          context,
          "Enregistrement annulé : aucun dossier sélectionné.",
          type: NotificationType.info,
        );
        return;
      }

      final bytes = await _buildReservationPdfBytes();
      final generationDate = DateFormat('dd_MMMM_yyyy_HH_mm', 'fr_FR').format(DateTime.now());
      final fileName = 'Bon_Visite_${(summary['userName'] ?? safeUsername).toString().replaceAll(' ', '_')}_du_$generationDate.pdf';

      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);

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

  Future<void> _sharePdf() async {
    final summary = _lastReservationSummary;
    if (summary == null) {
      FancyNotification.show(context, "Aucune réservation à partager");
      return;
    }
    try {
      final bytes = await _buildReservationPdfBytes();
      
      final generationDate = DateFormat('dd_MMMM_yyyy_HH_mm', 'fr_FR').format(DateTime.now());
      final fileName = 'Bon_Visite_${(summary['userName'] ?? safeUsername).toString().replaceAll(' ', '_')}_du_$generationDate.pdf';
      
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(bytes);
      
      final xfile = XFile(tempFile.path, mimeType: 'application/pdf', name: fileName);
      await Share.shareXFiles(
        [xfile],
        text: "Mon bon de visite CasaNayo - ${summary['propertyTitle'] ?? 'Propriété'}",
      );
    } catch (e) {
      FancyNotification.show(context, "Partage du PDF impossible");
    }
  }

  bool get _visitSchedulingBlocked {
    if (_isTerrain) {
      final tm = _rawProperty as TerrainModel;
      final t = tm.terrain;
      return PropertyAvailabilityUi.blocksSchedulingVisit(
        sold: t?.sold,
        available: t?.isAvailable,
      );
    }
    final p = _rawProperty as PropertyModel;
    return PropertyAvailabilityUi.blocksSchedulingVisit(
      sold: p.sold,
      available: p.available,
      listingAllowed: p.listingAllowed,
    );
  }

  String _visitBlockedUserMessage() {
    if (_isTerrain) {
      final tm = _rawProperty as TerrainModel;
      final t = tm.terrain;
      if (t?.sold == true) {
        final tt = t?.transactionType?.toLowerCase() ?? '';
        if (tt.contains('vente')) return 'Ce terrain a été vendu.';
        return "Ce terrain n'est plus disponible pour une visite.";
      }
      return "Ce terrain n'est plus disponible pour une visite.";
    }
    final p = _rawProperty as PropertyModel;
    if (p.sold == true) {
      final t = p.transactionType?.toLowerCase() ?? '';
      if (t.contains('vente')) return 'Ce bien a été vendu.';
      return "Ce bien n'est plus disponible pour une visite.";
    }
    return "Ce bien n'est plus disponible pour une visite.";
  }

  String get safeUsername {
    final dynamic userData = storage.read(StockageKeys.userKey);
    if (userData != null) {
      final Map<String, dynamic> user = _convertToStringMap(userData);
      return user['username']?.toString() ?? user['name']?.toString() ?? 'Visiteur';
    }
    return 'Visiteur';
  }

  final List<TimeOfDay> _availableHours = [
    TimeOfDay(hour: 7, minute: 0),
    TimeOfDay(hour: 8, minute: 0),
    TimeOfDay(hour: 9, minute: 0),
    TimeOfDay(hour: 10, minute: 0),
    TimeOfDay(hour: 11, minute: 0),
    TimeOfDay(hour: 12, minute: 0),
    TimeOfDay(hour: 13, minute: 0),
    TimeOfDay(hour: 14, minute: 0),
    TimeOfDay(hour: 15, minute: 0),
    TimeOfDay(hour: 16, minute: 0),
    TimeOfDay(hour: 17, minute: 0),
    TimeOfDay(hour: 18, minute: 0),
  ];

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR');
    _applyAgenceVacancePrefill();
    _loadUserInfo();
    _loadLogo();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureCertifiedForBooking());
  }

  Future<void> _precacheProfilePhotoIfNeeded() async {
    final url = _userProfilePhotoUrl;
    if (url == null || url.trim().isEmpty) return;
    try {
      await precacheImage(CachedNetworkImageProvider(url), context);
    } catch (_) {
      // best-effort only
    }
  }

  void _applyAgenceVacancePrefill() {
    if (!widget.agenceVacanceBooking) return;
    final d = _parseVacanceDateString(widget.initialVacanceDate);
    final t = _parseVacanceHeureString(widget.initialVacanceHeure);
    if (d != null) _selectedDate = d;
    if (t != null) _selectedTime = t;
  }

  DateTime? _parseVacanceDateString(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final s = raw.trim();
    try {
      return DateTime.parse(s);
    } catch (_) {}
    try {
      if (RegExp(r'^\d{1,2}/\d{1,2}/\d{4}$').hasMatch(s)) {
        final p = s.split('/');
        final d = int.parse(p[0]);
        final m = int.parse(p[1]);
        final y = int.parse(p[2]);
        return DateTime(y, m, d);
      }
    } catch (_) {}
    return null;
  }

  TimeOfDay? _parseVacanceHeureString(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final s = raw.trim().replaceAll('h', ':').replaceAll('H', ':');
    final parts = s.split(':');
    if (parts.isEmpty) return null;
    final h = int.tryParse(parts[0].trim());
    if (h == null) return null;
    final minute = parts.length > 1 ? int.tryParse(parts[1].trim()) ?? 0 : 0;
    return TimeOfDay(hour: h.clamp(0, 23), minute: minute.clamp(0, 59));
  }

  /// Uniquement si le compte **a été certifié puis décertifié** : même traitement que les pages « owner ».
  Future<void> _ensureCertifiedForBooking() async {
    if (!mounted) return;
    try {
      await DecertificationAccessGuard.redirectIfInactiveDecertified(context);
    } catch (e) {
      print('⚠️ [BookingVisitPage] _ensureCertifiedForBooking: $e');
    }
  }

  Future<void> _loadLogo() async {
    try {
      final data = await rootBundle.load('assets/images/logoCasa.png');
      setState(() {
        _logoImage = pw.MemoryImage(data.buffer.asUint8List());
      });
    } catch (_) {
      // ignore logo load failure
    }
  }

  void _loadUserInfo() {
    try {
      final dynamic userData = storage.read(StockageKeys.userKey);

      if (userData != null) {
        final Map<String, dynamic> user = _convertToStringMap(userData);

        setState(() {
          final rawId = user['user']?['userId'] ?? user['userId'];
          _userId = rawId is int
              ? rawId
              : int.tryParse(rawId?.toString() ?? '');
          
          // Récupérer le nom depuis profile stocké séparément dans StockageKeys.profileKey
          final profileData = storage.read(StockageKeys.profileKey);
          Map<String, dynamic>? profile;
          
          if (profileData != null) {
            if (profileData is Map<String, dynamic>) {
              profile = profileData;
            } else if (profileData is Map<dynamic, dynamic>) {
              profile = _convertToStringMap(profileData);
            }
          }
          
          // Si profile n'est pas trouvé dans profileKey, essayer dans user['profile']
          if (profile == null) {
            final profileFromUser = user['profile'];
            if (profileFromUser != null) {
              if (profileFromUser is Map<String, dynamic>) {
                profile = profileFromUser;
              } else if (profileFromUser is Map<dynamic, dynamic>) {
                profile = _convertToStringMap(profileFromUser);
              }
            }
          }
          
          if (profile != null) {
            // PRIORITÉ 1: fullName
            final fullname = profile['fullname']?.toString() ?? profile['fullName']?.toString() ?? '';
            
            if (fullname.isNotEmpty) {
              _userName = fullname;
              print("✅ FullName récupéré: $_userName");
            } else {
              // PRIORITÉ 2: firstname + lastname
              final firstname = profile['firstname']?.toString() ?? profile['firstName']?.toString() ?? '';
              final lastname = profile['lastname']?.toString() ?? profile['lastName']?.toString() ?? '';
              print("📋 Profile trouvé - firstname: $firstname, lastname: $lastname");
              
              if (firstname.isNotEmpty || lastname.isNotEmpty) {
                _userName = '${firstname} ${lastname}'.trim();
                print("✅ Nom composé récupéré: $_userName");
              } else {
                _userName = '';
              }
            }
          } else {
            print("⚠️ Profile non trouvé dans profileKey ni dans userData");
            // Fallback sur fullName dans user directement
            final fullname = user['fullname']?.toString() ?? user['fullName']?.toString() ?? '';
            if (fullname.isNotEmpty) {
              _userName = fullname;
            } else {
              // Fallback sur les autres champs si profile n'existe pas
              final username = user['username']?.toString() ?? '';
              final name = user['name']?.toString() ?? '';
              final firstName = user['firstName']?.toString() ?? '';
              final lastname = user['lastname']?.toString() ?? user['lastName']?.toString() ?? '';
              
              if (firstName.isNotEmpty || lastname.isNotEmpty) {
                _userName = '${firstName} ${lastname}'.trim();
              } else if (username.isNotEmpty) {
                _userName = username.replaceAll('@', '').trim();
              } else if (name.isNotEmpty) {
                _userName = name.trim();
              } else {
                _userName = '';
              }
            }
          }
          
          _userEmail = user['email']?.toString() ?? '';
          _userPhone = user['phone']?.toString() ?? '';
          // Priorité: fichier local (comme ProfilePage), sinon URL profil.
          final localPath = storage.read('user_image_path');
          final localFile = (localPath != null) ? File(localPath.toString()) : null;
          if (localFile != null && localFile.existsSync()) {
            _userProfilePhotoUrl = null;
          } else {
            _userProfilePhotoUrl = _extractProfilePhotoUrl(user, profile);
          }
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _precacheProfilePhotoIfNeeded();
        });
      }
    } catch (e) {
      print("Erreur lors du chargement des infos utilisateur: $e");
    }
  }

  Map<String, dynamic> _convertToStringMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    } else if (data is Map<dynamic, dynamic>) {
      return data.map((key, value) {
        // Convertir récursivement les valeurs qui sont aussi des Maps
        if (value is Map<dynamic, dynamic>) {
          return MapEntry(key.toString(), _convertToStringMap(value));
        }
        return MapEntry(key.toString(), value);
      });
    }
    return {};
  }

  String? _extractProfilePhotoUrl(Map<String, dynamic> user, Map<String, dynamic>? profile) {
    String? pick(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      if (s.isEmpty) return null;
      if (s.toLowerCase() == 'null') return null;
      return s;
    }

    // Même stratégie que ProfilePage: profile['image'] ou profile['images'] (URL) en priorité.
    final candidates = <dynamic>[
      profile?['image'],
      profile?['images'],
      profile?['profilePicture'],
      profile?['profile_picture'],
      profile?['picture'],
      profile?['photo'],
      profile?['avatar'],
      // user map
      user['image'],
      user['images'],
      user['profilePicture'],
      user['profile_picture'],
      user['picture'],
      user['photo'],
      user['avatar'],
      (user['user'] is Map) ? (user['user'] as Map)['profilePicture'] : null,
      (user['user'] is Map) ? (user['user'] as Map)['image'] : null,
    ];
    for (final c in candidates) {
      final out = pick(c);
      if (out != null) return out;
    }
    return null;
  }

  // Ajoutez cette méthode utilitaire
  int? _getUserId() {
    final dynamic userData = storage.read(StockageKeys.userKey);

    if (userData != null) {
      final Map<String, dynamic> user = _convertToStringMap(userData);
      final dynamic userId = user['userId'];

      if (userId is int) return userId;
      if (userId is String) return int.tryParse(userId);
    }
    return null;
  }

  String _getPartialAddress(String fullAddress) {
    if (fullAddress.length <= 30) return fullAddress;

    final parts = fullAddress.split(',');
    if (parts.length > 1) {
      return '${parts[0]}, ${parts[1]}...';
    }

    return '${fullAddress.substring(0, 30)}...';
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    picker.DatePicker.showDatePicker(
      context,
      showTitleActions: true,
      minTime: DateTime.now(),
      maxTime: DateTime.now().add(const Duration(days: 60)),
      theme: picker.DatePickerTheme(
        headerColor: _primaryColor,
        backgroundColor: Colors.white,
        itemStyle: TextStyle(
          color: _textPrimary,
          fontWeight: FontWeight.w400,
          fontSize: 16,
        ),
        doneStyle: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        cancelStyle: TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
      ),
      onConfirm: (date) {
        setState(() {
          _selectedDate = date;
          _selectedTime = null;
        });
      },
      currentTime: _selectedDate ?? DateTime.now(),
      locale: picker.LocaleType.fr,
    );
  }

  void _selectTime(TimeOfDay time) {
    setState(() {
      _selectedTime = time;
    });
  }

  Future<void> _handleBooking() async {
    final userId = _getUserId();
    final safeUsername = _userName.isNotEmpty ? _userName : "Utilisateur";

    if (userId == null) {
      FancyNotification.show(
        context, 
        "Vous devez être connecté pour planifier une visite",
        type: NotificationType.info
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
      return;
    }

    if (_selectedDate == null || _selectedTime == null) {
      FancyNotification.show(context, "Veuillez sélectionner une date et une heure");
      return;
    }

    if (_visitSchedulingBlocked) {
      FancyNotification.show(context, _visitBlockedUserMessage());
      return;
    }

    final allowed =
        await SubscriptionHelper.ensurePremiumForSubmit(context: context);
    if (!allowed || !mounted) return;

    if (!mounted || _isLoading) return;
    setState(() => _isLoading = true);

    FocusScope.of(context).unfocus();

    final isConnected = await NetworkUtils.checkInternetConnectivity();
    if (!isConnected) {
      if (mounted) {
        FancyNotification.show(context, "Pas de connexion internet");
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      final reservationCtrl = context.read<ReservationController>();
      final propertyOwnerId = _propertyOwnerId;

      // L'utilisateur tente de réserver son propre bien
      if (propertyOwnerId != null &&
          propertyOwnerId.toString() == userId.toString()) {
        FancyNotification.show(
            context, "Vous ne pouvez pas réserver votre propre bien");
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Vérifier localement une réservation en attente déjà existante
      final pModel = !_isTerrain && _rawProperty is PropertyModel
          ? _rawProperty as PropertyModel
          : null;
      final typeId = pModel?.propertyTypeId;
      final isVacanceSlot = widget.agenceVacanceBooking ||
          typeId == 6 ||
          typeId == 10 ||
          typeId == 11;

      final hasPendingForSameProperty = reservationCtrl.reservations.any(
        (r) {
          if (r.user?.userId?.toString() != userId.toString()) return false;
          if (r.status?.toUpperCase() != 'PENDING') return false;
          if (_effectiveChambreId != null) {
            return r.chambreId?.toString() == _effectiveChambreId.toString();
          }
          if (_isTerrain) {
            return r.terrainId?.toString() == _propertyId?.toString();
          }
          if (isVacanceSlot) {
            return r.vacanceId?.toString() == _propertyId?.toString();
          }
          return r.property?.propertyId?.toString() == _propertyId?.toString();
        },
      );

      if (hasPendingForSameProperty) {
        FancyNotification.show(context,
            "Vous avez déjà une réservation en attente pour ce bien");
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      // MODIFICATION ICI : Format HH:mm:ss au lieu de HH:mm
      final formattedTime = '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}:00';

      // CALCUL DE LA FIN DE VISITE (1 HEURE APRÈS LE DÉBUT)
      final visitStartDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      final visitEndDateTime = visitStartDateTime.add(Duration(hours: 1));
      final formattedEndDate = DateFormat('yyyy-MM-dd').format(visitEndDateTime);
      // MODIFICATION ICI AUSSI : Format HH:mm:ss pour l'heure de fin
      final formattedEndTime = '${visitEndDateTime.hour.toString().padLeft(2, '0')}:${visitEndDateTime.minute.toString().padLeft(2, '0')}:00';

      // Timestamp actuel pour createdAt
      final now = DateTime.now();
      final formattedCreatedAt = DateFormat('yyyy-MM-ddTHH:mm:ss').format(now);

      final isHotelChambreReservation = pModel?.propertyTypeId == 5 &&
          _effectiveChambreId != null;
      final isAgenceVacanceVip = widget.agenceVacanceBooking;

      final Map<String, dynamic> reservationData = isHotelChambreReservation
          ? {
              "userId": userId,
              "chambreId": _effectiveChambreId,
              "startDate": formattedDate,
              "message": _notesController.text.isNotEmpty
                  ? _notesController.text
                  : "Demande de réservation pour cette chambre.",
              "endDate": formattedEndDate,
              "type": "VIP",
              "reservationHeure": formattedTime,
            }
          : isAgenceVacanceVip
              ? {
                  "userId": userId,
                  "vacanceId": _propertyId,
                  "startDate": formattedDate,
                  "message": _notesController.text.isNotEmpty
                      ? _notesController.text
                      : "Demande de réservation pour ce site.",
                  "endDate": formattedEndDate,
                  "type": "VIP",
                  "reservationHeure": formattedTime,
                }
              : {
                  "userId": userId,
                  "message": _notesController.text.isNotEmpty
                      ? _notesController.text
                      : "Intéressé par ${_propertyType.toLowerCase()} $_propertyTitle",
                  "status": "PENDING",
                  "type": "STANDARD",
                  "reservationHeure": formattedTime,
                  "startDate": formattedDate,
                  "endDate": formattedEndDate,
                  "createdAt": formattedCreatedAt,
                };

      if (_isTerrain) {
        reservationData["terrainId"] = _propertyId;
      } else if (!isHotelChambreReservation && !isAgenceVacanceVip) {
        final p = _rawProperty as PropertyModel;
        final tid = p.propertyTypeId;
        final typeName = p.propertyType?.name?.toLowerCase() ?? '';

        if (tid == 4) reservationData["bureauId"] = _propertyId;
        else if (tid == 7) reservationData["funeraireId"] = _propertyId;
        else if (tid == 8) reservationData["festiveId"] = _propertyId;
        else if (tid == 6 || tid == 11 || tid == 10) {
          reservationData["vacanceId"] = _propertyId;
        } else if (tid == 5) {
          reservationData["hotelId"] = _propertyId;
        } else if (typeName.contains('chambre')) {
          reservationData["chambreId"] = _propertyId;
        } else {
          reservationData["propertyId"] = _propertyId;
        }
      }

      print("Données de réservation: $reservationData");
      print("Détails de la visite:");
      print("- Début: $formattedDate à $formattedTime");
      print("- Fin: $formattedEndDate à $formattedEndTime");
      print("- Durée: 1 heure");

      final response = await reservationCtrl.createReservation(
        reservationData,
        propertyOwnerId: propertyOwnerId,
        endpoint: _reservationEndpoint,
      );

      if (!mounted) return;

      final dataMap = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : null;
      final rawMessage = dataMap?['message'] ??
          dataMap?['error'] ??
          response.errorMsg;

      final hasApiError = dataMap?['error'] != null ||
          (rawMessage != null &&
              rawMessage
                  .toString()
                  .toLowerCase()
                  .contains("you already have a pending reservation")) ||
          (rawMessage != null &&
              rawMessage
                  .toString()
                  .toLowerCase()
                  .contains("you can't reserve your own"));

      final hasReservationPayload = dataMap?['reservation'] != null;
      final messageIndicatesSuccess =
          _isSuccessMessage(rawMessage?.toString());
      final isSuccess =
          response.status == true && !hasApiError &&
              (messageIndicatesSuccess || hasReservationPayload);

      if (isSuccess) {
        // Figées avant setState : la boîte de dialogue et le PDF en ont besoin, et on vide
        // _selectedDate / _selectedTime après succès (sinon _showConfirmationDialog planterait sur !).
        final selDate = _selectedDate!;
        final selTime = _selectedTime!;

        // Formater les dates en dd-MM-yyyy
        final formattedStartDate = DateFormat('dd-MM-yyyy').format(selDate);
        final formattedEndDateDisplay = DateFormat('dd-MM-yyyy').format(visitEndDateTime);

        setState(() {
          _lastReservationSummary = {
            'propertyTitle': _propertyTitle,
            'address': _propertyAddress,
            'startDate': formattedStartDate,
            'startTime': formattedTime,
            'endDate': formattedEndDateDisplay,
            'endTime': formattedEndTime,
            'userName': safeUsername,
            'createdAt': formattedCreatedAt,
            'responseData': response.data, // Stocker la réponse complète pour le PDF
          };

          // VIDER LES CHAMPS APRÈS SUCCESS
          _selectedDate = null;
          _selectedTime = null;
          _notesController.clear();
        });
        _showConfirmationDialog(selDate, selTime);
      } else {
        reportApiFailureToCrashlytics(
          'BookingVisitPage',
          response: response,
          reason: 'create_reservation',
        );
        final errorMessage = _toFrenchError(
          rawMessage?.toString() ??
              "La réservation n’a pas pu être enregistrée. Réessayez.",
        );
        FancyNotification.show(context, errorMessage, isError: true);
        print("Erreur réponse: ${response.data}");
        final certMsg = rawMessage?.toString() ??
            response.errorMsg ??
            dataMap?['detailMessage']?.toString();
        if (ReservationController.messageIndicatesUncertifiedAccount(certMsg)) {
          final userData = storage.read(StockageKeys.userKey);
          final uid = userData is Map
              ? (userData['userId'] ?? userData['user']?['userId'])?.toString() ?? ''
              : '';
          final wasCertified =
              storage.read<bool>('${StockageKeys.wasCertifiedKey}_$uid') ?? false;
          final reason = storage
              .read<String>('${StockageKeys.decertificationReasonKey}_$uid');
          if (wasCertified) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => DecertificationInfoPage(reason: reason),
              ),
            );
          } else {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const IdentityVerificationPage(),
              ),
            );
          }
        }
      }
    } catch (e, st) {
      reportApiFailureToCrashlytics(
        'BookingVisitPage',
        error: e,
        stackTrace: st,
        reason: 'create_reservation_exception',
      );
      if (mounted) {
        FancyNotification.show(
          context,
          "La réservation n’a pas abouti. Vérifiez la connexion et réessayez.",
          isError: true,
        );
      }
      print("Booking error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showConfirmationDialog(DateTime visitDate, TimeOfDay visitTime) {
    final formattedDate =
        DateFormat('EEEE d MMMM y', 'fr_FR').format(visitDate);
    final formattedTime =
        '${visitTime.hour.toString().padLeft(2, '0')}h${visitTime.minute == 0 ? '' : visitTime.minute.toString().padLeft(2, '0')}';

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (BuildContext dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                height: 5,
                color: _primaryColor,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Visite programmée',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                        letterSpacing: -0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Votre demande a bien été envoyée au propriétaire.',
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 14,
                        height: 1.35,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F4F8),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Date et heure',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _textSecondary,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            formattedDate,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'à $formattedTime',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _primaryColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async => await _downloadPdf(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide(
                                color: _primaryColor.withOpacity(0.45),
                              ),
                              foregroundColor: _primaryColor,
                            ),
                            child: const Text(
                              'Télécharger le PDF',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () async => await _sharePdf(),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              backgroundColor: _primaryColor,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text(
                              'Partager',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          Navigator.pop(context);
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          foregroundColor: _textSecondary,
                        ),
                        child: const Text(
                          'Fermer et retourner',
                          style: TextStyle(
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
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_primaryColor, _primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Réserver une visite',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          Text(
            'Planifiez votre visite',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
      centerTitle: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceColor,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPropertyHeader(),
            const SizedBox(height: 24),

            if (_visitSchedulingBlocked) ...[
              Material(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange.shade800, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _visitBlockedUserMessage(),
                          style: TextStyle(
                            color: Colors.orange.shade900,
                            fontSize: 14,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            if (_getUserId() != null) _buildUserInfoSection(),
            const SizedBox(height: 24),

            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Planifier votre visite',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Choisissez la date et l\'heure de votre visite',
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 28),

                  _buildDateField(),
                  const SizedBox(height: 24),

                  _buildTimeGrid(),
                  const SizedBox(height: 28),

                  _buildNotesField(),
                  const SizedBox(height: 36),

                  _buildSubmitButton(),
                  
                  // Ajouter un espace pour la barre de navigation système
                  SizedBox(height: MediaQuery.of(context).viewPadding.bottom),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyHeader() {
    final imageUrl = _propertyImageUrl;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[100],
                            child: Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: _primaryColor),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[100],
                            child: Icon(Icons.home_rounded, color: Colors.grey[400], size: 30),
                          ),
                        )
                      : Container(
                          color: Colors.grey[100],
                          child: Icon(Icons.home_rounded, color: Colors.grey[400], size: 30),
                        ),
                  Positioned(
                    top: 4,
                    left: 4,
                    child: _isTerrain
                        ? PropertyListingStatusChip(
                            sold: (_rawProperty as TerrainModel).terrain?.sold,
                            transactionType:
                                (_rawProperty as TerrainModel).terrain?.transactionType,
                            available:
                                (_rawProperty as TerrainModel).terrain?.isAvailable,
                            listingAllowed: true,
                            compact: true,
                            onDarkBackground: true,
                          )
                        : PropertyListingStatusChip(
                            sold: (_rawProperty as PropertyModel).sold,
                            transactionType:
                                (_rawProperty as PropertyModel).transactionType,
                            available: (_rawProperty as PropertyModel).available,
                            listingAllowed:
                                (_rawProperty as PropertyModel).listingAllowed,
                            compact: true,
                            onDarkBackground: true,
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _propertyTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: _textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _showAddressVerification,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F4F8),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.location_on_rounded, size: 16, color: _primaryColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Adresse masquée — appuyez pour voir',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.lock_outline_rounded, size: 16, color: _primaryColor),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _propertyPriceText,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _primaryColor,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  void _showAddressVerification() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icone décorative
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.location_on_rounded,
                      size: 40,
                      color: _primaryColor,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Titre
                  Text(
                    "Adresse Protégée",
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // Sous-titre
                  Text(
                    "Pour préserver l'intimité des propriétaires",
                    style: TextStyle(
                      color: _textPrimary.withOpacity(0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Contenu
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _accentColor.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _primaryColor.withOpacity(0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: _primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "L'adresse exacte vous sera communiquée après réservation et sera disponible dans votre document de confirmation à télécharger.",
                            style: TextStyle(
                              color: _textPrimary.withOpacity(0.8),
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Bouton Principal
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Fermer",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
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
      },
    );
  }

  void _navigateToContactPage() {
    // Navigation vers la page de contact/rendez-vous
    // Navigator.push(context, MaterialPageRoute(builder: (context) => ContactPage()));
  }

  Widget _buildUserInfoSection() {
    // Récupérer le nom depuis GetStorage de manière sécurisée
    String displayName = _userName; // Utiliser le nom déjà chargé dans _loadUserInfo()
    
    // Si _userName est vide ou null, essayer de récupérer depuis GetStorage directement
    if (displayName.isEmpty || displayName == 'null') {
      try {
        // Essayer d'abord depuis StockageKeys.profileKey (stockage séparé)
        final dynamic profileData = storage.read(StockageKeys.profileKey);
        print("🔍 Profile depuis profileKey: $profileData");
        
        Map<String, dynamic>? profile;
        
        if (profileData != null) {
          if (profileData is Map<String, dynamic>) {
            profile = profileData;
          } else if (profileData is Map<dynamic, dynamic>) {
            profile = _convertToStringMap(profileData);
          }
        }
        
        // Si pas trouvé, essayer depuis userData['profile']
        if (profile == null) {
          final dynamic userData = storage.read(StockageKeys.userKey);
          print("🔍 UserData depuis userKey: $userData");
          
          if (userData != null) {
            final Map<String, dynamic> user = _convertToStringMap(userData);
            final profileFromUser = user['profile'];
            
            if (profileFromUser != null) {
              if (profileFromUser is Map<String, dynamic>) {
                profile = profileFromUser;
              } else if (profileFromUser is Map<dynamic, dynamic>) {
                profile = _convertToStringMap(profileFromUser);
              }
            }
          }
        }
        
        if (profile != null) {
          // PRIORITÉ 1: fullName
          final fullname = profile['fullname']?.toString() ?? profile['fullName']?.toString() ?? '';
          
          if (fullname.isNotEmpty) {
            displayName = fullname;
          } else {
            // PRIORITÉ 2: firstname + lastname
            final firstname = profile['firstname']?.toString() ?? profile['firstName']?.toString() ?? '';
            final lastname = profile['lastname']?.toString() ?? profile['lastName']?.toString() ?? '';
            print("📋 Profile trouvé (fallback) - firstname: $firstname, lastname: $lastname");
            
            if (firstname.isNotEmpty || lastname.isNotEmpty) {
              displayName = '${firstname} ${lastname}'.trim();
            } else {
              displayName = 'Visiteur';
            }
          }
        } else {
          print("⚠️ Profile non trouvé dans profileKey ni dans userData (fallback)");
          displayName = 'Visiteur';
        }
      } catch (e, stackTrace) {
        print("❌ Erreur lors de la récupération du nom: $e");
        print("Stack trace: $stackTrace");
        displayName = (_userName.isNotEmpty && _userName != 'null') ? _userName : 'Visiteur';
      }
    }
    
    // Nettoyer le nom si c'est "null" ou vide
    if (displayName == 'null' || displayName.isEmpty) {
      displayName = 'Visiteur';
    }
    
    print("✅ Nom final à afficher: $displayName");
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_accentColor, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primaryColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_primaryColor, _primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: _primaryColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Builder(
              builder: (context) {
                final localPath = storage.read('user_image_path');
                final localFile = (localPath != null) ? File(localPath.toString()) : null;
                if (localFile != null && localFile.existsSync()) {
                  return Image.file(localFile, width: 50, height: 50, fit: BoxFit.cover);
                }
                if (_userProfilePhotoUrl != null) {
                  return CachedNetworkImage(
                    imageUrl: _userProfilePhotoUrl!,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    fadeInDuration: Duration.zero,
                    fadeOutDuration: Duration.zero,
                    placeholder: (_, __) => const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                    ),
                    errorWidget: (_, __, ___) => const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 24,
                    ),
                  );
                }
                return const Icon(Icons.person, color: Colors.white, size: 24);
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName.isNotEmpty ? 'Bonjour, $displayName' : 'Bonjour',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                if (_userEmail.isNotEmpty)
                  Text(
                    _userEmail,
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_month, size: 18, color: _primaryColor),
            const SizedBox(width: 8),
            Text(
              'Date de visite',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _textPrimary,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: _selectDate,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedDate == null ? _borderColor : _primaryColor,
                width: _selectedDate == null ? 1.5 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedDate == null
                      ? 'Sélectionnez une date'
                      : DateFormat('EEEE d MMMM y', 'fr_FR').format(_selectedDate!),
                  style: TextStyle(
                    color: _selectedDate == null ? _textLight : _textPrimary,
                    fontSize: 16,
                    fontWeight: _selectedDate == null ? FontWeight.normal : FontWeight.w600,
                  ),
                ),
                Icon(
                  Icons.calendar_today_rounded,
                  color: _selectedDate == null ? _textLight : _primaryColor,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.access_time_rounded, size: 18, color: _primaryColor),
            const SizedBox(width: 8),
            Text(
              'Heure de visite (7h - 18h)',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _textPrimary,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_selectedDate == null)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _borderColor),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 40, color: _textLight),
                  const SizedBox(height: 12),
                  Text(
                    'Sélectionnez d\'abord une date',
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.2,
            ),
            itemCount: _availableHours.length,
            itemBuilder: (context, index) {
              final time = _availableHours[index];
              final isSelected = _selectedTime == time;
              final isPastTime = _isPastTime(time);

              return Tooltip(
                message: isPastTime ? 'Cette heure est déjà passée' : '',
                child: InkWell(
                  onTap: isPastTime ? null : () => _selectTime(time),
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _primaryColor
                          : isPastTime
                          ? Colors.grey[100]
                          : _cardColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? _primaryColor
                            : isPastTime
                            ? Colors.grey[300]!
                            : _borderColor,
                        width: isSelected ? 2 : 1.5,
                      ),
                      boxShadow: isSelected
                          ? [
                        BoxShadow(
                          color: _primaryColor.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                          : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Text(
                            '${time.hour.toString().padLeft(2, '0')}h${time.minute == 0 ? '' : time.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : isPastTime
                                  ? _textLight
                                  : _textPrimary,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (isPastTime)
                          Positioned(
                            top: 2,
                            right: 2,
                            child: Icon(
                              Icons.block,
                              size: 12,
                              color: Colors.red.withOpacity(0.7),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  bool _isPastTime(TimeOfDay time) {
    if (_selectedDate == null) return false;

    final now = DateTime.now();
    final selectedDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      time.hour,
      time.minute,
    );

    return selectedDateTime.isBefore(now);
  }

  Widget _buildNotesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.message_rounded, size: 18, color: _primaryColor),
            const SizedBox(width: 8),
            Text(
              'Message (optionnel)',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _textPrimary,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextFormField(
            controller: _notesController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Précisez vos besoins, questions ou contraintes...',
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _primaryColor, width: 2),
              ),
              filled: true,
              fillColor: _cardColor,
              contentPadding: const EdgeInsets.all(18),
              hintStyle: TextStyle(color: _textLight, fontSize: 15),
            ),
            style: TextStyle(fontSize: 15, color: _textPrimary),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    final isFormValid = _selectedDate != null && _selectedTime != null;
    final canSubmit = isFormValid && !_isLoading && !_visitSchedulingBlocked;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: canSubmit ? _handleBooking : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: canSubmit ? _primaryColor : Colors.grey[400],
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 18),
          elevation: 4,
          shadowColor: canSubmit ? _primaryColor.withOpacity(0.4) : Colors.transparent,
        ),
        child: _isLoading
            ? SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: Colors.white,
          ),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today_rounded, size: 20),
            const SizedBox(width: 10),
            Text(
              'CONFIRMER LA VISITE',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

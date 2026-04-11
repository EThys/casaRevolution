import 'package:casa/controllers/ReservationController.dart';
import 'package:casa/screens/auth/DecertificationInfoPage.dart';
import 'package:casa/screens/auth/IdentityVerificationPage.dart';
import 'package:casa/screens/auth/LoginScreen.dart';
import 'package:casa/models/PropertyModel.dart';
import 'package:casa/models/TerrainModel.dart';
import 'package:casa/utils/Endpoints.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/StockageKeys.dart';
import 'package:casa/utils/decertification_access_guard.dart';
import 'package:casa/utils/networkCheck.dart';
import 'package:casa/utils/Constantes.dart';
import 'package:casa/utils/export_directory.dart';
import 'package:casa/utils/property_availability_ui.dart';
import 'package:casa/widgets/property_sold_badge.dart';
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
  final int? chambreId;

  const BookingVisitPage({Key? key, required this.property, this.chambreId})
      : super(key: key);

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
      return "Vous avez déjà une réservation en attente pour ce bien";
    }
    if (lower.contains("you can't reserve your own property") ||
        lower.contains("you can\'t reserve your own property")) {
      return "Vous ne pouvez pas réserver votre propre bien";
    }
    if (lower.contains("already") && lower.contains("book")) {
      return "Ce créneau est déjà réservé, veuillez choisir une autre heure.";
    }
    if (lower.contains("not available") || lower.contains("unavailable")) {
      return "Ce créneau n'est plus disponible, choisissez un autre horaire.";
    }
    return message;
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
       return "${t.terrain?.price?.toInt() ?? 0} ${t.devise?.code ?? 'USD'}";
    }
    final p = _rawProperty as PropertyModel;
    final isForRent = p.transactionType?.toLowerCase().contains('location') ?? false;
    final price = p.price?.toInt() ?? 0;
    return isForRent ? '${price} ${p.currency} / mois' : '${price} ${p.currency}';
  }

  Future<Uint8List> _buildReservationPdfBytes() async {
    final summary = _lastReservationSummary;
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
    final propertyData = reservationData?['property'] as Map<String, dynamic>?;
    final publisherData = propertyData?['user'] as Map<String, dynamic>?;
    final typeAccountData = publisherData?['typeAccount'] as Map<String, dynamic>?;

    // Infos propriétaire/commissionnaire depuis la réponse API
    // PRIORITÉ au postBy comme demandé par l'utilisateur
    final publisherName = propertyData?['postBy']?.toString() ?? 
        publisherData?['username']?.toString() ?? 
        publisherData?['email']?.toString()?.split('@').first ?? 
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
    final typeAccountName = typeAccountData?['name']?.toString()?.toLowerCase() ?? '';
    final publisherRole = typeAccountName.contains('bailleur')
        ? 'Bailleur'
        : (typeAccountName.contains('commission') || typeAccountName.contains('commissionnaire')
            ? 'Commissionnaire'
            : 'Annonceur');

    // Localisation enrichie
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

    final cleanedAddress = _getCleanAddress(propertyData?['address']);
    final fullAddress = [cleanedAddress, communeName, cityName]
        .where((e) => e.isNotEmpty)
        .join(', ');

    // Type de propriété depuis la réponse API
    final propTypeName = propertyData?['typeProperty']?['name']?.toString() ?? _propertyType;

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
      final bytes = await _buildReservationPdfBytes();
      final dir = await getCasaNayoExportDirectory(CasaNayoExportKind.reservation);
      
      final generationDate = DateFormat('dd_MMMM_yyyy_HH_mm', 'fr_FR').format(DateTime.now());
      final fileName = 'Bon_Visite_${(summary['userName'] ?? safeUsername).toString().replaceAll(' ', '_')}_du_$generationDate.pdf';
      
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      
      FancyNotification.show(
        context,
        "PDF enregistré dans ${dir.path}",
        isError: false,
        type: NotificationType.success,
      );
    } catch (e) {
      FancyNotification.show(context, "Impossible de générer le PDF");
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
    _loadUserInfo();
    _loadLogo();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureCertifiedForBooking());
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
      final hasPendingForSameProperty = reservationCtrl.reservations.any(
        (r) {
          if (r.user?.userId?.toString() != userId.toString()) return false;
          if (r.status?.toUpperCase() != 'PENDING') return false;
          if (_effectiveChambreId != null) {
            return r.chambreId?.toString() == _effectiveChambreId.toString();
          }
          final rId = (_isTerrain ? r.terrainId : r.property?.propertyId)?.toString();
          return rId == _propertyId?.toString();
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

      final pModel = !_isTerrain && _rawProperty is PropertyModel
          ? _rawProperty as PropertyModel
          : null;
      final isHotelChambreReservation = pModel?.propertyTypeId == 5 &&
          _effectiveChambreId != null;

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
      } else if (!isHotelChambreReservation) {
        final p = _rawProperty as PropertyModel;
        final typeId = p.propertyTypeId;
        final typeName = p.propertyType?.name?.toLowerCase() ?? '';

        if (typeId == 4) reservationData["bureauId"] = _propertyId;
        else if (typeId == 7) reservationData["funeraireId"] = _propertyId;
        else if (typeId == 8) reservationData["festiveId"] = _propertyId;
        else if (typeId == 6 || typeId == 11 || typeId == 10) {
          reservationData["vacanceId"] = _propertyId;
        } else if (typeId == 5) {
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
                  .contains("you can't reserve your own property"));

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
        final errorMessage = _toFrenchError(
          rawMessage?.toString() ?? "Erreur lors de la réservation",
        );
        FancyNotification.show(context, errorMessage);
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
    } catch (e) {
      if (mounted) {
        FancyNotification.show(context, "Erreur technique lors de la réservation: $e");
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
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          elevation: 0,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_primaryColor, _primaryLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Visite programmée !',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Text(
                    'Votre demande a été envoyée avec succès',
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 15,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_accentColor, Colors.white],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _primaryColor.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.calendar_month, color: _primaryColor, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Rendez-vous confirmé',
                              style: TextStyle(
                                color: _textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _primaryColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'à $formattedTime',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Export / Partage (confirmation)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async => await _downloadPdf(),
                          icon: Icon(Icons.download_rounded, color: _primaryColor),
                          label: Text(
                            "Télécharger",
                            style: TextStyle(
                              color: _textPrimary.withOpacity(0.9),
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
                        child: ElevatedButton.icon(
                          onPressed: () async => await _sharePdf(),
                          icon: Icon(Icons.ios_share_rounded),
                          label: Text(
                            "Partager",
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor: _primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        elevation: 2,
                        shadowColor: _primaryColor.withOpacity(0.3),
                      ),
                      child: Text(
                        'Retour à l\'accueil',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
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
                      ? Image.network(
                          imageUrl,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
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
                          )
                        : PropertyListingStatusChip(
                            sold: (_rawProperty as PropertyModel).sold,
                            transactionType:
                                (_rawProperty as PropertyModel).transactionType,
                            available: (_rawProperty as PropertyModel).available,
                            listingAllowed:
                                (_rawProperty as PropertyModel).listingAllowed,
                            compact: true,
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

                // Adresse masquée avec effet de flou
                GestureDetector(
                  onTap: () {
                    // Action pour révéler l'adresse (redirection, popup, etc.)
                    _showAddressVerification();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _accentColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _primaryColor.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.location_on_rounded, size: 14, color: _primaryColor),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Texte flouté
                              Text(
                                _propertyAddress,
                                style: TextStyle(
                                  color: Colors.transparent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              // Overlay flou
                              Container(
                                height: 20,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  color: Colors.black.withOpacity(0.1),
                                ),
                                child: Center(
                                  child: Text(
                                    "••••••••••••••••••••",
                                    style: TextStyle(
                                      color: _textPrimary.withOpacity(0.7),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.lock_outline,
                          size: 14,
                          color: _primaryColor,
                        ),
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
                      fontSize: 16,
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
            child: Icon(
              Icons.person,
              color: Colors.white,
              size: 24,
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

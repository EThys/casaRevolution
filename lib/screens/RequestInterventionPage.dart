import 'package:casa/models/PrestationModel.dart';
import 'package:casa/models/DeviseModel.dart';
import 'package:casa/controllers/ServiceController.dart';
import 'package:casa/screens/auth/LoginScreen.dart';
import 'package:provider/provider.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/api_error_message.dart';
import 'package:casa/utils/crashlytics_api.dart';
import 'package:casa/utils/StockageKeys.dart';
import 'package:casa/utils/decertification_access_guard.dart';
import 'package:casa/utils/networkCheck.dart';
import 'package:casa/utils/offline_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart' as picker;
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:casa/utils/export_directory.dart';
import 'package:casa/utils/SubscriptionHelper.dart';
import 'package:casa/utils/currency_display.dart';
import 'package:casa/utils/french_date.dart';
import 'package:casa/utils/status_labels_fr.dart';
import 'package:casa/widgets/RequestSentDialog.dart';


class RequestInterventionPage extends StatefulWidget {
  final PrestationModel service;

  const RequestInterventionPage({Key? key, required this.service}) : super(key: key);

  @override
  _RequestInterventionPageState createState() => _RequestInterventionPageState();
}

class _RequestInterventionPageState extends State<RequestInterventionPage> {
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
  DateTime? _selectedEndDate;
  TimeOfDay? _selectedTime;
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();
  DeviseModel? _selectedDevise;
  bool _isLoading = false;

  String _userName = '';
  String _userEmail = '';
  String _userPhone = '';
  int? _userId;
  String? _userProfilePhotoUrl;
  pw.MemoryImage? _logoImage;


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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (await DecertificationAccessGuard.redirectIfInactiveDecertified(
            context,
          )) {
        return;
      }
      if (!mounted) return;
      await _loadDevises();
    });
    _loadLogo();
  }

  Future<void> _precacheProfilePhotoIfNeeded() async {
    final url = _userProfilePhotoUrl;
    if (url == null || url.trim().isEmpty) return;
    try {
      await precacheImage(OfflineImageProvider(url), context);
    } catch (_) {
      // best-effort only
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
            } else {
              // PRIORITÉ 2: firstname + lastname
              final firstname = profile['firstname']?.toString() ?? profile['firstName']?.toString() ?? '';
              final lastname = profile['lastname']?.toString() ?? profile['lastName']?.toString() ?? '';
              
              if (firstname.isNotEmpty || lastname.isNotEmpty) {
                _userName = '${firstname} ${lastname}'.trim();
              } else {
                _userName = '';
              }
            }
          } else {
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

  Future<void> _loadDevises() async {
    final serviceCtrl = Provider.of<ServiceController>(context, listen: false);
    await serviceCtrl.fetchDevises();
    if (mounted && serviceCtrl.devisesList.isNotEmpty) {
      setState(() {
        _selectedDevise = serviceCtrl.devisesList.firstWhere((d) => d.code == 'USD', orElse: () => serviceCtrl.devisesList.first);
      });
    }
  }

  Map<String, dynamic> _convertToStringMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    } else if (data is Map<dynamic, dynamic>) {
      return data.map((key, value) {
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

    final candidates = <dynamic>[
      profile?['image'],
      profile?['images'],
      profile?['profilePicture'],
      profile?['profile_picture'],
      profile?['picture'],
      profile?['photo'],
      profile?['avatar'],
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
      theme: _getDatePickerTheme(),
      onConfirm: (date) {
        setState(() {
          _selectedDate = date;
          // Si la date d'intervention change, on reset la date de fin si elle est avant
          if (_selectedEndDate != null && _selectedEndDate!.isBefore(date)) {
            _selectedEndDate = null;
          }
          _selectedTime = null;
        });
      },
      currentTime: _selectedDate ?? DateTime.now(),
      locale: picker.LocaleType.fr,
    );
  }

  Future<void> _selectEndDate() async {
    if (_selectedDate == null) {
      FancyNotification.show(context, "Veuillez d'abord sélectionner une date de début");
      return;
    }

    picker.DatePicker.showDatePicker(
      context,
      showTitleActions: true,
      minTime: _selectedDate!,
      maxTime: _selectedDate!.add(const Duration(days: 60)),
      theme: _getDatePickerTheme(),
      onConfirm: (date) {
        setState(() {
          _selectedEndDate = date;
        });
      },
      currentTime: _selectedEndDate ?? _selectedDate!,
      locale: picker.LocaleType.fr,
    );
  }

  picker.DatePickerTheme _getDatePickerTheme() {
    return picker.DatePickerTheme(
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
    );
  }

  void _selectTime(TimeOfDay time) {
    setState(() {
      _selectedTime = time;
    });
  }

  Future<void> _handleInterventionRequest() async {
    final userId = _getUserId();
    if (userId == null) {
      FancyNotification.show(
        context, 
        "Vous devez être connecté pour demander une intervention",
        type: NotificationType.info
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
      return;
    }

    if (_selectedDate == null) {
      FancyNotification.show(context, "Veuillez sélectionner une date de début");
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
      final double? budget = double.tryParse(_budgetController.text.replaceAll(RegExp(r'[^0-9.]'), ''));
      if (budget == null) {
        FancyNotification.show(context, "Budget invalide");
        return;
      }

      final solicitationData = {
        "userId": userId,
        "prestationId": widget.service.id,
        "deviseId": _selectedDevise?.id ?? 1,
        "budget": budget,
        "description": _notesController.text.trim(),
        "startDate": DateFormat('yyyy-MM-dd').format(_selectedDate!),
        "endDate": DateFormat('yyyy-MM-dd').format(_selectedEndDate ?? _selectedDate!),
      };


      final serviceCtrl = Provider.of<ServiceController>(context, listen: false);
      final response = await serviceCtrl.createSolicitation(solicitationData);

      if (!mounted) return;

      if (response.status) {
         Map<String, dynamic> responseData = {};
         if (response.data is Map) {
            responseData = Map<String, dynamic>.from(response.data);
         }

         final startSnapshot = _selectedDate;
         final endSnapshot = _selectedEndDate;
         final budgetSnapshot = budget;
         final deviseSnapshot = _selectedDevise?.displaySymbol ?? '';
         responseData['localDescription'] = _notesController.text.trim();
         responseData['localBudget'] = budgetSnapshot;
         responseData['localDevise'] = deviseSnapshot;
         responseData['localStart'] = startSnapshot == null
             ? ''
             : DateFormat('yyyy-MM-dd').format(startSnapshot);
         responseData['localEnd'] = endSnapshot == null
             ? ''
             : DateFormat('yyyy-MM-dd').format(endSnapshot);

         // VIDER LES CHAMPS APRÈS SUCCESS (ne pas utiliser _selectedDate! dans le dialogue ensuite)
         setState(() {
           _selectedDate = null;
           _selectedEndDate = null;
           _selectedTime = null;
           _notesController.clear();
           _budgetController.clear();
         });

         _showConfirmationDialog(
           responseData,
           startDate: startSnapshot,
           endDate: endSnapshot,
           budget: budgetSnapshot,
           devise: deviseSnapshot,
         );
      } else {
         reportApiFailureToCrashlytics(
           'RequestInterventionPage',
           response: response,
           reason: 'create_solicitation',
         );
         FancyNotification.show(
           context,
           ApiErrorMessages.fromResponse(response),
           isError: true,
         );
      }

    } catch (e, st) {
      reportApiFailureToCrashlytics(
        'RequestInterventionPage',
        error: e,
        stackTrace: st,
        reason: 'create_solicitation_exception',
      );
      if (mounted) {
        FancyNotification.show(
          context,
          "La demande n’a pas pu être envoyée. Vérifiez la connexion et réessayez.",
          isError: true,
        );
      }
      print("Intervention request error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  DateTime? _startDateFromSolicitationResponse(Map<String, dynamic> data) {
    final w = data['sollicitation'];
    if (w is! Map) return null;
    final outer = Map<String, dynamic>.from(w as Map);
    final inner = outer['sollicitation'];
    final node =
        inner is Map ? Map<String, dynamic>.from(inner as Map) : outer;
    final s = node['startDate']?.toString();
    if (s == null || s.isEmpty) return null;
    return DateTime.tryParse(s) ?? DateTime.tryParse(s.split('T').first);
  }

  void _showConfirmationDialog(
    Map<String, dynamic> successData, {
    DateTime? startDate,
    DateTime? endDate,
    double? budget,
    String devise = '',
  }) {
    final date = startDate ?? _startDateFromSolicitationResponse(successData);
    final formattedDate = date != null
        ? DateFormat('EEEE d MMMM y', 'fr_FR').format(date)
        : '';
    final formattedEnd = endDate != null
        ? DateFormat('EEEE d MMMM y', 'fr_FR').format(endDate)
        : '';
    final budgetLabel = budget == null
        ? ''
        : '${NumberFormat('#,##0.##', 'fr_FR').format(budget)} ${devise.trim()}'.trim();
    final ref = _solicitationRef(successData);

    showRequestSentDialog(
      context: context,
      primaryColor: _primaryColor,
      message: 'Votre demande d’intervention a bien été envoyée au prestataire.',
      facts: [
        RequestSentFact(
          icon: Icons.handyman_rounded,
          label: 'Service',
          value: (widget.service.title ?? '').trim(),
        ),
        if (ref.isNotEmpty)
          RequestSentFact(
            icon: Icons.tag_rounded,
            label: 'Référence',
            value: '#$ref',
          ),
        RequestSentFact(
          icon: Icons.event_rounded,
          label: 'Début',
          value: formattedDate,
        ),
        if (formattedEnd.isNotEmpty)
          RequestSentFact(
            icon: Icons.event_available_rounded,
            label: 'Fin',
            value: formattedEnd,
          ),
        RequestSentFact(
          icon: Icons.payments_rounded,
          label: 'Budget',
          value: budgetLabel,
        ),
        const RequestSentFact(
          icon: Icons.hourglass_top_rounded,
          label: 'Statut',
          value: 'En attente de confirmation',
        ),
      ],
      onDownload: () => _downloadInterventionPdf(successData),
      onShare: () => _shareInterventionPdf(successData),
      onClose: () {
        if (mounted) Navigator.pop(context);
      },
    );
  }

  String _solicitationRef(Map<String, dynamic> data) {
    Map<String, dynamic> asMap(dynamic value) {
      if (value is Map) return Map<String, dynamic>.from(value);
      return {};
    }

    var root = asMap(data);
    if (root['sollicitation'] == null && root['data'] is Map) {
      root = asMap(root['data']);
    }
    final wrapper = asMap(root['sollicitation']);
    final nested = asMap(wrapper['sollicitation']);
    final node = nested.isNotEmpty ? nested : wrapper;
    final id = node['id'] ?? root['id'];
    final text = id?.toString().trim() ?? '';
    if (text.isEmpty || text == 'null') return '';
    return text;
  }

  Future<Uint8List> _buildInterventionPdfBytes(Map<String, dynamic> data) async {
    final doc = pw.Document();
    
    pw.Font? ttf;
    try {
      final fontData = await rootBundle.load('assets/fonts/Outfit-SemiBold.ttf');
      ttf = pw.Font.ttf(fontData);
    } catch (_) {}

    final now = DateFormat('dd/MM/yy HH:mm', 'fr_FR').format(DateTime.now());
    final service = widget.service;

    Map<String, dynamic> asMap(dynamic value) {
      if (value is Map) return Map<String, dynamic>.from(value);
      return {};
    }

    String pick(dynamic value) {
      if (value == null) return '';
      final text = value.toString().trim();
      if (text.isEmpty || text.toLowerCase() == 'null') return '';
      return text;
    }

    String first(List<String> values) {
      for (final value in values) {
        if (value.trim().isNotEmpty) return value.trim();
      }
      return '';
    }

    String shown(String value) => value.trim().isEmpty ? 'Non renseigné' : value.trim();

    String shownDate(dynamic raw) {
      final value = formatFrenchShortDate(pick(raw));
      return value == '—' ? 'Non renseignée' : value;
    }

    var root = asMap(data);
    if (root['sollicitation'] == null && root['data'] is Map) {
      root = asMap(root['data']);
    }
    final wrapper = asMap(root['sollicitation']);
    final nested = asMap(wrapper['sollicitation']);
    final sol = nested.isNotEmpty ? nested : wrapper;
    final prestation = asMap(root['prestation']).isNotEmpty
        ? asMap(root['prestation'])
        : asMap(wrapper['prestation']);
    final userApi = asMap(root['user']).isNotEmpty
        ? asMap(root['user'])
        : asMap(root['demandeur']);
    final devise = asMap(root['devise']).isNotEmpty
        ? asMap(root['devise'])
        : asMap(wrapper['devise']);

    final ref = first([pick(sol['id']), pick(root['id']), 'NO-REF']);
    final status = frSolicitationStatus(first([pick(sol['status']), 'PENDING']));
    final serviceTitle = first([
      pick(prestation['title']),
      pick(service.title),
      'Service CasaNayo',
    ]);
    final providerName = first([
      pick(service.postBy),
      pick(service.username),
      pick(service.user?.displayFullName),
      pick(prestation['postBy']),
      pick(prestation['username']),
    ]);
    final providerPhone = first([
      pick(root['postByTel']),
      pick(wrapper['postByTel']),
      pick(sol['postByTel']),
      pick(prestation['postByTel']),
      pick(prestation['phone']),
      pick(service.phone),
      pick(service.user?.phone),
    ]);
    final providerEmail = first([
      pick(prestation['email']),
      pick(service.email),
      pick(service.user?.email),
    ]);
    final place = first([
      [
        pick(prestation['address']).isNotEmpty ? pick(prestation['address']) : pick(service.address),
        pick(prestation['quartierValue']).isNotEmpty ? pick(prestation['quartierValue']) : pick(service.quartierValue),
        pick(prestation['communeValue']).isNotEmpty ? pick(prestation['communeValue']) : pick(service.communeValue),
        pick(prestation['cityValue']).isNotEmpty ? pick(prestation['cityValue']) : pick(service.cityValue),
        pick(prestation['countryValue']).isNotEmpty ? pick(prestation['countryValue']) : pick(service.countryValue),
      ].where((part) => part.isNotEmpty).join(', '),
    ]);
    final availability = [
      first([pick(service.plageJourPrestation), pick(prestation['plageJourPrestation'])]),
      first([pick(service.plageHeurePrestation), pick(prestation['plageHeurePrestation'])]),
    ].where((part) => part.isNotEmpty).join(' · ');
    String money(dynamic amount) {
      final number = amount is num ? amount.toDouble() : double.tryParse(pick(amount).replaceAll(',', '.'));
      if (number == null) return '';
      return NumberFormat('#,##0.##', 'fr_FR').format(number);
    }

    final tariff = () {
      final cur = service.currency;
      String priced(double? amount) {
        if (amount == null || amount <= 0) return '';
        return '${money(amount)} $cur';
      }

      final min = priced(service.minPrice);
      final max = priced(service.maxPrice);
      if (min.isEmpty && max.isEmpty) return '';
      if (max.isEmpty || min == max) return min.isEmpty ? '' : 'À partir de $min $cur';
      if (min.isEmpty) return 'Jusqu’à $max $cur';
      return 'De $min à $max $cur';
    }();
    final deviseLabel = first([
      pick(data['localDevise']),
      CurrencyDisplay.symbolFromCode(pick(devise['code'])),
      pick(devise['code']),
    ]);
    final budgetValue = first([
      pick(sol['budget']),
      pick(data['localBudget']),
    ]);
    final budgetLabel = money(budgetValue).isEmpty
        ? shown(budgetValue)
        : '${money(budgetValue)} $deviseLabel'.trim();
    final description = first([
      pick(sol['description']),
      pick(data['localDescription']),
    ]);
    final clientName = first([
      _userName,
      pick(userApi['fullName']),
      pick(userApi['username']),
    ]);
    final clientPhone = first([_userPhone, pick(userApi['phone'])]);
    final clientEmail = first([_userEmail, pick(userApi['email'])]);
    final startRaw = first([pick(sol['startDate']), pick(data['localStart'])]);
    final endRaw = first([pick(sol['endDate']), pick(data['localEnd'])]);
    final createdRaw = first([pick(sol['createdAt']), now]);

    pw.Widget row(String label, String value) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 132,
              child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
            ),
            pw.Expanded(child: pw.Text(shown(value), style: const pw.TextStyle(fontSize: 10))),
          ],
        ),
      );
    }

    pw.Widget section(String title) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 16, bottom: 8),
        child: pw.Text(
          title,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1976D2')),
        ),
      );
    }

    doc.addPage(
      pw.MultiPage(
        theme: ttf != null ? pw.ThemeData.withFont(base: ttf, bold: ttf) : null,
        margin: const pw.EdgeInsets.all(32),
        footer: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 6),
            pw.Text(
              "Ce document est la preuve de votre demande d'intervention via CasaNayo. Le prestataire doit l'accepter avant d'intervenir. Assistance : +243 836 323 805.",
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 4),
            pw.Text('Document généré par CasaNayo - www.casanayo.com', style: const pw.TextStyle(fontSize: 8)),
          ],
        ),
        build: (ctx) => [
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
                      'DEMANDE D\'INTERVENTION',
                      style: pw.TextStyle(color: PdfColors.white, fontSize: 18, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      'Référence : #SOL-$ref',
                      style: pw.TextStyle(color: PdfColor.fromInt(0xE6FFFFFF), fontSize: 11),
                    ),
                  ],
                ),
                if (_logoImage != null)
                  pw.Container(
                    width: 45,
                    height: 45,
                    decoration: const pw.BoxDecoration(color: PdfColors.white, shape: pw.BoxShape.circle),
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Image(_logoImage!),
                  ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('CasaNayo', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  pw.Text('Généré le $now', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                ],
              ),
              pw.Text(status, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1976D2'))),
            ],
          ),
          section('1. SERVICE ET PRESTATAIRE'),
          row('Service', serviceTitle),
          row('Prestataire', providerName),
          row('Téléphone', providerPhone),
          if (providerEmail.isNotEmpty) row('E-mail', providerEmail),
          row('Lieu', place),
          if (tariff.isNotEmpty) row('Tarif annoncé', tariff),
          if (availability.isNotEmpty) row('Disponibilité', availability),
          section('2. DEMANDEUR'),
          row('Nom', clientName),
          row('Téléphone', clientPhone),
          row('E-mail', clientEmail),
          section('3. INTERVENTION'),
          row('Début', shownDate(startRaw)),
          row('Fin', shownDate(endRaw)),
          row('Budget proposé', budgetLabel),
          row('Statut', status),
          row('Envoyée le', createdRaw.contains('/') ? createdRaw : shownDate(createdRaw)),
          if (description.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
            pw.SizedBox(height: 4),
            pw.Text(description, style: const pw.TextStyle(fontSize: 10)),
          ],
          pw.SizedBox(height: 18),
        ],
      ),
    );

    return doc.save();
  }

  Future<void> _downloadInterventionPdf(Map<String, dynamic> data) async {
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

      final bytes = await _buildInterventionPdfBytes(data);

      final ref = _solicitationRef(data).isEmpty ? 'NO-REF' : _solicitationRef(data);

      final generationDate = DateFormat('dd_MMMM_yyyy_HH_mm', 'fr_FR').format(DateTime.now());
      final fileName = 'Demande_Intervention_Ref_${ref}_du_$generationDate.pdf';

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
      print("PDF Download Error: $e");
      FancyNotification.show(
        context,
        "Le PDF n’a pas pu être enregistré. Vérifiez l’espace disque et réessayez.",
        isError: true,
      );
    }
  }

  Future<void> _shareInterventionPdf(Map<String, dynamic> data) async {
    try {
      final bytes = await _buildInterventionPdfBytes(data);
      final ref = _solicitationRef(data).isEmpty ? 'NO-REF' : _solicitationRef(data);

      final generationDate = DateFormat('dd_MMMM_yyyy_HH_mm', 'fr_FR').format(DateTime.now());
      final fileName = 'Demande_Intervention_Ref_${ref}_du_$generationDate.pdf';
      
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(bytes);
      
      final xfile = XFile(tempFile.path, mimeType: 'application/pdf', name: fileName);
      await Share.shareXFiles(
        [xfile],
        text: "Ma demande d'intervention CasaNayo - Ref: $ref",
      );
    } catch (e) {
      print("PDF Share Error: $e");
      FancyNotification.show(context, "Partage du PDF impossible");
    }
  }

  PreferredSizeWidget _buildAppBar() {
    final firstImage = widget.service.images != null && widget.service.images!.isNotEmpty
        ? widget.service.images!.first
        : null;

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
            'Demander une intervention',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          Text(
            'Planifiez votre intervention',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceColor,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          28 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildServiceHeader(),
            const SizedBox(height: 24),

            if (_getUserId() != null) _buildUserInfoSection(),
            const SizedBox(height: 24),

            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Planifier votre intervention',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Choisissez la date de votre intervention',
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 28),

                  _buildDateField(),
                  const SizedBox(height: 24),
                  
                  _buildBudgetField(),
                  // const SizedBox(height: 24),
                  // _buildTimeGrid(), // Time grid removed as requested by user logic implicit replacement
                  const SizedBox(height: 28),

                  _buildNotesField(),
                  const SizedBox(height: 36),

                  _buildSubmitButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _servicePlace() {
    final service = widget.service;
    final parts = <String>[
      service.address ?? '',
      service.quartierValue ?? '',
      service.communeValue ?? '',
      service.cityValue ?? '',
      service.countryValue ?? '',
    ];
    final seen = <String>{};
    final labels = <String>[];
    for (final part in parts) {
      final text = part.trim();
      if (text.isEmpty || text.toLowerCase() == 'null') continue;
      if (seen.add(text.toLowerCase())) labels.add(text);
    }
    return labels.join(', ');
  }

  Widget _buildServiceHeader() {
    final images = widget.service.images ?? const <String>[];
    final imageUrl = images.cast<String?>().map((item) => item?.trim() ?? '').firstWhere(
          (item) => item.isNotEmpty,
          orElse: () => '',
        );
    final title = (widget.service.title ?? '').trim();
    final provider = (widget.service.postBy ?? widget.service.username ?? '').trim();
    final place = _servicePlace();
    final hours = (widget.service.plageHeurePrestation ?? '').trim();

    return Container(
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
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 180,
            width: double.infinity,
            child: imageUrl.isNotEmpty
                ? OfflineNetworkImage(
                    imageUrl: imageUrl,
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: const Color(0xFFE5E7EB),
                      child: const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: const Color(0xFFE5E7EB),
                      child: Icon(Icons.handyman_rounded, color: Colors.grey[500], size: 42),
                    ),
                  )
                : Container(
                    color: const Color(0xFFE5E7EB),
                    child: Icon(Icons.handyman_rounded, color: Colors.grey[500], size: 42),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isEmpty ? 'Service' : title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: _textPrimary,
                    height: 1.25,
                  ),
                ),
                if (provider.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    provider,
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_on_rounded, size: 18, color: _primaryColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        place.isEmpty ? 'Adresse non renseignée' : place,
                        style: TextStyle(
                          color: _textPrimary,
                          fontSize: 14,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if ((widget.service.minPrice ?? 0) > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getPriceText(),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _primaryColor,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    if (hours.isNotEmpty && hours.toLowerCase() != 'null')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F4F8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          hours,
                          style: TextStyle(
                            color: _textSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
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

  String _getPriceText() {
    if (widget.service.minPrice == null) return 'Prix sur demande';

    final price = widget.service.minPrice!;
    final displayCurrency = CurrencyDisplay.symbolFromCode(widget.service.currency);
    final formatted = NumberFormat('#,##0', 'de_DE').format(price);
    return 'À partir de $formatted $displayCurrency';
  }

  Widget _buildUserInfoSection() {
    String displayName = _userName;
    
    if (displayName.isEmpty || displayName == 'null') {
      displayName = 'Visiteur';
    }
    
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
                  return OfflineNetworkImage(
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
                  displayName.isNotEmpty ? displayName : 'Bonjour',
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
        if (widget.service.minPrice != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Container(
            padding: const EdgeInsets.all(12),
             decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _primaryColor.withOpacity(0.3)),
             ),
             child: Row(
                children: [
                   Icon(Icons.info_outline, color: _primaryColor, size: 20),
                   SizedBox(width: 8),
                   Expanded(child: Text(
                       "Je tarifie mes services ${_getPriceText().toLowerCase()}",
                       style: TextStyle(
                          color: _primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14
                       ),
                   )),
                ],
             ),
          ),
        ),
        Row(
          children: [

            Icon(Icons.calendar_month, size: 18, color: _primaryColor),
            const SizedBox(width: 8),
            Text(
              'Date d\'intervention',
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
        
        const SizedBox(height: 16),
        
        // Date de fin
        Row(
          children: [
            Icon(Icons.event_available, size: 18, color: _primaryColor),
            const SizedBox(width: 8),
            Text(
              'Date de fin',
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
          onTap: _selectEndDate,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedEndDate == null ? _borderColor : _primaryColor,
                width: _selectedEndDate == null ? 1.5 : 2,
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
                  _selectedEndDate == null
                      ? 'Date de fin (Optionnel)'
                      : DateFormat('EEEE d MMMM y', 'fr_FR').format(_selectedEndDate!),

                  style: TextStyle(
                    color: _selectedEndDate == null ? _textLight : _textPrimary,
                    fontSize: 16,
                    fontWeight: _selectedEndDate == null ? FontWeight.normal : FontWeight.w600,
                  ),
                ),
                Icon(
                  Icons.event_busy,
                  color: _selectedEndDate == null ? _textLight : _primaryColor,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildBudgetField() {
    final serviceCtrl = Provider.of<ServiceController>(context);
    final devises = serviceCtrl.devisesList;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.monetization_on_outlined, size: 18, color: _primaryColor),
            const SizedBox(width: 8),
            Text(
              'Votre Budget',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _textPrimary,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _budgetController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(fontSize: 16, color: _textPrimary),
                decoration: InputDecoration(
                  hintText: 'Montant (ex: 50)',
                  helperStyle: TextStyle(color: _primaryColor, fontSize: 12, fontWeight: FontWeight.w500),
                  hintStyle: TextStyle(color: _textLight),
                  filled: true,
                  fillColor: _cardColor,
                  contentPadding: EdgeInsets.all(18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _borderColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _borderColor)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _primaryColor, width: 2)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12),
                height: 56, // Match height of TextFormField
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _borderColor),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<DeviseModel>(
                    value: _selectedDevise,
                    isExpanded: true,
                    hint: Text("Devise"),
                    items: devises.map((DeviseModel d) {
                      return DropdownMenuItem<DeviseModel>(
                        value: d,
                        child: Text(
                          d.displaySymbol,
                          style: TextStyle(fontSize: 14),
                        ),
                      );
                    }).toList(),
                    onChanged: (DeviseModel? newVal) {
                      setState(() {
                        _selectedDevise = newVal;
                      });
                    },
                  ),
                ),
              ),
            ),
          ],
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
              'Heure d\'intervention (7h - 18h)',
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
              'Détails de l\'intervention (optionnel)',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _textPrimary,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _notesController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Décrivez votre problème ou vos besoins...',
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
      ],
    );
  }

  Widget _buildSubmitButton() {
    final isFormValid = _selectedDate != null;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isFormValid && !_isLoading ? _handleInterventionRequest : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isFormValid ? _primaryColor : Colors.grey[400],
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 18),
          elevation: 4,
          shadowColor: isFormValid ? _primaryColor.withOpacity(0.4) : Colors.transparent,
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
            Icon(Icons.build, size: 20),
            const SizedBox(width: 10),
            Text(
              'DEMANDER UNE INTERVENTION',
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








import 'package:casa/models/PrestationModel.dart';
import 'package:casa/models/DeviseModel.dart';
import 'package:casa/controllers/ServiceController.dart';
import 'package:casa/screens/auth/LoginScreen.dart';
import 'package:provider/provider.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/StockageKeys.dart';
import 'package:casa/utils/networkCheck.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart' as picker;
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;


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
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDevises());
    _loadLogo();
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
        });
      }
    } catch (e) {
      print("Erreur lors du chargement des infos utilisateur: $e");
    }
  }

  void _loadDevises() async {
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
        "endDate": _selectedEndDate != null 
            ? DateFormat('yyyy-MM-dd').format(_selectedEndDate!)
            : DateFormat('yyyy-MM-dd').format(DateTime.now())
      };


      final serviceCtrl = Provider.of<ServiceController>(context, listen: false);
      final response = await serviceCtrl.createSolicitation(solicitationData);

      if (!mounted) return;

      if (response.status) {
         Map<String, dynamic> responseData = {};
         if (response.data is Map) {
            responseData = Map<String, dynamic>.from(response.data);
         }
         _showConfirmationDialog(responseData);
      } else {
         String errorMsg = response.errorMsg ?? 
                           (response.data is Map ? (response.data['detailMessage'] ?? response.data['message']) : "Erreur inconnue");
         FancyNotification.show(context, errorMsg, isError: true);
      }

    } catch (e) {
      if (mounted) {
        FancyNotification.show(context, "Une erreur est survenue, veuillez réessayer.");
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

  void _showConfirmationDialog(Map<String, dynamic> successData) {
    final formattedDate = DateFormat('EEEE d MMMM y', 'fr_FR').format(_selectedDate!);
    // Time selection removed
    // Time selection removed

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
                    'Demande envoyée !',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Text(
                    'Votre demande d\'intervention a été envoyée avec succès',
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
                              'Intervention programmée',
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
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  // Boutons Partager et Télécharger
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async => await _shareInterventionPdf(successData),
                          icon: Icon(Icons.ios_share_rounded, color: _primaryColor),
                          label: Text(
                            "Partager",
                            style: TextStyle(
                              color: _textPrimary,
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
                          onPressed: () async => await _downloadInterventionPdf(successData),
                          icon: Icon(Icons.download_rounded, color: _primaryColor),
                          label: Text(
                            "Télécharger",
                            style: TextStyle(
                              color: _textPrimary,
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
                  const SizedBox(height: 20),

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
                        'Retour',
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

  Future<Uint8List> _buildInterventionPdfBytes(Map<String, dynamic> data) async {
    final doc = pw.Document();
    final now = DateFormat('dd/MM/yy HH:mm').format(DateTime.now());

    final solicitationWrapper = data['sollicitation'] ?? {};
    final solicitation = solicitationWrapper['sollicitation'] ?? solicitationWrapper;

    final prestation = solicitationWrapper['prestation'] ?? data['prestation'] ?? {};
    final prestateur = data['prestateur'] ?? {};
    final demandeur = data['demandeur'] ?? {};
    final devise = solicitationWrapper['devise'] ?? data['devise'] ?? {};
    
    // Infos Prestateur
    final prestateurName = prestateur['username']?.toString() ?? 'Non renseigné';
    final prestateurPhone = prestateur['phone']?.toString() ?? 'Non renseigné';
    final prestateurEmail = prestateur['email']?.toString() ?? 'Non renseigné';

    // Service Info
    final serviceTitle = prestation['title']?.toString() ?? 'Service';
    final serviceAddress = prestation['address']?.toString() ?? '';
    final serviceCity = prestation['cityValue']?.toString() ?? '';
    final serviceCountry = prestation['countryValue']?.toString() ?? '';
    
    final fullServiceAddress = [serviceAddress, serviceCity, serviceCountry]
        .where((s) => s.isNotEmpty)
        .join(', ');

    // Infos Demandeur
    final demandeurName = demandeur['username']?.toString() ?? 'Client';
    final demandeurPhone = demandeur['phone']?.toString() ?? '';
    final demandeurEmail = demandeur['email']?.toString() ?? '';

    // Sollicitation Info
    final budget = solicitation['budget']?.toString() ?? '0';
    final deviseCode = devise['code']?.toString() ?? 'USD';
    final startDateStr = solicitation['startDate'];
    final endDateStr = solicitation['endDate'];
    final description = solicitation['description']?.toString() ?? '';

    String formatDate(String? dateStr) {
      if (dateStr == null) return 'Non spécifiée';
      try {
        final date = DateTime.parse(dateStr);
        return DateFormat('dd-MM-yyyy').format(date);
      } catch (e) {
        return dateStr;
      }
    }

    doc.addPage(
      pw.Page(
        build: (context) => pw.Container(
          padding: const pw.EdgeInsets.all(24),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                   if (_logoImage != null)
                    pw.Container(
                      width: 48,
                      height: 48,
                      margin: const pw.EdgeInsets.only(right: 12),
                      child: pw.Image(_logoImage!),
                    ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'CasaNayo',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Demande d\'intervention',
                        style: pw.TextStyle(
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Text('Généré le $now'),
              pw.Divider(),
              pw.SizedBox(height: 12),

              pw.Text('Service', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text(serviceTitle),
              if (fullServiceAddress.isNotEmpty)
                pw.Text(fullServiceAddress),
              pw.SizedBox(height: 16),

              pw.Text('Intervention', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text('Début : ${formatDate(startDateStr)}'),
              pw.Text('Fin : ${formatDate(endDateStr)}'),
              pw.Text('Budget proposé : $budget $deviseCode'),
              if (description.isNotEmpty)
                pw.Text('Description : $description'),
              pw.SizedBox(height: 16),

              pw.Text('Demandeur', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text('Nom : $demandeurName'),
              if (demandeurPhone.isNotEmpty) pw.Text('Téléphone : $demandeurPhone'),
              if (demandeurEmail.isNotEmpty) pw.Text('Email : $demandeurEmail'),
              pw.SizedBox(height: 16),

              pw.Text('Prestataire', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text('Nom : $prestateurName'),
              if (prestateurPhone.isNotEmpty) pw.Text('Téléphone : $prestateurPhone'),
              if (prestateurEmail.isNotEmpty) pw.Text('Email : $prestateurEmail'),
              pw.SizedBox(height: 24),

              pw.Text(
                "Ce document confirme l'envoi de votre demande d'intervention. "
                "Le prestataire doit encore valider la demande.",
                style: pw.TextStyle(fontSize: 12),
                textAlign: pw.TextAlign.justify,
              ),
              pw.SizedBox(height: 18),
              pw.Text(
                "Coordonnées CasaNayo :",
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text("Siège : CasaNayo, Support"),
              pw.Text("Email : contact@casanayo.com"),
            ],
          ),
        ),
      ),
    );

    return doc.save();
  }

  Future<Directory> _getExportDir() async {
    try {
      if (Platform.isAndroid) {
        final dir = Directory('/storage/emulated/0/casa');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return dir;
      }
      
      final ext = await getExternalStorageDirectory();
      if (ext != null) {
        final parts = ext.path.split('/');
        int androidIndex = parts.indexOf('Android');
        String base;
        if (androidIndex > 0) {
          base = parts.sublist(0, androidIndex).join('/');
        } else {
          base = ext.path;
        }
        if (base.isEmpty) base = '/storage/emulated/0';
        final dir = Directory('$base/casa');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return dir;
      }
    } catch (e) {
      print("Erreur répertoire: $e");
    }

    final docs = await getApplicationDocumentsDirectory();
    final fallbackDir = Directory('${docs.path}/casa');
    if (!await fallbackDir.exists()) {
      await fallbackDir.create(recursive: true);
    }
    return fallbackDir;
  }

  Future<void> _downloadInterventionPdf(Map<String, dynamic> data) async {
    try {
      final bytes = await _buildInterventionPdfBytes(data);
      final dir = await _getExportDir();
      
      final demandeur = data['demandeur'] ?? {};
      final userName = demandeur['username']?.toString() ?? 'Client';
      final nowStr = DateFormat('dd-MM-yyyy_HHmm').format(DateTime.now());
      
      final baseName = '${userName.replaceAll(' ', '_')}_intervention_$nowStr';
      final filePath = '${dir.path}/$baseName.pdf';
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);
      FancyNotification.show(
        context,
        "PDF enregistré dans ${dir.path}",
        isError: false,
        type: NotificationType.success,
      );
    } catch (e) {
       print("PDF Download Error: $e");
      FancyNotification.show(context, "Impossible de générer le PDF");
    }
  }

  Future<void> _shareInterventionPdf(Map<String, dynamic> data) async {
    try {
      final bytes = await _buildInterventionPdfBytes(data);
       final demandeur = data['demandeur'] ?? {};
      final userName = demandeur['username']?.toString() ?? 'Client';
      final nowStr = DateFormat('dd-MM-yyyy_HHmm').format(DateTime.now());
      final baseName = '${userName.replaceAll(' ', '_')}_intervention_$nowStr';
      
      final xfile = XFile.fromData(
        bytes,
        mimeType: 'application/pdf',
        name: '$baseName.pdf',
      );
      await Share.shareXFiles(
        [xfile],
        text: "Demande d'intervention - CasaNayo",
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
        padding: const EdgeInsets.all(20),
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

  Widget _buildServiceHeader() {
    final firstImage = widget.service.images != null && widget.service.images!.isNotEmpty
        ? widget.service.images!.first
        : null;

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
              child: firstImage != null
                  ? CachedNetworkImage(
                      imageUrl: firstImage,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[100],
                        child: Icon(
                          Icons.build,
                          color: Colors.grey[400],
                          size: 30,
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[100],
                        child: Icon(
                          Icons.build,
                          color: Colors.grey[400],
                          size: 30,
                        ),
                      ),
                    )
                  : Container(
                      color: Colors.grey[100],
                      child: Icon(
                        Icons.build,
                        color: Colors.grey[400],
                        size: 30,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.service.title ?? "Service sans titre",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: _textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                // Address hidden as requested
                // if (widget.service.address != null && widget.service.address!.isNotEmpty)
                //   Container(
                //     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                //     decoration: BoxDecoration(
                //       color: _accentColor,
                //       borderRadius: BorderRadius.circular(8),
                //       border: Border.all(color: _primaryColor.withOpacity(0.2)),
                //     ),
                //     child: Row(
                //       children: [
                //         Icon(Icons.location_on_rounded, size: 14, color: _primaryColor),
                //         const SizedBox(width: 6),
                //         Expanded(
                //           child: Text(
                //             widget.service.address!,
                //             style: TextStyle(
                //               color: _textPrimary,
                //               fontSize: 13,
                //               fontWeight: FontWeight.w500,
                //             ),
                //             maxLines: 1,
                //             overflow: TextOverflow.ellipsis,
                //           ),
                //         ),
                //       ],
                //     ),
                //   ),
                const SizedBox(height: 8),
                if (widget.service.minPrice != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getPriceText(),
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

  String _getPriceText() {
    if (widget.service.minPrice == null) return 'Prix sur demande';
    
    final price = widget.service.minPrice!;
    final displayCurrency = widget.service.currency;

    if (price >= 1000000) {
      return 'À partir de ${(price / 1000000).toStringAsFixed(1)}M $displayCurrency';
    } else if (price >= 1000) {
      return 'À partir de ${(price / 1000).toStringAsFixed(0)}K $displayCurrency';
    }
    return 'À partir de ${price.toStringAsFixed(0)} $displayCurrency';
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
                        child: Text(d.code ?? d.name ?? "", style: TextStyle(fontSize: 14)),
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








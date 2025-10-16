import 'package:casa/controllers/PropertyVisitCtrl.dart';
import 'package:casa/models/PropertyModel.dart';
import 'package:casa/utils/Constantes.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/StockageKeys.dart';
import 'package:casa/utils/networkCheck.dart';
import 'package:flutter/material.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart' as picker;
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

class BookingVisitPage extends StatefulWidget {
  final PropertyModel property;

  const BookingVisitPage({Key? key, required this.property}) : super(key: key);

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

  String get safeUsername {
    return storage.read(StockageKeys.userKey)?['username']?.toString() ?? 'Visiteur';
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
    TimeOfDay(hour: 19, minute: 0),
    TimeOfDay(hour: 20, minute: 0),
    TimeOfDay(hour: 21, minute: 0),
  ];

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR');
    _loadUserInfo();
  }

  void _loadUserInfo() {
    try {
      final dynamic userData = storage.read(StockageKeys.userKey);

      if (userData != null) {
        final Map<String, dynamic> user = _convertToStringMap(userData);

        setState(() {
          _userId = user['UserId'] as int?;
          _userName = '${user['username'] ?? ''}'.trim();
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
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    return {};
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
    if (_selectedDate == null || _selectedTime == null) {
      FancyNotification.show(context, "Veuillez sélectionner une date et une heure");
      return;
    }

    if (_userId == null) {
      FancyNotification.show(context, "Utilisateur non connecté");
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
      final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      final formattedTime = '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';

      final bookingData = {
        "PropertyId": widget.property.PropertyId,
        "UserId": _userId,
        "name": _userName,
        "secondName": "",
        "email": _userEmail,
        "phone": _userPhone,
        "message": _notesController.text.isNotEmpty
            ? _notesController.text
            : "Intéressé par la propriété",
        "address": widget.property.address ?? "",
        "visitDate": formattedDate,
        "visitHour": formattedTime,
        "ipAddress": "192.168.1.1"
      };

      final ctrl = context.read<PropertyVisitCtrl>();
      final res = await ctrl.createVisitProperty(bookingData);

      if (!mounted) return;

      if (res.data['success'] == true) {
        _showConfirmationDialog();
      } else {
        final errorMessage = res.data['message'] ?? "Erreur lors de la réservation";
        FancyNotification.show(context, errorMessage);
      }
    } catch (e) {
      if (mounted) {
        FancyNotification.show(context, "Erreur technique lors de la réservation");
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

  void _showConfirmationDialog() {
    final formattedDate = DateFormat('EEEE d MMMM y', 'fr_FR').format(_selectedDate!);
    final formattedTime = '${_selectedTime!.hour.toString().padLeft(2, '0')}h${_selectedTime!.minute == 0 ? '' : _selectedTime!.minute.toString().padLeft(2, '0')}';

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

            if (_userId != null) _buildUserInfoSection(),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyHeader() {
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
              child: Image.network(
                "${Constantes.URL_IMAGES}${widget.property.images?.first.path ?? ''}",
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey[100],
                  child: Icon(Icons.home_rounded, color: Colors.grey[400], size: 30),
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
                  widget.property.title ?? "",
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
                                widget.property.address ?? "Adresse non disponible",
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
                    widget.property.transactionType == "location"
                        ? '${widget.property.price?.toInt() ?? 0}\$ / mois'
                        : '${widget.property.price?.toInt() ?? 0}\$',
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
                            "L'adresse complète est accessible après prise de contact avec notre agence",
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
                  const SizedBox(height: 28),

                  // Actions
                  Row(
                    children: [
                      // Bouton Fermer
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(
                              color: _primaryColor.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            "Plus tard",
                            style: TextStyle(
                              color: _textPrimary.withOpacity(0.8),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Bouton Principal
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _navigateToContactPage();
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
                                Icons.calendar_today_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Rendez-vous",
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

                  // Lien de contact alternatif
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      _navigateToContactPage();
                    },
                    child: Text(
                      "Ou nous contacter par téléphone",
                      style: TextStyle(
                        color: _primaryColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.underline,
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
                  _userName.isNotEmpty ? 'Bonjour, $_userName' : 'Bonjour',
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
              'Heure de visite (7h - 21h)',
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

              return InkWell(
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
                  child: Center(
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

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isFormValid && !_isLoading ? _handleBooking : null,
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
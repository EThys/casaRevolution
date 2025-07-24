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

import 'PropertyDetailPage.dart';

class BookingVisitPage extends StatefulWidget {
  final PropertyModel property;

  const BookingVisitPage({Key? key, required this.property}) : super(key: key);

  @override
  _BookingVisitPageState createState() => _BookingVisitPageState();
}

class _BookingVisitPageState extends State<BookingVisitPage> {

  final Color _primaryColor = Color(0xFF1976D2);
  final Color _secondaryColor = Color(0xFF64B5F6);
  final Color darkBlue = Color(0xFF0D47A1);



  final _formKey = GlobalKey<FormState>();
  final GetStorage storage = GetStorage();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR'); // Initialisation ici
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
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
        itemStyle: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w500,
          fontSize: 18,
        ),
        doneStyle: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        cancelStyle: const TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
      ),
      onConfirm: (date) {
        setState(() {
          _selectedDate = date;
          // Reset time when date changes
          _selectedTime = null;
        });
      },
      currentTime: _selectedDate ?? DateTime.now(),
      locale: picker.LocaleType.fr,
    );
  }

  Future<void> _selectTime() async {
    if (_selectedDate == null) {
      FancyNotification.show(context, "Veuillez d\'abord sélectionner une date");
      return;
    }

    final now = DateTime.now();
    final isToday = _selectedDate!.day == now.day &&
        _selectedDate!.month == now.month &&
        _selectedDate!.year == now.year;

    final initialTime = _selectedTime ?? (isToday ? TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))) : const TimeOfDay(hour: 9, minute: 0));

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme:  ColorScheme.light(
              primary: _primaryColor,
              onSurface: Colors.black,
            ),
            timePickerTheme: TimePickerThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              hourMinuteShape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ),
          ),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              alwaysUse24HourFormat: true,
            ),
            child: child!,
          ),
        );
      },
    );

    if (picked != null) {
      // verifie si l'heure choisi est deja passée
      if (isToday) {
        final now = TimeOfDay.fromDateTime(DateTime.now());
        if (picked.hour < now.hour || (picked.hour == now.hour && picked.minute <= now.minute)) {
          FancyNotification.show(context, "Veuillez choisir une heure future");
          return;
        }
      }

      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _handleBooking() async {
    // Validation du formulaire
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDate == null || _selectedTime == null) {
      FancyNotification.show(context,"Veuillez sélectionner une date et une heure");

      return;
    }

    if (!mounted || _isLoading) return;
    setState(() => _isLoading = true);

    FocusScope.of(context).unfocus();

    // Vérification de la connexion internet
    final isConnected = await NetworkUtils.checkInternetConnectivity();
    if (!isConnected) {
      if (mounted) {
        FancyNotification.show(context,"Pas de connexion internet");
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      // Formatage de la date et de l'heure
      final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      final formattedTime = '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';

      // Préparation des données à envoyer
      final bookingData = {
        "PropertyId": widget.property.PropertyId,
        "UserId": storage.read(StockageKeys.userKey)?['UserId'],
        "name": _nameController.text,
        "secondName": "",
        "email": _emailController.text,
        "phone": _phoneController.text,
        "message": _notesController.text.isNotEmpty
            ? _notesController.text
            : "Intéressé par la propriété",
        "address": widget.property.address ?? "",
        "visitDate": formattedDate,
        "visitHour": formattedTime,
        "ipAddress": "192.168.1.1" // Vous pouvez obtenir la vraie IP si nécessaire
      };

      final ctrl = context.read<PropertyVisitCtrl>();
      final res = await ctrl.createVisitProperty(bookingData);


      if (!mounted) return;

      if (res.data['success'] == true) {
        // Succès
        _showConfirmationDialog();
      } else {
        // Erreur
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
    final formattedTime = _selectedTime!.format(context);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          elevation: 0,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated checkmark
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.check_rounded,
                        color: Color(0xFF4CAF50),
                        size: 48,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title with gradient
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF1976D2), Color(0xFF2196F3)],
                    ).createShader(bounds),
                    child: const Text(
                      'Demande confirmée !',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Divider with icon
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: Colors.grey[300],
                          thickness: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(
                          Icons.calendar_today_rounded,
                          color: Colors.grey[500],
                          size: 18,
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: Colors.grey[300],
                          thickness: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Date/time info card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F9FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFE3F2FD),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Votre visite est programmée',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          formattedDate,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1976D2),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'à $formattedTime',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF424242),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1976D2),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 2,
                          ),
                          child: const Text(
                            'RETOUR',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildreservationVisiteAppBar() {
    return AppBar(
      elevation: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_primaryColor, _secondaryColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_month, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Text(
            'Réserver une visite',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
            textAlign: TextAlign.left,
          ),
        ],
      ),

      bottom: PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Container(
          height: 1,
          color: Colors.white.withOpacity(0.2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:_buildreservationVisiteAppBar(),


      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec infos propriété
            _buildPropertyHeader(),
            const SizedBox(height: 24),

            // Formulaire de réservation
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Informations de visite',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1D26),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Sélection de date
                  _buildDateField(),
                  const SizedBox(height: 16),

                  // Sélection d'heure
                  _buildTimeField(),
                  const SizedBox(height: 24),

                  Text(
                    'Vos informations',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1D26),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Champ nom
                  _buildNameField(),
                  const SizedBox(height: 16),

                  // Champ téléphone
                  _buildPhoneField(),
                  const SizedBox(height: 16),

                  // Champ email
                  _buildEmailField(),
                  const SizedBox(height: 16),

                  // Champ notes
                  _buildNotesField(),
                  const SizedBox(height: 32),

                  // Bouton de soumission
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network( // Utilisez Image.network pour les URLs
              "${Constantes.URL_IMAGES}${widget.property.images!.first.path}", // Adaptez selon votre modèle
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 80,
                height: 80,
                color: Colors.grey[200],
                child: const Icon(Icons.home, color: Colors.grey),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF1A1D26),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.property.address ?? "",
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.property.transactionType=="location"
                      ? '${widget.property.price!.toInt()}\$/mois'
                      : '${widget.property.price!.toInt()}\$',
                  style:  TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                    fontSize: 16,
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
    return InkWell(
      onTap: _selectDate,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedDate == null
                  ? 'Choisir une date'
                  : DateFormat('EEEE d MMMM y', 'fr_FR').format(_selectedDate!),
              style: TextStyle(
                color: _selectedDate == null ? Colors.grey[500] : const Color(0xFF1A1D26),
                fontSize: 16,
              ),
            ),
            Icon(
              Icons.calendar_today_rounded,
              color: _primaryColor,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeField() {
    return InkWell(
      onTap: _selectTime,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedTime == null
                  ? 'Choisir une heure'
                  : _selectedTime!.format(context),
              style: TextStyle(
                color: _selectedTime == null ? Colors.grey[500] : const Color(0xFF1A1D26),
                fontSize: 16,
              ),
            ),
            Icon(
              Icons.access_time_rounded,
              color: _primaryColor,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      decoration: InputDecoration(
        labelText: 'Nom complet',
        hintText: 'Votre nom',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        filled: true,
        fillColor: Colors.white,
        prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF6C757D)),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Veuillez entrer votre nom';
        }
        return null;
      },
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      decoration: InputDecoration(
        labelText: 'Téléphone',
        hintText: '0000000000',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        filled: true,
        fillColor: Colors.white,
        prefixIcon: const Icon(Icons.phone_rounded, color: Color(0xFF6C757D)),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Veuillez entrer votre téléphone';
        }
        if (!RegExp(r'^[0-9]{10}$').hasMatch(value)) {
          return 'Numéro invalide (10 chiffres)';
        }
        return null;
      },
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
        labelText: 'Email',
        hintText: 'exemple@email.com',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        filled: true,
        fillColor: Colors.white,
        prefixIcon: const Icon(Icons.email_rounded, color: Color(0xFF6C757D)),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Veuillez entrer votre email';
        }
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
          return 'Email invalide';
        }
        return null;
      },
    );
  }

  Widget _buildNotesField() {
    return TextFormField(
      controller: _notesController,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: 'Notes supplémentaires (optionnel)',
        alignLabelWithHint: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleBooking,
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
        child: _isLoading
            ? const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: Colors.white,
          ),
        )
            : const Text(
          'CONFIRMER LA RÉSERVATION',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
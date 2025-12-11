import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:casa/utils/FancyNotification.dart';
import '../widgets/ModernModal.dart';

class ServiceRequestResponseDialog extends StatefulWidget {
  final int requestId;

  const ServiceRequestResponseDialog({
    Key? key,
    required this.requestId,
  }) : super(key: key);

  @override
  _ServiceRequestResponseDialogState createState() => _ServiceRequestResponseDialogState();
}

class _ServiceRequestResponseDialogState extends State<ServiceRequestResponseDialog> {
  final Color _primaryColor = Color(0xFF1976D2);
  final Color _primaryDark = Color(0xFF1565C0);
  final Color _textPrimary = Color(0xFF1A1A1A);
  final Color _textSecondary = Color(0xFF666666);
  final Color _borderColor = Color(0xFFEEEEEE);

  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _estimatedTimeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _messageController.dispose();
    _priceController.dispose();
    _estimatedTimeController.dispose();
    super.dispose();
  }

  void _submitResponse() {
    final message = _messageController.text.trim();
    
    if (message.isEmpty) {
      FancyNotification.show(
        context,
        'Veuillez saisir un message',
        type: NotificationType.warning,
      );
      return;
    }

    if (_isLoading) return;
    
    final price = _priceController.text.trim().isNotEmpty
        ? double.tryParse(_priceController.text.trim())
        : null;
    final estimatedTime = _estimatedTimeController.text.trim().isNotEmpty
        ? _estimatedTimeController.text.trim()
        : null;

    Navigator.pop(context, {
      'message': message,
      'price': price,
      'estimatedTime': estimatedTime,
    });
  }

  @override
  Widget build(BuildContext context) {
    return ModernModal(
      title: 'Répondre à la demande',
      subtitle: 'Proposez vos services',
      icon: Icons.reply_rounded,
      iconColor: _primaryColor,
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Message
                    Text(
                      'Votre message',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                    ),
                    SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _borderColor),
                        color: Colors.white,
                      ),
                      child: TextField(
                        controller: _messageController,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: 'Ex: Je peux intervenir rapidement, j\'ai une bonne expérience...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: _primaryColor, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.all(16),
                          hintStyle: GoogleFonts.inter(
                            color: _textSecondary.withOpacity(0.5),
                            fontSize: 14,
                          ),
                        ),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: _textPrimary,
                          height: 1.5,
                        ),
                      ),
                    ),

                    SizedBox(height: 20),

                    // Prix (optionnel)
                    Text(
                      'Prix proposé (optionnel)',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _borderColor),
                        color: Colors.white,
                      ),
                      child: TextField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          prefixText: 'CDF ',
                          hintText: '0',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: _primaryColor, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.all(16),
                        ),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: _textPrimary,
                        ),
                      ),
                    ),

                    SizedBox(height: 20),

                    // Temps estimé (optionnel)
                    Text(
                      'Temps estimé (optionnel)',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _borderColor),
                        color: Colors.white,
                      ),
                      child: TextField(
                        controller: _estimatedTimeController,
                        decoration: InputDecoration(
                          hintText: 'Ex: 2 heures, 1 jour, 3 jours...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: _primaryColor, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.all(16),
                          hintStyle: GoogleFonts.inter(
                            color: _textSecondary.withOpacity(0.5),
                            fontSize: 14,
                          ),
                        ),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: _textPrimary,
                        ),
                      ),
                    ),

                    SizedBox(height: 24),

                    // Bouton
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                          colors: [_primaryColor, _primaryDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _primaryColor.withOpacity(0.4),
                            blurRadius: 12,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _isLoading ? null : _submitResponse,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: _isLoading
                                ? Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.send_rounded, size: 22, color: Colors.white),
                                      SizedBox(width: 12),
                                      Text(
                                        'ENVOYER MA RÉPONSE',
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                          letterSpacing: 0.8,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}


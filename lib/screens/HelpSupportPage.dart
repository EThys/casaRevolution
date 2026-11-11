import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpSupportPage extends StatelessWidget {
  const HelpSupportPage({Key? key}) : super(key: key);

  static const Color _primary = Color(0xFF1976D2);
  static const Color _dark = Color(0xFF1A1D26);
  static const Color _muted = Color(0xFF64748B);
  static const Color _line = Color(0xFFE6E8EC);
  static const Color _whatsapp = Color(0xFF128C7E);

  static const String _callDisplay = '+243 836 323 805';
  static const String _whatsappDisplay = '+243 961 246 044';
  static const String _whatsappMessage = 'Bonjour CasaNayo, j’ai besoin d’aide.';

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: const Color(0xFFF7F8FA),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _dark, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Aide et support',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: _dark,
            fontSize: 17,
          ),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20, 8, 20, 32 + bottom),
        children: [
          const SizedBox(height: 8),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.support_agent_rounded, color: _primary, size: 28),
          ),
          const SizedBox(height: 18),
          Text(
            'On est là pour vous',
            style: GoogleFonts.inter(
              fontSize: 28,
              height: 1.15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
              color: _dark,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Appelez la ligne CasaNayo, ou écrivez-nous sur WhatsApp. Le message est déjà préparé.',
            style: GoogleFonts.inter(
              fontSize: 16,
              height: 1.45,
              color: _muted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 28),
          _actionCard(
            icon: Icons.call_rounded,
            iconColor: _primary,
            title: 'Appeler',
            subtitle: 'Ouvre l’appel sur votre téléphone',
            value: _callDisplay,
            onTap: _callSupport,
          ),
          const SizedBox(height: 12),
          _actionCard(
            icon: FontAwesomeIcons.whatsapp,
            iconColor: _whatsapp,
            title: 'WhatsApp',
            subtitle: 'Ouvre une conversation avec un message',
            value: _whatsappDisplay,
            onTap: _openWhatsApp,
          ),
          const SizedBox(height: 12),
          _actionCard(
            icon: Icons.mail_outline_rounded,
            iconColor: _primary,
            title: 'Email',
            subtitle: 'Pour une demande plus détaillée',
            value: 'contact@casanayo.com',
            onTap: () => _launch(Uri.parse('mailto:contact@casanayo.com')),
          ),
          const SizedBox(height: 32),
          Text(
            'Questions fréquentes',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: _dark,
            ),
          ),
          const SizedBox(height: 12),
          _faq(
            'Comment réserver sur CasaNayo ?',
            'Trouvez le bien, puis touchez Réserver ou Demander une visite. La première réservation demande un abonnement annuel de 4 \$, qui ouvre l’accès aux opportunités du réseau pendant un an.',
          ),
          _faq(
            'Les annonces sont-elles vérifiées ?',
            'Chaque annonce passe par une modération. Les documents du bien et l’identité de l’annonceur sont contrôlés avant la mise en ligne.',
          ),
          _faq(
            'Puis-je publier mon bien ?',
            'Oui. Créez un compte propriétaire, puis publiez votre annonce. La mise en ligne demande le même abonnement de 4 \$ par an, avec le suivi de vos réservations.',
          ),
          _faq(
            'Mes données sont-elles protégées ?',
            'Oui. Les informations de compte, de réservation et de paiement restent protégées et ne sont utilisées que pour le service CasaNayo.',
          ),
        ],
      ),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String value,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _line),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: _dark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: _muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: iconColor,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _faq(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: Theme(
        data: ThemeData(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: _primary,
          collapsedIconColor: _muted,
          title: Text(
            question,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _dark,
              height: 1.3,
            ),
          ),
          children: [
            Text(
              answer,
              style: GoogleFonts.inter(fontSize: 14, color: _muted, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _callSupport() {
    return _launch(Uri.parse('tel:+243836323805'));
  }

  Future<void> _openWhatsApp() {
    final text = Uri.encodeComponent(_whatsappMessage);
    return _launch(Uri.parse('https://wa.me/243961246044?text=$text'));
  }

  Future<void> _launch(Uri uri) async {
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        await launchUrl(uri);
      }
    } catch (e) {
      debugPrint("Impossible d'ouvrir $uri: $e");
    }
  }
}

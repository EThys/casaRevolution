import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpSupportPage extends StatelessWidget {
  const HelpSupportPage({Key? key}) : super(key: key);

  static const Color _primary = Color(0xFF1976D2);
  static const Color _dark = Color(0xFF1A1D26);
  static const Color _muted = Color(0xFF7F8C8D);
  static const Color _whatsapp = Color(0xFF128C7E);

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_primary, Color(0xFF64B5F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Aide & Support',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 16, 16, 28 + bottom),
        children: [
          _hero(),
          const SizedBox(height: 22),
          _sectionLabel('Nous écrire'),
          const SizedBox(height: 10),
          _contactCard(
            icon: FontAwesomeIcons.whatsapp,
            iconColor: _whatsapp,
            title: 'WhatsApp',
            description: 'Une réponse rapide, du lundi au samedi',
            value: '+243 836 323 805',
            onTap: () => _launchURL('https://wa.me/243836323805'),
          ),
          const SizedBox(height: 10),
          _contactCard(
            icon: Icons.mail_outline_rounded,
            iconColor: _primary,
            title: 'Email',
            description: 'Pour une demande détaillée',
            value: 'contact@casanayo.com',
            onTap: () => _launchURL('mailto:contact@casanayo.com'),
          ),
          const SizedBox(height: 10),
          _contactCard(
            icon: Icons.call_outlined,
            iconColor: const Color(0xFF047857),
            title: 'Téléphone',
            description: 'Appeler le support CasaNayo',
            value: '+243 836 323 805',
            onTap: () => _launchURL('tel:+243836323805'),
          ),
          const SizedBox(height: 26),
          _sectionLabel('Questions fréquentes'),
          const SizedBox(height: 10),
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

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Besoin d’un coup de main ?',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Écrivez-nous ou parcourez les réponses les plus demandées.',
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.92),
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: _dark,
      ),
    );
  }

  Widget _contactCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
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
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: _dark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: GoogleFonts.inter(fontSize: 12, color: _muted, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: iconColor,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey[400]),
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
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Theme(
        data: ThemeData(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          iconColor: _primary,
          collapsedIconColor: _muted,
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.help_outline_rounded, color: _primary, size: 18),
          ),
          title: Text(
            question,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _dark,
              height: 1.3,
            ),
          ),
          children: [
            Text(
              answer,
              style: GoogleFonts.inter(fontSize: 13, color: _muted, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint("Impossible d'ouvrir l'URL: $e");
    }
  }
}

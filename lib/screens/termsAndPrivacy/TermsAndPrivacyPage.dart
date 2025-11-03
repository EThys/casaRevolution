import 'package:flutter/material.dart';

class TermsAndPrivacyPage extends StatefulWidget {
  final int initialTabIndex;

  const TermsAndPrivacyPage({Key? key, this.initialTabIndex = 0}) : super(key: key);

  @override
  State<TermsAndPrivacyPage> createState() => _TermsAndPrivacyPageState();
}

class _TermsAndPrivacyPageState extends State<TermsAndPrivacyPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Color _primaryColor = Color(0xFF1976D2); // Bleu principal
  final Color _primaryLight = Color(0xFF42A5F5); // Bleu clair
  final Color _primaryDark = Color(0xFF0D47A1); // Bleu foncé
  final Color _accentColor = Color(0xFF2196F3); // Bleu accent
  final Color _darkColor = Color(0xFF1A1D26);
  final Color _lightColor = Color(0xFFF8F9FA);
  final Color _greyColor = Color(0xFF6C757D);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      initialIndex: widget.initialTabIndex,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 180.0,
              floating: false,
              pinned: true,
              backgroundColor: _primaryColor,
              elevation: 0,
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  "Conditions & Confidentialité",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                centerTitle: true,
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _primaryDark,
                        _primaryColor,
                        _primaryLight,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyTabBarDelegate(
                child: Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: _primaryColor,
                    unselectedLabelColor: _greyColor,
                    indicatorColor: _primaryColor,
                    indicatorWeight: 3,
                    indicatorPadding: EdgeInsets.symmetric(horizontal: 20),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    tabs: [
                      Tab(
                        icon: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.description_rounded, size: 18),
                            SizedBox(width: 8),
                            Text("Conditions d'utilisation"),
                          ],
                        ),
                      ),
                      Tab(
                        icon: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.privacy_tip_rounded, size: 18),
                            SizedBox(width: 8),
                            Text("Confidentialité"),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildTermsContent(),
            _buildPrivacyContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsContent() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _buildLastUpdated("05/11/2025"),
        ),
        SliverList(
          delegate: SliverChildListDelegate([
            _buildModernSectionCard(
              title: "1. Acceptation des conditions",
              content: "En utilisant l'application Casanayo, vous acceptez pleinement et sans réserve les présentes conditions d'utilisation. Votre accès et votre utilisation continués du service constituent votre acceptation de toute modification.",
              icon: Icons.gavel_rounded,
              gradient: [_primaryDark, _primaryColor],
            ),
            _buildModernSectionCard(
              title: "2. Description du service",
              content: "Casanayo est une plateforme de mise en relation entre propriétaires, locataires et commissionnaires immobiliers pour faciliter les transactions immobilières en RDC. Nous offrons des services de recherche, de mise en relation, de vérification et de documentation.",
              icon: Icons.business_center_rounded,
              gradient: [_primaryColor, _primaryLight],
              bullets: [
                "Recherche intelligente de propriétés",
                "Mise en relation sécurisée",
                "Vérification d'identité KYC",
                "Gestion documentaire",
              ],
            ),
            _buildModernSectionCard(
              title: "3. Compte utilisateur",
              content: "Pour accéder à certaines fonctionnalités, vous devez créer un compte en fournissant des informations exactes et à jour. Vous êtes responsable de la confidentialité de vos identifiants.",
              icon: Icons.person_outline_rounded,
              gradient: [_primaryDark, _accentColor],
              bullets: [
                "Âge minimum requis : 18 ans",
                "Un seul compte par personne",
                "Vérification d'identité obligatoire",
                "Sécurité des identifiants",
              ],
            ),
            _buildModernSectionCard(
              title: "4. Responsabilités",
              content: "Les utilisateurs sont seuls responsables du contenu qu'ils publient et des transactions réalisées.",
              icon: Icons.warning_amber_rounded,
              gradient: [_primaryColor, Color(0xFF64B5F6)],
              bullets: [
                "Véracité des informations publiées",
                "Respect des lois et réglementations",
                "Communications avec les autres utilisateurs",
                "Transactions réalisées hors plateforme",
              ],
            ),
            _buildModernSectionCard(
              title: "5. Propriété intellectuelle",
              content: "Tous les éléments de l'application Casanayo (logos, interfaces, contenus) sont la propriété exclusive de Casanayo SARL. Toute reproduction sans autorisation est interdite.",
              icon: Icons.copyright_rounded,
              gradient: [_primaryDark, _primaryColor],
            ),
            _buildModernSectionCard(
              title: "6. Limitations de responsabilité",
              content: "Casanayo agit en tant qu'intermédiaire et ne peut être tenu responsable des litiges entre utilisateurs.",
              icon: Icons.work_outline_rounded,
              gradient: [_primaryColor, _primaryLight],
              bullets: [
                "Litiges entre utilisateurs",
                "Exactitude des annonces publiées",
                "Échec de transactions",
                "Problèmes techniques indépendants",
              ],
            ),
            SizedBox(height: 30),
            _buildContactSection(),
            SizedBox(height: 40),
          ]),
        ),
      ],
    );
  }

  Widget _buildPrivacyContent() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _buildLastUpdated("05/11/2025"),
        ),
        SliverList(
          delegate: SliverChildListDelegate([
            _buildModernSectionCard(
              title: "1. Données collectées",
              content: "Nous collectons les informations suivantes pour fournir et améliorer nos services :",
              icon: Icons.collections_bookmark_rounded,
              gradient: [_primaryDark, _primaryColor],
              bullets: [
                "Informations de compte et profil",
                "Documents d'identité (KYC)",
                "Historique d'activité et interactions",
                "Données techniques et de navigation",
                "Préférences de recherche et transactions",
              ],
            ),
            _buildModernSectionCard(
              title: "2. Utilisation des données",
              content: "Vos données sont utilisées pour les finalités suivantes :",
              icon: Icons.analytics_outlined,
              gradient: [_primaryColor, _primaryLight],
              bullets: [
                "Fournir et améliorer nos services",
                "Vérifier votre identité et prévenir les fraudes",
                "Personnaliser votre expérience utilisateur",
                "Développer de nouvelles fonctionnalités",
                "Analyser l'usage de l'application",
              ],
            ),
            _buildModernSectionCard(
              title: "3. Partage des données",
              content: "Nous ne partageons vos informations personnelles qu'avec :",
              icon: Icons.share_rounded,
              gradient: [_primaryDark, _accentColor],
              bullets: [
                "Utilisateurs concernés par vos transactions",
                "Autorités légales si requis par la loi",
                "Prestataires techniques liés par confidentialité",
                "Partenaires de vérification d'identité",
              ],
            ),
            _buildModernSectionCard(
              title: "4. Sécurité des données",
              content: "Nous mettons en œuvre des mesures techniques et organisationnelles de haute sécurité :",
              icon: Icons.lock_outline_rounded,
              gradient: [_primaryColor, Color(0xFF64B5F6)],
              bullets: [
                "Chiffrement AES-256 des données sensibles",
                "Accès restreint et 2FA",
                "Audits de sécurité réguliers",
                "Sauvegardes cryptées",
                "Conformité aux standards internationaux",
              ],
            ),
            _buildModernSectionCard(
              title: "5. Vos droits",
              content: "Conformément à la loi n°19/002 sur la protection des données, vous pouvez :",
              icon: Icons.manage_accounts_rounded,
              gradient: [_primaryDark, _primaryColor],
              bullets: [
                "Accéder à vos données personnelles",
                "Demander leur rectification ou effacement",
                "Vous opposer à leur traitement",
                "Demander la limitation du traitement",
                "Retirer votre consentement",
              ],
            ),
            SizedBox(height: 30),
            _buildContactSection(),
            SizedBox(height: 40),
          ]),
        ),
      ],
    );
  }

  Widget _buildModernSectionCard({
    required String title,
    required String content,
    required IconData icon,
    required List<Color> gradient,
    List<String>? bullets,
  }) {
    return Container(
      margin: EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(20),
        shadowColor: gradient.first.withOpacity(0.3),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.white,
                _lightColor,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.grey.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: gradient.map((color) => color.withOpacity(0.05)).toList(),
                    ),
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(20),
                      bottomLeft: Radius.circular(40),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: gradient,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: gradient.first.withOpacity(0.3),
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(icon, color: Colors.white, size: 20),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: _darkColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Text(
                      content,
                      style: TextStyle(
                        color: _greyColor,
                        fontSize: 15,
                        height: 1.6,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    if (bullets != null) ...[
                      SizedBox(height: 16),
                      ...bullets.map((bullet) => _buildModernBulletPoint(bullet, gradient.first)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernBulletPoint(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(top: 6, right: 12),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: _darkColor.withOpacity(0.8),
                fontSize: 14,
                height: 1.5,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastUpdated(String date) {
    return Container(
      margin: EdgeInsets.fromLTRB(20, 20, 20, 10),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _primaryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.update_rounded,
            color: _primaryColor,
            size: 16,
          ),
          SizedBox(width: 8),
          Text(
            "Dernière mise à jour : $date",
            style: TextStyle(
              color: _primaryColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _primaryColor.withOpacity(0.05),
            _primaryLight.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.grey.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primaryColor, _primaryLight],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.help_outline_rounded, color: Colors.white, size: 20),
              ),
              SizedBox(width: 12),
              Text(
                "Besoin d'aide ?",
                style: TextStyle(
                  color: _darkColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            "Notre équipe est là pour répondre à toutes vos questions concernant nos conditions ou notre politique de confidentialité.",
            style: TextStyle(
              color: _greyColor,
              fontSize: 14,
              height: 1.6,
            ),
          ),
          SizedBox(height: 20),
          _buildModernContactItem(
            icon: Icons.email_rounded,
            title: "Email",
            subtitle: "contact@casanayo.cd",
            description: "Réponse sous 24h",
            gradient: [_primaryColor, _primaryLight],
          ),
          _buildModernContactItem(
            icon: Icons.phone_rounded,
            title: "Téléphone",
            subtitle: "+243 810 000 000",
            description: "Lun-Ven, 8h-17h",
            gradient: [_primaryDark, _primaryColor],
          ),
          _buildModernContactItem(
            icon: Icons.location_on_rounded,
            title: "Adresse",
            subtitle: "Gombe, Kinshasa, RDC",
            description: "Siège social",
            gradient: [_primaryColor, _accentColor],
          ),
          SizedBox(height: 16),
          Divider(color: Colors.grey.withOpacity(0.3)),
          SizedBox(height: 12),
          Center(
            child: Text(
              "Délégué à la protection des données : dpd@casanayo.cd",
              style: TextStyle(
                color: _primaryColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernContactItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String description,
    required List<Color> gradient,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: _darkColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: _darkColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: _greyColor,
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
}

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _StickyTabBarDelegate({required this.child});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  double get maxExtent => 48;

  @override
  double get minExtent => 48;

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) {
    return child != oldDelegate.child;
  }
}
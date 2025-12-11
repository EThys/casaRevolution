import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:casa/utils/Routes.dart';

class CommissionDashboardPage extends StatefulWidget {
  @override
  _CommissionDashboardPageState createState() => _CommissionDashboardPageState();
}

class _CommissionDashboardPageState extends State<CommissionDashboardPage> {

  final Color primaryColor = Color(0xFF1976D2);
  final Color accentColor = Color(0xFF64B5F6);
  final Color darkBlue = Color(0xFF0D47A1);

  // Couleurs dérivées pour un design moderne
  final Color _primaryLight = Color(0xFFE3F2FD);
  final Color _cardColor = Colors.white;
  final Color _textColor = Color(0xFF1A237E);
  final Color _greyColor = Color(0xFF607D8B);
  final Color _greyLight = Color(0xFFECEFF1);
  final Color _successColor = Color(0xFF4CAF50);
  final Color _warningColor = Color(0xFFFF9800);
  final Color _dangerColor = Color(0xFFF44336);

  // Données simulées
  int _totalSponsored = 12;
  double _totalEarnings = 245.50;
  int _currentTabIndex = 0;
  double _scrollOffset = 0.0;

  final List<Map<String, dynamic>> _sponsoredLandlords = [
    {
      'id': 'BL001',
      'name': 'Jean Dupont',
      'phone': '243810123456',
      'registrationDate': DateTime(2023, 5, 15),
      'propertiesCount': 4,
      'activeProperties': 3,
      'occupiedProperties': 2,
      'lastActivity': DateTime(2023, 10, 28, 14, 30),
      'photoUrl': 'https://randomuser.me/api/portraits/men/1.jpg',
      'status': 'active',
      'earnings': 45.00,
    },
    {
      'id': 'BL002',
      'name': 'Marie Lambert',
      'phone': '243810654321',
      'registrationDate': DateTime(2023, 6, 2),
      'propertiesCount': 2,
      'activeProperties': 2,
      'occupiedProperties': 1,
      'lastActivity': DateTime(2023, 10, 25, 9, 15),
      'photoUrl': 'https://randomuser.me/api/portraits/women/2.jpg',
      'status': 'active',
      'earnings': 30.00,
    },
  ];

  final List<Map<String, dynamic>> _recentActivities = [
    {
      'type': 'new_property',
      'landlordId': 'BL003',
      'landlordName': 'Paul Mbayo',
      'propertyId': 'PR098',
      'propertyTitle': 'Appartement moderne à Gombe',
      'date': DateTime(2023, 10, 30, 16, 45),
    },
    {
      'type': 'payment',
      'landlordId': 'BL003',
      'landlordName': 'Paul Mbayo',
      'amount': 5.00,
      'date': DateTime(2023, 10, 20, 12, 0),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _greyLight,
      body: NotificationListener<ScrollNotification>(
        onNotification: (scrollNotification) {
          setState(() {
            _scrollOffset = scrollNotification.metrics.pixels;
          });
          return false;
        },
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              _buildAppBar(),
              _buildStatsHeader(),
            ];
          },
          body: _buildTabContent(),
        ),
      ),
      floatingActionButton: _currentTabIndex == 0 ? _buildAddLandlordButton() : null,
    );
  }

  SliverAppBar _buildAppBar() {
    final double opacity = (1 - (_scrollOffset / 100)).clamp(0.0, 1.0);

    return SliverAppBar(
      expandedHeight: 180.0,
      floating: false,
      pinned: true,
      backgroundColor: _cardColor,
      elevation: _scrollOffset > 50 ? 4 : 0,
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
        collapseMode: CollapseMode.pin,
        title: AnimatedOpacity(
          opacity: opacity < 0.3 ? 1.0 : 0.0,
          duration: Duration(milliseconds: 200),
          child: Text(
            'Tableau de Bord',
            style: TextStyle(
              color: _textColor,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [darkBlue, primaryColor],
            ),
          ),
          child: Stack(
            children: [
              // Éléments décoratifs
              Positioned(
                top: -20,
                right: -20,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                bottom: -30,
                left: -30,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                ),
              ),

              Padding(
                padding: EdgeInsets.only(left: 24, right: 24, top: 80, bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Solde disponible',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '\$${_totalEarnings.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 12),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.trending_up, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text(
                            '+12% ce mois-ci',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        _buildNotificationButton(),
        SizedBox(width: 8),
        _buildProfileAvatar(),
        SizedBox(width: 16),
      ],
    );
  }

  SliverPersistentHeader _buildStatsHeader() {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _ModernStatsHeaderDelegate(
        minHeight: 100.0,
        maxHeight: 140.0,
        totalSponsored: _totalSponsored,
        activeProperties: 8,
        occupiedProperties: 6,
        primaryColor: primaryColor,
        accentColor: accentColor,
        darkBlue: darkBlue,
        cardColor: _cardColor,
      ),
    );
  }

  Widget _buildTabContent() {
    return Container(
      decoration: BoxDecoration(
        color: _greyLight,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Barre d'onglets moderne
          _buildModernTabBar(),

          // Contenu des onglets
          Expanded(
            child: _buildCurrentTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTabBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      padding: EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildModernTabButton(
            icon: Icons.people_alt_outlined,
            label: 'Bailleurs',
            isActive: _currentTabIndex == 0,
            onTap: () => setState(() => _currentTabIndex = 0),
          ),
          _buildModernTabButton(
            icon: Icons.timeline_outlined,
            label: 'Activités',
            isActive: _currentTabIndex == 1,
            onTap: () => setState(() => _currentTabIndex = 1),
          ),
          _buildModernTabButton(
            icon: Icons.monetization_on_outlined,
            label: 'Revenus',
            isActive: _currentTabIndex == 2,
            onTap: () => setState(() => _currentTabIndex = 2),
          ),
          _buildModernTabButton(
            icon: Icons.home_work_outlined,
            label: 'Mes Biens',
            isActive: _currentTabIndex == 3,
            onTap: () => setState(() => _currentTabIndex = 3),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTabButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required Function() onTap,
  }) {
    return Expanded(
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isActive ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          gradient: isActive ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [primaryColor, accentColor],
          ) : null,
          boxShadow: isActive ? [
            BoxShadow(
              color: primaryColor.withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ] : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: isActive ? Colors.white : _greyColor,
                  ),
                  SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isActive ? Colors.white : _greyColor,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTab() {
    switch (_currentTabIndex) {
      case 0:
        return _buildLandlordsTab();
      case 1:
        return _buildActivitiesTab();
      case 2:
        return _buildEarningsTab();
      case 3:
        return _buildMyPropertiesTab();
      default:
        return _buildLandlordsTab();
    }
  }

  Widget _buildMyPropertiesTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.home_work_outlined, size: 64, color: primaryColor),
          SizedBox(height: 16),
          Text(
            'Gérer vos propriétés',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _textColor,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Consultez, modifiez et supprimez vos annonces',
            style: TextStyle(
              fontSize: 14,
              color: _greyColor,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, Routes.myPropertiesRoute);
            },
            icon: Icon(Icons.arrow_forward_rounded),
            label: Text('Voir mes propriétés'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLandlordsTab() {
    return Column(
      children: [
        // Barre de recherche moderne
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                SizedBox(width: 16),
                Icon(Icons.search, color: _greyColor, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Rechercher un bailleur...',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: _greyColor),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: _greyLight,
                ),
                IconButton(
                  icon: Icon(Icons.filter_list_rounded, color: primaryColor),
                  onPressed: () {},
                ),
                SizedBox(width: 8),
              ],
            ),
          ),
        ),

        // En-tête de section
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            children: [
              Text(
                'Bailleurs sponsorisés',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _textColor,
                ),
              ),
              Spacer(),
              Text(
                '${_sponsoredLandlords.length} trouvés',
                style: TextStyle(
                  fontSize: 12,
                  color: _greyColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        // Liste des bailleurs
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _sponsoredLandlords.length,
            separatorBuilder: (context, index) => SizedBox(height: 12),
            itemBuilder: (context, index) {
              final landlord = _sponsoredLandlords[index];
              return _buildModernLandlordCard(landlord);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildModernLandlordCard(Map<String, dynamic> landlord) {
    final isActive = landlord['status'] == 'active';
    final daysSinceRegistration = DateTime.now().difference(landlord['registrationDate']).inDays;

    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {},
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar avec badge
                Stack(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: primaryColor.withOpacity(0.2),
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: Image.network(
                          landlord['photoUrl'],
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: isActive ? _successColor : _dangerColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(width: 16),

                // Informations
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            landlord['name'],
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: _textColor,
                            ),
                          ),
                          Spacer(),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [primaryColor, accentColor],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '\$${landlord['earnings'].toStringAsFixed(0)}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        landlord['phone'],
                        style: TextStyle(
                          fontSize: 13,
                          color: _greyColor,
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          _buildPropertyStat('${landlord['propertiesCount']}', 'Biens'),
                          SizedBox(width: 12),
                          _buildPropertyStat('${landlord['activeProperties']}', 'Actifs'),
                          SizedBox(width: 12),
                          _buildPropertyStat('${landlord['occupiedProperties']}', 'Occupés'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPropertyStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: primaryColor,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: _greyColor,
          ),
        ),
      ],
    );
  }

  Widget _buildActivitiesTab() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Text(
                'Activités récentes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _textColor,
                ),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Aujourd\'hui',
                  style: TextStyle(
                    fontSize: 12,
                    color: primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _recentActivities.length,
            separatorBuilder: (context, index) => SizedBox(height: 12),
            itemBuilder: (context, index) {
              final activity = _recentActivities[index];
              return _buildModernActivityCard(activity);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildModernActivityCard(Map<String, dynamic> activity) {
    final config = _getActivityConfig(activity['type']);

    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {},
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // Icône avec fond coloré
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [config.color.withOpacity(0.2), config.color.withOpacity(0.1)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(config.icon, size: 20, color: config.color),
                ),

                SizedBox(width: 16),

                // Contenu
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        config.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: _textColor,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        config.subtitle(activity),
                        style: TextStyle(
                          fontSize: 13,
                          color: _greyColor,
                        ),
                      ),
                    ],
                  ),
                ),

                // Timestamp
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      DateFormat('HH:mm').format(activity['date']),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _textColor,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      DateFormat('dd/MM').format(activity['date']),
                      style: TextStyle(
                        fontSize: 11,
                        color: _greyColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEarningsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _buildModernChart(),
          SizedBox(height: 24),
          _buildEarningsGrid(),
        ],
      ),
    );
  }

  Widget _buildModernChart() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Performance des revenus',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: _textColor,
                ),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _successColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.trending_up, size: 12, color: _successColor),
                    SizedBox(width: 4),
                    Text(
                      '+12.5%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _successColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Container(
            height: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildModernChartBar(35, 'J', 0),
                _buildModernChartBar(42, 'F', 1),
                _buildModernChartBar(28, 'M', 2),
                _buildModernChartBar(55, 'A', 3),
                _buildModernChartBar(60, 'M', 4),
                _buildModernChartBar(45, 'J', 5),
                _buildModernChartBar(65, 'C', 6, isCurrent: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernChartBar(int value, String label, int index, {bool isCurrent = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 8,
          height: (value / 65) * 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isCurrent
                  ? [darkBlue, primaryColor]
                  : [accentColor.withOpacity(0.3), primaryColor.withOpacity(0.3)],
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isCurrent ? primaryColor : _greyColor,
            fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildEarningsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.3,
      children: [
        _buildModernEarningStatItem('Ce mois-ci', 65.0, '+12%', Icons.trending_up),
        _buildModernEarningStatItem('Moyenne mensuelle', 46.8, '+5%', Icons.bar_chart),
        _buildModernEarningStatItem('Bailleurs actifs', 8.0, '+2', Icons.people),
        _buildModernEarningStatItem('Taux d\'occupation', 75.0, '+8%', Icons.percent),
      ],
    );
  }

  Widget _buildModernEarningStatItem(String title, double value, String change, IconData icon) {
    final isPositive = change.contains('+');

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: primaryColor),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isPositive ? _successColor.withOpacity(0.1) : _dangerColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(
                      isPositive ? Icons.trending_up : Icons.trending_down,
                      size: 10,
                      color: isPositive ? _successColor : _dangerColor,
                    ),
                    SizedBox(width: 2),
                    Text(
                      change,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isPositive ? _successColor : _dangerColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: _textColor,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: _greyColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationButton() {
    return Container(
      decoration: BoxDecoration(
        color: _primaryLight,
        shape: BoxShape.circle,
      ),
      child: Stack(
        children: [
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: primaryColor, size: 22),
            onPressed: () {},
          ),
          Positioned(
            right: 10,
            top: 10,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _dangerColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: primaryColor.withOpacity(0.2), width: 2),
      ),
      child: CircleAvatar(
        radius: 18,
        backgroundColor: _primaryLight,
        backgroundImage: NetworkImage('https://randomuser.me/api/portraits/men/5.jpg'),
      ),
    );
  }

  Widget _buildAddLandlordButton() {
    return FloatingActionButton(
      heroTag: "commission_dashboard_fab", // Tag unique pour éviter les conflits Hero
      onPressed: () {},
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Icon(Icons.person_add_alt_rounded, size: 24),
    );
  }

  ActivityConfig _getActivityConfig(String type) {
    switch (type) {
      case 'new_property':
        return ActivityConfig(
          icon: Icons.home_work_outlined,
          color: primaryColor,
          title: 'Nouvelle propriété',
          subtitle: (activity) => '${activity['landlordName']}',
        );
      case 'payment':
        return ActivityConfig(
          icon: Icons.payment_outlined,
          color: _successColor,
          title: 'Paiement reçu',
          subtitle: (activity) => '\$${activity['amount']}',
        );
      default:
        return ActivityConfig(
          icon: Icons.notifications_outlined,
          color: _greyColor,
          title: 'Activité',
          subtitle: (activity) => 'Nouvelle activité',
        );
    }
  }
}

class _ModernStatsHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final int totalSponsored;
  final int activeProperties;
  final int occupiedProperties;
  final Color primaryColor;
  final Color accentColor;
  final Color darkBlue;
  final Color cardColor;

  _ModernStatsHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.totalSponsored,
    required this.activeProperties,
    required this.occupiedProperties,
    required this.primaryColor,
    required this.accentColor,
    required this.darkBlue,
    required this.cardColor,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final double progress = shrinkOffset / maxHeight;
    final bool isCollapsed = progress > 0.5;

    return Container(
      color: cardColor,
      child: Stack(
        children: [
          // Fond qui s'estompe
          AnimatedContainer(
            duration: Duration(milliseconds: 200),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [darkBlue, primaryColor],
              ),
            ),
          ),

          // Statistiques
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildModernStatItem(
                  Icons.people_alt_outlined,
                  totalSponsored.toString(),
                  'Bailleurs',
                  isCollapsed,
                ),
                _buildModernStatItem(
                  Icons.home_outlined,
                  activeProperties.toString(),
                  'Actives',
                  isCollapsed,
                ),
                _buildModernStatItem(
                  Icons.king_bed_outlined,
                  occupiedProperties.toString(),
                  'Occupées',
                  isCollapsed,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernStatItem(IconData icon, String value, String label, bool isCollapsed) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      padding: EdgeInsets.all(isCollapsed ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(isCollapsed ? 0.15 : 0.2),
        borderRadius: BorderRadius.circular(isCollapsed ? 12 : 16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: isCollapsed ? 12 : 18,
            color: Colors.white,
          ),
          SizedBox(height: isCollapsed ? 2 : 4),
          Text(
            value,
            style: TextStyle(
              fontSize: isCollapsed ? 10 : 14,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: isCollapsed ? 10 : 11,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  double get maxExtent => maxHeight;

  @override
  double get minExtent => minHeight;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return true;
  }
}

class ActivityConfig {
  final IconData icon;
  final Color color;
  final String title;
  final String Function(Map<String, dynamic>) subtitle;

  ActivityConfig({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });
}
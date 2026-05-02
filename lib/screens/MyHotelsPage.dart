import 'package:casa/controllers/PropertyCtrl.dart';
import 'package:casa/models/PropertyModel.dart';
import 'package:casa/screens/HotelDetailPage.dart';
import 'package:casa/screens/HotelManageDetailPage.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/Routes.dart';
import 'package:casa/utils/StockageKeys.dart';
import 'package:casa/utils/SubscriptionHelper.dart';
import 'package:casa/utils/decertification_access_guard.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

/// Liste des hôtels du propriétaire — même ligne graphique que [MyPropertiesPage], chargement cache d’abord.
class MyHotelsPage extends StatefulWidget {
  const MyHotelsPage({Key? key}) : super(key: key);

  @override
  State<MyHotelsPage> createState() => _MyHotelsPageState();
}

class _MyHotelsPageState extends State<MyHotelsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoadingData = true;
  bool _isRefreshing = false;
  final GetStorage _stockage = GetStorage();

  final Color _primaryColor = const Color(0xFF1976D2);
  final Color _secondaryColor = const Color(0xFF64B5F6);
  final Color _darkColor = const Color(0xFF1A1D26);
  final Color _lightGrey = const Color(0xFFF5F6FA);
  final Color _mediumGrey = const Color(0xFF7F8C8D);
  final Color _successColor = const Color(0xFF00B894);
  final Color _cardBackground = Colors.white;

  List<PropertyModel> _hotels = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (await DecertificationAccessGuard.redirectIfInactiveDecertified(context)) {
        return;
      }
      if (!mounted) return;
      _load();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      setState(() {
        _isRefreshing = true;
        if (_hotels.isEmpty) _isLoadingData = true;
      });
      final ctrl = context.read<PropertyController>();
      final cached = await ctrl.loadMyHotelsFromDatabase();
      if (!mounted) return;
      setState(() {
        _hotels = cached;
        _isLoadingData = false;
      });
      final fresh = await ctrl.syncOwnerHotelsToDatabase();
      if (!mounted) return;
      setState(() {
        if (fresh.isNotEmpty) _hotels = fresh;
        _isRefreshing = false;
      });
    } catch (e) {
      print('❌ MyHotelsPage load: $e');
      if (mounted) {
        setState(() {
          _isLoadingData = false;
          _isRefreshing = false;
        });
        FancyNotification.show(
          context,
          'Les hôtels n’ont pas pu être chargés. Tirez pour rafraîchir.',
          isError: true,
        );
      }
    }
  }

  List<PropertyModel> get _disponibles => _hotels.where((p) => p.sold != true).toList();
  List<PropertyModel> get _indisponibles => _hotels.where((p) => p.sold == true).toList();

  List<PropertyModel> _filtered(String key) {
    switch (key) {
      case 'disponible':
        return _disponibles;
      case 'indisponible':
        return _indisponibles;
      default:
        return _hotels;
    }
  }

  void _openManage(PropertyModel h) {
    Navigator.push<PropertyModel>(
      context,
      MaterialPageRoute(builder: (_) => HotelManageDetailPage(initialHotel: h)),
    ).then((_) => _load());
  }

  void _openPublic(PropertyModel h) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => HotelDetailPage(property: h)),
    );
  }

  void _createHotel() {
    final token = _stockage.read(StockageKeys.tokenKey);
    if (token == null) {
      FancyNotification.show(
        context,
        'Vous devez être connecté pour publier.',
        type: NotificationType.info,
      );
      return;
    }
    SubscriptionHelper.checkCertifiedThenProceed(
      context: context,
      onProceed: () {
        Navigator.pushNamed(context, Routes.createPropertyRoute).then((_) => _load());
      },
    );
  }

  Widget _buildStatusBadge(PropertyModel property) {
    final isSold = property.sold == true;
    final bg = isSold ? _mediumGrey : _successColor;
    final text = isSold ? 'Indisponible' : 'Disponible';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Widget _buildShimmerList() {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 20),
      itemBuilder: (_, __) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            height: 220,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmpty(String filterKey) {
    final messages = {
      'all': 'Aucun hôtel publié',
      'disponible': 'Aucun hôtel disponible',
      'indisponible': 'Aucun hôtel indisponible',
    };
    final subs = {
      'all': 'Créez un hôtel avec le type « Hotels » dans la publication d’annonce.',
      'disponible': 'Les hôtels marqués indisponible n’apparaissent pas ici.',
      'indisponible': 'Les hôtels encore en ligne apparaissent dans l’onglet Disponible.',
    };
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(color: _lightGrey, shape: BoxShape.circle),
              child: Icon(Icons.hotel_rounded, size: 56, color: _mediumGrey.withOpacity(0.35)),
            ),
            const SizedBox(height: 20),
            Text(
              messages[filterKey] ?? messages['all']!,
              style: TextStyle(color: _mediumGrey, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                subs[filterKey] ?? subs['all']!,
                textAlign: TextAlign.center,
                style: TextStyle(color: _mediumGrey.withOpacity(0.85), fontSize: 14),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _createHotel,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Créer une annonce'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHotelCard(PropertyModel h) {
    final firstImage = h.propertyImage?.isNotEmpty == true ? h.propertyImage!.first.path : null;
    final cover = firstImage ??
        (h.image ?? (h.allImageUrls.isNotEmpty ? h.allImageUrls.first : null));
    final roomCount = h.hotelStructure?.length ?? 0;
    final priceText = h.price != null
        ? '${NumberFormat('#,###', 'fr_FR').format(h.price!.toInt())} ${h.currency}'
        : '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: _cardBackground,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            spreadRadius: 1,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: cover != null && cover.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: cover,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: _lightGrey,
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2, color: _primaryColor),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: _lightGrey,
                            child: Icon(Icons.hotel_rounded, size: 48, color: _mediumGrey),
                          ),
                        )
                      : Container(
                          color: _lightGrey,
                          alignment: Alignment.center,
                          child: Icon(Icons.hotel_rounded, size: 48, color: _mediumGrey),
                        ),
                ),
              ),
              Positioned(bottom: 15, left: 15, child: _buildStatusBadge(h)),
            
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  h.title ?? 'Hôtel',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: _darkColor),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 16, color: _mediumGrey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${h.cityValue ?? ''}${(h.communeValue ?? '').isNotEmpty ? ', ${h.communeValue}' : ''}',
                        style: TextStyle(color: _mediumGrey, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.bed_rounded, size: 16, color: _primaryColor),
                    const SizedBox(width: 6),
                    Text(
                      '$roomCount chambre(s) · #${h.propertyId}',
                      style: TextStyle(
                        fontSize: 13,
                        color: _primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openPublic(h),
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                        label: const Text('Voir fiche'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _primaryColor,
                          side: BorderSide(color: _primaryColor.withOpacity(0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _openManage(h),
                        icon: const Icon(Icons.settings_suggest_outlined, size: 18),
                        label: const Text('Gérer'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget _buildList(String filterKey) {
    final list = _filtered(filterKey == 'all' ? 'all' : filterKey);
    if (_isLoadingData && list.isEmpty) {
      return _buildShimmerList();
    }
    if (list.isEmpty) {
      return _buildEmpty(filterKey == 'all' ? 'all' : filterKey);
    }
    return RefreshIndicator(
      color: _primaryColor,
      backgroundColor: Colors.white,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 20),
        itemBuilder: (_, i) => _buildHotelCard(list[i]),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      iconTheme: const IconThemeData(color: Colors.white),
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
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.hotel_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          const Text(
            'Mes hôtels',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(_isRefreshing ? Icons.hourglass_top : Icons.refresh_rounded, color: Colors.white),
          onPressed: _isRefreshing ? null : _load,
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: Colors.white.withOpacity(0.2)),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: _primaryColor,
            unselectedLabelColor: _mediumGrey,
            indicatorColor: _primaryColor,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorPadding: const EdgeInsets.symmetric(horizontal: 10),
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            tabs: [
              Tab(text: 'Tous (${_hotels.length})'),
              Tab(text: 'Disponible (${_disponibles.length})'),
              Tab(text: 'Indisponible (${_indisponibles.length})'),
            ],
          ),
          if (_isLoadingData && _hotels.isEmpty)
            LinearProgressIndicator(
              backgroundColor: _lightGrey,
              valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
              minHeight: 2,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightGrey,
      appBar: _buildAppBar(),
      floatingActionButton: FloatingActionButton(
        heroTag: 'my_hotels_fab',
        onPressed: _isRefreshing ? null : _load,
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: _isRefreshing
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.refresh_rounded, size: 24),
      ),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildList('all'),
                _buildList('disponible'),
                _buildList('indisponible'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

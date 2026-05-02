import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:provider/provider.dart';

import '../controllers/PropertyCtrl.dart';
import '../controllers/AgenceController.dart';
import '../models/PropertyModel.dart';
import '../models/AgenceModel.dart';
import '../utils/Constantes.dart';
import '../utils/FancyNotification.dart';
import '../utils/property_detail_navigation.dart';
import '../utils/FavoriteEartIcon.dart';
import 'package:casa/widgets/property_sold_badge.dart';
import 'AgenceDetailsPage.dart';

class AllPropertiesPage extends StatefulWidget {
  final List<PropertyModel> initialProperties;
  final bool isForRent;
  final String? title;

  const AllPropertiesPage({
    Key? key,
    required this.initialProperties,
    required this.isForRent,
    this.title,
  }) : super(key: key);

  @override
  _AllPropertiesPageState createState() => _AllPropertiesPageState();
}

class _AllPropertiesPageState extends State<AllPropertiesPage> {
  late List<PropertyModel> _filteredProperties;
  final TextEditingController _searchController = TextEditingController();
  bool _isGridView = true;
  String _selectedFilter = 'Tous';
  PropertyController? _propertyCtrl;
  VoidCallback? _propertyCtrlListener;
  final List<String> _filters = [
    'Tous',
    'Appartements',
    'Maisons',
    'Studios',
    'Bureaux',
    'Terrains',
    'Vacances',
    'Salles de fête',
    'Funéraires',
    'Hôtels'
  ];

  // Infinity Scroll Logic
  int _visibleCount = 15;
  final int _pageSize = 15;
  bool _isLoadingMore = false;
  final RefreshController _refreshController = RefreshController();

  // Couleurs du design PropertySearchPage
  final Color _primaryColor = Color(0xFF1976D2);
  final Color _darkColor = Color(0xFF1A1D26);
  final Color _lightColor = Color(0xFFF5F6FA);
  final Color _greyColor = Color(0xFF7F8C8D);
  final Color _accentColor = Color(0xFF4CAF50);

  bool get _shouldShowAgencesSection =>
      _selectedFilter == 'Tous' || _selectedFilter == 'Vacances';

  bool _matchesAgenceQuery(AgenceModel a, String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return true;
    final hay = StringBuffer()
      ..write((a.name ?? ''))
      ..write(' ')
      ..write((a.description ?? ''))
      ..write(' ')
      ..write((a.address ?? ''));

    final sites = a.sites ?? const <AgenceSiteModel>[];
    for (final s in sites) {
      hay
        ..write(' ')
        ..write((s.title ?? ''))
        ..write(' ')
        ..write((s.description ?? ''));
    }
    return hay.toString().toLowerCase().contains(query);
  }

  List<AgenceModel> _filteredAgencesForUi(AgenceController agenceCtrl) {
    final q = _searchController.text;
    final list =
        agenceCtrl.agences.where((a) => _matchesAgenceQuery(a, q)).toList();
    list.sort((a, b) {
      final sa = (a.sites?.length ?? 0);
      final sb = (b.sites?.length ?? 0);
      if (sa != sb) return sb.compareTo(sa);
      return (b.id ?? 0).compareTo(a.id ?? 0);
    });
    return list;
  }

  String? _agenceCoverImage(AgenceModel a) {
    final sites = a.sites;
    if (sites == null || sites.isEmpty) return a.logo;
    for (final s in sites) {
      final imgs = s.images;
      if (imgs != null && imgs.isNotEmpty) return imgs.first;
    }
    return a.logo;
  }

  String _locationText(String? commune, String? city) {
    final parts = <String>[];
    final c1 = (commune ?? '').trim();
    final c2 = (city ?? '').trim();
    if (c1.isNotEmpty) parts.add(c1);
    if (c2.isNotEmpty) parts.add(c2);
    return parts.isEmpty ? 'Localisation' : parts.join(', ');
  }

  @override
  void initState() {
    super.initState();
    _filteredProperties = List<PropertyModel>.from(widget.initialProperties);
    _sortMostRecentFirst(_filteredProperties);
    // Aligner "Tous" sur la source unifiée (incl. terrains/hôtels) dès l'ouverture.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final propertyCtrl =
          Provider.of<PropertyController>(context, listen: false);
      final agenceCtrl = Provider.of<AgenceController>(context, listen: false);
      _propertyCtrl = propertyCtrl;

      // Re-appliquer automatiquement les filtres quand la sync remplit terrains/hôtels/vacances.
      _propertyCtrlListener ??= () {
        if (!mounted) return;
        _applyFilters();
      };
      propertyCtrl.removeListener(_propertyCtrlListener!);
      propertyCtrl.addListener(_propertyCtrlListener!);

      // Toujours lancer la sync spéciale (local-first + online en arrière-plan).
      // Sinon un type peut rester vide (ex. terrains) si une autre catégorie est déjà en mémoire.
      propertyCtrl.syncAllSpecialCategories();
      // Charger aussi les agences tourisme pour qu'elles soient visibles dans "Tous" et "Vacances"
      try {
        // fire-and-forget (cache GetStorage affiché tout de suite si dispo)
        agenceCtrl.fetchAgences();
      } catch (_) {}
      _applyFilters();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final propertyCtrl = context.watch<PropertyController>();

    return Scaffold(
      backgroundColor: isDarkMode ? _darkColor : _lightColor,
      appBar: _buildAppBar(theme),
      body: SmartRefresher(
        controller: _refreshController,
        enablePullDown: true,
        enablePullUp: true,
        header: WaterDropMaterialHeader(
          backgroundColor: _primaryColor,
          color: Colors.white,
        ),
        footer: ClassicFooter(
          loadingText: "Plus de biens en chemin...",
          noDataText: "Toutes les propriétés sont affichées",
          idleText: "Scrollez pour voir plus",
          loadingIcon: SizedBox(
            width: 25,
            height: 25,
            child:
                CircularProgressIndicator(strokeWidth: 2, color: _primaryColor),
          ),
        ),
        onRefresh: () async {
          setState(() => _visibleCount = _pageSize);
          await _handlePullToRefresh(propertyCtrl);
        },
        onLoading: () async {
          await _loadMore(propertyCtrl);
        },
        child: Column(
          children: [
            //_buildSearchBar(isDarkMode),
            _buildFilterChips(isDarkMode),

            // Indicateur de synchronisation discret
            if (propertyCtrl.syncing) _buildMinimalSyncIndicator(),

            Expanded(
              child: _buildResultsScroll(isDarkMode),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsScroll(bool isDarkMode) {
    final agenceCtrl = context.watch<AgenceController>();
    final agences = _shouldShowAgencesSection
        ? _filteredAgencesForUi(agenceCtrl)
        : const <AgenceModel>[];
    final showAgences = _shouldShowAgencesSection && agences.isNotEmpty;
    final visibleItems = _filteredProperties.take(_visibleCount).toList();

    // Inline sections (Tous uniquement): 4 propriétés → hôtels horizontal → 4 propriétés → agences horizontal → suite...
    final bool showInlineMix = _selectedFilter == 'Tous';
    final hotelsInline = showInlineMix
        ? _filteredProperties.where((p) {
            final n = (p.propertyType?.name ?? '').toString().toLowerCase();
            final id = p.propertyTypeId ?? p.propertyType?.propertyTypeId;
            return id == 5 || n.contains('hotel') || n.contains('hôtel');
          }).toList()
        : const <PropertyModel>[];

    if (_filteredProperties.isEmpty && !showAgences) {
      return _buildEmptyState(isDarkMode);
    }

    // Single scroll (slivers) for better UX/perf + keeps SmartRefresher smooth.
    return CustomScrollView(
      slivers: [
        // (SUPPRIMÉ) Premier scroll "Tourisme" en haut :
        // Tourisme/Hôtels sont visibles via l'intercalation dans la liste/grille (Tous).

        // Properties section
        if (_isGridView)
          ...() {
            // In "Tous" we interleave starting with Hotels:
            // Hotels scroll → 5 properties → Tourisme scroll → 5 properties → Hotels scroll → ...
            if (!showInlineMix) {
              return <Widget>[
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.72,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          _buildPropertyCard(visibleItems[index], isDarkMode),
                      childCount: visibleItems.length,
                    ),
                  ),
                ),
              ];
            }

            final hasHotels = hotelsInline.isNotEmpty;
            final hasAgences = agences.isNotEmpty;
            const int k = 6;

            final slivers = <Widget>[];
            int start = 0;
            int sectionIndex = 0; // 0=hotels first, 1=agences next, repeat

            // Start with hotels (if available), otherwise start with tourisme.
            if (hasHotels || hasAgences) {
              final startWithHotels = hasHotels;
              if (startWithHotels) {
                slivers.add(
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child:
                          _buildInlineHotelsSection(hotelsInline, isDarkMode),
                    ),
                  ),
                );
                sectionIndex = 1; // next section should be tourisme
              } else {
                slivers.add(
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: _buildInlineAgencesSection(agences, isDarkMode),
                    ),
                  ),
                );
                sectionIndex =
                    1; // next section should be hotels (if they appear later)
              }
            }

            while (start < visibleItems.length) {
              final end = (start + k).clamp(0, visibleItems.length);
              final chunk = visibleItems.sublist(start, end);

              slivers.add(
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.72,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, idx) =>
                          _buildPropertyCard(chunk[idx], isDarkMode),
                      childCount: chunk.length,
                    ),
                  ),
                ),
              );

              // After each 5-block, insert section (tourisme then hotels, alternating, with hotels prioritized first overall)
              if (end < visibleItems.length && (hasHotels || hasAgences)) {
                final wantHotels =
                    hasHotels && (!hasAgences || sectionIndex % 2 == 0);
                final wantAgences =
                    hasAgences && (!hasHotels || sectionIndex % 2 == 1);

                if (wantHotels) {
                  slivers.add(
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                        child:
                            _buildInlineHotelsSection(hotelsInline, isDarkMode),
                      ),
                    ),
                  );
                  sectionIndex += 1;
                } else if (wantAgences) {
                  slivers.add(
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                        child: _buildInlineAgencesSection(agences, isDarkMode),
                      ),
                    ),
                  );
                  sectionIndex += 1;
                }
              }

              start = end;
            }

            return slivers;
          }()
        else
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (!showInlineMix) {
                    return _buildPropertyListItem(
                        visibleItems[index], isDarkMode);
                  }

                  // Insert sections repeatedly starting with Hotels:
                  // Hotels scroll → 6 properties → Tourisme scroll → 6 properties → Hotels scroll → ...
                  final hasHotels = hotelsInline.isNotEmpty;
                  final hasAgences = agences.isNotEmpty;
                  const int k = 6;

                  bool isInsertionIndex(int i) {
                    return i % (k + 1) == 0;
                  }

                  int insertionBlockIndex(int i) {
                    // valid only if isInsertionIndex(i) == true
                    return i ~/ (k + 1);
                  }

                  int insertsBefore(int i) {
                    final q = i ~/ (k + 1);
                    final r = i % (k + 1);
                    return q + (r == 0 ? 0 : 1);
                  }

                  if (isInsertionIndex(index) && (hasHotels || hasAgences)) {
                    final b = insertionBlockIndex(index); // 0 => hotels first
                    final wantHotels = hasHotels && (!hasAgences || b % 2 == 0);
                    final wantAgences =
                        hasAgences && (!hasHotels || b % 2 == 1);

                    // Prioriser hotels avant agences tourisme
                    if (wantHotels)
                      return _buildInlineHotelsSection(
                          hotelsInline, isDarkMode);
                    if (wantAgences)
                      return _buildInlineAgencesSection(agences, isDarkMode);
                    return const SizedBox.shrink();
                  }

                  // Map sliver index to property index
                  final pIndex = index - insertsBefore(index);

                  if (pIndex < 0 || pIndex >= visibleItems.length)
                    return const SizedBox.shrink();
                  return _buildPropertyListItem(
                      visibleItems[pIndex], isDarkMode);
                },
                childCount: () {
                  if (!showInlineMix) return visibleItems.length;
                  const int k = 6;
                  final hasSection =
                      hotelsInline.isNotEmpty || agences.isNotEmpty;
                  // Start with a section, then one section after every k items (except maybe at end).
                  final extra =
                      hasSection ? (1 + ((visibleItems.length - 1) ~/ k)) : 0;
                  return visibleItems.length + extra;
                }(),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
      ],
    );
  }

  Widget _buildInlineHotelsSection(
      List<PropertyModel> hotels, bool isDarkMode) {
    final items = hotels.take(12).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(Icons.hotel_rounded, color: _primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Hôtels',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDarkMode ? Colors.white : _darkColor,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            // Même hauteur que la section Tourisme
            height: 210,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) =>
                  _buildMiniHotelCard(items[index], isDarkMode),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniHotelCard(PropertyModel property, bool isDarkMode) {
    final firstImage = property.propertyImage?.isNotEmpty ?? false
        ? property.propertyImage!.first
        : null;
    final imageUrl =
        firstImage != null ? "${firstImage.path ?? firstImage.path}" : null;
    return InkWell(
      onTap: () => _navigateToDetail(property,
          heroTag: 'all-inline-hotel-${property.propertyId}'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 240,
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 14,
                offset: const Offset(0, 6))
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageUrl != null)
                CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover)
              else
                Container(
                    color: Colors.grey[200],
                    child: Icon(Icons.photo_outlined,
                        size: 44, color: Colors.grey[400])),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.85)
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: PropertyListingStatusChip(
                  sold: property.sold,
                  transactionType: property.transactionType,
                  available: property.available,
                  listingAllowed: property.listingAllowed,
                  compact: true,
                  onDarkBackground: true,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: property.propertyId != null
                    ? Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.92),
                          shape: BoxShape.circle,
                        ),
                        child: FavoriteHeartIcon(
                          propertyId: property.propertyId.toString(),
                          propertyTypeId: property.propertyTypeId,
                          size: 16,
                          splashRadius: 16,
                          activeColor: Colors.red,
                          inactiveColor: _greyColor,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      property.title ?? 'Hôtel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded,
                            size: 14, color: Colors.white.withOpacity(0.85)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _locationText(
                                property.communeValue, property.cityValue),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInlineAgencesSection(
      List<AgenceModel> agences, bool isDarkMode) {
    if (agences.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(Icons.attractions_rounded, color: _primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Agences (Tourisme)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDarkMode ? Colors.white : _darkColor,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 210,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: agences.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) =>
                  _buildAgenceTourismeCard(agences[index], isDarkMode),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgenceTourismeCard(AgenceModel agence, bool isDarkMode) {
    final cover = _agenceCoverImage(agence);
    final sitesCount = agence.sites?.length ?? 0;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AgenceDetailsPage(agency: agence)),
        );
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (cover != null && cover.trim().isNotEmpty)
                CachedNetworkImage(
                  imageUrl: cover,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      Container(color: Colors.grey[200]),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[200],
                    child: Icon(Icons.photo_outlined,
                        size: 44, color: Colors.grey[400]),
                  ),
                )
              else
                Container(
                  color: Colors.grey[200],
                  child: Icon(Icons.photo_outlined,
                      size: 44, color: Colors.grey[400]),
                ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.05),
                      Colors.black.withOpacity(0.88),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withOpacity(0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.attractions_rounded,
                          size: 14, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        sitesCount > 0 ? '$sitesCount site(s)' : 'Tourisme',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: (agence.id != null)
                    ? FavoriteHeartIcon(
                        propertyId: agence.id.toString(),
                        propertyTypeId: 11,
                        size: 26,
                        splashRadius: 22,
                      )
                    : const SizedBox.shrink(),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      agence.name ?? 'Agence',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if ((agence.address ?? '').trim().isNotEmpty)
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded,
                              size: 14, color: Colors.white.withOpacity(0.85)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              agence.address!.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
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
        ),
      ),
    );
  }

  Widget _buildFilterChips(bool isDarkMode) {
    final filterIcons = {
      'Tous': Icons.all_inclusive_rounded,
      'Appartements': FontAwesomeIcons.building,
      'Maisons': FontAwesomeIcons.house,
      'Studios': FontAwesomeIcons.buildingCircleCheck,
      'Bureaux': FontAwesomeIcons.buildingColumns,
      'Terrains': Icons.landscape_rounded,
      'Vacances': Icons.beach_access_rounded,
      'Salles de fête': Icons.celebration_rounded,
      'Funéraires': Icons.church_rounded,
      'Hôtels': Icons.hotel_rounded,
    };

    return Container(
      height: 66,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, __) => SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _selectedFilter == filter;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedFilter = filter;
                _applyFilters();
              });
            },
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? _primaryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? _primaryColor : Colors.grey[300]!,
                  width: 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: _primaryColor.withOpacity(0.3),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        )
                      ]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    filterIcons[filter],
                    size: 16,
                    color: isSelected ? Colors.white : Colors.black54,
                  ),
                  SizedBox(width: 6),
                  Text(
                    filter,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMinimalSyncIndicator() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: EdgeInsets.all(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
            ),
          ),
          SizedBox(width: 8),
          Text(
            'Chargement...',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadMore(PropertyController propertyCtrl) async {
    if (_isLoadingMore) return;

    final totalLoaded = _filteredProperties.length;

    // 1. Buffer local first
    if (_visibleCount < totalLoaded) {
      setState(() => _isLoadingMore = true);
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        setState(() {
          _visibleCount = (_visibleCount + _pageSize).clamp(0, totalLoaded);
          _isLoadingMore = false;
        });
        _refreshController.loadComplete();
      }
      return;
    }

    // 2. API Fetch next page
    if (propertyCtrl.hasMoreData) {
      setState(() => _isLoadingMore = true);

      final searchTerm = _searchController.text.trim();
      if (searchTerm.isNotEmpty) {
        await propertyCtrl.searchProperties(searchTerm, isLoadMore: true);
      } else {
        await propertyCtrl.filterProperties(
          sold: !widget.isForRent,
          isLoadMore: true,
          sortBy: 'id',
          sortOrder: 'desc',
        );
      }

      if (mounted) {
        setState(() {
          // Utiliser propertyCtrl.allProperties comme nouvelle base pour AllPropertiesPage
          _filteredProperties = propertyCtrl.allProperties.where((p) {
            final tt = p.transactionType?.toLowerCase() ?? '';
            final need = widget.isForRent ? 'location' : 'vente';
            return tt.contains(need);
          }).toList();

          _applyFilters(); // Re-appliquer les filtres de recherche/chips sur la nouvelle liste unifiée
          final target = _visibleCount + _pageSize;
          _visibleCount = target.clamp(0, _filteredProperties.length);
          _isLoadingMore = false;
        });
        _refreshController.loadComplete();
      }
    } else {
      _refreshController.loadNoData();
    }
  }

  Future<void> _handlePullToRefresh(PropertyController propertyCtrl) async {
    // Sauvegarder le filtre actuel avant le refresh
    final currentFilter = _selectedFilter;
    print(
        "🔄 [AllPropertiesPage] Début du refresh - Filtre actuel: $currentFilter");

    try {
      await propertyCtrl.refreshProperties();

      // Si le filtre est "Tous", récupérer toutes les propriétés du type de transaction
      if (currentFilter == 'Tous') {
        final newProperties = propertyCtrl.allProperties
            .where((p) =>
                p.listingAllowed &&
                (p.transactionType
                        ?.toLowerCase()
                        .contains(widget.isForRent ? 'location' : 'vente') ??
                    false))
            .toList();

        setState(() {
          _filteredProperties = newProperties;
          _sortMostRecentFirst(_filteredProperties);
        });
      } else {
        // Sinon, réappliquer le filtre actuel
        setState(() {
          _applyFilters();
        });
      }

      _refreshController.refreshCompleted();
      // Pas de snackbar de succès comme demandé par l'utilisateur
    } catch (e) {
      print("❌ Erreur refresh: $e");
      _refreshController.refreshFailed();
      SnackbarForCasa.error(context, "Erreur de connexion");
    }
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        widget.title ??
            (widget.isForRent ? 'Locations disponibles' : 'Biens à vendre'),
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 20,
          letterSpacing: 0.5,
          color: Colors.white,
        ),
      ),
      centerTitle: true,
      elevation: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_primaryColor, Color(0xFF64B5F6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            _isGridView ? Icons.list_rounded : Icons.grid_view_rounded,
            color: Colors.white,
          ),
          onPressed: () {
            setState(() {
              _isGridView = !_isGridView;
            });
          },
          tooltip: _isGridView ? 'Vue en liste' : 'Vue en grille',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildSearchBar(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: SizedBox(
        height: 50,
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Rechercher une propriété...',
            hintStyle: TextStyle(color: _greyColor),
            prefixIcon: Icon(Icons.search, color: _primaryColor),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: _greyColor),
                    onPressed: () {
                      _searchController.clear();
                      _applyFilters();
                    },
                  )
                : null,
            filled: true,
            fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          ),
          style: TextStyle(
            fontSize: 16,
            color: isDarkMode ? Colors.white : _darkColor,
          ),
          onChanged: (value) => _applyFilters(),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.home_work_outlined,
            size: 72,
            color: _primaryColor.withOpacity(0.3),
          ),
          const SizedBox(height: 24),
          Text(
            'Aucun résultat trouvé',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : _darkColor,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Ajustez vos filtres pour trouver plus de résultats.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: isDarkMode ? Colors.grey[400] : _greyColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyList(bool isDarkMode) {
    final visibleItems = _filteredProperties.take(_visibleCount).toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: visibleItems.length,
      itemBuilder: (context, index) {
        return _buildPropertyListItem(visibleItems[index], isDarkMode);
      },
    );
  }

  Widget _buildPropertyGrid(bool isDarkMode) {
    final visibleItems = _filteredProperties.take(_visibleCount).toList();

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: visibleItems.length,
      itemBuilder: (context, index) {
        return _buildPropertyCard(visibleItems[index], isDarkMode);
      },
    );
  }

  Widget _buildShimmerGridItem() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
        ),
      ),
    );
  }

  // Carte en mode liste - Design moderne avec superposition améliorée
  Widget _buildPropertyListItem(PropertyModel property, bool isDarkMode) {
    final typeName =
        (property.propertyType?.name ?? '').toString().toLowerCase();
    final isHotel = typeName.contains('hotel') ||
        typeName.contains('hôtel') ||
        property.propertyTypeId == 5;

    final isForRent = widget.isForRent;
    // Hôtels: ne pas afficher le prix ici (demande UX).
    final priceText = isHotel
        ? null
        : (isForRent
            ? '${property.price?.toStringAsFixed(0) ?? '0'} ${property.currency}/mois'
            : '${property.price?.toStringAsFixed(0) ?? '0'} ${property.currency}');

    // Utilisation des vraies images du modèle
    final firstImage = property.propertyImage?.isNotEmpty ?? false
        ? property.propertyImage!.first
        : null;
    final imageUrl =
        firstImage != null ? "${firstImage.path ?? firstImage.path}" : null;

    String propertyType = _getPropertyTypeFromTitle(property.propertyType?.name,
        propertyTypeId: property.propertyTypeId);

    final String heroTag = 'all-list-${property.propertyId}';

    return InkWell(
      onTap: () => _navigateToDetail(property, heroTag: heroTag),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDarkMode ? Colors.grey[900] : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Image (plein) + overlays
            SizedBox(
              width: 150,
              height: 175,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Hero(
                      tag: heroTag,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                        ),
                        child: imageUrl != null
                            ? CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                placeholder: (context, url) => Container(
                                  color: Colors.grey[200],
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          _primaryColor),
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.grey[200],
                                  child: Icon(Icons.home_rounded,
                                      size: 40, color: Colors.grey[400]),
                                ),
                              )
                            : Container(
                                color: Colors.grey[200],
                                child: Icon(Icons.home_rounded,
                                    size: 40, color: Colors.grey[400]),
                              ),
                      ),
                    ),
                  ),

                  // Gradient overlay pour meilleur contraste
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.1),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Disponible/état en superposition à gauche
                  Positioned(
                    top: 8,
                    left: 8,
                    child: PropertyListingStatusChip(
                      sold: property.sold,
                      transactionType: property.transactionType,
                      available: property.available,
                      listingAllowed: property.listingAllowed,
                      onDarkBackground: true,
                      compact: true,
                    ),
                  ),

                  // Bouton favoris en haut à droite
                  if (property.propertyId != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: FavoriteHeartIcon(
                          propertyId: property.propertyId.toString(),
                          propertyTypeId: property.propertyTypeId,
                          size: 16,
                          splashRadius: 16,
                          activeColor: Colors.red,
                          inactiveColor: _greyColor,
                        ),
                      ),
                    ),

                  // Prix en bas - Design amélioré avec gradient
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: (priceText == null)
                        ? const SizedBox.shrink()
                        : Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(12),
                                bottomRight: Radius.circular(12),
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.8),
                                ],
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.45),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          propertyType,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Spacer(),
                                    ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(maxWidth: 92),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: widget.isForRent
                                              ? Colors.blue[500]
                                              : Colors.green[500],
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          widget.isForRent
                                              ? 'LOCATION'
                                              : 'VENTE',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  priceText,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),

            // Section détails
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(
                    top: 12, left: 12, right: 12, bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Titre avec gestion du overflow
                    Container(
                      constraints: BoxConstraints(maxHeight: 40),
                      child: Text(
                        property.title ?? 'Sans titre',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: isDarkMode ? Colors.white : _darkColor,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    SizedBox(height: 6),

                    // Localisation avec gestion du overflow
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 14, color: _primaryColor),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _locationText(
                                property.communeValue, property.cityValue),
                            style: TextStyle(
                              color: _greyColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 12),

                    // Caractéristiques
                    Builder(
                      builder: (context) {
                        final typeId = property.propertyTypeId ??
                            property.propertyType?.propertyTypeId;
                        final typeName =
                            property.propertyType?.name?.toLowerCase() ?? '';
                        final isTerrain =
                            typeId == 9 || typeName.contains('terrain');
                        final isHotel = typeId == 5 ||
                            typeName.contains('hotel') ||
                            typeName.contains('hôtel');
                        final isTourisme = typeId == 6 ||
                            typeName.contains('vacance') ||
                            typeName.contains('tourisme');
                        final isBureau = typeId == 4 ||
                            typeName.contains('bureau') ||
                            typeName.contains('office');
                        final isFestive = typeId == 8 ||
                            typeName.contains('fete') ||
                            typeName.contains('fête');
                        final isFuneraire = typeId == 7 ||
                            typeName.contains('funeraire') ||
                            typeName.contains('funéra') ||
                            typeName.contains('funera');

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            if (isTerrain) ...[
                              if ((property.surface ?? 0) > 0)
                                _buildFeatureItem(
                                  icon: FontAwesomeIcons.rulerCombined,
                                  value:
                                      '${property.surface?.toStringAsFixed(0) ?? '0'}',
                                  label: 'm²',
                                ),
                            ] else if (isHotel) ...[
                              _buildFeatureItem(
                                icon: Icons.hotel_rounded,
                                value: '—',
                                label: 'Hôtel',
                              ),
                            ] else if (isTourisme) ...[
                              _buildFeatureItem(
                                icon: Icons.attractions_rounded,
                                value: '—',
                                label: 'Tourisme',
                              ),
                            ] else if (!isBureau &&
                                !isFuneraire &&
                                !isFestive) ...[
                              if ((property.bedrooms ?? 0) > 0)
                                _buildFeatureItem(
                                  icon: FontAwesomeIcons.bed,
                                  value: '${property.bedrooms ?? 0}',
                                  label: 'Chambres',
                                ),
                              if ((property.bathroom ?? 0) > 0)
                                _buildFeatureItem(
                                  icon: FontAwesomeIcons.bath,
                                  value: '${property.bathroom ?? 0}',
                                  label: 'SDB',
                                ),
                            ] else ...[
                              if (isBureau) ...[
                                if ((property.roomMeet ?? 0) > 0)
                                  _buildFeatureItem(
                                    icon: Icons.meeting_room_outlined,
                                    value: '${property.roomMeet ?? 0}',
                                    label: 'Réunions',
                                  ),
                                _buildFeatureItem(
                                  icon: property.isEquip == true
                                      ? Icons.chair
                                      : Icons.chair_outlined,
                                  value:
                                      property.isEquip == true ? 'Oui' : 'Non',
                                  label: 'Meublé',
                                ),
                              ],
                              if (isFuneraire || isFestive) ...[
                                if ((property.capacityPeople ?? 0) > 0)
                                  _buildFeatureItem(
                                    icon: Icons.people_outline,
                                    value: '${property.capacityPeople ?? 0}',
                                    label: 'Pers.',
                                  ),
                              ],
                            ],
                            // Surface: pas pour hôtels / tourisme, oui pour le reste (sauf terrain déjà affiché).
                            if (!isTerrain &&
                                !isHotel &&
                                !isTourisme &&
                                (property.surface ?? 0) > 0)
                              _buildFeatureItem(
                                icon: FontAwesomeIcons.rulerCombined,
                                value:
                                    '${property.surface?.toStringAsFixed(0) ?? '0'}',
                                label: 'm²',
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Carte en mode grille - Design moderne avec superposition améliorée
  Widget _buildPropertyCard(PropertyModel property, bool isDarkMode) {
    final typeName = property.propertyType?.name?.toLowerCase() ?? '';
    final isHotel = typeName.contains('hotel') ||
        typeName.contains('hôtel') ||
        property.propertyTypeId == 5;
    final isTerrain =
        typeName.contains('terrain') || property.propertyTypeId == 9;
    final isFestive = typeName.contains('fête') ||
        typeName.contains('fete') ||
        property.propertyTypeId == 8;
    final isFuneraire = typeName.contains('funéra') ||
        typeName.contains('funera') ||
        property.propertyTypeId == 7;
    final isMonthly = widget.isForRent &&
        !isHotel &&
        !isTerrain &&
        !isFestive &&
        !isFuneraire;

    // Hôtels: pas de prix sur la carte (demande UX).
    final priceText = isHotel
        ? null
        : (isMonthly
            ? '${property.price?.toStringAsFixed(0) ?? '0'} ${property.currency}/mois'
            : '${property.price?.toStringAsFixed(0) ?? '0'} ${property.currency}');

    // Utilisation des vraies images du modèle
    final firstImage = property.propertyImage?.isNotEmpty ?? false
        ? property.propertyImage!.first
        : null;
    final imageUrl =
        firstImage != null ? "${firstImage.path ?? firstImage.path}" : null;

    String propertyType = _getPropertyTypeFromTitle(property.propertyType?.name,
        propertyTypeId: property.propertyTypeId);

    final String heroTag = 'all-grid-${property.propertyId}';

    return InkWell(
      onTap: () => _navigateToDetail(property, heroTag: heroTag),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDarkMode ? Colors.grey[900] : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Image avec superposition
            Expanded(
              flex: 6,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Hero(
                      tag: heroTag,
                      child: ClipRRect(
                        // En mode grid: pas de radius en bas gauche/droit sur l'image
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                        child: imageUrl != null
                            ? CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                placeholder: (context, url) => Container(
                                  color: Colors.grey[200],
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          _primaryColor),
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) {
                                  return Container(
                                    color: Colors.grey[200],
                                    child: Icon(Icons.home_rounded,
                                        size: 40, color: Colors.grey[400]),
                                  );
                                },
                              )
                            : Container(
                                color: Colors.grey[200],
                                child: Icon(Icons.home_rounded,
                                    size: 40, color: Colors.grey[400]),
                              ),
                      ),
                    ),

                    // Gradient overlay
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.3),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // (Allégé) Type + statut déplacés dans la barre du bas

                    // Bouton favoris
                    if (property.propertyId != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          child: FavoriteHeartIcon(
                            propertyId: property.propertyId.toString(),
                            propertyTypeId: property.propertyTypeId,
                            size: 16,
                            splashRadius: 16,
                            activeColor: Colors.red,
                            inactiveColor: _greyColor,
                          ),
                        ),
                      ),

                    // Disponible/état en superposition à gauche
                    Positioned(
                      top: 8,
                      left: 8,
                      child: PropertyListingStatusChip(
                        sold: property.sold,
                        transactionType: property.transactionType,
                        available: property.available,
                        listingAllowed: property.listingAllowed,
                        onDarkBackground: true,
                        compact: true,
                      ),
                    ),

                    // Prix en bas - Design amélioré avec gradient
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: (priceText == null)
                          ? const SizedBox.shrink()
                          : Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(12),
                                  bottomRight: Radius.circular(12),
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.8),
                                  ],
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 7, vertical: 4),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.black.withOpacity(0.45),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            propertyType,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      ConstrainedBox(
                                        constraints:
                                            const BoxConstraints(maxWidth: 92),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 7, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: widget.isForRent
                                                ? Colors.blue[500]
                                                : Colors.green[500],
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            widget.isForRent
                                                ? 'LOCATION'
                                                : 'VENTE',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  if (priceText != null)
                                    Text(
                                      priceText,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),

            // Section détails
            Expanded(
              flex: 4,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Titre et localisation avec gestion du overflow
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          constraints: BoxConstraints(maxHeight: 32),
                          child: Text(
                            property.title ?? 'Sans titre',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: isDarkMode ? Colors.white : _darkColor,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined,
                                size: 10, color: _greyColor),
                            SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                _locationText(
                                    property.communeValue, property.cityValue),
                                style: TextStyle(
                                  color: _greyColor,
                                  fontSize: 10,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Caractéristiques
                    Builder(
                      builder: (context) {
                        final typeId = property.propertyTypeId ??
                            property.propertyType?.propertyTypeId;
                        final typeName =
                            property.propertyType?.name?.toLowerCase() ?? '';
                        final isTerrain =
                            typeId == 9 || typeName.contains('terrain');
                        final isHotel = typeId == 5 ||
                            typeName.contains('hotel') ||
                            typeName.contains('hôtel');
                        final isTourisme = typeId == 6 ||
                            typeName.contains('vacance') ||
                            typeName.contains('tourisme');
                        final isBureau = typeId == 4 ||
                            typeName.contains('bureau') ||
                            typeName.contains('office');
                        final isFestive = typeId == 8 ||
                            typeName.contains('fete') ||
                            typeName.contains('fête');
                        final isFuneraire = typeId == 7 ||
                            typeName.contains('funeraire') ||
                            typeName.contains('funéra') ||
                            typeName.contains('funera');

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (isTerrain) ...[
                              if ((property.surface ?? 0) > 0)
                                _buildMiniFeatureItem(
                                    FontAwesomeIcons.rulerCombined,
                                    '${property.surface?.toStringAsFixed(0) ?? '0'}m²'),
                            ] else if (isHotel) ...[
                              _buildMiniFeatureItem(
                                  Icons.hotel_rounded, 'Hôtel'),
                            ] else if (isTourisme) ...[
                              _buildMiniFeatureItem(
                                  Icons.attractions_rounded, 'Tourisme'),
                            ] else if (!isBureau &&
                                !isFuneraire &&
                                !isFestive) ...[
                              if ((property.bedrooms ?? 0) > 0)
                                _buildMiniFeatureItem(FontAwesomeIcons.bed,
                                    '${property.bedrooms ?? 0}'),
                              if ((property.bathroom ?? 0) > 0)
                                _buildMiniFeatureItem(FontAwesomeIcons.bath,
                                    '${property.bathroom ?? 0}'),
                            ] else ...[
                              if (isBureau) ...[
                                if ((property.roomMeet ?? 0) > 0)
                                  _buildMiniFeatureItem(
                                      Icons.meeting_room_outlined,
                                      '${property.roomMeet ?? 0}'),
                                _buildMiniFeatureItem(
                                    property.isEquip == true
                                        ? Icons.chair
                                        : Icons.chair_outlined,
                                    property.isEquip == true ? 'Oui' : 'Non'),
                              ],
                              if (isFuneraire || isFestive) ...[
                                if ((property.capacityPeople ?? 0) > 0)
                                  _buildMiniFeatureItem(Icons.people_outline,
                                      '${property.capacityPeople ?? 0}'),
                              ],
                            ],
                            if (!isTerrain &&
                                !isHotel &&
                                !isTourisme &&
                                (property.surface ?? 0) > 0)
                              _buildMiniFeatureItem(
                                  FontAwesomeIcons.rulerCombined,
                                  '${property.surface?.toStringAsFixed(0) ?? '0'}m²'),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Item de caractéristique pour la vue liste
  Widget _buildFeatureItem(
      {required IconData icon, required String value, required String label}) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 14,
            color: _primaryColor,
          ),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _darkColor,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: _greyColor,
          ),
        ),
      ],
    );
  }

  // Item de caractéristique miniature pour la vue grille
  Widget _buildMiniFeatureItem(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: _primaryColor),
        SizedBox(width: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: _darkColor,
          ),
        ),
      ],
    );
  }

  // Navigation vers la page de détail
  Future<void> _navigateToDetail(PropertyModel property,
      {String? heroTag}) async {
    await navigateToPropertyDetail(context, property, heroTag: heroTag);
  }

  // Méthode pour déterminer le type de propriété depuis le titre
  String _getPropertyTypeFromTitle(String? title, {int? propertyTypeId}) {
    // Priorité aux IDs (plus fiable que le texte)
    if (propertyTypeId == 5) return 'Hôtel';
    if (propertyTypeId == 9) return 'Terrain';
    if (propertyTypeId == 6) return 'Vacances';
    if (propertyTypeId == 4) return 'Bureau';
    if (propertyTypeId == 8) return 'Festif';
    if (propertyTypeId == 7) return 'Funéraire';

    if (title == null) return 'Propriété';

    final lowerTitle = title.toLowerCase();
    if (lowerTitle.contains('appart') || lowerTitle.contains('apart')) {
      return 'Appart';
    } else if (lowerTitle.contains('maison')) {
      return 'Maison';
    } else if (lowerTitle.contains('studio')) {
      return 'Studio';
    } else if (lowerTitle.contains('bureau')) {
      return 'Bureau';
    } else if (lowerTitle.contains('terrain')) {
      return 'Terrain';
    } else if (lowerTitle.contains('hotel')) {
      return 'Hôtel';
    } else if (lowerTitle.contains('vacance') ||
        lowerTitle.contains('tourisme')) {
      return 'Vacances';
    } else if (lowerTitle.contains('penthouse')) {
      return 'Penthouse';
    }
    return 'Propriété';
  }

  bool _matchesTransaction(PropertyModel p) {
    final tt = (p.transactionType ?? '').toLowerCase().trim();
    final isRent =
        tt.contains('location') || tt.contains('rent') || tt.contains('rental');
    final isSale =
        tt.contains('vente') || tt.contains('sale') || tt.contains('sell');

    // Terrains: afficher dans toutes les listes (vente/location) car l’API n’est pas homogène sur transactionType.
    if (p.propertyTypeId == 9) return true;

    if (widget.isForRent) {
      if (isRent) return true;
      // Fallback: hôtels / vacances sont quasi toujours "location", même si tt est absent côté API.
      if (tt.isEmpty &&
          (p.propertyTypeId == 5 ||
              p.propertyTypeId == 6 ||
              p.propertyTypeId == 10 ||
              p.propertyTypeId == 11)) {
        return true;
      }
      return false;
    }

    // Vente
    if (isSale) return true;
    return false;
  }

  void _sortMostRecentFirst(List<PropertyModel> list) {
    // API: pas de createdAt exposé ici => fallback stable par id décroissant.
    list.sort((a, b) {
      final ai = a.propertyId ?? 0;
      final bi = b.propertyId ?? 0;
      return bi.compareTo(ai);
    });
  }

  void _applyFilters() {
    final propertyCtrl =
        Provider.of<PropertyController>(context, listen: false);

    // Base de données : Toutes les propriétés unifiées filtrées par type de transaction (Vente/Location)
    final unified = propertyCtrl.allProperties;
    final baseProperties =
        (unified.isNotEmpty ? unified : widget.initialProperties).where((p) {
      return _matchesTransaction(p);
    }).toList();

    setState(() {
      _filteredProperties = baseProperties.where((property) {
        final searchText = _searchController.text.toLowerCase();
        final matchesSearch = searchText.isEmpty ||
            (property.title?.toLowerCase().contains(searchText) ?? false) ||
            (property.description?.toLowerCase().contains(searchText) ??
                false) ||
            (property.address?.toLowerCase().contains(searchText) ?? false) ||
            (property.quartier?.toLowerCase().contains(searchText) ?? false);

        final matchesCategory = _selectedFilter == 'Tous' ||
            _matchesCategory(property, _selectedFilter);

        return matchesSearch && matchesCategory;
      }).toList();

      _sortMostRecentFirst(_filteredProperties);

      // Important pour l'infinity scroll: on repart d'une "page" quand on change de filtre/recherche.
      _visibleCount = _pageSize.clamp(0, _filteredProperties.length);
    });
  }

  bool _matchesCategory(PropertyModel property, String category) {
    final propertyTypeName = property.propertyType?.name?.toLowerCase() ?? '';
    final propertyTypeId =
        property.propertyTypeId ?? property.propertyType?.propertyTypeId;

    switch (category) {
      case 'Appartements':
        return propertyTypeName.contains('appart') ||
            propertyTypeName.contains('apart');
      case 'Maisons':
        return propertyTypeName.contains('maison') ||
            propertyTypeName.contains('house');
      case 'Studios':
        return propertyTypeName.contains('studio');
      case 'Bureaux':
        return propertyTypeName.contains('bureau') ||
            propertyTypeName.contains('office') ||
            propertyTypeId == 4;
      case 'Terrains':
        return propertyTypeName.contains('terrain') || propertyTypeId == 9;
      case 'Vacances':
        return propertyTypeName.contains('vacance') ||
            propertyTypeName.contains('tourisme') ||
            propertyTypeId == 6 ||
            propertyTypeId == 10 ||
            propertyTypeId == 11;
      case 'Salles de fête':
        return propertyTypeName.contains('fête') ||
            propertyTypeName.contains('fete') ||
            propertyTypeId == 8;
      case 'Funéraires':
        return propertyTypeName.contains('funéraire') ||
            propertyTypeName.contains('funeraire') ||
            propertyTypeId == 7;
      case 'Hôtels':
        return propertyTypeName.contains('hôtel') ||
            propertyTypeName.contains('hotel') ||
            propertyTypeId == 5;
      default:
        return true;
    }
  }

  @override
  void dispose() {
    final ctrl = _propertyCtrl;
    final l = _propertyCtrlListener;
    if (ctrl != null && l != null) {
      ctrl.removeListener(l);
    }
    _searchController.dispose();
    _refreshController.dispose();
    super.dispose();
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:casa/controllers/PropertyCtrl.dart';
import 'package:casa/models/TerrainModel.dart';
import 'package:casa/screens/TerrainDetailPage.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:shimmer/shimmer.dart';

import '../utils/FancyNotification.dart';

class TerrainPropertiesPage extends StatefulWidget {
  const TerrainPropertiesPage({Key? key}) : super(key: key);

  @override
  _TerrainPropertiesPageState createState() => _TerrainPropertiesPageState();
}

class _TerrainPropertiesPageState extends State<TerrainPropertiesPage> {
  final Color _primaryColor = Color(0xFF1976D2);
  final Color _secondaryColor = Color(0xFF64B5F6);
  final Color _darkColor = Color(0xFF1A1D26);
  final Color _lightColor = Color(0xFFF5F6FA);
  final Color _greyColor = Color(0xFF7F8C8D);

  bool _isGridView = false;
  String _selectedFilter = 'Tous';
  final List<String> _filters = ['Tous', 'Location', 'Vente', 'Nouveautés'];
  final RefreshController _refreshController = RefreshController();

  @override
  Widget build(BuildContext context) {
    final propertyCtrl = context.watch<PropertyController>();
    final terrains = propertyCtrl.terrains;
    
    final filteredTerrains = _applyFilter(terrains, _selectedFilter);

    return Scaffold(
      backgroundColor: _lightColor,
      appBar: _buildAppBar(),
      body: SmartRefresher(
        controller: _refreshController,
        enablePullDown: true,
        enablePullUp: false,
        header: WaterDropMaterialHeader(
          backgroundColor: _primaryColor,
          color: Colors.white,
        ),
        onRefresh: () async {
          await _handlePullToRefresh(propertyCtrl);
        },
        child: Column(
          children: [
            _buildFilterChips(),

            if (propertyCtrl.syncing)
              _buildMinimalSyncIndicator(),

            Expanded(
              child: propertyCtrl.loading
                  ? _buildShimmerLoading()
                  : filteredTerrains.isEmpty
                  ? _buildEmptyState()
                  : _buildTerrainListOrGrid(filteredTerrains),
            ),
          ],
        ),
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

  Future<void> _handlePullToRefresh(PropertyController propertyCtrl) async {
    try {
      await propertyCtrl.syncAllSpecialCategories();
      _refreshController.refreshCompleted();
    } catch (e) {
      print("❌ Erreur refresh terrains: $e");
      _refreshController.refreshFailed();
      SnackbarForCasa.error(context, "Erreur de connexion");
    }
  }

  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> terrains, String filter) {
    switch (filter) {
      case 'Location':
        return terrains.where((t) {
          final terrain = t['terrain'] as Map<String, dynamic>?;
          return terrain?['transactionType']?.toString().toLowerCase().contains('location') ?? false;
        }).toList();
      case 'Vente':
        return terrains.where((t) {
          final terrain = t['terrain'] as Map<String, dynamic>?;
          return terrain?['transactionType']?.toString().toLowerCase().contains('vente') ?? false;
        }).toList();
      case 'Nouveautés':
        return terrains..sort((a, b) {
          final aId = (a['terrain'] as Map<String, dynamic>?)?['id'] ?? 0;
          final bId = (b['terrain'] as Map<String, dynamic>?)?['id'] ?? 0;
          return (bId as int).compareTo(aId as int);
        });
      default:
        return terrains;
    }
  }

  PreferredSizeWidget _buildAppBar() {
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
        children: [
          Icon(FontAwesomeIcons.mountain, size: 20, color: Colors.white),
          SizedBox(width: 10),
          Text(
            'Terrains',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
        ],
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
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    final filterIcons = {
      'Tous': Icons.all_inclusive_rounded,
      'Location': Icons.apartment_rounded,
      'Vente': Icons.sell_rounded,
      'Nouveautés': Icons.fiber_new_rounded,
    };

    return Container(
      height: 66,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
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
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: _primaryColor.withOpacity(0.3),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  )
                ] : [],
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

  Widget _buildTerrainListOrGrid(List<Map<String, dynamic>> terrains) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: _isGridView
          ? GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
              itemCount: terrains.length,
              itemBuilder: (context, index) {
                return _buildTerrainCard(terrains[index]);
              },
            )
          : ListView.builder(
              itemCount: terrains.length,
              itemBuilder: (context, index) {
                return _buildTerrainListItem(terrains[index]);
              },
            ),
    );
  }

  Widget _buildTerrainListItem(Map<String, dynamic> terrainData) {
    final terrain = terrainData['terrain'] as Map<String, dynamic>?;
    final devise = terrainData['devise'] as Map<String, dynamic>?;
    final address = terrainData['address'] as Map<String, dynamic>?;
    final images = terrainData['images'] as List<dynamic>?;

    final title = terrain?['title'] ?? 'Terrain';
    final price = terrain?['price'] ?? 0.0;
    final surface = terrain?['surface'] ?? '';
    final transactionType = terrain?['transactionType'] ?? '';
    final rawDeviseCode = devise?['code'] ?? 'USD';
    final deviseCode = (rawDeviseCode == 'USD') ? '\$' : (rawDeviseCode == 'CDF' ? 'FC' : rawDeviseCode);
    final location = "${address?['cityValue']}, ${address?['communeValue']}";
    
    final firstImage = images?.isNotEmpty == true ? images!.first['path'] : null;

    return InkWell(
      onTap: () {
        final model = TerrainModel.fromJson(terrainData);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TerrainDetailPage(terrain: model),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 200,
        margin: EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Section
            Container(
              width: 140,
              height: 175,
              margin: EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: firstImage != null
                    ? CachedNetworkImage(
                        imageUrl: firstImage,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[200],
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[200],
                          child: Icon(FontAwesomeIcons.mountain, size: 40, color: Colors.grey[400]),
                        ),
                      )
                    : Container(
                        color: Colors.grey[200],
                        child: Icon(FontAwesomeIcons.mountain, size: 40, color: Colors.grey[400]),
                      ),
              ),
            ),

            // Content Section
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 12, right: 12, bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Transaction Type Badge
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: transactionType.toLowerCase().contains('vente')
                            ? Colors.green.withOpacity(0.1)
                            : Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        transactionType.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: transactionType.toLowerCase().contains('vente')
                              ? Colors.green[700]
                              : Colors.blue[700],
                        ),
                      ),
                    ),
                    SizedBox(height: 8),

                    // Title
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: _darkColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8),

                    // Location
                    if (location.isNotEmpty)
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 14, color: _greyColor),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              style: TextStyle(color: _greyColor, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    SizedBox(height: 8),

                    // Surface
                    if (surface.isNotEmpty)
                      Row(
                        children: [
                          Icon(Icons.square_foot, size: 14, color: _greyColor),
                          SizedBox(width: 4),
                          Text(
                            '$surface m²',
                            style: TextStyle(color: _greyColor, fontSize: 12),
                          ),
                        ],
                      ),
                    Spacer(),

                    // Price
                    Text(
                      '${price.toStringAsFixed(0)} $deviseCode',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
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

  Widget _buildTerrainCard(Map<String, dynamic> terrainData) {
    final terrain = terrainData['terrain'] as Map<String, dynamic>?;
    final devise = terrainData['devise'] as Map<String, dynamic>?;
    final address = terrainData['address'] as Map<String, dynamic>?;
    final images = terrainData['images'] as List<dynamic>?;

    final title = terrain?['title'] ?? 'Terrain';
    final price = terrain?['price'] ?? 0.0;
    final surface = terrain?['surface'] ?? '';
    final transactionType = terrain?['transactionType'] ?? '';
    final rawDeviseCode = devise?['code'] ?? 'USD';
    final deviseCode = (rawDeviseCode == 'USD') ? '\$' : (rawDeviseCode == 'CDF' ? 'FC' : rawDeviseCode);
    final location = "${address?['cityValue']}, ${address?['communeValue']}";
    
    final firstImage = images?.isNotEmpty == true ? images!.first['path'] : null;

    return InkWell(
      onTap: () {
        final model = TerrainModel.fromJson(terrainData);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TerrainDetailPage(terrain: model),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    child: firstImage != null
                        ? CachedNetworkImage(
                            imageUrl: firstImage,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[200],
                              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[200],
                              child: Icon(FontAwesomeIcons.mountain, size: 30, color: Colors.grey[400]),
                            ),
                          )
                        : Container(
                            color: Colors.grey[200],
                            child: Center(
                              child: Icon(FontAwesomeIcons.mountain, size: 30, color: Colors.grey[400]),
                            ),
                          ),
                  ),
                  // Transaction Type Badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        transactionType.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _primaryColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: _darkColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (surface.isNotEmpty) ...[
                          SizedBox(height: 4),
                          Text(
                            '$surface m²',
                            style: TextStyle(
                              fontSize: 12,
                              color: _greyColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '${price.toStringAsFixed(0)} $deviseCode',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(FontAwesomeIcons.mountain, size: 64, color: Colors.grey[300]),
          SizedBox(height: 16),
          Text(
            'Aucun terrain disponible',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Revenez plus tard',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          margin: EdgeInsets.only(bottom: 16),
          child: Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              height: 175,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        );
      },
    );
  }
}

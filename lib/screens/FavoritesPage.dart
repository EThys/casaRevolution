import 'package:cached_network_image/cached_network_image.dart';
import 'package:casa/controllers/PropertyFavoriteCtrl.dart';
import 'package:casa/controllers/provider/FavoriteProvider.dart';
import 'package:casa/models/PropertyFavoriteModel.dart';
import 'package:casa/models/PropertyModel.dart';
import 'package:casa/utils/Constantes.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/StockageKeys.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../utils/Routes.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({Key? key}) : super(key: key);

  @override
  _FavoritesPageState createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final DateFormat _dateFormat = DateFormat('EEEE d MMMM y', 'fr_FR');
  final GetStorage storage = GetStorage();

  // Couleurs
  final Color _primaryColor = Color(0xFF1976D2);
  final Color _darkColor = Color(0xFF1A1D26);
  final Color _lightGrey = Color(0xFFF5F6FA);
  final Color _mediumGrey = Color(0xFF7F8C8D);
  final Color _successColor = Color(0xFF00B894);
  final Color _errorColor = Color(0xFFD63031);
  final Color _cardBackground = Colors.white;

  bool _isLoading = false;
  String? _errorMessage;
  List<int> _deletingIds = [];



  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFavorites();
    });
  }

  Future<void> _loadFavorites() async {
    final tkn = storage.read<String>(StockageKeys.tokenKey);

    if (tkn == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'connect';
      });
      return;
    }


    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userId = storage.read(StockageKeys.userKey)?['UserId'];
      if (userId != null) {
        final propertyCtrl = Provider.of<PropertyFavoriteCtrl>(context, listen: false);
        await propertyCtrl.getFavoritesByUser(userId.toString());

        print("TESTTTTTTTTTTTTTT${userId}");
        print("TESTTTTTTTTTTTTTT${propertyCtrl.propertyFavorites}");
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors du chargement des favoris';
      });
      print("Erreur lors du chargement des favoris: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _removeFavorite(int? propertyId) async {
    if (propertyId == null) return;

    setState(() {
      _deletingIds.add(propertyId);
    });

    try {
      final userId = storage.read(StockageKeys.userKey)?['UserId']?.toString();
      if (userId != null) {
        final propertyCtrl = Provider.of<PropertyFavoriteCtrl>(context, listen: false);
        final success = await propertyCtrl.removeFavorite(userId, propertyId.toString());

        if (success) {
          // Synchroniser l'état avec le provider
          final favoriteProvider = Provider.of<FavoriteProvider>(context, listen: false);
          await favoriteProvider.syncFavorites(userId);

          // Attendre que l'animation se termine
          await Future.delayed(Duration(milliseconds: 300));
          FancyNotification.show(context, "Supprimé des favoris", isError: false);
        }
      }
    } catch (e) {
      FancyNotification.show(context, "Échec de la suppression");
      print("Erreur lors de la suppression: $e");
    } finally {
      if (mounted) {
        setState(() {
          _deletingIds.remove(propertyId);
        });
      }
    }
  }

  void _showPropertyDetails(PropertyFavoriteModel property) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildPropertyDetails(property),
    );
  }

  Widget _buildPropertyDetails(PropertyFavoriteModel property) {
    final propertyData = property.property;
    final isForRent = propertyData?.transactionType == 'location';
    final firstImagePath = propertyData?.images != null && propertyData!.images!.isNotEmpty
        ? propertyData.images!.first.path
        : null;

    final priceText = isForRent
        ? '${propertyData?.price?.toStringAsFixed(0) ?? '0'}\$/mois'
        : '${propertyData?.price?.toStringAsFixed(0) ?? '0'}\$';

    final isAvailable = propertyData?.isAvailable ?? false;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          padding: EdgeInsets.all(24),
          child: SingleChildScrollView(
            controller: controller,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'Détails du bien',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _darkColor,
                  ),
                ),
                SizedBox(height: 20),
                GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      Routes.detailPageRoute,
                      arguments: propertyData,
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: firstImagePath != null
                        ? CachedNetworkImage(
                      imageUrl: "${Constantes.URL_IMAGES}$firstImagePath",
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _primaryColor,
                        ),
                      ),
                      errorWidget: (context, url, error) => Center(
                        child: Icon(Icons.home, size: 50, color: _mediumGrey),
                      ),
                    )
                        : Center(
                      child: Icon(Icons.home, size: 50, color: _mediumGrey),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  propertyData?.title ?? 'Propriété sans titre',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: _darkColor,
                  ),
                ),
                SizedBox(height: 5),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 16, color: _mediumGrey),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        propertyData?.address ?? 'Adresse non disponible',
                        style: TextStyle(
                          color: _mediumGrey,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Divider(height: 1, color: Colors.grey[200]),
                SizedBox(height: 15),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.monetization_on_outlined,
                        size: 20,
                        color: _primaryColor,
                      ),
                    ),
                    SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Prix',
                          style: TextStyle(
                            color: _mediumGrey,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '${priceText}',
                          style: TextStyle(
                            color: _darkColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isAvailable
                            ? _successColor.withOpacity(0.1)
                            : _errorColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isAvailable ? 'Disponible' : 'Indisponible',
                        style: TextStyle(
                          color: isAvailable ? _successColor : _errorColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 15),
                Divider(height: 1, color: Colors.grey[200]),
                SizedBox(height: 15),
                Text(
                  'Caractéristiques',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _darkColor,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  _buildFeaturesText(propertyData),
                  style: TextStyle(
                    color: _darkColor.withOpacity(0.8),
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 25),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          if (property.propertyId != null) {
                            _removeFavorite(property.propertyId!);
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _errorColor,
                          side: BorderSide(color: _errorColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          'SUPPRIMER DES FAVORIS',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),

                  ],
                ),
                SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }



  String _buildFeaturesText(PropertyModel? property) {
    if (property == null) return 'Aucune information disponible';

    List<String> features = [];
    if (property.bedrooms != null) features.add('${property.bedrooms} chambres');
    if (property.floor != null) features.add('${property.floor}m²');
    if (property.floor != null) features.add('Étage ${property.floor}');

    return features.join(' · ');
  }

  Widget _buildPlaceholderImage() {
    return Container(
      height: 180,
      color: _lightGrey,
      child: Center(
        child: Icon(Icons.home, size: 50, color: _mediumGrey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final propertyCtrl = Provider.of<PropertyFavoriteCtrl>(context);

    return Scaffold(
      backgroundColor: _lightGrey,
      appBar: _buildFavoritesAppBar(),
      body: _buildFavoritesList(propertyCtrl),
    );
  }

  PreferredSizeWidget _buildFavoritesAppBar() {
    return AppBar(
      elevation: 2,
      backgroundColor: _primaryColor,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite_rounded, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Text(
            'Mes Favoris',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),textAlign: TextAlign.left,
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.search_rounded, color: Colors.white),
          onPressed: () {
            // Action de recherche
          },
        ),
      ],

      bottom: PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Container(
          height: 1,
          color: Colors.white.withOpacity(0.2),
        ),
      ),
    );
  }


  Widget _buildShimmerLoading() {
    return ListView.separated(
      padding: EdgeInsets.all(20),
      itemCount: 5,
      separatorBuilder: (_, __) => SizedBox(height: 20),
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 180,
                  width: double.infinity,
                  color: Colors.white,
                ),
                Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 20,
                        color: Colors.white,
                      ),
                      SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        height: 16,
                        color: Colors.white,
                      ),
                      SizedBox(height: 15),
                      Row(
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            color: Colors.white,
                          ),
                          SizedBox(width: 8),
                          Container(
                            width: 120,
                            height: 14,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotConnectedView() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 70, color: _primaryColor),
            SizedBox(height: 20),
            Text(
              'Connexion requise',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _darkColor,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Veuillez vous connecter pour accéder à vos favoris.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _mediumGrey,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: _errorColor, size: 60),
            SizedBox(height: 20),
            Text(
              'Oups ! Une erreur est survenue',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _darkColor,
              ),
            ),
            SizedBox(height: 10),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: _mediumGrey),
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadFavorites,
              icon: Icon(Icons.refresh),
              label: Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyFavoritesView() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border_outlined, size: 70, color: _primaryColor),
            SizedBox(height: 20),
            Text(
              'Aucun favori pour l’instant',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _darkColor,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Ajoutez des propriétés à vos favoris pour les retrouver facilement.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _mediumGrey,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 30),
            // ElevatedButton.icon(
            //   onPressed: () {
            //    Navigator.pushNamed(context, Routes.homeRoute);
            //   },
            //   icon: Icon(Icons.explore,color: Colors.white,),
            //   label: Text('Explorer',style: TextStyle(color: Colors.white),),
            //   style: ElevatedButton.styleFrom(
            //     backgroundColor: _primaryColor,
            //     padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            //     shape: RoundedRectangleBorder(
            //       borderRadius: BorderRadius.circular(12),
            //     ),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }



  Widget _buildFavoritesList(PropertyFavoriteCtrl propertyCtrl) {
    if (_isLoading && propertyCtrl.propertyFavorites.isEmpty) {
      return _buildShimmerLoading();
    }

    if (_errorMessage == 'connect') {
      return _buildNotConnectedView();
    }

    if (_errorMessage != null) {
      return _buildErrorView();
    }

    if (propertyCtrl.propertyFavorites.isEmpty) {
      return _buildEmptyFavoritesView();
    }


    if (propertyCtrl.propertyFavorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border_outlined,
              size: 60,
              color: _mediumGrey.withOpacity(0.3),
            ),
            SizedBox(height: 20),
            Text(
              'Aucun favori',
              style: TextStyle(
                color: _mediumGrey,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 10),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Ajoutez des propriétés à vos favoris pour les retrouver facilement',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _mediumGrey.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Action pour explorer les propriétés
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 14),
              ),
              child: Text(
                'Explorer les propriétés',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _primaryColor,
      backgroundColor: Colors.white,
      onRefresh: _loadFavorites,
      child: ListView.builder(
        padding: EdgeInsets.all(20),
        itemCount: propertyCtrl.propertyFavorites.length,
        itemBuilder: (context, index) {
          final property = propertyCtrl.propertyFavorites[index];
          final isDeleting = _deletingIds.contains(property.property?.PropertyId);

          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(-1, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: AlwaysStoppedAnimation(1.0), // Fixe l'animation
              curve: Curves.easeOut,
            )),
            child: Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: _buildFavoriteCard(property, isDeleting: isDeleting),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFavoriteCard(PropertyFavoriteModel property, {bool isDeleting = false}) {
    final propertyData = property.property;
    final isForRent = propertyData?.transactionType == "location";
    final isAvailable = propertyData?.isAvailable ?? false;
    final firstImagePath = propertyData?.images?.isNotEmpty == true
        ? propertyData?.images!.first.path
        : null;

    final priceText = isForRent
        ? '${propertyData?.price?.toStringAsFixed(0) ?? '0'}\$/mois'
        : '${propertyData?.price?.toStringAsFixed(0) ?? '0'}\$';

    // if (propertyData == null) {
    //   return SizedBox.shrink(); // Ou retournez un widget vide
    // }


    return Dismissible(
      key: Key(propertyData?.PropertyId?.toString() ?? UniqueKey().toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: _errorColor.withOpacity(0.1),
        ),
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20),
        child: Icon(Icons.delete, color: _errorColor, size: 30),
      ),
      confirmDismiss: (direction) async {
        if (propertyData?.PropertyId != null) {
          await _removeFavorite(propertyData!.PropertyId);
          return false; // Nous gérons la suppression nous-mêmes
        }
        return false;
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        transform: Matrix4.translationValues(
            isDeleting ? 50 : 0,
            0,
            0
        ),
        child: Opacity(
          opacity: isDeleting ? 0.6 : 1.0,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _showPropertyDetails(property),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: _cardBackground,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    spreadRadius: 1,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        child: firstImagePath != null
                            ? CachedNetworkImage(
                          imageUrl: "${Constantes.URL_IMAGES}$firstImagePath",
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 180,
                          placeholder: (context, url) => Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _primaryColor,
                            ),
                          ),
                          errorWidget: (context, url, error) => _buildPlaceholderImage(),
                        )
                            : _buildPlaceholderImage(),
                      ),
                      Positioned(
                        top: 15,
                        right: 15,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Text(
                            priceText,
                            style: TextStyle(
                              color: _primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      if (!isAvailable)
                        Positioned(
                          bottom: 15,
                          left: 15,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _errorColor.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'INDISPONIBLE',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      if (isDeleting)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: Colors.black.withOpacity(0.3),
                            ),
                            child: Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          propertyData?.title ?? 'Propriété sans titre',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: _darkColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 16,
                              color: _mediumGrey,
                            ),
                            SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                propertyData?.address ?? 'Adresse non disponible',
                                style: TextStyle(
                                  color: _mediumGrey,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 15),
                        Row(
                          children: [
                            Icon(
                              Icons.favorite,
                              size: 18,
                              color: _primaryColor,
                            ),
                            SizedBox(width: 8),
                            Text(
                              // 'Ajouté le ${_dateFormat.format(property.createdAt ?? DateTime.now())}'
                              'Ajouté ${_dateFormat.format(DateTime.now())}',
                              style: TextStyle(
                                color: _mediumGrey,
                                fontSize: 13,
                              ),
                            ),
                            Spacer(),
                            if (isDeleting)
                              Padding(
                                padding: EdgeInsets.all(8),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _errorColor,
                                  ),
                                ),
                              )
                            else
                              IconButton(
                                icon: Icon(Icons.delete_outline, color: _errorColor),
                                onPressed: () {
                                  if (propertyData?.PropertyId != null) {
                                    _removeFavorite(propertyData!.PropertyId);
                                  }
                                },
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
        ),
      ),
    );
  }

}
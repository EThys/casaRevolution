import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/Routes.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/provider/FavoriteProvider.dart';
import '../controllers/AuthentificationCtrl.dart';

class FavoriteHeartIcon extends StatefulWidget {
  final String propertyId;
  final int? propertyTypeId;
  final bool isPrestation;
  final double size;
  final Color? activeColor;
  final Color? inactiveColor;
  final double splashRadius;
  final Function(bool isLiked)? onLikeChanged;

  const FavoriteHeartIcon({
    super.key,
    required this.propertyId,
    this.propertyTypeId,
    this.isPrestation = false,
    this.size = 48,
    this.activeColor = Colors.red,
    this.inactiveColor = Colors.grey,
    this.splashRadius = 30, 
    this.onLikeChanged,
  });

  @override
  State<FavoriteHeartIcon> createState() => _FavoriteHeartIconState();
}

class _FavoriteHeartIconState extends State<FavoriteHeartIcon> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Consumer2<FavoriteProvider, AuthentificationCtrl>(
      builder: (context, provider, authCtrl, child) {
        final key = FavoriteProvider.generateKey(widget.propertyId, typeId: widget.propertyTypeId, isPrestation: widget.isPrestation);
        final isLoggedIn = authCtrl.token.isNotEmpty;
        final isFavorite = isLoggedIn
            ? provider.state.favoriteStatus[key] ?? false
            : false;
        // Vérifier seulement si CETTE propriété spécifique est en chargement
        final isLoadingThisProperty = provider.state.loadingProperties.contains(key) || _isProcessing;

        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              iconSize: widget.size,
              splashRadius: widget.splashRadius,
              padding: EdgeInsets.zero,
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(
                    scale: animation,
                    child: FadeTransition(
                      opacity: animation,
                      child: child,
                    ),
                  );
                },
                child: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        key: ValueKey('${widget.propertyId}-${isFavorite}'),
                        color: isFavorite
                            ? widget.activeColor
                            : widget.inactiveColor,
                        size: widget.size,
                        shadows: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 3,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
              ),
              onPressed: isLoadingThisProperty
                  ? null // Prevent double-tap while processing
                  : () async {
                if (!isLoggedIn) {
                  Navigator.pushNamed(context, Routes.loginRoute);
                  return;
                }

                // Feedback haptique (vibration légère)
                try {
                  // HapticFeedback.lightImpact(); // Décommentez si vous avez le package
                } catch (e) {}

                setState(() => _isProcessing = true);
                try {
                  final userId = authCtrl.user.userId?.toString();
                  if (userId == null || userId.isEmpty) {
                    throw Exception("ID utilisateur invalide");
                  }

                  await provider.toggleFavorite(
                    userId: userId,
                    propertyId: widget.propertyId,
                    propertyTypeId: widget.propertyTypeId,
                    isPrestation: widget.isPrestation,
                  );
                  
                  // Callback après succès
                  if (widget.onLikeChanged != null) {
                    final newStatus = provider.state.isFavorite(widget.propertyId);
                    widget.onLikeChanged!(newStatus);
                  }
                } catch (e) {
                  // Erreur silencieuse ou snackbar discret si vraiment nécessaire
                  // Mais le provider gère le rollback si c'est une erreur critique (pas offline)
                  print("Erreur favorite icon: $e"); 
                } finally {
                  if (mounted) {
                    setState(() => _isProcessing = false);
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }
}
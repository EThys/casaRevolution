import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/Routes.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/provider/FavoriteProvider.dart';
import '../controllers/AuthentificationCtrl.dart';

class FavoriteHeartIcon extends StatefulWidget {
  final String propertyId;
  final double size;
  final Color? activeColor;
  final Color? inactiveColor;
  final double splashRadius;

  const FavoriteHeartIcon({
    super.key,
    required this.propertyId,
    this.size = 48, // Taille augmentée (32 → 48)
    this.activeColor = Colors.red,
    this.inactiveColor = Colors.grey,
    this.splashRadius = 30, // Zone de splash augmentée pour correspondre
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
        final isLoggedIn = authCtrl.token.isNotEmpty;
        final isFavorite = isLoggedIn
            ? provider.state.isFavorite(widget.propertyId)
            : false;
        // Vérifier seulement si CETTE propriété spécifique est en chargement
        final isLoadingThisProperty = provider.state.isLoadingProperty(widget.propertyId) || _isProcessing;

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
                child: isLoadingThisProperty
                    ? SizedBox(
                        key: ValueKey('loading-${widget.propertyId}'),
                        width: widget.size * 0.6,
                        height: widget.size * 0.6,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            widget.activeColor ?? Colors.red,
                          ),
                        ),
                      )
                    : Icon(
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
                  ? null
                  : () async {
                if (!isLoggedIn) {
                  FancyNotification.show(
                    context,
                    "Vous devez avoir un compte et être connecté pour ajouter aux favoris",
                    onTap: () {
                      Navigator.pushNamed(context, Routes.loginRoute);
                    },
                  );
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
                  );
                } catch (e) {
                  FancyNotification.show(
                    context,
                    'Erreur: ${e.toString().replaceAll("Null check", "Veuillez vous connecter")}',
                    isError: true,
                  );
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
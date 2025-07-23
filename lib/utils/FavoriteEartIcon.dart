import 'package:casa/utils/FancyNotification.dart';
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

        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              iconSize: widget.size,
              splashRadius: widget.splashRadius,
              padding: EdgeInsets.zero,
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(
                    scale: animation,
                    child: child,
                  );
                },
                child: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  key: ValueKey<bool>(isFavorite),
                  color: isFavorite
                      ? widget.activeColor
                      : widget.inactiveColor,
                  size: widget.size,
                  shadows: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 2,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              onPressed: _isProcessing
                  ? null
                  : () async {
                if (!isLoggedIn) {
                  FancyNotification.show(
                    context,
                    "Vous devez être connecté pour ajouter aux favoris",
                  );
                  return;
                }

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
                  );
                } finally {
                  if (mounted) {
                    setState(() => _isProcessing = false);
                  }
                }
              },
            ),
            if (_isProcessing)
              Positioned(
                child: Container(
                  width: widget.size * 0.5,
                  height: widget.size * 0.5,
                  padding: EdgeInsets.all(widget.size * 0.1),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    shape: BoxShape.circle,
                  ),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      widget.activeColor ?? Colors.red,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
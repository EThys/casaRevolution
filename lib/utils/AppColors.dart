import 'package:flutter/material.dart';

/// Helper class pour gérer les couleurs de l'application de manière adaptative
/// Utilise le thème actuel pour s'adapter automatiquement au mode sombre
class AppColors {
  // Couleurs primaires (toujours les mêmes)
  static const Color primaryBlue = Color(0xFF1976D2);
  static const Color secondaryBlue = Color(0xFF64B5F6);
  static const Color darkBlue = Color(0xFF0D47A1);
  static const Color lightBlue = Color(0xFFE3F2FD);

  // Couleurs fonctionnelles
  static const Color successColor = Color(0xFF4CAF50);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color errorColor = Color(0xFFF44336);
  static const Color infoColor = Color(0xFF2196F3);

  /// Retourne la couleur de fond adaptative selon le thème
  static Color backgroundColor(BuildContext context) {
    return Theme.of(context).scaffoldBackgroundColor;
  }

  /// Retourne la couleur de surface (cartes, conteneurs) adaptative
  static Color surfaceColor(BuildContext context) {
    return Theme.of(context).cardColor;
  }

  /// Retourne la couleur de texte principale adaptative
  static Color textColor(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface;
  }

  /// Retourne la couleur de texte secondaire adaptative
  static Color secondaryTextColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? Colors.white70
        : Colors.black87;
  }

  /// Retourne la couleur de texte tertiaire adaptative
  static Color tertiaryTextColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? Colors.white54
        : Colors.black54;
  }

  /// Retourne la couleur de bordure adaptative
  static Color borderColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? Colors.white24
        : Colors.black12;
  }

  /// Retourne la couleur de bordure légère adaptative
  static Color lightBorderColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? Colors.white12
        : Colors.black.withOpacity(0.05);
  }

  /// Retourne la couleur d'ombre adaptative
  static Color shadowColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? Colors.black.withOpacity(0.5)
        : Colors.black.withOpacity(0.1);
  }

  /// Retourne la couleur de fond de carte adaptative
  static Color cardBackgroundColor(BuildContext context) {
    return Theme.of(context).cardColor;
  }

  /// Retourne la couleur de fond de champ de texte adaptative
  static Color inputBackgroundColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? const Color(0xFF1E1E1E)
        : Colors.white;
  }

  /// Retourne la couleur de division/divider adaptative
  static Color dividerColor(BuildContext context) {
    return Theme.of(context).dividerColor;
  }

  /// Retourne la couleur d'icône adaptative
  static Color iconColor(BuildContext context) {
    return Theme.of(context).iconTheme.color ?? Theme.of(context).colorScheme.onSurface;
  }

  /// Retourne la couleur d'icône secondaire adaptative
  static Color secondaryIconColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? Colors.white70
        : Colors.black54;
  }

  /// Retourne si le thème est sombre
  static bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }
}





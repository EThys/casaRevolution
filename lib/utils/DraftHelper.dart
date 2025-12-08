import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DraftHelper {
  // Supprimer les brouillons expirés (plus d'un jour)
  static Future<void> clearExpiredDrafts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftData = prefs.getString('property_draft');

      if (draftData != null) {
        final draft = jsonDecode(draftData) as Map<String, dynamic>;
        final createdAt = draft['createdAt'] as int?;

        if (createdAt != null) {
          final draftDate = DateTime.fromMillisecondsSinceEpoch(createdAt);
          final now = DateTime.now();
          final difference = now.difference(draftDate);

          // Si le brouillon a plus d'un jour, le supprimer
          if (difference.inDays >= 1) {
            print('🗑️ Suppression du brouillon expiré (${difference.inDays} jours)');
            await prefs.remove('property_draft');
          } else {
            print('✅ Brouillon valide (${difference.inHours} heures)');
          }
        } else {
          // Si pas de timestamp, supprimer le brouillon (ancien format)
          print('🗑️ Suppression du brouillon sans timestamp (ancien format)');
          await prefs.remove('property_draft');
        }
      }
    } catch (e) {
      print('❌ Erreur lors de la suppression des brouillons expirés: $e');
    }
  }

  // Vérifier si un brouillon existe et est valide
  static Future<bool> hasValidDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftData = prefs.getString('property_draft');

      if (draftData != null) {
        final draft = jsonDecode(draftData) as Map<String, dynamic>;
        final createdAt = draft['createdAt'] as int?;

        if (createdAt != null) {
          final draftDate = DateTime.fromMillisecondsSinceEpoch(createdAt);
          final now = DateTime.now();
          final difference = now.difference(draftDate);

          // Le brouillon est valide s'il a moins d'un jour
          return difference.inDays < 1;
        }
      }
      return false;
    } catch (e) {
      print('❌ Erreur lors de la vérification du brouillon: $e');
      return false;
    }
  }

  // Supprimer TOUS les brouillons (utilisé lors de la déconnexion)
  static Future<void> clearAllDrafts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasDraft = prefs.containsKey('property_draft');
      
      if (hasDraft) {
        await prefs.remove('property_draft');
        await prefs.remove('draft_created_at');
        print('🗑️ Tous les brouillons supprimés lors de la déconnexion');
      }
    } catch (e) {
      print('❌ Erreur lors de la suppression de tous les brouillons: $e');
    }
  }
}


import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

class ProfileImageCache {
  static const _cacheDir = 'profile_images';

  // Singleton
  ProfileImageCache._privateConstructor();
  static final ProfileImageCache instance = ProfileImageCache._privateConstructor();

  // Obtenir le répertoire de cache
  Future<Directory> get _getCacheDirectory async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory(path.join(appDir.path, _cacheDir));
    
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    
    return cacheDir;
  }

  // Générer un nom de fichier unique basé sur l'URL
  String _getFileNameFromUrl(String url) {
    // Utiliser un hash de l'URL pour créer un nom de fichier unique
    final uri = Uri.parse(url);
    final fileName = uri.pathSegments.last;
    return fileName.isNotEmpty ? fileName : 'profile_${url.hashCode}.jpg';
  }

  // Télécharger et cacher une image de profil
  Future<File?> cacheProfileImage(String imageUrl, String userId) async {
    try {
      print("📥 Téléchargement image profil: $imageUrl");
      
      final response = await http.get(Uri.parse(imageUrl));
      
      if (response.statusCode == 200) {
        final cacheDir = await _getCacheDirectory;
        final fileName = 'profile_$userId.jpg';
        final file = File(path.join(cacheDir.path, fileName));
        
        await file.writeAsBytes(response.bodyBytes);
        print("✅ Image profil cachée: ${file.path}");
        
        return file;
      } else {
        print("❌ Erreur téléchargement image: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("❌ Erreur cache image profil: $e");
      return null;
    }
  }

  // Récupérer l'image de profil depuis le cache
  Future<File?> getCachedProfileImage(String userId) async {
    try {
      final cacheDir = await _getCacheDirectory;
      final fileName = 'profile_$userId.jpg';
      final file = File(path.join(cacheDir.path, fileName));
      
      if (await file.exists()) {
        print("✅ Image profil trouvée en cache: ${file.path}");
        return file;
      } else {
        print("⚠️ Image profil non trouvée en cache pour user: $userId");
        return null;
      }
    } catch (e) {
      print("❌ Erreur récupération cache image: $e");
      return null;
    }
  }

  // Vérifier si une image est en cache
  Future<bool> hasCachedImage(String userId) async {
    final file = await getCachedProfileImage(userId);
    return file != null;
  }

  // Supprimer l'image de profil du cache
  Future<bool> deleteCachedImage(String userId) async {
    try {
      final cacheDir = await _getCacheDirectory;
      final fileName = 'profile_$userId.jpg';
      final file = File(path.join(cacheDir.path, fileName));
      
      if (await file.exists()) {
        await file.delete();
        print("🗑️ Image profil supprimée du cache");
        return true;
      }
      return false;
    } catch (e) {
      print("❌ Erreur suppression cache image: $e");
      return false;
    }
  }

  // Vider tout le cache d'images
  Future<void> clearAllCache() async {
    try {
      final cacheDir = await _getCacheDirectory;
      
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        print("🗑️ Cache images profil vidé");
      }
    } catch (e) {
      print("❌ Erreur vidage cache: $e");
    }
  }

  // Obtenir la taille du cache
  Future<int> getCacheSize() async {
    try {
      final cacheDir = await _getCacheDirectory;
      int totalSize = 0;
      
      if (await cacheDir.exists()) {
        await for (var entity in cacheDir.list(recursive: true)) {
          if (entity is File) {
            totalSize += await entity.length();
          }
        }
      }
      
      return totalSize;
    } catch (e) {
      print("❌ Erreur calcul taille cache: $e");
      return 0;
    }
  }

  // Obtenir le chemin de l'image en cache (pour utilisation directe)
  Future<String?> getCachedImagePath(String userId) async {
    final file = await getCachedProfileImage(userId);
    return file?.path;
  }
}

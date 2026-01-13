import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/PropertyFavoriteModel.dart';

class FavoriteDatabaseHelper {
  static const _databaseName = "favorites.db";
  static const _databaseVersion = 1;
  static const table = 'favorites';

  static const columnId = 'id';
  static const columnUserId = 'userId';
  static const columnData = 'data';

  // Singleton
  FavoriteDatabaseHelper._privateConstructor();
  static final FavoriteDatabaseHelper instance = FavoriteDatabaseHelper._privateConstructor();

  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  // NOUVELLE TABLE POUR LA FILE D'ATTENTE
  static const tableQueue = 'favorite_queue';
  static const columnAction = 'action'; // 'ADD' or 'REMOVE'
  static const columnTimestamp = 'timestamp';

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $table (
        $columnId INTEGER PRIMARY KEY,
        $columnUserId INTEGER NOT NULL,
        $columnData TEXT NOT NULL,
        UNIQUE($columnId, $columnUserId)
      )
    ''');
    await db.execute('''
      CREATE INDEX idx_favorite_user ON $table ($columnUserId)
    ''');
    
    // Création de la table de file d'attente
    await db.execute('''
      CREATE TABLE $tableQueue (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnUserId INTEGER NOT NULL,
        propertyId TEXT NOT NULL,
        $columnAction TEXT NOT NULL,
        $columnTimestamp INTEGER NOT NULL
      )
    ''');
  }

  // MÉTHODES POUR LA FILE D'ATTENTE (QUEUE)
  
  Future<int> enqueueAction(String userId, String propertyId, String action) async {
    final db = await database;
    return await db.insert(
      tableQueue,
      {
        columnUserId: int.tryParse(userId) ?? 0,
        'propertyId': propertyId,
        columnAction: action,
        columnTimestamp: DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getQueue(String userId) async {
    final db = await database;
    return await db.query(
      tableQueue,
      where: '$columnUserId = ?',
      whereArgs: [userId],
      orderBy: '$columnTimestamp ASC',
    );
  }

  Future<int> removeFromQueue(int id) async {
    final db = await database;
    return await db.delete(
      tableQueue,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }
  
  Future<int> clearQueue(String userId) async {
    final db = await database;
    return await db.delete(
      tableQueue,
      where: '$columnUserId = ?',
      whereArgs: [userId],
    );
  }

  Future<int> clearAllFavorites() async {
    final db = await database;
    return await db.delete(table);
  }

// Méthode pour vider complètement la base de données
  Future<void> clearDatabase() async {
    final db = await database;
    await db.delete(table);
    await db.delete(tableQueue); // Vidage de la queue aussi
  }


  Future<int> insertOrUpdateFavorite(PropertyFavoriteModel favorite, String userId) async {
    final db = await database;

    // Utiliser le userId passé en paramètre au lieu de favorite.userId
    final int userIdInt = int.tryParse(userId) ?? 0;
    if (userIdInt == 0) {
      print('❌ ERROR: Invalid userId: $userId');
      // On ne lance pas d'exception pour éviter de crasher l'app en prod, juste log
      return 0; 
    }

    // Convertir le property en JSON pour le stocker
    final propertyJson = favorite.property?.toJson() ?? {};

    return await db.insert(
      table,
      {
        columnId: favorite.propertyFavoriteId,
        columnUserId: userIdInt, // ← Utiliser le userId passé en paramètre
        columnData: jsonEncode(propertyJson),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PropertyFavoriteModel>> getFavoritesByUser(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      table,
      where: '$columnUserId = ?',
      whereArgs: [userId],
    );

    return List.generate(maps.length, (i) {
      return PropertyFavoriteModel.fromJson(jsonDecode(maps[i][columnData]));
    });
  }

  Future<int> deleteFavorite(int userId, String propertyId) async {
    final db = await database;
    return await db.delete(
      table,
      where: '$columnUserId = ? AND $columnData LIKE ?',
      whereArgs: [userId, '%"PropertyId":"$propertyId"%'],
    );
  }

  // NOUVELLE MÉTHODE : Supprimer un favori par userId et propertyId
  Future<int> removeFavorite(String userId, String propertyId) async {
    final db = await database;

    // Méthode 1 : Recherche par propertyId dans les données JSON
    final favorites = await getFavoritesByUser(userId);
    for (var favorite in favorites) {
      if (favorite.property?.propertyId.toString() == propertyId) {
        return await db.delete(
          table,
          where: '$columnId = ? AND $columnUserId = ?',
          whereArgs: [favorite.propertyFavoriteId, userId],
        );
      }
    }

    // Méthode alternative si la première ne fonctionne pas
    return await db.delete(
      table,
      where: '$columnUserId = ? AND $columnData LIKE ?',
      whereArgs: [userId, '%"propertyId":$propertyId%'],
    );
  }

  // Méthode alternative plus directe
  Future<int> removeFavoriteDirect(int favoriteId, String userId) async {
    final db = await database;
    return await db.delete(
      table,
      where: '$columnId = ? AND $columnUserId = ?',
      whereArgs: [favoriteId, userId],
    );
  }

  Future<int> clearUserFavorites(String userId) async {
    final db = await database;
    return await db.delete(
      table,
      where: '$columnUserId = ?',
      whereArgs: [userId],
    );
  }

  // Méthode utilitaire pour trouver un favori par propertyId
  Future<PropertyFavoriteModel?> findFavoriteByPropertyId(String userId, String propertyId) async {
    final favorites = await getFavoritesByUser(userId);
    for (var favorite in favorites) {
      if (favorite.property?.propertyId.toString() == propertyId) {
        return favorite;
      }
    }
    return null;
  }
}
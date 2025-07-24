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
  }

  Future<int> insertOrUpdateFavorite(PropertyFavoriteModel favorite, String userId) async {
    final db = await database;

    // Convertir le property en JSON pour le stocker
    final propertyJson = favorite.property?.toJson() ?? {};

    return await db.insert(
      table,
      {
        columnId: favorite.propertyFavoriteId,
        columnUserId: favorite.userId,
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


  Future<int> clearUserFavorites(String userId) async {
    final db = await database;
    return await db.delete(
      table,
      where: '$columnUserId = ?',
      whereArgs: [userId],
    );
  }
}
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/PropertyModel.dart';

class PropertyDatabaseHelper {
  static const _databaseName = "user_properties.db";
  static const _databaseVersion = 1;
  static const table = 'user_properties';

  static const columnId = 'id';
  static const columnUserId = 'userId';
  static const columnData = 'data';
  static const columnTitle = 'title';
  static const columnPrice = 'price';
  static const columnCreatedAt = 'createdAt';

  // Singleton
  PropertyDatabaseHelper._privateConstructor();
  static final PropertyDatabaseHelper instance = PropertyDatabaseHelper._privateConstructor();

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
        $columnId TEXT PRIMARY KEY,
        $columnUserId TEXT NOT NULL,
        $columnData TEXT NOT NULL,
        $columnTitle TEXT,
        $columnPrice REAL,
        $columnCreatedAt TEXT
      )
    ''');

    // Index pour améliorer les performances
    await db.execute('''
      CREATE INDEX idx_user_property ON $table ($columnUserId)
    ''');
  }

  // Insérer ou mettre à jour une propriété
  Future<int> insertOrUpdateProperty(PropertyModel property, String userId) async {
    final db = await database;
    return await db.insert(
      table,
      {
        columnId: property.propertyId?.toString(),
        columnUserId: userId,
        columnData: propertyToJsonString(property),
        columnTitle: property.title ?? '',
        columnPrice: property.price ?? 0.0,
        columnCreatedAt: property.createdAt ?? '',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Insérer ou mettre à jour plusieurs propriétés
  Future<void> insertOrUpdateProperties(List<PropertyModel> properties, String userId) async {
    final db = await database;
    final batch = db.batch();

    for (final property in properties) {
      batch.insert(
        table,
        {
          columnId: property.propertyId?.toString(),
          columnUserId: userId,
          columnData: propertyToJsonString(property),
          columnTitle: property.title ?? '',
          columnPrice: property.price ?? 0.0,
          columnCreatedAt: property.createdAt ?? '',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  // Récupérer toutes les propriétés d'un utilisateur
  Future<List<PropertyModel>> getMyProperties(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      table,
      where: '$columnUserId = ?',
      whereArgs: [userId],
      orderBy: '$columnCreatedAt DESC',
    );

    return List.generate(maps.length, (i) {
      return propertyFromJsonString(maps[i][columnData]);
    });
  }

  // Récupérer une propriété spécifique
  Future<PropertyModel?> getPropertyById(String propertyId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      table,
      where: '$columnId = ?',
      whereArgs: [propertyId],
    );

    if (maps.isNotEmpty) {
      return propertyFromJsonString(maps.first[columnData]);
    }
    return null;
  }

  // Supprimer toutes les propriétés d'un utilisateur
  Future<int> clearMyProperties(String userId) async {
    final db = await database;
    return await db.delete(
      table,
      where: '$columnUserId = ?',
      whereArgs: [userId],
    );
  }

  // Supprimer une propriété spécifique
  Future<int> deleteProperty(String propertyId) async {
    final db = await database;
    return await db.delete(
      table,
      where: '$columnId = ?',
      whereArgs: [propertyId],
    );
  }

  // Compter le nombre de propriétés
  Future<int> getPropertyCount(String userId) async {
    final db = await database;
    final count = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM $table WHERE $columnUserId = ?',
      [userId],
    ));
    return count ?? 0;
  }

  // Vérifier si une propriété existe
  Future<bool> propertyExists(String propertyId) async {
    final db = await database;
    final count = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM $table WHERE $columnId = ?',
      [propertyId],
    ));
    return (count ?? 0) > 0;
  }

  // Méthodes utilitaires pour la conversion JSON
  String propertyToJsonString(PropertyModel property) {
    return json.encode(property.toJson());
  }

  PropertyModel propertyFromJsonString(String jsonString) {
    return PropertyModel.fromJson(json.decode(jsonString));
  }

  // Vider complètement la base de données
  Future<void> clearDatabase() async {
    final db = await database;
    await db.delete(table);
  }
}

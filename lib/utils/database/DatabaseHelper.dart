import 'package:casa/models/PropertyModel.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';

class DatabaseHelper {
  static const _databaseName = "properties.db";
  static const _databaseVersion = 1;
  static const table = 'properties';

  static const columnId = 'id';
  static const columnData = 'data'; // Stockage JSON sérialisé

  // Singleton
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

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
        $columnData TEXT NOT NULL
      )
    ''');
  }

  Future<int> insertOrUpdateProperty(PropertyModel property) async {
    final db = await database;
    return await db.insert(
      table,
      {
        columnId: property.propertyId,
        columnData: json.encode(property.toJson()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PropertyModel>> getAllProperties() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(table);

    return maps.map((map) {
      final jsonData = json.decode(map[columnData]);
      return PropertyModel.fromJson(jsonData);
    }).toList();
  }

  Future<PropertyModel?> getPropertyById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      table,
      where: '$columnId = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      final jsonData = json.decode(maps.first[columnData]);
      return PropertyModel.fromJson(jsonData);
    }
    return null;
  }

  Future<int> deleteProperty(int id) async {
    final db = await database;
    return await db.delete(
      table,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  Future<int> clearProperties() async {
    final db = await database;
    return await db.delete(table);
  }

  // Méthode pour insérer plusieurs propriétés en une seule transaction
  Future<void> insertMultipleProperties(List<PropertyModel> properties) async {
    final db = await database;
    final batch = db.batch();

    for (final property in properties) {
      batch.insert(
        table,
        {
          columnId: property.propertyId,
          columnData: json.encode(property.toJson()),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit();
  }

  // Méthode pour vérifier si une propriété existe
  Future<bool> propertyExists(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      table,
      where: '$columnId = ?',
      whereArgs: [id],
      limit: 1,
    );
    return maps.isNotEmpty;
  }

  // Méthode pour compter le nombre de propriétés
  Future<int> getPropertiesCount() async {
    final db = await database;
    final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $table')
    );
    return count ?? 0;
  }
}
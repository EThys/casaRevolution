import 'package:casa/models/PropertyModel.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';

class DatabaseHelper {
  static const _databaseName = "properties.db";
  static const _databaseVersion = 2;
  static const table = 'properties';
  static const propertyTypesTable = 'property_types';
  static const featuresTable = 'features';

  static const columnId = 'id';
  static const columnData = 'data'; // Stockage JSON sérialisé
  
  // Property Types columns
  static const columnPropertyTypeId = 'propertyTypeId';
  static const columnName = 'name';
  static const columnDescription = 'description';
  static const columnUpdatedAt = 'updated_at';
  
  // Features columns
  static const columnFeatureId = 'featureId';

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
      onUpgrade: _onUpgrade,
    );
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add property_types table
      await db.execute('''
        CREATE TABLE $propertyTypesTable (
          $columnPropertyTypeId INTEGER PRIMARY KEY,
          $columnName TEXT NOT NULL,
          $columnDescription TEXT,
          $columnUpdatedAt INTEGER NOT NULL
        )
      ''');
      
      // Add features table
      await db.execute('''
        CREATE TABLE $featuresTable (
          $columnFeatureId INTEGER PRIMARY KEY,
          $columnName TEXT NOT NULL,
          $columnUpdatedAt INTEGER NOT NULL
        )
      ''');
    }
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $table (
        $columnId INTEGER PRIMARY KEY,
        $columnData TEXT NOT NULL
      )
    ''');
    
    await db.execute('''
      CREATE TABLE $propertyTypesTable (
        $columnPropertyTypeId INTEGER PRIMARY KEY,
        $columnName TEXT NOT NULL,
        $columnDescription TEXT,
        $columnUpdatedAt INTEGER NOT NULL
      )
    ''');
    
    await db.execute('''
      CREATE TABLE $featuresTable (
        $columnFeatureId INTEGER PRIMARY KEY,
        $columnName TEXT NOT NULL,
        $columnUpdatedAt INTEGER NOT NULL
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

  // ========== Property Types Methods ==========
  
  /// Insert or update multiple property types
  Future<void> insertPropertyTypes(List<Map<String, dynamic>> types) async {
    final db = await database;
    final batch = db.batch();
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    for (final type in types) {
      batch.insert(
        propertyTypesTable,
        {
          columnPropertyTypeId: type['propertyTypeId'],
          columnName: type['name'],
          columnDescription: type['description'],
          columnUpdatedAt: timestamp,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// Get all property types
  Future<List<Map<String, dynamic>>> getAllPropertyTypes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      propertyTypesTable,
      orderBy: '$columnPropertyTypeId ASC',
    );
    
    return maps.map((map) => {
      'propertyTypeId': map[columnPropertyTypeId],
      'name': map[columnName],
      'description': map[columnDescription],
    }).toList();
  }

  /// Clear all property types
  Future<int> clearPropertyTypes() async {
    final db = await database;
    return await db.delete(propertyTypesTable);
  }

  /// Get property types count
  Future<int> getPropertyTypesCount() async {
    final db = await database;
    final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $propertyTypesTable')
    );
    return count ?? 0;
  }

  // ========== Features Methods ==========
  
  /// Insert or update multiple features
  Future<void> insertFeatures(List<Map<String, dynamic>> features) async {
    final db = await database;
    final batch = db.batch();
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    for (final feature in features) {
      batch.insert(
        featuresTable,
        {
          columnFeatureId: feature['featureId'],
          columnName: feature['name'],
          columnUpdatedAt: timestamp,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// Get all features
  Future<List<Map<String, dynamic>>> getAllFeatures() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      featuresTable,
      orderBy: '$columnFeatureId ASC',
    );
    
    return maps.map((map) => {
      'featureId': map[columnFeatureId],
      'name': map[columnName],
    }).toList();
  }

  /// Clear all features
  Future<int> clearFeatures() async {
    final db = await database;
    return await db.delete(featuresTable);
  }

  /// Get features count
  Future<int> getFeaturesCount() async {
    final db = await database;
    final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $featuresTable')
    );
    return count ?? 0;
  }
}
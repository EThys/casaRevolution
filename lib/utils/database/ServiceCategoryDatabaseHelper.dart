import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class ServiceCategoryDatabaseHelper {
  static const _databaseName = "service_categories.db";
  static const _databaseVersion = 1;
  static const table = 'service_categories';

  static const columnId = 'id';
  static const columnAccountId = 'accountId';
  static const columnAccountName = 'accountName';
  static const columnData = 'data'; // Stockage JSON sérialisé de la catégorie complète
  static const columnUpdatedAt = 'updated_at';

  // Singleton
  ServiceCategoryDatabaseHelper._privateConstructor();
  static final ServiceCategoryDatabaseHelper instance = ServiceCategoryDatabaseHelper._privateConstructor();

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

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $table (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnAccountId INTEGER NOT NULL UNIQUE,
        $columnAccountName TEXT NOT NULL UNIQUE,
        $columnData TEXT NOT NULL,
        $columnUpdatedAt INTEGER NOT NULL
      )
    ''');
    
    await db.execute('''
      CREATE INDEX idx_category_accountId ON $table ($columnAccountId)
    ''');
    
    await db.execute('''
      CREATE INDEX idx_category_accountName ON $table ($columnAccountName)
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 1) {
      await _onCreate(db, newVersion);
    }
  }

  // Insérer ou mettre à jour une catégorie
  Future<int> insertOrUpdateCategory(Map<String, dynamic> category) async {
    final db = await database;
    final accountId = category['accountId'] as int;
    final accountName = category['accountName'] as String;
    
    return await db.insert(
      table,
      {
        columnAccountId: accountId,
        columnAccountName: accountName,
        columnData: json.encode(category),
        columnUpdatedAt: DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Insérer ou mettre à jour plusieurs catégories
  Future<void> insertOrUpdateCategories(List<Map<String, dynamic>> categories) async {
    final db = await database;
    
    // D'abord, vider toutes les catégories existantes pour éviter les doublons
    await db.delete(table);
    
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final category in categories) {
      final accountId = category['accountId'] as int;
      final accountName = category['accountName'] as String;
      
      batch.insert(
        table,
        {
          columnAccountId: accountId,
          columnAccountName: accountName.toLowerCase(), // Normaliser en minuscules
          columnData: json.encode(category),
          columnUpdatedAt: now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit();
  }

  // Récupérer toutes les catégories
  Future<List<Map<String, dynamic>>> getAllCategories() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      table,
      orderBy: '$columnAccountName ASC',
    );

    return maps.map((map) {
      try {
        final jsonData = json.decode(map[columnData] as String);
        return jsonData as Map<String, dynamic>;
      } catch (e) {
        print("❌ [ServiceCategoryDB] Erreur lors du parsing: $e");
        return <String, dynamic>{};
      }
    }).where((c) => c.isNotEmpty).toList();
  }

  // Récupérer une catégorie par accountId
  Future<Map<String, dynamic>?> getCategoryByAccountId(int accountId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      table,
      where: '$columnAccountId = ?',
      whereArgs: [accountId],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      try {
        final jsonData = json.decode(maps.first[columnData] as String);
        return jsonData as Map<String, dynamic>;
      } catch (e) {
        print("❌ [ServiceCategoryDB] Erreur lors du parsing: $e");
        return null;
      }
    }
    return null;
  }

  // Récupérer une catégorie par accountName
  Future<Map<String, dynamic>?> getCategoryByAccountName(String accountName) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      table,
      where: '$columnAccountName = ?',
      whereArgs: [accountName.toLowerCase()],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      try {
        final jsonData = json.decode(maps.first[columnData] as String);
        return jsonData as Map<String, dynamic>;
      } catch (e) {
        print("❌ [ServiceCategoryDB] Erreur lors du parsing: $e");
        return null;
      }
    }
    return null;
  }

  // Supprimer une catégorie
  Future<int> deleteCategory(int accountId) async {
    final db = await database;
    return await db.delete(
      table,
      where: '$columnAccountId = ?',
      whereArgs: [accountId],
    );
  }

  // Vider toutes les catégories
  Future<int> clearAllCategories() async {
    final db = await database;
    return await db.delete(table);
  }

  // Obtenir le timestamp de la dernière mise à jour
  Future<int?> getLastUpdateTime() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      table,
      columns: [columnUpdatedAt],
      orderBy: '$columnUpdatedAt DESC',
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return maps.first[columnUpdatedAt] as int?;
    }
    return null;
  }
}



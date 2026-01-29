import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class AgencyDatabaseHelper {
  static const _databaseName = "user_agency.db";
  static const _databaseVersion = 1;
  static const table = 'user_agency';

  static const columnId = 'id';
  static const columnUserId = 'userId';
  static const columnData = 'data';
  static const columnName = 'name';
  static const columnUpdatedAt = 'updatedAt';

  // Singleton
  AgencyDatabaseHelper._privateConstructor();
  static final AgencyDatabaseHelper instance = AgencyDatabaseHelper._privateConstructor();

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
        $columnName TEXT,
        $columnUpdatedAt TEXT
      )
    ''');

    // Index pour améliorer les performances
    await db.execute('''
      CREATE INDEX idx_user_agency ON $table ($columnUserId)
    ''');
  }

  // Insérer ou mettre à jour l'agence
  Future<int> insertOrUpdateAgency(Map<String, dynamic> agencyData, String userId) async {
    final db = await database;
    return await db.insert(
      table,
      {
        columnId: agencyData['agencyId']?.toString() ?? userId,
        columnUserId: userId,
        columnData: json.encode(agencyData),
        columnName: agencyData['name'] ?? '',
        columnUpdatedAt: DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Récupérer l'agence de l'utilisateur
  Future<Map<String, dynamic>?> getMyAgency(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      table,
      where: '$columnUserId = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return json.decode(maps.first[columnData]);
    }
    return null;
  }

  // Supprimer l'agence de l'utilisateur
  Future<int> clearMyAgency(String userId) async {
    final db = await database;
    return await db.delete(
      table,
      where: '$columnUserId = ?',
      whereArgs: [userId],
    );
  }

  // Vérifier si l'utilisateur a une agence en cache
  Future<bool> hasAgency(String userId) async {
    final db = await database;
    final count = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM $table WHERE $columnUserId = ?',
      [userId],
    ));
    return (count ?? 0) > 0;
  }

  // Vider complètement la base de données
  Future<void> clearDatabase() async {
    final db = await database;
    await db.delete(table);
  }
}

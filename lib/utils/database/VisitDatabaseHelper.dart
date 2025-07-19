import 'package:sqflite/sqflite.dart';
import 'package:sqflite/sqlite_api.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/PropertyVisitModel.dart';


class VisitDatabaseHelper {
  static const _databaseName = "visits.db";
  static const _databaseVersion = 1;
  static const table = 'visits';

  static const columnId = 'id';
  static const columnUserId = 'userId';
  static const columnData = 'data';

  // Singleton
  VisitDatabaseHelper._privateConstructor();
  static final VisitDatabaseHelper instance = VisitDatabaseHelper._privateConstructor();

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
        $columnData TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE INDEX idx_user ON $table ($columnUserId)
    ''');
  }

  Future<int> insertOrUpdateVisit(PropertyVisitModel visit, String userId) async {
    final db = await database;
    return await db.insert(
      table,
      {
        columnId: visit.propertyVisitId,
        columnUserId: userId,
        columnData: visit.toJsonString(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PropertyVisitModel>> getVisitsByUser(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      table,
      where: '$columnUserId = ?',
      whereArgs: [userId],
    );
    return List.generate(maps.length, (i) {
      return PropertyVisitModel.fromJsonString(maps[i][columnData]);
    });
  }

  Future<int> deleteVisit(String id) async {
    final db = await database;
    return await db.delete(
      table,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  Future<int> clearUserVisits(String userId) async {
    final db = await database;
    return await db.delete(
      table,
      where: '$columnUserId = ?',
      whereArgs: [userId],
    );
  }
}
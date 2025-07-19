import 'package:casa/models/PropertyModel.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

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
        $columnId TEXT PRIMARY KEY,
        $columnData TEXT NOT NULL
      )
    ''');
  }

  Future<int> insertOrUpdateProperty(PropertyModel property) async {
    final db = await database;
    return await db.insert(
      table,
      {
        columnId: property.PropertyId,
        columnData: property.toJsonString(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PropertyModel>> getAllProperties() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(table);
    return List.generate(maps.length, (i) {
      return PropertyModel.fromJsonString(maps[i][columnData]);
    });
  }

  Future<int> deleteProperty(String id) async {
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
}
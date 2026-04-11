import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class UserDatabaseHelper {
  static final UserDatabaseHelper instance = UserDatabaseHelper._init();
  static Database? _database;

  UserDatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('user_settings.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
    CREATE TABLE user_settings (
      userId TEXT PRIMARY KEY,
      wasCertified INTEGER DEFAULT 0,
      decertificationReason TEXT
    )
    ''');
  }

  Future<void> saveCertificationStatus(String userId, bool wasCertified, {String? reason}) async {
    final db = await instance.database;
    await db.insert(
      'user_settings',
      {
        'userId': userId,
        'wasCertified': wasCertified ? 1 : 0,
        'decertificationReason': reason,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getUserSettings(String userId) async {
    final db = await instance.database;
    final maps = await db.query(
      'user_settings',
      where: 'userId = ?',
      whereArgs: [userId],
    );

    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  Future<bool> wasUserCertified(String userId) async {
    final settings = await getUserSettings(userId);
    if (settings != null) {
      return settings['wasCertified'] == 1;
    }
    return false;
  }
}

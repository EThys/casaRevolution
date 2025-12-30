import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/PrestationModel.dart';

class PrestationDatabaseHelper {
  static const _databaseName = "prestations.db";
  static const _databaseVersion = 1;
  static const table = 'prestations';

  static const columnId = 'id';
  static const columnServiceId = 'serviceId';
  static const columnData = 'data';
  static const columnUpdatedAt = 'updated_at';

  // Singleton
  PrestationDatabaseHelper._privateConstructor();
  static final PrestationDatabaseHelper instance = PrestationDatabaseHelper._privateConstructor();

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
        $columnServiceId INTEGER NOT NULL,
        $columnData TEXT NOT NULL,
        $columnUpdatedAt INTEGER NOT NULL
      )
    ''');
    
    await db.execute('''
      CREATE INDEX idx_service_id ON $table ($columnServiceId)
    ''');
    
    await db.execute('''
      CREATE INDEX idx_updated_at ON $table ($columnUpdatedAt)
    ''');
  }

  // Insérer ou mettre à jour une prestation
  Future<int> insertOrUpdatePrestation(PrestationModel prestation) async {
    final db = await database;
    return await db.insert(
      table,
      {
        columnId: prestation.id,
        columnServiceId: prestation.serviceId ?? 0,
        columnData: json.encode(prestation.toJson()),
        columnUpdatedAt: DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Insérer ou mettre à jour plusieurs prestations
  Future<void> insertOrUpdatePrestations(List<PrestationModel> prestations) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final prestation in prestations) {
      if (prestation.id != null) {
        batch.insert(
          table,
          {
            columnId: prestation.id,
            columnServiceId: prestation.serviceId ?? 0,
            columnData: json.encode(prestation.toJson()),
            columnUpdatedAt: now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }

    await batch.commit();
  }

  // Récupérer toutes les prestations
  Future<List<PrestationModel>> getAllPrestations() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(table);

    return maps.map((map) {
      try {
        final jsonData = json.decode(map[columnData]);
        return PrestationModel.fromJson(jsonData);
      } catch (e) {
        print("❌ [PrestationDB] Erreur lors du parsing: $e");
        return PrestationModel();
      }
    }).where((p) => p.id != null).toList();
  }

  // Récupérer les prestations par serviceId
  Future<List<PrestationModel>> getPrestationsByServiceId(int serviceId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      table,
      where: '$columnServiceId = ?',
      whereArgs: [serviceId],
      orderBy: '$columnUpdatedAt DESC',
    );

    return maps.map((map) {
      try {
        final jsonData = json.decode(map[columnData]);
        return PrestationModel.fromJson(jsonData);
      } catch (e) {
        print("❌ [PrestationDB] Erreur lors du parsing: $e");
        return PrestationModel();
      }
    }).where((p) => p.id != null).toList();
  }

  // Supprimer une prestation
  Future<int> deletePrestation(int id) async {
    final db = await database;
    return await db.delete(
      table,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  // Vider toutes les prestations
  Future<int> clearAllPrestations() async {
    final db = await database;
    return await db.delete(table);
  }

  // Vider les prestations d'un serviceId spécifique
  Future<int> clearPrestationsByServiceId(int serviceId) async {
    final db = await database;
    return await db.delete(
      table,
      where: '$columnServiceId = ?',
      whereArgs: [serviceId],
    );
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




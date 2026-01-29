import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/PrestationModel.dart';

class ServiceDatabaseHelper {
  static const _databaseName = "user_services.db";
  static const _databaseVersion = 2; // Incremented for schema change
  static const table = 'user_services';

  // Columns matching PrestationModel
  static const columnId = 'id';
  static const columnUserId = 'userId';
  static const columnServiceId = 'serviceId';
  static const columnDeviseId = 'deviseId';
  static const columnTitle = 'title';
  static const columnProfile = 'profile';
  static const columnDescription = 'description';
  static const columnExperience = 'experience';
  static const columnPlageJour = 'plageJourPrestation';
  static const columnPlageHeure = 'plageHeurePrestation';
  static const columnMinPrice = 'minPrice';
  static const columnMaxPrice = 'maxPrice';
  static const columnAddress = 'address';
  static const columnCommuneValue = 'communeValue';
  static const columnQuartierValue = 'quartierValue';
  static const columnCityValue = 'cityValue';
  static const columnCountryValue = 'countryValue';
  static const columnCityId = 'cityId';
  static const columnCommuneId = 'communeId';
  static const columnQuartierId = 'quartierId';
  static const columnIsCertified = 'isCertified';
  static const columnIsActive = 'isActive';
  static const columnDateCreated = 'dateCreated';
  static const columnUsername = 'username';
  static const columnPostBy = 'postBy';
  static const columnImages = 'images';
  static const columnData = 'data'; // Keeping the JSON blob for any extra/nested fields

  // Singleton
  ServiceDatabaseHelper._privateConstructor();
  static final ServiceDatabaseHelper instance = ServiceDatabaseHelper._privateConstructor();

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
        $columnId INTEGER PRIMARY KEY,
        $columnUserId INTEGER,
        $columnServiceId INTEGER,
        $columnDeviseId INTEGER,
        $columnTitle TEXT,
        $columnProfile TEXT,
        $columnDescription TEXT,
        $columnExperience TEXT,
        $columnPlageJour TEXT,
        $columnPlageHeure TEXT,
        $columnMinPrice REAL,
        $columnMaxPrice REAL,
        $columnAddress TEXT,
        $columnCommuneValue TEXT,
        $columnQuartierValue TEXT,
        $columnCityValue TEXT,
        $columnCountryValue TEXT,
        $columnCityId INTEGER,
        $columnCommuneId INTEGER,
        $columnQuartierId INTEGER,
        $columnIsCertified INTEGER,
        $columnIsActive INTEGER,
        $columnDateCreated TEXT,
        $columnUsername TEXT,
        $columnPostBy TEXT,
        $columnImages TEXT,
        $columnData TEXT
      )
    ''');

    await db.execute('CREATE INDEX idx_user_service ON $table ($columnUserId)');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Simplest way to upgrade is to drop and recreate for version 2 since it's a major schema sync
      // and this is a local cache.
      await db.execute("DROP TABLE IF EXISTS $table");
      await _onCreate(db, newVersion);
    }
  }

  // Insérer ou mettre à jour un service
  Future<int> insertOrUpdateService(PrestationModel service, String userId) async {
    final db = await database;
    return await db.insert(
      table,
      _toMap(service, userId),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Insérer ou mettre à jour plusieurs services
  Future<void> insertOrUpdateServices(List<PrestationModel> services, String userId) async {
    final db = await database;
    final batch = db.batch();

    for (final service in services) {
      batch.insert(
        table,
        _toMap(service, userId),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  Map<String, dynamic> _toMap(PrestationModel service, String userId) {
    return {
      columnId: service.id,
      columnUserId: int.tryParse(userId) ?? service.userId,
      columnServiceId: service.serviceId,
      columnDeviseId: service.deviseId,
      columnTitle: service.title,
      columnProfile: service.profile,
      columnDescription: service.description,
      columnExperience: service.experience,
      columnPlageJour: service.plageJourPrestation,
      columnPlageHeure: service.plageHeurePrestation,
      columnMinPrice: service.minPrice,
      columnMaxPrice: service.maxPrice,
      columnAddress: service.address,
      columnCommuneValue: service.communeValue,
      columnQuartierValue: service.quartierValue,
      columnCityValue: service.cityValue,
      columnCountryValue: service.countryValue,
      columnCityId: service.cityId,
      columnCommuneId: service.communeId,
      columnQuartierId: service.quartierId,
      columnIsCertified: service.isCertified == true ? 1 : 0,
      columnIsActive: service.isActive == true ? 1 : 0,
      columnDateCreated: service.dateCreated?.toIso8601String(),
      columnUsername: service.username,
      columnPostBy: service.postBy,
      columnImages: json.encode(service.images),
      columnData: json.encode(service.toJson()),
    };
  }

  // Récupérer tous les services d'un utilisateur
  Future<List<PrestationModel>> getMyServices(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      table,
      where: '$columnUserId = ?',
      whereArgs: [userId],
      orderBy: '$columnDateCreated DESC',
    );

    return List.generate(maps.length, (i) {
      return serviceFromJsonString(maps[i][columnData]);
    });
  }

  // Récupérer un service spécifique
  Future<PrestationModel?> getServiceById(String serviceId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      table,
      where: '$columnId = ?',
      whereArgs: [serviceId],
    );

    if (maps.isNotEmpty) {
      return serviceFromJsonString(maps.first[columnData]);
    }
    return null;
  }

  // Supprimer tous les services d'un utilisateur
  Future<int> clearMyServices(String userId) async {
    final db = await database;
    return await db.delete(
      table,
      where: '$columnUserId = ?',
      whereArgs: [userId],
    );
  }

  // Supprimer un service spécifique
  Future<int> deleteService(String serviceId) async {
    final db = await database;
    return await db.delete(
      table,
      where: '$columnId = ?',
      whereArgs: [serviceId],
    );
  }

  // Compter le nombre de services
  Future<int> getServiceCount(String userId) async {
    final db = await database;
    final count = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM $table WHERE $columnUserId = ?',
      [userId],
    ));
    return count ?? 0;
  }

  // Méthodes utilitaires pour la conversion JSON
  String serviceToJsonString(PrestationModel service) {
    return json.encode(service.toJson());
  }

  PrestationModel serviceFromJsonString(String jsonString) {
    try {
      return PrestationModel.fromJson(json.decode(jsonString));
    } catch (e) {
      print("Error decoding service JSON: $e");
      // Fallback or empty model
      return PrestationModel();
    }
  }

  // Vider complètement la base de données
  Future<void> clearDatabase() async {
    final db = await database;
    await db.delete(table);
  }
}

import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/CityModel.dart';
import '../../models/CommuneModel.dart';
import '../../models/CountryModel.dart';
import '../../models/DistrictModel.dart';
import '../../models/QuartierModel.dart';

class LocationDatabaseHelper {
  static const _databaseName = "location_database.db";
  static const _databaseVersion = 2;

  // Tables
  static const tableCountries = 'countries';
  static const tableCities = 'cities';
  static const tableCommunes = 'communes';
  static const tableDistricts = 'districts';
  static const tableQuartiers = 'quartiers';

  // Colonnes
  static const columnId = 'id';
  static const columnData = 'data';

  // Singleton
  LocationDatabaseHelper._privateConstructor();
  static final LocationDatabaseHelper instance = LocationDatabaseHelper._privateConstructor();

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
    // Table countries
    await db.execute('''
      CREATE TABLE $tableCountries (
        $columnId INTEGER PRIMARY KEY,
        $columnData TEXT NOT NULL
      )
    ''');

    // Table cities
    await db.execute('''
      CREATE TABLE $tableCities (
        $columnId INTEGER PRIMARY KEY,
        $columnData TEXT NOT NULL
      )
    ''');

    // Table communes
    await db.execute('''
      CREATE TABLE $tableCommunes (
        $columnId INTEGER PRIMARY KEY,
        $columnData TEXT NOT NULL
      )
    ''');

    // Table districts
    await db.execute('''
      CREATE TABLE $tableDistricts (
        $columnId INTEGER PRIMARY KEY,
        $columnData TEXT NOT NULL
      )
    ''');

    // Table quartiers (nouvelle table)
    await db.execute('''
      CREATE TABLE $tableQuartiers (
        $columnId INTEGER PRIMARY KEY,
        $columnData TEXT NOT NULL
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Ajouter la table quartiers pour la version 2
      await db.execute('''
        CREATE TABLE $tableQuartiers (
          $columnId INTEGER PRIMARY KEY,
          $columnData TEXT NOT NULL
        )
      ''');
    }
  }

  // ==================== COUNTRIES ====================
  Future<int> insertOrUpdateCountry(CountryModel country) async {
    final db = await database;
    return await db.insert(
      tableCountries,
      {
        columnId: country.countryId,
        columnData: countryModelToJson(country),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<CountryModel>> getAllCountries() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(tableCountries);
    return List.generate(maps.length, (i) {
      return countryModelFromJson(maps[i][columnData]);
    });
  }

  Future<CountryModel?> getCountryById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableCountries,
      where: '$columnId = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return countryModelFromJson(maps.first[columnData]);
    }
    return null;
  }

  Future<int> deleteCountry(int id) async {
    final db = await database;
    return await db.delete(
      tableCountries,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  Future<int> clearCountries() async {
    final db = await database;
    return await db.delete(tableCountries);
  }

  // ==================== CITIES ====================
  Future<int> insertOrUpdateCity(CityModel city) async {
    final db = await database;
    return await db.insert(
      tableCities,
      {
        columnId: city.cityId,
        columnData: cityModelToJson(city),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<CityModel>> getAllCities() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(tableCities);
    return List.generate(maps.length, (i) {
      return cityModelFromJson(maps[i][columnData]);
    });
  }

  Future<CityModel?> getCityById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableCities,
      where: '$columnId = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return cityModelFromJson(maps.first[columnData]);
    }
    return null;
  }

  Future<List<CityModel>> getCitiesByCountry(int countryId) async {
    final db = await database;
    final List<CityModel> allCities = await getAllCities();
    return allCities.where((city) => city.country?.countryId == countryId).toList();
  }

  Future<int> deleteCity(int id) async {
    final db = await database;
    return await db.delete(
      tableCities,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  Future<int> clearCities() async {
    final db = await database;
    return await db.delete(tableCities);
  }

  // ==================== COMMUNES ====================
  Future<int> insertOrUpdateCommune(CommuneModel commune) async {
    final db = await database;
    return await db.insert(
      tableCommunes,
      {
        columnId: commune.communeId,
        columnData: communeModelToJson(commune),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<CommuneModel>> getAllCommunes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(tableCommunes);
    return List.generate(maps.length, (i) {
      return communeModelFromJson(maps[i][columnData]);
    });
  }

  Future<CommuneModel?> getCommuneById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableCommunes,
      where: '$columnId = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return communeModelFromJson(maps.first[columnData]);
    }
    return null;
  }

  Future<List<CommuneModel>> getCommunesByDistrict(int districtId) async {
    final db = await database;
    final List<CommuneModel> allCommunes = await getAllCommunes();
    return allCommunes.where((commune) => commune.district?.districtId == districtId).toList();
  }

  Future<List<CommuneModel>> getCommunesByCity(int cityId) async {
    final db = await database;
    final List<CommuneModel> allCommunes = await getAllCommunes();
    return allCommunes.where((commune) => commune.district?.city?.cityId == cityId).toList();
  }

  Future<int> deleteCommune(int id) async {
    final db = await database;
    return await db.delete(
      tableCommunes,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  Future<int> clearCommunes() async {
    final db = await database;
    return await db.delete(tableCommunes);
  }

  // ==================== DISTRICTS ====================
  Future<int> insertOrUpdateDistrict(DistrictModel district) async {
    final db = await database;
    return await db.insert(
      tableDistricts,
      {
        columnId: district.districtId,
        columnData: districtModelToJson(district),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<DistrictModel>> getAllDistricts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(tableDistricts);
    return List.generate(maps.length, (i) {
      return districtModelFromJson(maps[i][columnData]);
    });
  }

  Future<DistrictModel?> getDistrictById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableDistricts,
      where: '$columnId = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return districtModelFromJson(maps.first[columnData]);
    }
    return null;
  }

  Future<List<DistrictModel>> getDistrictsByCity(int cityId) async {
    final db = await database;
    final List<DistrictModel> allDistricts = await getAllDistricts();
    return allDistricts.where((district) => district.city?.cityId == cityId).toList();
  }

  Future<int> deleteDistrict(int id) async {
    final db = await database;
    return await db.delete(
      tableDistricts,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  Future<int> clearDistricts() async {
    final db = await database;
    return await db.delete(tableDistricts);
  }

  // ==================== QUARTIERS ====================
  Future<int> insertOrUpdateQuartier(QuartierModel quartier) async {
    final db = await database;
    return await db.insert(
      tableQuartiers,
      {
        columnId: quartier.quartierId,
        columnData: quartierModelToJson(quartier),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<QuartierModel>> getAllQuartiers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(tableQuartiers);
    return List.generate(maps.length, (i) {
      return quartierModelFromJson(maps[i][columnData]);
    });
  }

  Future<QuartierModel?> getQuartierById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableQuartiers,
      where: '$columnId = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return quartierModelFromJson(maps.first[columnData]);
    }
    return null;
  }

  Future<List<QuartierModel>> getQuartiersByCommune(int communeId) async {
    final db = await database;
    final List<QuartierModel> allQuartiers = await getAllQuartiers();
    return allQuartiers.where((quartier) => quartier.communeId == communeId).toList();
  }

  Future<List<QuartierModel>> getQuartiersByDistrict(int districtId) async {
    final db = await database;
    final List<QuartierModel> allQuartiers = await getAllQuartiers();

    // Récupérer toutes les communes du district
    final communes = await getCommunesByDistrict(districtId);
    final communeIds = communes.map((c) => c.communeId).toSet();

    return allQuartiers.where((quartier) => communeIds.contains(quartier.communeId)).toList();
  }

  Future<List<QuartierModel>> getQuartiersByCity(int cityId) async {
    final db = await database;
    final List<QuartierModel> allQuartiers = await getAllQuartiers();

    // Récupérer tous les districts de la ville
    final districts = await getDistrictsByCity(cityId);
    final districtIds = districts.map((d) => d.districtId).toSet();

    // Récupérer toutes les communes de ces districts
    final List<CommuneModel> allCommunes = await getAllCommunes();
    final communesInCity = allCommunes.where((commune) =>
        districtIds.contains(commune.district?.districtId)).toList();

    final communeIds = communesInCity.map((c) => c.communeId).toSet();

    return allQuartiers.where((quartier) => communeIds.contains(quartier.communeId)).toList();
  }

  Future<List<QuartierModel>> searchQuartiers(String query, {int? communeId}) async {
    final db = await database;
    List<QuartierModel> allQuartiers;

    if (communeId != null) {
      allQuartiers = await getQuartiersByCommune(communeId);
    } else {
      allQuartiers = await getAllQuartiers();
    }

    if (query.isEmpty) {
      return allQuartiers;
    }

    return allQuartiers.where((quartier) =>
    quartier.name?.toLowerCase().contains(query.toLowerCase()) ?? false
    ).toList();
  }

  Future<Map<CommuneModel, List<QuartierModel>>> getCommunesWithQuartiers() async {
    final db = await database;
    final List<CommuneModel> allCommunes = await getAllCommunes();
    final Map<CommuneModel, List<QuartierModel>> result = {};

    for (var commune in allCommunes) {
      final quartiers = await getQuartiersByCommune(commune.communeId!);
      result[commune] = quartiers;
    }

    return result;
  }

  Future<int> deleteQuartier(int id) async {
    final db = await database;
    return await db.delete(
      tableQuartiers,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  Future<int> clearQuartiers() async {
    final db = await database;
    return await db.delete(tableQuartiers);
  }

  // ==================== MÉTHODES GLOBALES ====================
  Future<void> clearAllLocationData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(tableCountries);
      await txn.delete(tableCities);
      await txn.delete(tableDistricts);
      await txn.delete(tableCommunes);
      await txn.delete(tableQuartiers);
    });
  }

  Future<void> initializeLocationData({
    List<CountryModel>? countries,
    List<CityModel>? cities,
    List<DistrictModel>? districts,
    List<CommuneModel>? communes,
    List<QuartierModel>? quartiers,
  }) async {
    if (countries != null) {
      for (var country in countries) {
        await insertOrUpdateCountry(country);
      }
    }
    if (cities != null) {
      for (var city in cities) {
        await insertOrUpdateCity(city);
      }
    }
    if (districts != null) {
      for (var district in districts) {
        await insertOrUpdateDistrict(district);
      }
    }
    if (communes != null) {
      for (var commune in communes) {
        await insertOrUpdateCommune(commune);
      }
    }
    if (quartiers != null) {
      for (var quartier in quartiers) {
        await insertOrUpdateQuartier(quartier);
      }
    }
  }

  // Obtenir les statistiques de la base de données
  Future<Map<String, int>> getDatabaseStatistics() async {
    final db = await database;

    final countriesCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $tableCountries')
    ) ?? 0;

    final citiesCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $tableCities')
    ) ?? 0;

    final districtsCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $tableDistricts')
    ) ?? 0;

    final communesCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $tableCommunes')
    ) ?? 0;

    final quartiersCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $tableQuartiers')
    ) ?? 0;

    return {
      'countries': countriesCount,
      'cities': citiesCount,
      'districts': districtsCount,
      'communes': communesCount,
      'quartiers': quartiersCount,
    };
  }

  // Vérifier si la base contient des données
  Future<bool> hasData() async {
    final stats = await getDatabaseStatistics();
    return stats.values.any((count) => count > 0);
  }

  // Sauvegarder en masse les quartiers
  Future<void> batchInsertQuartiers(List<QuartierModel> quartiers) async {
    final db = await database;
    final batch = db.batch();

    for (var quartier in quartiers) {
      batch.insert(
        tableQuartiers,
        {
          columnId: quartier.quartierId,
          columnData: quartierModelToJson(quartier),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(tableCountries);
      await txn.delete(tableCities);
      await txn.delete(tableDistricts);
      await txn.delete(tableCommunes);
      await txn.delete(tableQuartiers);
    });

    print('✅ Toutes les données de localisation ont été supprimées du cache');
  }

  // Fermer la base de données
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}

// Méthodes de sérialisation pour QuartierModel (à ajouter si elles n'existent pas)
String quartierModelToJson(QuartierModel model) {
  return jsonEncode(model.toJson());
}

QuartierModel quartierModelFromJson(String jsonString) {
  return QuartierModel.fromJson(jsonDecode(jsonString));
}
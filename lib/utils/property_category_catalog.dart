import 'package:casa/controllers/PropertyCtrl.dart';

/// Catalogue des types de biens affichés sur l'accueil (« Explorer par type »).
class PropertyCategoryCatalog {
  PropertyCategoryCatalog._();

  static const List<Map<String, dynamic>> fallbackCategories = [
    {'label': 'Studios', 'image': 'assets/images/studio.png', 'value': 'Studio'},
    {'label': 'Apparts', 'image': 'assets/images/apart.png', 'value': 'Apparts'},
    {'label': 'Maisons', 'image': 'assets/images/maison.png', 'value': 'Maisons'},
    {'label': 'Bureaux', 'image': 'assets/images/office.png', 'value': 'Bureau'},
    {'label': 'Fêtes', 'image': 'assets/images/fete.png', 'value': 'Salle de fête'},
    {
      'label': 'Funéraires',
      'image': 'assets/images/funebre.png',
      'value': 'Salle funéraires',
    },
    {'label': 'Terrains', 'image': 'assets/images/Terrain.png', 'value': 'Terrain'},
    {'label': 'Hôtels', 'image': 'assets/images/hotel.png', 'value': 'Hotels'},
  ];

  static List<Map<String, dynamic>> resolve(PropertyController propertyCtrl) {
    if (propertyCtrl.propertyTypes.isEmpty) {
      return List<Map<String, dynamic>>.from(fallbackCategories);
    }
    return propertyCtrl.propertyTypes
        .map((type) => {
              'propertyTypeId': type['propertyTypeId'],
              'label': type['name'],
              'image': categoryImage(type['name']?.toString() ?? ''),
              'value': categoryValue(type['name']?.toString() ?? ''),
            })
        .toList();
  }

  static String categoryImage(String name) {
    final n = name.toLowerCase();
    if (n.contains('studio')) return 'assets/images/studio.png';
    if (n.contains('appart')) return 'assets/images/apart.png';
    if (n.contains('maison') || n.contains('villa')) {
      return 'assets/images/maison.png';
    }
    if (n.contains('bureau') || n.contains('office')) {
      return 'assets/images/office.png';
    }
    if (n.contains('hotel')) return 'assets/images/hotel.png';
    if (n.contains('vacance')) return 'assets/images/plage.png';
    if (n.contains('fête')) return 'assets/images/fete.png';
    if (n.contains('funérair')) return 'assets/images/funebre.png';
    if (n.contains('entrepôt')) return 'assets/images/Entrepot.png';
    if (n.contains('terrain')) return 'assets/images/Terrain.png';
    return 'assets/images/apart.png';
  }

  static String categoryValue(String name) {
    final n = name.toLowerCase();
    if (n.contains('studio')) return 'Studio';
    if (n.contains('appart')) return 'Apparts';
    if (n.contains('maison')) return 'Maisons';
    if (n.contains('bureau')) return 'Bureau';
    if (n.contains('hotel') || n.contains('hôtel')) return 'Hotels';
    if (n.contains('vacance')) return 'Vacances';
    if (n.contains('funérair')) return 'Salle funéraires';
    if (n.contains('fête')) return 'Salle de fête';
    if (n.contains('terrain')) return 'Terrain';
    return name;
  }

  /// Valeur de navigation (alignée sur le carrousel de l'accueil).
  static String normalizedCategoryValue(String rawValue) {
    final lower = rawValue.toLowerCase();
    if (lower.contains('appart')) return 'Apparts';
    return rawValue;
  }
}

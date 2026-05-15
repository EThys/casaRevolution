import 'package:casa/controllers/PropertyCtrl.dart';
import 'package:casa/screens/CategoryPropertiesPage.dart';
import 'package:casa/screens/TerrainPropertiesPage.dart';
import 'package:casa/utils/property_category_catalog.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

/// Liste complète des types de biens (section « Explorer par type » de l'accueil).
class AllPropertyCategoriesPage extends StatelessWidget {
  const AllPropertyCategoriesPage({super.key});

  static const Color _primaryColor = Color(0xFF1976D2);
  static const Color _darkBlue = Color(0xFF0D47A1);

  void _openCategory(BuildContext context, Map<String, dynamic> category) {
    final rawValue = (category['value'] as String?) ?? '';
    final normalized = PropertyCategoryCatalog.normalizedCategoryValue(rawValue);

    if (normalized == 'Terrain') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TerrainPropertiesPage()),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryPropertiesPage(category: normalized),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories =
        PropertyCategoryCatalog.resolve(context.watch<PropertyController>());

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F9),
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, _darkBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Explorer par type',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 16,
          mainAxisSpacing: 20,
          childAspectRatio: 0.78,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final label = category['label'] as String? ?? '';
          final image = category['image'] as String? ?? '';

          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openCategory(context, category),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Image.asset(image, fit: BoxFit.contain),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

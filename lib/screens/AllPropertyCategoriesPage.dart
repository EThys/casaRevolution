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
    final rawValue = (category['value']?.toString() ?? '').trim();
    final label = (category['label']?.toString() ?? '').trim();
    final source = rawValue.isNotEmpty ? rawValue : label;
    final normalized = PropertyCategoryCatalog.normalizedCategoryValue(source);

    if (normalized.toLowerCase().contains('terrain')) {
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
        PropertyCategoryCatalog.resolve(context.watch<PropertyController>())
            .toList()
          ..sort((a, b) => ((a['label'] as String?) ?? '')
              .toLowerCase()
              .compareTo(((b['label'] as String?) ?? '').toLowerCase()));

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
      body: RefreshIndicator(
        color: _primaryColor,
        onRefresh: () async {
          final propertyCtrl = context.read<PropertyController>();
          await propertyCtrl.refreshProperties(forceSync: true);
          await propertyCtrl.syncAllSpecialCategories();
        },
        child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 16, 16, 28 + MediaQuery.viewPaddingOf(context).bottom),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final label = category['label'] as String? ?? '';
          final image = category['image'] as String? ?? '';

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openCategory(context, category),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Image.asset(image, fit: BoxFit.contain),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF111827),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
                  ],
                ),
            ),
          );
        },
      ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/ServiceModel.dart';
import 'CategoryPropertiesPage.dart';

class AllServiceCategoriesPage extends StatelessWidget {
  final Color primaryColor = Color(0xFF1976D2);
  final Color accentColor = Color(0xFF64B5F6);
  final Color darkBlue = Color(0xFF0D47A1);

  // Liste des catégories de services demandées
  final List<Map<String, dynamic>> serviceCategories = [
    {
      'name': 'Plombier',
      'value': 'plomberie',
      'icon': Icons.plumbing_rounded,
      'color': Color(0xFF2196F3),
    },
    {
      'name': 'Ajusteur',
      'value': 'reparation',
      'icon': Icons.build_rounded,
      'color': Color(0xFF4CAF50),
    },
    {
      'name': 'Architecte',
      'value': 'renovation',
      'icon': Icons.architecture_rounded,
      'color': Color(0xFFFF9800),
    },
    {
      'name': 'Carreleur',
      'value': 'carrelage',
      'icon': Icons.square_foot_rounded,
      'color': Color(0xFF9C27B0),
    },
    {
      'name': 'Chauffeur',
      'value': 'transport',
      'icon': Icons.drive_eta_rounded,
      'color': Color(0xFFF44336),
    },
    {
      'name': 'Électricien',
      'value': 'electricite',
      'icon': Icons.electrical_services_rounded,
      'color': Color(0xFFFFEB3B),
    },
    {
      'name': 'Frigoriste',
      'value': 'climatisation',
      'icon': Icons.ac_unit_rounded,
      'color': Color(0xFF00BCD4),
    },
    {
      'name': 'Maçon',
      'value': 'renovation',
      'icon': Icons.construction_rounded,
      'color': Color(0xFF795548),
    },
    {
      'name': 'Majordome',
      'value': 'majordhomme',
      'icon': Icons.cleaning_services_rounded,
      'color': Color(0xFF607D8B),
    },
    {
      'name': 'Menuisier',
      'value': 'reparation',
      'icon': Icons.carpenter_rounded,
      'color': Color(0xFF8D6E63),
    },
    {
      'name': 'Salubrité',
      'value': 'nettoyage',
      'icon': Icons.cleaning_services_rounded,
      'color': Color(0xFF4CAF50),
    },
    {
      'name': 'Peintre',
      'value': 'peinture',
      'icon': Icons.format_paint_rounded,
      'color': Color(0xFFFF5722),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: Colors.grey[900]),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Toutes les catégories',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[900],
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 8),
            Text(
              'Découvrez tous nos services',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 24),
            GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
              ),
              itemCount: serviceCategories.length,
              itemBuilder: (context, index) {
                final category = serviceCategories[index];
                return _buildCategoryCard(context, category);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, Map<String, dynamic> category) {
    final color = category['color'] as Color;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CategoryPropertiesPage(
                category: category['value'] as String,
              ),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                spreadRadius: 2,
                offset: Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: Colors.grey[200]!,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  category['icon'] as IconData,
                  color: color,
                  size: 32,
                ),
              ),
              SizedBox(height: 12),
              Text(
                category['name'] as String,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[900],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


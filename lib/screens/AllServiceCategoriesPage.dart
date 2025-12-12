import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/ServiceModel.dart';
import '../utils/static_services_data.dart';
import 'ServiceCategoryPage.dart';
import 'CategoryPropertiesPage.dart'; // fallback legacy import

class AllServiceCategoriesPage extends StatefulWidget {
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
  State<AllServiceCategoriesPage> createState() => _AllServiceCategoriesPageState();
}

class _AllServiceCategoriesPageState extends State<AllServiceCategoriesPage> {
  Color get primaryColor => widget.primaryColor;
  Color get accentColor => widget.accentColor;
  Color get darkBlue => widget.darkBlue;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [widget.primaryColor, widget.darkBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Toutes les catégories',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
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
              itemCount: widget.serviceCategories.length,
              itemBuilder: (context, index) {
                final category = widget.serviceCategories[index];
                return _buildCategoryCard(context, category);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, Map<String, dynamic> category) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          final serviceType = ServiceTypeExtension.fromString(category['value'] as String);
          final services = StaticServicesData.getServicesByType(serviceType);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ServiceCategoryPage(
                serviceType: serviceType,
                services: services,
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
              color: primaryColor.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor, accentColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  category['icon'] as IconData,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              SizedBox(height: 12),
              Text(
                category['name'] as String,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: darkBlue,
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


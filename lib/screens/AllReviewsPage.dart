import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:casa/models/ServiceModel.dart';

class AllReviewsPage extends StatelessWidget {
  final ServiceModel service;

  const AllReviewsPage({
    Key? key,
    required this.service,
  }) : super(key: key);

  static const Color primaryColor = Color(0xFF1976D2);
  static const Color darkBlue = Color(0xFF0D47A1);

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'À l\'instant';
        }
        return 'Il y a ${difference.inMinutes} ${difference.inMinutes > 1 ? 'minutes' : 'minute'}';
      }
      return 'Aujourd\'hui à ${date.hour.toString().padLeft(2, '0')}h${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Hier à ${date.hour.toString().padLeft(2, '0')}h${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays} ${difference.inDays > 1 ? 'jours' : 'jour'}';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return 'Il y a ${weeks} ${weeks > 1 ? 'semaines' : 'semaine'}';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return 'Il y a ${months} ${months > 1 ? 'mois' : 'mois'}';
    } else {
      final years = (difference.inDays / 365).floor();
      return 'Il y a ${years} ${years > 1 ? 'ans' : 'an'}';
    }
  }

  Widget _buildReviewCard({
    required String name,
    required double rating,
    required String comment,
    required DateTime datePosted,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: primaryColor.withOpacity(0.1),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: darkBlue,
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        ...List.generate(5, (index) {
                          return Icon(
                            index < rating.floor()
                                ? Icons.star
                                : (index < rating ? Icons.star_half : Icons.star_border),
                            color: Colors.amber,
                            size: 16,
                          );
                        }),
                        SizedBox(width: 8),
                        Text(
                          rating.toStringAsFixed(1),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                _getTimeAgo(datePosted),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            comment,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      elevation: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [primaryColor, darkBlue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tous les avis',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            '${service.reviewCount ?? 0} avis',
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Liste des avis (statiques pour l'instant, à remplacer par les données de l'API)
    final reviews = [
      {
        'name': 'Patrick K.',
        'rating': 4.8,
        'comment': 'Travail propre et rapide, très professionnel. Je recommande vivement ce prestataire pour tous vos besoins de plomberie.',
        'date': DateTime.now().subtract(Duration(days: 5)),
      },
      {
        'name': 'Mireille N.',
        'rating': 4.7,
        'comment': 'Ponctuel et soigneux, les finitions sont impeccables. Très satisfaite du service rendu.',
        'date': DateTime.now().subtract(Duration(days: 12)),
      },
      {
        'name': 'Arnaud T.',
        'rating': 4.9,
        'comment': 'Très bonne communication et respect des délais. Le prestataire a su s\'adapter à mes besoins.',
        'date': DateTime.now().subtract(Duration(days: 3)),
      },
      {
        'name': 'Sophie M.',
        'rating': 5.0,
        'comment': 'Excellent service, je recommande vivement ! Travail de qualité et professionnel.',
        'date': DateTime.now().subtract(Duration(days: 7)),
      },
      {
        'name': 'Jean P.',
        'rating': 4.5,
        'comment': 'Très satisfait du travail effectué. Prix raisonnable et résultat conforme aux attentes.',
        'date': DateTime.now().subtract(Duration(days: 15)),
      },
      {
        'name': 'Marie L.',
        'rating': 4.8,
        'comment': 'Prestataire sérieux et compétent. Intervention rapide et efficace. À recommander sans hésitation.',
        'date': DateTime.now().subtract(Duration(days: 20)),
      },
      {
        'name': 'Pierre D.',
        'rating': 4.6,
        'comment': 'Service de qualité, prestataire à l\'écoute. Bon rapport qualité-prix.',
        'date': DateTime.now().subtract(Duration(hours: 5)),
      },
      {
        'name': 'Julie R.',
        'rating': 5.0,
        'comment': 'Parfait ! Intervention rapide, travail soigné, et prestataire très sympathique. Merci beaucoup !',
        'date': DateTime.now().subtract(Duration(hours: 2)),
      },
    ];

    // Trier les avis par date (plus récents en premier)
    reviews.sort((a, b) {
      final dateA = a['date'] as DateTime;
      final dateB = b['date'] as DateTime;
      return dateB.compareTo(dateA);
    });

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(context),
      body: reviews.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.rate_review_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Aucun avis pour le moment',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Statistiques
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text(
                              service.rating?.toStringAsFixed(1) ?? '0.0',
                              style: GoogleFonts.inter(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: darkBlue,
                              ),
                            ),
                            Row(
                              children: [
                                Icon(Icons.star, color: Colors.amber, size: 20),
                                SizedBox(width: 4),
                                Text(
                                  'Note moyenne',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          width: 1,
                          height: 50,
                          color: Colors.grey[300],
                        ),
                        Column(
                          children: [
                            Text(
                              '${reviews.length}',
                              style: GoogleFonts.inter(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: darkBlue,
                              ),
                            ),
                            Text(
                              'Avis au total',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Tous les avis',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: darkBlue,
                    ),
                  ),
                  SizedBox(height: 12),
                  ...reviews.map((review) {
                    return _buildReviewCard(
                      name: review['name'] as String,
                      rating: review['rating'] as double,
                      comment: review['comment'] as String,
                      datePosted: review['date'] as DateTime,
                    );
                  }).toList(),
                ],
              ),
            ),
    );
  }
}


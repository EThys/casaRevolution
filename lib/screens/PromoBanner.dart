import 'dart:convert';

import 'package:casa/utils/Endpoints.dart';
import 'package:casa/utils/cache/HotelImageCache.dart';
import 'package:casa/utils/offline_network_image.dart';
import 'package:casa/utils/requetes.dart';
import 'package:flutter/material.dart';

class PromoBanner extends StatefulWidget {
  const PromoBanner({super.key});

  @override
  State<PromoBanner> createState() => _PromoBannerState();
}

class _PromoBannerState extends State<PromoBanner> {
  static List<_Offer>? _cached;
  static Future<List<_Offer>>? _loading;

  final List<_Offer> _offers = [];
  late PageController _pageController;
  int _currentPage = 0;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
    _load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final offers = await _offersOnce();
    if (!mounted) return;
    setState(() {
      _offers
        ..clear()
        ..addAll(offers);
      _ready = true;
      _currentPage = 0;
    });
  }

  static Future<List<_Offer>> _offersOnce() {
    final cached = _cached;
    if (cached != null) return Future.value(cached);
    return _loading ??= _fetchOffers().then((value) {
      _cached = value;
      return value;
    }).whenComplete(() {
      _loading = null;
    });
  }

  static Future<List<_Offer>> _fetchOffers() async {
    final body = await getData(Endpoints.publicPubs, token: '');
    final rows = _rowsOf(body);
    final offers = <_Offer>[];
    for (final row in rows) {
      if (!_isActive(row)) continue;
      final title = _text(row['title']);
      if (title.isEmpty) continue;
      offers.add(
        _Offer(
          title: title,
          description: _text(row['description']),
          imageUrl: _imageSrc(_text(row['imagePath'])),
        ),
      );
    }
    return offers;
  }

  static List<Map<String, dynamic>> _rowsOf(dynamic body) {
    if (body is List) {
      return body.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
    }
    if (body is Map) {
      for (final value in body.values) {
        if (value is List) {
          return value
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList();
        }
        if (value is Map) {
          final nested = _rowsOf(value);
          if (nested.isNotEmpty) return nested;
        }
      }
    }
    return const [];
  }

  static bool _isActive(Map<String, dynamic> row) {
    final value = row['isActive'] ?? row['active'];
    if (value == null) return true;
    if (value is bool) return value;
    final text = value.toString().toLowerCase();
    return text == 'true' || text == '1';
  }

  static String _text(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return '';
    return text;
  }

  static String _imageSrc(String raw) {
    if (raw.isEmpty) return '';
    if (raw.startsWith('data:image')) return raw;
    final compact = raw.replaceAll(RegExp(r'\s'), '');
    final storedAsText = compact.length > 80 &&
        !compact.contains('/') &&
        !compact.contains('http');
    if (storedAsText) return 'data:image/jpeg;base64,$compact';
    return HotelImageCache.resolve(raw);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || _offers.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      height: 240,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1976D2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Offres du moment',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[800],
                  ),
                ),
                const Spacer(),
                Text(
                  '${_currentPage + 1}/${_offers.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 160,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _offers.length,
              onPageChanged: (index) {
                if (!mounted) return;
                setState(() => _currentPage = index);
              },
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final offer = _offers[index];
                final isActive = index == _currentPage;
                return Transform.scale(
                  scale: isActive ? 1 : 0.92,
                  child: Opacity(
                    opacity: isActive ? 1 : 0.7,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1976D2).withOpacity(0.16),
                            blurRadius: 15,
                            spreadRadius: 1,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _OfferImage(url: offer.imageUrl),
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Color(0xB3000000),
                                  ],
                                  stops: [0.3, 1],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    offer.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      height: 1.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (offer.description.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      offer.description,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        height: 1.3,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Positioned(
                              top: 12,
                              left: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.92),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'OFFRE',
                                  style: TextStyle(
                                    color: Color(0xFF1976D2),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_offers.length, (index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: _currentPage == index ? 20 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? const Color(0xFF1976D2)
                      : Colors.grey[300],
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _OfferImage extends StatelessWidget {
  final String url;

  const _OfferImage({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return const _OfferFallback();
    if (url.startsWith('data:image')) {
      final comma = url.indexOf(',');
      if (comma > 0) {
        try {
          return Image.memory(
            base64Decode(url.substring(comma + 1)),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => const _OfferFallback(),
          );
        } catch (_) {
          return const _OfferFallback();
        }
      }
    }
    return OfflineNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => const _OfferFallback(),
      errorWidget: (_, __, ___) => const _OfferFallback(),
    );
  }
}

class _OfferFallback extends StatelessWidget {
  const _OfferFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1976D2), Color(0xFF64B5F6)],
        ),
      ),
    );
  }
}

class _Offer {
  final String title;
  final String description;
  final String imageUrl;

  const _Offer({
    required this.title,
    required this.description,
    required this.imageUrl,
  });
}

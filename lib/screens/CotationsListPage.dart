import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/CotationModel.dart';

/// Liste complète des avis (`cotation`) pour une prestation.
class CotationsListPage extends StatefulWidget {
  final List<CotationModel> cotations;
  final String? title;

  const CotationsListPage({
    super.key,
    required this.cotations,
    this.title,
  });

  @override
  State<CotationsListPage> createState() => _CotationsListPageState();
}

enum _ReviewsSortMode { recent, best, worst }

class _CotationsListPageState extends State<CotationsListPage> {
  // Aligné avec ServiceDetailPage / shell Casa
  static const Color primaryColor = Color(0xFF1976D2);
  static const Color darkBlue = Color(0xFF0D47A1);
  static const Color _bg = Color(0xFFF3F6FB);
  static const Color _text = Color(0xFF0B1220);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _star = Color(0xFFFFB300);

  _ReviewsSortMode _sortMode = _ReviewsSortMode.recent;

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) return 'À l\'instant';
        return 'Il y a ${difference.inMinutes} min';
      }
      return 'Aujourd\'hui';
    }
    if (difference.inDays == 1) return 'Hier';
    if (difference.inDays < 7) return 'Il y a ${difference.inDays} j';
    return '${date.day}/${date.month}/${date.year}';
  }

  double _avgRating(List<CotationModel> list) {
    if (list.isEmpty) return 0;
    double sum = 0;
    int count = 0;
    for (final c in list) {
      final v = c.cote;
      if (v == null) continue;
      sum += v;
      count += 1;
    }
    return count == 0 ? 0 : (sum / count);
  }

  int _countWithRating(List<CotationModel> list, int star) {
    int n = 0;
    for (final c in list) {
      final v = c.cote;
      if (v == null) continue;
      final rounded = v.round().clamp(1, 5);
      if (rounded == star) n++;
    }
    return n;
  }

  List<CotationModel> _sorted(List<CotationModel> input) {
    final out = [...input];
    out.sort((a, b) {
      final aDate = DateTime.tryParse(a.createdAt ?? '');
      final bDate = DateTime.tryParse(b.createdAt ?? '');
      final aId = a.id ?? 0;
      final bId = b.id ?? 0;
      final aRating = (a.cote ?? 0).toDouble();
      final bRating = (b.cote ?? 0).toDouble();

      switch (_sortMode) {
        case _ReviewsSortMode.best:
          final byRate = bRating.compareTo(aRating);
          if (byRate != 0) return byRate;
          if (bDate != null && aDate != null) return bDate.compareTo(aDate);
          return bId.compareTo(aId);
        case _ReviewsSortMode.worst:
          final byRate = aRating.compareTo(bRating);
          if (byRate != 0) return byRate;
          if (bDate != null && aDate != null) return bDate.compareTo(aDate);
          return bId.compareTo(aId);
        case _ReviewsSortMode.recent:
          if (bDate != null && aDate != null) return bDate.compareTo(aDate);
          return bId.compareTo(aId);
      }
    });
    return out;
  }

  List<Widget> _buildStarIcons(double rating, {double size = 18}) {
    final r = rating.isNaN ? 0.0 : rating.clamp(0.0, 5.0);
    final halfSteps = (r * 2).round(); // 4.5 -> 9
    final full = halfSteps ~/ 2;
    final hasHalf = halfSteps % 2 == 1;
    final empty = 5 - full - (hasHalf ? 1 : 0);

    final stars = <Widget>[];
    for (var i = 0; i < full; i++) {
      stars.add(
          Icon(Icons.star_rounded, color: _star, size: size));
    }
    if (hasHalf) {
      stars.add(Icon(Icons.star_half_rounded,
          color: _star, size: size));
    }
    for (var i = 0; i < empty; i++) {
      stars.add(Icon(Icons.star_border_rounded,
          color: _star, size: size));
    }
    return stars;
  }

  @override
  Widget build(BuildContext context) {
    final list = _sorted(widget.cotations);
    final avg = _avgRating(list);
    final total = list.length;

    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            elevation: 0,
            scrolledUnderElevation: 0.5,
            shadowColor: Colors.black26,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            foregroundColor: darkBlue,
            title: Text(
              widget.title != null ? 'Avis · ${widget.title}' : 'Tous les avis',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: darkBlue,
                letterSpacing: -0.2,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: _border.withOpacity(0.8)),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _border),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.07),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 100,
                      padding: const EdgeInsets.only(top: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            avg == 0 ? '—' : avg.toStringAsFixed(1),
                            style: GoogleFonts.inter(
                              fontSize: 40,
                              height: 1.0,
                              fontWeight: FontWeight.w900,
                              color: darkBlue,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(children: _buildStarIcons(avg, size: 20)),
                          const SizedBox(height: 8),
                          Text(
                            total <= 1 ? '$total avis' : '$total avis au total',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        children: List.generate(5, (i) {
                          final star = 5 - i;
                          final n = _countWithRating(list, star);
                          final p = total == 0 ? 0.0 : (n / total);
                          return Padding(
                            padding: EdgeInsets.only(bottom: i == 4 ? 0 : 8),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 18,
                                  child: Text(
                                    '$star',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                      color: _muted,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.star_rounded, size: 14, color: _star),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(999),
                                    child: LinearProgressIndicator(
                                      minHeight: 9,
                                      value: p,
                                      backgroundColor: const Color(0xFFE8EEF5),
                                      valueColor: const AlwaysStoppedAnimation<Color>(
                                          darkBlue),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: 28,
                                  child: Text(
                                    '$n',
                                    textAlign: TextAlign.right,
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                      color: _muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Row(
                children: [
                  _SortChip(
                    label: 'Récent',
                    selected: _sortMode == _ReviewsSortMode.recent,
                    onTap: () => setState(() => _sortMode = _ReviewsSortMode.recent),
                  ),
                  const SizedBox(width: 10),
                  _SortChip(
                    label: 'Meilleurs',
                    selected: _sortMode == _ReviewsSortMode.best,
                    onTap: () => setState(() => _sortMode = _ReviewsSortMode.best),
                  ),
                  const SizedBox(width: 10),
                  _SortChip(
                    label: 'Moins bons',
                    selected: _sortMode == _ReviewsSortMode.worst,
                    onTap: () => setState(() => _sortMode = _ReviewsSortMode.worst),
                  ),
                ],
              ),
            ),
          ),
          if (list.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.rate_review_outlined,
                          size: 56, color: primaryColor.withOpacity(0.45)),
                      const SizedBox(height: 16),
                      Text(
                        'Pas encore d’avis',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: darkBlue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Les premiers retours apparaîtront ici.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: _muted,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
              sliver: SliverList.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final c = list[i];
                  final name = c.user?.username ?? c.user?.fullName ?? 'Client';
                  final avatarUrl = c.user?.profilePicture;
                  final rating = c.cote ?? 0;
                  final comment = c.commentaire?.trim().isNotEmpty == true
                      ? c.commentaire!.trim()
                      : '—';
                  final datePosted = c.createdAt != null
                      ? DateTime.tryParse(c.createdAt!)
                      : null;

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _border),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.06),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [darkBlue, primaryColor],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: (avatarUrl != null &&
                                      avatarUrl.trim().isNotEmpty &&
                                      avatarUrl.toLowerCase() != 'null')
                                  ? CachedNetworkImage(
                                      imageUrl: avatarUrl.trim(),
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Center(
                                        child: Text(
                                          name.isNotEmpty
                                              ? name[0].toUpperCase()
                                              : '?',
                                          style: GoogleFonts.inter(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      errorWidget: (_, __, ___) => Center(
                                        child: Text(
                                          name.isNotEmpty
                                              ? name[0].toUpperCase()
                                              : '?',
                                          style: GoogleFonts.inter(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    )
                                  : Center(
                                      child: Text(
                                        name.isNotEmpty
                                            ? name[0].toUpperCase()
                                            : '?',
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: _text,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      ..._buildStarIcons(rating, size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        rating.toStringAsFixed(1),
                                        style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                            color: const Color(0xFF111827)),
                                      ),
                                      if (datePosted != null) ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          '• ${_getTimeAgo(datePosted)}',
                                          style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: _muted,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          comment,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xFF374151),
                            height: 1.45,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const darkBlue = Color(0xFF0D47A1);
    const primaryColor = Color(0xFF1976D2);
    final bg = selected ? primaryColor : Colors.white;
    final fg = selected ? Colors.white : darkBlue;
    final border = selected ? primaryColor : const Color(0xFFDCE4EE);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border, width: selected ? 0 : 1),
            boxShadow: [
              if (selected)
                BoxShadow(
                  color: primaryColor.withOpacity(0.28),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}

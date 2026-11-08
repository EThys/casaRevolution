import 'package:casa/controllers/AuthentificationCtrl.dart';
import 'package:casa/controllers/CotationController.dart';
import 'package:casa/controllers/ServiceController.dart';
import 'package:casa/models/SollicitationModel.dart';
import 'package:casa/utils/AppColors.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/review_eligibility.dart';
import 'package:casa/widgets/ReviewComposerSheet.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

/// Carte d’accueil pour un avis en attente.
/// Une seule demande à la fois, jamais en fenêtre bloquante.
/// « Plus tard » et la croix endorment le rappel une semaine.
/// Après trois jours vus sans action, le rappel se tait un mois.
class ReviewReminderCard extends StatefulWidget {
  const ReviewReminderCard({super.key});

  @override
  State<ReviewReminderCard> createState() => _ReviewReminderCardState();
}

class _ReviewPrefs {
  DateTime? quietUntil;
  final Map<int, DateTime> snoozeUntil = {};
  final Set<int> muted = {};
  final Map<int, int> impressions = {};
  final Map<int, String> lastDay = {};

  static _ReviewPrefs read(GetStorage storage) {
    final prefs = _ReviewPrefs();
    final raw = storage.read(_ReviewReminderCardState.storageKey);
    if (raw is! Map) return prefs;
    final map = Map<String, dynamic>.from(raw);
    prefs.quietUntil = DateTime.tryParse('${map['quietUntil'] ?? ''}');
    final snooze = map['snoozeUntil'];
    if (snooze is Map) {
      snooze.forEach((key, value) {
        final id = int.tryParse('$key');
        final at = DateTime.tryParse('$value');
        if (id != null && at != null) prefs.snoozeUntil[id] = at;
      });
    }
    final muted = map['muted'];
    if (muted is List) {
      for (final entry in muted) {
        final id = int.tryParse('$entry');
        if (id != null) prefs.muted.add(id);
      }
    }
    final impressions = map['impressions'];
    if (impressions is Map) {
      impressions.forEach((key, value) {
        final id = int.tryParse('$key');
        final count = int.tryParse('$value');
        if (id != null && count != null) prefs.impressions[id] = count;
      });
    }
    final lastDay = map['lastDay'];
    if (lastDay is Map) {
      lastDay.forEach((key, value) {
        final id = int.tryParse('$key');
        if (id != null && '$value'.isNotEmpty) prefs.lastDay[id] = '$value';
      });
    }
    return prefs;
  }

  Map<String, dynamic> toJson() => {
        'quietUntil': quietUntil?.toIso8601String(),
        'snoozeUntil': {
          for (final entry in snoozeUntil.entries)
            '${entry.key}': entry.value.toIso8601String(),
        },
        'muted': muted.toList(),
        'impressions': {
          for (final entry in impressions.entries) '${entry.key}': entry.value,
        },
        'lastDay': {
          for (final entry in lastDay.entries) '${entry.key}': entry.value,
        },
      };
}

class _ReviewReminderCardState extends State<ReviewReminderCard> {
  static const storageKey = 'review_reminder_state';
  static const _ratedKey = 'cotation_rated_sollicitation_ids';
  static const _later = Duration(days: 7);
  static const _month = Duration(days: 30);

  final GetStorage _storage = GetStorage();
  SollicitationModel? _item;
  int _others = 0;
  int? _requestedFor;
  bool _requestStarted = false;

  void _schedule(int? userId) {
    if (_requestStarted && _requestedFor == userId) return;
    _requestStarted = true;
    _requestedFor = userId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load(userId);
    });
  }

  Future<void> _load(int? userId) async {
    if (userId == null) {
      if (mounted) {
        setState(() {
          _item = null;
          _others = 0;
        });
      }
      return;
    }

    try {
      final mine = await context.read<ServiceController>().fetchUserSollicitations(
            silent: true,
          );
      if (!mounted) return;
      final cotations = await context.read<CotationController>().fetchPublicCotations(
            forceRefresh: false,
          );
      if (!mounted) return;

      final rated = _ratedIds();
      for (final review in cotations) {
        if (review.userId == userId && review.sollicitationId != null) {
          rated.add(review.sollicitationId!);
        }
      }

      final prefs = _ReviewPrefs.read(_storage);
      final now = DateTime.now();
      final waiting = mine.where((item) {
        if (!solicitationCanBeReviewed(item, userId: userId, alreadyRated: rated)) {
          return false;
        }
        final id = item.id!;
        if (prefs.muted.contains(id)) return false;
        final snooze = prefs.snoozeUntil[id];
        return snooze == null || !snooze.isAfter(now);
      }).toList();

      waiting.sort((a, b) {
        final da = reviewCalendarDay(a.endDate) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final db = reviewCalendarDay(b.endDate) ?? DateTime.fromMillisecondsSinceEpoch(0);
        return db.compareTo(da);
      });

      SollicitationModel? chosen;
      var others = 0;
      if (prefs.quietUntil == null || !prefs.quietUntil!.isAfter(now)) {
        final today = _dayKey(now);
        final still = <SollicitationModel>[];
        for (final item in waiting) {
          final id = item.id!;
          final seen = prefs.impressions[id] ?? 0;
          if (seen >= 3) {
            prefs.snoozeUntil[id] = now.add(_month);
            prefs.impressions[id] = 0;
            prefs.lastDay.remove(id);
            continue;
          }
          still.add(item);
        }
        if (still.isNotEmpty) {
          chosen = still.first;
          others = still.length - 1;
          final id = chosen.id!;
          if (prefs.lastDay[id] != today) {
            prefs.impressions[id] = (prefs.impressions[id] ?? 0) + 1;
            prefs.lastDay[id] = today;
          }
        }
        await _storage.write(storageKey, prefs.toJson());
      }

      if (!mounted) return;
      setState(() {
        _item = chosen;
        _others = others;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _item = null;
          _others = 0;
        });
      }
    }
  }

  Set<int> _ratedIds() {
    final raw = _storage.read(_ratedKey);
    final ids = <int>{};
    if (raw is List) {
      for (final entry in raw) {
        final id = int.tryParse('$entry');
        if (id != null && id > 0) ids.add(id);
      }
    }
    return ids;
  }

  Future<void> _rememberRated(int id) async {
    final ids = _ratedIds()..add(id);
    await _storage.write(_ratedKey, ids.toList());
  }

  Future<void> _saveQuiet(SollicitationModel item, {required bool mute}) async {
    final prefs = _ReviewPrefs.read(_storage);
    final id = item.id;
    final until = DateTime.now().add(_later);
    prefs.quietUntil = until;
    if (id != null) {
      if (mute) {
        prefs.muted.add(id);
      } else {
        prefs.snoozeUntil[id] = until;
      }
    }
    await _storage.write(storageKey, prefs.toJson());
    if (!mounted) return;
    setState(() {
      _item = null;
      _others = 0;
    });
  }

  String _dayKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<void> _rate(SollicitationModel item) async {
    final userId = context.read<AuthentificationCtrl>().user.userId;
    final sid = item.id;
    if (userId == null || sid == null) return;
    final ok = await showReviewComposer(
      context: context,
      userId: userId,
      sollicitationId: sid,
      serviceTitle: item.prestation?.title,
    );
    if (!mounted || !ok) return;
    await _rememberRated(sid);
    final prefs = _ReviewPrefs.read(_storage);
    prefs.quietUntil = DateTime.now().add(const Duration(days: 2));
    prefs.muted.add(sid);
    await _storage.write(storageKey, prefs.toJson());
    if (!mounted) return;
    setState(() {
      _item = null;
      _others = 0;
    });
    FancyNotification.show(
      context,
      'Merci, votre note aide les autres.',
      type: NotificationType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<AuthentificationCtrl>().user.userId;
    _schedule(userId);
    final item = _item;
    final title = item?.prestation?.title?.trim();
    final serviceName = (title == null || title.isEmpty) ? 'Ce service' : title;
    final dark = AppColors.isDarkMode(context);
    final muted = dark ? Colors.white70 : const Color(0xFF64748B);

    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: item == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
              child: Material(
                color: AppColors.cardBackgroundColor(context),
                elevation: 0,
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: const Color(0xFF1976D2).withOpacity(dark ? 0.35 : 0.14),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1976D2).withOpacity(dark ? 0.0 : 0.06),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 10, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFB300).withOpacity(0.16),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.star_rounded,
                                color: Color(0xFFF5A623),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Un service attend votre note',
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: dark ? Colors.white : const Color(0xFF0B1220),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$serviceName a été rendu. Quelques étoiles aident les prochaines personnes à choisir.',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        height: 1.4,
                                        color: muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Plus tard',
                              onPressed: () => _saveQuiet(item, mute: false),
                              icon: Icon(Icons.close_rounded, color: muted, size: 20),
                            ),
                          ],
                        ),
                        if (_others > 0) ...[
                          const SizedBox(height: 8),
                          Text(
                            _others == 1
                                ? 'Un autre service attend aussi, un peu plus tard.'
                                : '$_others autres services attendent aussi, un peu plus tard.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: muted,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () => _saveQuiet(item, mute: false),
                              child: Text(
                                'Plus tard',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  color: muted,
                                ),
                              ),
                            ),
                            const Spacer(),
                            FilledButton(
                              onPressed: () => _rate(item),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF1976D2),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Donner une note',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () => _saveQuiet(item, mute: true),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            child: Text(
                              'Ne plus rappeler ce service',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: muted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

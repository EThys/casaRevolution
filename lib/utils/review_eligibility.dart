import 'package:casa/models/SollicitationModel.dart';

/// Un avis d'intervention n'est possible qu'après acceptation,
/// une fois la date de fin passée. Le demandeur doit être le compte connecté.
bool solicitationCanBeReviewed(
  SollicitationModel item, {
  required int? userId,
  Set<int> alreadyRated = const {},
}) {
  final requester = item.userId ?? item.user?.userId;
  if (item.id == null || userId == null || requester != userId) return false;
  if (alreadyRated.contains(item.id)) return false;
  final status = (item.status ?? '').toUpperCase().trim();
  const allowed = {'APPROVED', 'ACCEPTED', 'COMPLETED'};
  if (!allowed.contains(status)) return false;
  final endDay = reviewCalendarDay(item.endDate);
  if (endDay == null) return false;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return endDay.isBefore(today);
}

/// Jour calendaire, sans décalage d’heure (une date `2026-11-08` reste le 8).
DateTime? reviewCalendarDay(String? raw) {
  final value = (raw ?? '').trim();
  if (value.length < 10) return null;
  final year = int.tryParse(value.substring(0, 4));
  final month = int.tryParse(value.substring(5, 7));
  final day = int.tryParse(value.substring(8, 10));
  if (year == null || month == null || day == null) return null;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  return DateTime(year, month, day);
}

SollicitationModel? firstReviewableSolicitation(
  Iterable<SollicitationModel> items, {
  required int? userId,
  required int? prestationId,
  Set<int> alreadyRated = const {},
  int? preferredId,
}) {
  final eligible = items.where((item) {
    if (prestationId != null) {
      final linked = item.prestationId ?? item.prestation?.id;
      if (linked != prestationId) return false;
    }
    return solicitationCanBeReviewed(
      item,
      userId: userId,
      alreadyRated: alreadyRated,
    );
  }).toList();
  if (eligible.isEmpty) return null;
  if (preferredId != null) {
    for (final item in eligible) {
      if (item.id == preferredId) return item;
    }
  }
  eligible.sort((a, b) {
    final da = DateTime.tryParse(a.endDate ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
    final db = DateTime.tryParse(b.endDate ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
    return db.compareTo(da);
  });
  return eligible.first;
}

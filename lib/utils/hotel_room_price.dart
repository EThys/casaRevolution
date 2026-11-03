import 'package:casa/models/PropertyModel.dart';

class HotelRoomPriceView {
  final String amount;
  final String period;

  const HotelRoomPriceView({required this.amount, required this.period});

  String get compact => period.isEmpty ? amount : '$amount · $period';
}

HotelRoomPriceView hotelRoomPriceView(HotelRoomModel room, PropertyModel hotel) {
  final period = hotelStayPeriodLabel(room.priceHeure);
  final price = room.price;
  if (price == null || price <= 0) {
    final raw = (room.priceHeure ?? '').trim();
    if (raw.isEmpty || raw.toLowerCase() == 'null') {
      return const HotelRoomPriceView(amount: 'Tarif sur demande', period: '');
    }
    if (period.isEmpty || period.toLowerCase() == raw.toLowerCase()) {
      return HotelRoomPriceView(amount: raw, period: '');
    }
    return HotelRoomPriceView(amount: raw, period: period);
  }

  final deviseId = room.deviseId ?? hotel.deviseId;
  final symbol = deviseId == 1
      ? 'FC'
      : deviseId == 2
          ? '\$'
          : (hotel.currency.trim().isNotEmpty ? hotel.currency : '\$');
  final amountText = price == price.roundToDouble()
      ? price.toStringAsFixed(0)
      : price.toStringAsFixed(2);
  return HotelRoomPriceView(amount: '$amountText $symbol', period: period);
}

/// Prix le plus bas des chambres disponibles, le plus récent en cas d’égalité.
/// Ex. « À partir de 25 $ ».
String? hotelStartingPriceLabel(PropertyModel hotel) {
  final rooms = <HotelRoomModel>[];
  for (final row in hotel.hotelStructure ?? const <HotelRoomStructure>[]) {
    final room = row.chambre;
    final price = room?.price;
    if (room == null || price == null || price <= 0) continue;
    if (room.available == false) continue;
    rooms.add(room);
  }
  if (rooms.isEmpty) return null;
  rooms.sort((a, b) {
    final byPrice = (a.price ?? 0).compareTo(b.price ?? 0);
    if (byPrice != 0) return byPrice;
    return (b.updatedAt ?? '').compareTo(a.updatedAt ?? '');
  });
  final amount = hotelRoomPriceView(rooms.first, hotel).amount.trim();
  if (amount.isEmpty || amount == 'Tarif sur demande') return null;
  return 'À partir de $amount';
}

/// « par heure », « par nuit », « par jour », ou le texte saisi tel quel.
String hotelStayPeriodLabel(String? raw) {
  final text = (raw ?? '').trim();
  if (text.isEmpty || text.toLowerCase() == 'null') return '';
  final lower = text.toLowerCase();
  if (lower.contains('heure') ||
      lower.contains('hour') ||
      lower.contains('/h') ||
      lower.contains(' / h')) {
    return 'par heure';
  }
  if (lower.contains('nuit') || lower.contains('night')) return 'par nuit';
  if (lower.contains('jour') || lower.contains('day')) return 'par jour';
  if (lower.contains('semaine') || lower.contains('week')) return 'par semaine';
  if (lower.contains('mois') || lower.contains('month')) return 'par mois';
  if (lower.contains('séjour') || lower.contains('sejour')) return 'par séjour';
  return text;
}

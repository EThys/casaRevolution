import 'dart:async';

/// Émis quand une notification temps réel concerne réservations ou sollicitations
/// (même flux STOMP que le web — pour rafraîchir les écrans sans recharger à la main).
class RealtimeRefreshHub {
  RealtimeRefreshHub._();
  static final RealtimeRefreshHub instance = RealtimeRefreshHub._();

  static const String reservations = 'reservations';
  static const String serviceSolicitations = 'service_solicitations';
  static const String payments = 'payments';

  final _controller = StreamController<String>.broadcast();

  Stream<String> get stream => _controller.stream;

  void emit(String channel) {
    if (!_controller.isClosed) {
      _controller.add(channel);
    }
  }
}

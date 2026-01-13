import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  // Singleton
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectionChangeController = StreamController<bool>.broadcast();

  Stream<bool> get connectionChange => _connectionChangeController.stream;

  void initialize() {
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      _checkConnection(results);
    });
  }

  void _checkConnection(List<ConnectivityResult> results) async {
    bool hasConnection = results.any((result) => 
      result == ConnectivityResult.mobile || 
      result == ConnectivityResult.wifi || 
      result == ConnectivityResult.ethernet);
      
    _connectionChangeController.add(hasConnection);
  }
  
  // Check once manually
  Future<bool> get isConnected async {
    final results = await _connectivity.checkConnectivity();
    return results.any((result) => 
      result != ConnectivityResult.none && result != ConnectivityResult.bluetooth);
  }
}

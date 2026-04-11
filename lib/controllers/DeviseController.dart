import 'package:casa/models/DeviseModel.dart';
import 'package:casa/utils/Endpoints.dart';
import 'package:casa/utils/StockageKeys.dart';
import 'package:casa/utils/requetes.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';

class DeviseController with ChangeNotifier {
  final GetStorage? stockage;
  List<DeviseModel> devises = [];
  bool isLoading = false;

  DeviseController({this.stockage}) {
    _loadInitialDevises();
  }

  void _loadInitialDevises() {
    // Check if we have cached devises
    final cached = stockage?.read(StockageKeys.devisesKey);
    if (cached != null && cached is Map && cached['devises'] != null) {
      try {
        devises = (cached['devises'] as List).map((e) => DeviseModel.fromJson(e)).toList();
      } catch (e) {
        print("Error parsing cached devises: $e");
      }
    }
    
    // If list is still empty, we set basic defaults but we'll fetch from API soon
    if (devises.isEmpty) {
      devises = [
        DeviseModel(id: 1, name: "Franc Congolais", code: "CDF", tauxLocal: 2200.0),
        DeviseModel(id: 2, name: "Dollar Americain", code: "USD", tauxLocal: 1.0),
      ];
    }
    notifyListeners();
  }

  Future<void> fetchDevises() async {
    isLoading = true;
    notifyListeners();

    try {
      final token = stockage?.read<String>(StockageKeys.tokenKey);
      final response = await getData(Endpoints.devises, token: token);
      
      if (response != null && response is Map && response['devises'] != null) {
        final List list = response['devises'];
        devises = list.map((e) => DeviseModel.fromJson(e)).toList();
        stockage?.write(StockageKeys.devisesKey, response);
      }
    } catch (e) {
      print("Error fetching devises: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  double convert(double amount, {required String fromCode, required String toCode}) {
    if (devises.isEmpty) return amount;
    
    // Find rates in the list
    final from = devises.firstWhere((d) => d.code == fromCode, orElse: () => _getFallback(fromCode));
    final to = devises.firstWhere((d) => d.code == toCode, orElse: () => _getFallback(toCode));
    
    if (fromCode == toCode) return amount;

    // Conversion: (amount / fromTaux) * toTaux
    // tauxLocal is relative to USD (USD = 1.0 usually)
    double fromTaux = from.tauxLocal ?? 1.0;
    double toTaux = to.tauxLocal ?? 1.0;

    return (amount / fromTaux) * toTaux;
  }

  DeviseModel _getFallback(String code) {
    if (code == "USD") return DeviseModel(code: "USD", tauxLocal: 1.0);
    if (code == "CDF") return DeviseModel(code: "CDF", tauxLocal: 2200.0);
    return DeviseModel(code: code, tauxLocal: 1.0);
  }
}

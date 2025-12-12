import 'package:flutter/material.dart';
import '../utils/requetes.dart';

class TypeAccountController with ChangeNotifier {
  List<dynamic> typeAccounts = [];
  bool loading = false;

  Future<void> fetchTypeAccounts() async {
    loading = true;
    notifyListeners();
    try {
      final response = await getData("account"); // https://server.casanayo.com/api/account
      if (response != null && response is Map<String, dynamic>) {
        typeAccounts = response['type_accounts'] ?? [];
      }
    } catch (e) {
      print("Erreur chargement type accounts: $e");
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}








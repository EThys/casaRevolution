import 'package:flutter/material.dart';
import '../utils/requetes.dart';

class TypeAccountController with ChangeNotifier {
  List<dynamic> typeAccounts = [];
  bool loading = false;

  Future<void> fetchTypeAccounts() async {
    loading = true;
    notifyListeners();
    try {
      final response = await getData("accounts/type", token: "");
      if (response != null && response is Map<String, dynamic>) {
        if (response['data'] != null) {
          typeAccounts = response['data'];
        } else {
           typeAccounts = [];
        }
      }
    } catch (e) {
      print("Erreur chargement type accounts: $e");
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}








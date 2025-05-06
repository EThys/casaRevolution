import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class NetworkUtils {
  /// Vérifie la connectivité Internet.
  static Future<bool> checkInternetConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      return await InternetConnectionChecker.instance.hasConnection;
    }
    return false;
  }

  /// Vérifie la connectivité Internet et affiche un SnackBar si non connecté.
  static Future<bool> checkAndShowSnackBarIfNoConnection(BuildContext context) async {
    bool isConnected = await checkInternetConnectivity();
    if (!isConnected) {
      // Affiche un SnackBar si aucune connexion Internet
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Row(
            children: [
              Icon(FontAwesomeIcons.wifi, color: Colors.white),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "Vous n'avez pas de connexion internet !",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return isConnected;
  }
}
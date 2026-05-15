import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:get_storage/get_storage.dart';
import 'firebase_options.dart';
import 'Apps/MonApllication.dart';
import 'services/ConnectivityService.dart';
import 'services/onesignal_service.dart';

void main() async {
  // IMPORTANT: tout (ensureInitialized + runApp) doit être dans la même Zone.
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    // Objectif: réduire le délai perçu à l'ouverture.
    // On garde le minimum bloquant avant le 1er frame (Firebase + storage),
    // puis on décale le rest e en arrière-plan.
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await GetStorage.init();

    // Crashlytics: activer la collecte + capturer erreurs sync/async.
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    runApp(MonApplication());

    // Init non-bloquants après lancement UI.
    Future<void>(() async {
      try {
        await initOneSignal();
      } catch (_) {}

      ConnectivityService().initialize();
      try {
        await initializeDateFormatting('fr_FR', null);
      } catch (_) {}
    });
  }, (error, stack) {
    // Ne pas laisser Crashlytics masquer la cause si Firebase n’est pas prêt.
    try {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    } catch (_) {
      FlutterError.dumpErrorToConsole(
        FlutterErrorDetails(exception: error, stack: stack),
      );
    }
  });
}
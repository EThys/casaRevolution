import 'package:casa/controllers/LocationController.dart';
import 'package:casa/controllers/PropertyCtrl.dart';
import 'package:casa/controllers/PropertyFavoriteCtrl.dart';
import 'package:casa/controllers/ReservationController.dart';
import 'package:casa/controllers/RegisterBailleurCtrl.dart';
import 'package:casa/controllers/RegisterCommissionnaireCtrl.dart';
import 'package:casa/controllers/RegisterLocataireCtrl.dart';
import 'package:casa/controllers/provider/FavoriteProvider.dart';
import 'package:casa/utils/database/FavoriteDatabaseHelper.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
// AJOUT: Import Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../controllers/AuthentificationCtrl.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../utils/Routes.dart';
import '../utils/RoutesManager.dart';
import '../utils/StockageKeys.dart';

class MonApplication extends StatelessWidget {
  final GetStorage _stockage = GetStorage();

  // AJOUT: Firebase Analytics
  static FirebaseAnalytics get analytics => FirebaseAnalytics.instance;
  static FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: analytics);

  @override
  Widget build(BuildContext context) {
    bool isFirstLaunch = _stockage.read(StockageKeys.firstLaunchKey) ?? true;
    var token = _stockage.read(StockageKeys.tokenKey);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthentificationCtrl(stockage: _stockage)),
        ChangeNotifierProvider(create: (_) => RegisterCommissionnaireCtrl()),
        ChangeNotifierProvider(create: (_) => RegisterBailleurCtrl()),
        ChangeNotifierProvider(create: (_) => RegisterLocataireCtrl()),
        ChangeNotifierProvider(create: (_) => PropertyController(stockage: _stockage)),
        ChangeNotifierProvider(create: (_) => ReservationController(stockage: _stockage)),
        ChangeNotifierProvider(create: (_) => PropertyFavoriteCtrl()),
        ChangeNotifierProvider(create: (_) => LocationController()),
        ChangeNotifierProvider(
          create: (context) {
            // CORRECTION: Utiliser la méthode getInstance() au lieu de .instance
            final databaseHelper = FavoriteDatabaseHelper.instance;
            final favoriteCtrl = PropertyFavoriteCtrl();
            return FavoriteProvider(databaseHelper, favoriteCtrl);
          },
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        useInheritedMediaQuery: true,

        // AJOUT: Firebase Analytics Observer
        navigatorObservers: [observer],

        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2A5C99),
            brightness: Brightness.light,
          ),
          fontFamily: GoogleFonts.inter().fontFamily,
          textTheme: TextTheme(
            displayLarge: TextStyle(
              fontSize: 57,
              fontWeight: FontWeight.w400,
              letterSpacing: -0.25,
            ),
            displayMedium: TextStyle(
              fontSize: 45,
              fontWeight: FontWeight.w400,
            ),
            displaySmall: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w400,
            ),
            headlineLarge: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w400,
            ),
            headlineMedium: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w400,
            ),
            headlineSmall: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w400,
            ),
            titleLarge: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w500,
            ),
            titleMedium: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.15,
            ),
            titleSmall: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.1,
            ),
            bodyLarge: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.5,
            ),
            bodyMedium: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.25,
            ),
            bodySmall: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.4,
            ),
            labelLarge: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.1,
            ),
            labelMedium: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
            labelSmall: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          appBarTheme: AppBarTheme(
            titleTextStyle: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              textStyle: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              textStyle: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            labelStyle: TextStyle(),
            hintStyle: TextStyle(),
            errorStyle: TextStyle(),
            floatingLabelStyle: TextStyle(),
          ),
        ),

        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2A5C99),
            brightness: Brightness.dark,
          ),
          fontFamily: GoogleFonts.inter().fontFamily,
          textTheme: TextTheme(
            displayLarge: TextStyle(
              fontSize: 57,
              fontWeight: FontWeight.w400,
              letterSpacing: -0.25,
              color: Colors.white,
            ),
            displayMedium: TextStyle(
              fontSize: 45,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
            displaySmall: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
            headlineLarge: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
            headlineMedium: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
            headlineSmall: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
            titleLarge: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
            titleMedium: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.15,
              color: Colors.white,
            ),
            titleSmall: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.1,
              color: Colors.white,
            ),
            bodyLarge: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.5,
              color: Colors.white,
            ),
            bodyMedium: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.25,
              color: Colors.white,
            ),
            bodySmall: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.4,
              color: Colors.white70,
            ),
            labelLarge: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.1,
              color: Colors.white,
            ),
            labelMedium: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
              color: Colors.white,
            ),
            labelSmall: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
              color: Colors.white70,
            ),
          ),
        ),

        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('fr', 'FR'),
          Locale('en', 'US'),
        ],
        onGenerateRoute: RoutesManager.route,
        initialRoute: Routes.splashRoute,
      ),
    );
  }
}
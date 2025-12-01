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
        ChangeNotifierProvider(create: (_) => LocationController()),
        ChangeNotifierProvider<PropertyFavoriteCtrl>(
          create: (_) => PropertyFavoriteCtrl(stockage: _stockage),
        ),

        ChangeNotifierProvider(create: (_) => LocationController()),
        ChangeNotifierProxyProvider<PropertyFavoriteCtrl, FavoriteProvider>(
          create: (context) {
            final databaseHelper = FavoriteDatabaseHelper.instance;
            final favoriteCtrl = Provider.of<PropertyFavoriteCtrl>(context, listen: false);
            return FavoriteProvider(databaseHelper, favoriteCtrl);
          },
          update: (context, favoriteCtrl, previous) => previous!,
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        useInheritedMediaQuery: true,

        // SOLUTION: Forcer le mode clair
        themeMode: ThemeMode.light, // ← FORCER LE MODE CLAIR

        // AJOUT: Firebase Analytics Observer
        navigatorObservers: [observer],

        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light, // ← S'ASSURER QUE C'EST CLAIR
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
            backgroundColor: Colors.white,
            titleTextStyle: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
            iconTheme: IconThemeData(color: Colors.black),
          ),
          scaffoldBackgroundColor: Colors.white,
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
            fillColor: Colors.white,
            filled: true,
          ),
        ),

        // SUPPRIMER le darkTheme ou le commenter
        // darkTheme: ThemeData(...),

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
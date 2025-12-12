import 'package:casa/controllers/LocationController.dart';
import 'package:casa/controllers/PropertyCtrl.dart';
import 'package:casa/controllers/PropertyFavoriteCtrl.dart';
import 'package:casa/controllers/ReservationController.dart';
import 'package:casa/controllers/RegisterBailleurCtrl.dart';
import 'package:casa/controllers/RegisterCommissionnaireCtrl.dart';
import 'package:casa/controllers/RegisterLocataireCtrl.dart';
import 'package:casa/controllers/RegisterMajordomeCtrl.dart';
import 'package:casa/controllers/RegisterPlombierCtrl.dart';
import 'package:casa/controllers/RegisterElectricienCtrl.dart';
import 'package:casa/controllers/RegisterSalubriteCtrl.dart';
import 'package:casa/controllers/RegisterPeintreCtrl.dart';
import 'package:casa/controllers/RegisterCarreleurCtrl.dart';
import 'package:casa/controllers/RegisterMenuisierCtrl.dart';
import 'package:casa/controllers/RegisterFrigoristeCtrl.dart';
import 'package:casa/controllers/RegisterAjusteurCtrl.dart';
import 'package:casa/controllers/RegisterArchitecteCtrl.dart';
import 'package:casa/controllers/RegisterChauffeurCtrl.dart';
import 'package:casa/controllers/RegisterDemenagementCtrl.dart';
import 'package:casa/controllers/TypeAccountController.dart';
import 'package:casa/controllers/ServiceController.dart';
import 'package:casa/controllers/ServiceRequestController.dart';
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
import '../controllers/ForgotPasswordController.dart';
import '../controllers/ThemeController.dart';
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
        ChangeNotifierProvider(create: (_) => ThemeController()),
        ChangeNotifierProvider(create: (_) => AuthentificationCtrl(stockage: _stockage)),
        ChangeNotifierProvider(create: (_) => ForgotPasswordController()),
        ChangeNotifierProvider(create: (_) => RegisterCommissionnaireCtrl()),
        ChangeNotifierProvider(create: (_) => RegisterBailleurCtrl()),
        ChangeNotifierProvider(create: (_) => RegisterLocataireCtrl()),
        ChangeNotifierProvider(create: (_) => RegisterMajordomeCtrl()), 
        ChangeNotifierProvider(create: (_) => RegisterPlombierCtrl()),
        ChangeNotifierProvider(create: (_) => RegisterElectricienCtrl()),
        ChangeNotifierProvider(create: (_) => RegisterSalubriteCtrl()),
        ChangeNotifierProvider(create: (_) => RegisterPeintreCtrl()),
        ChangeNotifierProvider(create: (_) => RegisterCarreleurCtrl()),
        ChangeNotifierProvider(create: (_) => RegisterMenuisierCtrl()),
        ChangeNotifierProvider(create: (_) => RegisterFrigoristeCtrl()),
        ChangeNotifierProvider(create: (_) => RegisterAjusteurCtrl()),
        ChangeNotifierProvider(create: (_) => RegisterArchitecteCtrl()),
        ChangeNotifierProvider(create: (_) => RegisterChauffeurCtrl()),
        ChangeNotifierProvider(create: (_) => RegisterDemenagementCtrl()),
        ChangeNotifierProvider(create: (_) => TypeAccountController()),
        ChangeNotifierProvider(create: (_) => PropertyController(stockage: _stockage)),
        ChangeNotifierProvider(create: (_) => ReservationController(stockage: _stockage)),
        ChangeNotifierProvider(create: (_) => LocationController()),
        ChangeNotifierProvider(create: (_) => ServiceController(stockage: _stockage)),
        ChangeNotifierProvider(create: (_) => ServiceRequestController(stockage: _stockage)),
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
      child: Consumer<ThemeController>(
        builder: (context, themeController, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            useInheritedMediaQuery: true,

            // Utiliser le themeMode du controller
            themeMode: themeController.themeMode,

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

        // Thème sombre professionnel
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1976D2),
            brightness: Brightness.dark,
            primary: const Color(0xFF1976D2),
            secondary: const Color(0xFF64B5F6),
            surface: const Color(0xFF1E1E1E),
            onSurface: Colors.white,
            onPrimary: Colors.white,
            onSecondary: Colors.white,
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
              color: Colors.white70,
            ),
            bodyMedium: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.25,
              color: Colors.white70,
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
              color: Colors.white,
            ),
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: const Color(0xFF1A1D26),
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            titleTextStyle: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
            iconTheme: const IconThemeData(color: Colors.white),
            actionsIconTheme: const IconThemeData(color: Colors.white),
          ),
          scaffoldBackgroundColor: const Color(0xFF121212),
          cardColor: const Color(0xFF1E1E1E),
          dialogBackgroundColor: const Color(0xFF1E1E1E),
          bottomSheetTheme: const BottomSheetThemeData(
            backgroundColor: Color(0xFF1E1E1E),
            modalBackgroundColor: Color(0xFF1E1E1E),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
              elevation: 2,
              shadowColor: Colors.black.withOpacity(0.3),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF64B5F6),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF64B5F6),
              side: const BorderSide(color: Color(0xFF64B5F6)),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            labelStyle: const TextStyle(color: Colors.white70),
            hintStyle: const TextStyle(color: Colors.white54),
            errorStyle: TextStyle(color: Colors.red[300]),
            floatingLabelStyle: const TextStyle(color: Color(0xFF64B5F6)),
            fillColor: const Color(0xFF1E1E1E),
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.red[300]!),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.red[300]!, width: 2),
            ),
          ),
          dividerColor: Colors.white24,
          dividerTheme: const DividerThemeData(
            color: Colors.white24,
            thickness: 1,
            space: 1,
          ), 
          cardTheme: CardThemeData(
            color: const Color(0xFF1E1E1E),
            elevation: 2,
            shadowColor: Colors.black.withOpacity(0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ), 
          ),
          chipTheme: ChipThemeData(
            backgroundColor: const Color(0xFF2C2C2C),
            selectedColor: const Color(0xFF1976D2), 
            labelStyle: const TextStyle(color: Colors.white70),
            secondaryLabelStyle: const TextStyle(color: Colors.white),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          iconTheme: const IconThemeData(
            color: Colors.white70,
            size: 24,
          ),
          listTileTheme: const ListTileThemeData(
            textColor: Colors.white70,
            iconColor: Colors.white70,
          ),
          switchTheme: SwitchThemeData(
            thumbColor: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.selected)) {
                return const Color(0xFF1976D2);
              }
              return Colors.grey[600];
            }),
            trackColor: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.selected)) {
                return const Color(0xFF1976D2).withOpacity(0.5);
              }
              return Colors.grey[800];
            }),
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
        initialRoute: Routes.bottomPageRoute,
          );
        },
      ),
    );
  }
}
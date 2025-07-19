import 'package:casa/controllers/PropertyCtrl.dart';
import 'package:casa/controllers/PropertyVisitCtrl.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../controllers/AuthentificationCtrl.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../utils/Routes.dart';
import '../utils/RoutesManager.dart';
import '../utils/StockageKeys.dart';
//import 'package:alice/alice.dart';

//Alice alice = Alice( showNotification: true);

class MonApplication extends StatelessWidget {
  final GetStorage _stockage = GetStorage();

  @override
  Widget build(BuildContext context) {
    var token = _stockage.read(StockageKeys.tokenKey);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthentificationCtrl(stockage: _stockage)),
        ChangeNotifierProvider(create: (_) => PropertyController(stockage: _stockage)),
        ChangeNotifierProvider(create: (_) => PropertyVisitCtrl(stockage: _stockage)),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        useInheritedMediaQuery: true, // pour support dynamique de dark mode
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2A5C99),
            brightness: Brightness.light,
          ),
          textTheme: GoogleFonts.interTextTheme(),
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
        initialRoute: Routes.loginRoute,
      ),
    );
  }
}


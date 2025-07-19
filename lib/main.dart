import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:get_storage/get_storage.dart';

import 'Apps/MonApllication.dart';


void main() async {
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
  );
  await GetStorage.init();
  initializeDateFormatting().then((_) => runApp(MonApplication()));
}





// import 'package:casa/screens/BottomNavBar.dart';
// import 'package:casa/screens/HomePage.dart';
// import 'package:casa/screens/BookingHistoryPage.dart';
// import 'package:casa/screens/BookingVisitPage.dart';
// import 'package:casa/screens/CategoryPropertiesPage.dart';
// import 'package:casa/screens/CreatePropertyPost.dart';
// import 'package:casa/screens/FavoritesPage.dart';
// import 'package:casa/screens/OnboardingPage.dart';
// import 'package:casa/screens/PropertySearchPage.dart';
// import 'package:casa/screens/auth/LoginScreen.dart';
// import 'package:casa/screens/auth/RegisterScreen.dart';
// import 'package:flutter/material.dart';
// import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:intl/date_symbol_data_local.dart';
//
// import 'screens/PropertyDetailPage.dart';
//
// void main() {
//   initializeDateFormatting().then((_) => runApp(MyApp()));
// }
//
//
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//
//     final categories = [
//       {'icon': FontAwesomeIcons.building, 'label': 'Appartements'},
//       {'icon': FontAwesomeIcons.house, 'label': 'Maisons'},
//       {'icon': FontAwesomeIcons.houseChimney, 'label': 'Villas'},
//       {'icon': FontAwesomeIcons.buildingColumns, 'label': 'Bureaux'},
//       {'icon': FontAwesomeIcons.umbrellaBeach, 'label': 'Vacances'},
//       {'icon': FontAwesomeIcons.city, 'label': 'Résidences'},
//     ];
//
//     final Property sampleProperty = Property(
//       id: '1',
//       title: 'Magnifique appartement lumineux à Lemba',
//       address: '15 Rue de la foire, 75004 lemba',
//       price: 1200,
//       isForRent: true,
//       images: [
//         'assets/images/one.jpg',
//         'assets/images/two.jpg',
//         'assets/images/three.jpg'
//       ],
//       bedrooms: 2,
//       bathrooms: 1,
//       area: 75,
//       floor: 3,
//       description: 'Cet appartement lumineux de 75m² situé en plein cœur de Kinshasa offre une vue imprenable sur les toits de la capitale...',
//       location: LatLng(48.8566, 2.3522),
//       agentName: 'Agence Lemba lifuti ',
//       agentBio: 'Spécialiste des biens kinois depuis 15 ans',
//       rating: 4.5,
//       similarProperties: [
//         Property(
//           id: '2',
//           title: 'Studio moderne hypercentre',
//           address: '22 Rue Matamba, 75001 Ngaba',
//           price: 850,
//           isForRent: true,
//           images: [
//             'assets/images/one.jpg',
//             'assets/images/two.jpg',
//             'assets/images/three.jpg'
//           ],
//           bedrooms: 1,
//           bathrooms: 1,
//           area: 32,
//           floor: 2,
//           description: 'Studio entièrement rénové avec cuisine ouverte et espace optimisé. Parquet ancien et grande fenêtre donnant sur cour calme.',
//           location: LatLng(48.8635, 2.3475),
//           agentName: 'Agence Limete Bonganga',
//           agentBio: 'Spécialiste depuis 15 ans',
//           rating: 4.2,
//           similarProperties: [], // Laisser vide pour éviter la récursion
//         ),
//         Property(
//           id: '3',
//           title: 'Duplex loft Marais',
//           address: '40 Rue du livre, 75004 Gombe',
//           price: 1800,
//           isForRent: true,
//           images: [
//             'assets/images/one.jpg',
//             'assets/images/two.jpg',
//             'assets/images/three.jpg'
//           ],
//           bedrooms: 1,
//           bathrooms: 1,
//           area: 65,
//           floor: 4,
//           description: 'Exceptionnel loft duplex dans le Marais avec mezzanine. Hauteur sous plafond 4m, poutres apparentes et grandes baies vitrées.',
//           location: LatLng(48.8575, 2.3585),
//           agentName: 'Agence Ngaba Molakisi',
//           agentBio: 'Spécialiste depuis 15 ans',
//           rating: 4.7,
//           similarProperties: [],
//         ),
//         Property(
//           id: '4',
//           title: 'Appartement haussmannien rénové',
//           address: '12 Avenue de l\'Opéra, 75002 Ngaba ',
//           price: 2500,
//           isForRent: true,
//           images: [
//             'assets/images/one.jpg',
//             'assets/images/two.jpg',
//             'assets/images/three.jpg'
//           ],
//           bedrooms: 2,
//           bathrooms: 2,
//           area: 90,
//           floor: 1,
//           description: 'Authentique appartement haussmannien entièrement rénové avec cheminée d\'époque, moulures et parquet Versailles. Séjour de 35m² avec double exposition.',
//           location: LatLng(48.8667, 2.3333),
//           agentName: 'Agence Gombe solution',
//           agentBio: 'Spécialiste depuis 15 ans',
//           rating: 4.9,
//           similarProperties: [],
//         ),
//       ],
//     );
//
//     return MaterialApp(
//         theme: ThemeData(
//           primarySwatch: Colors.blue,
//           colorScheme: ColorScheme.fromSeed(
//             seedColor: Colors.blue,
//             primary: const Color(0xFF2A5C99),
//             secondary: const Color(0xFFE6B33D),
//             error: const Color(0xFFD93E30),
//           ),
//           textTheme: GoogleFonts.openSansTextTheme(
//             Theme.of(context).textTheme,
//           ),
//         ),
//         debugShowCheckedModeBanner: false,
//         home:  CreatePropertyPostPage()//CreatePropertyPostPage()//BookingHistoryPage()//BookVisitPage(property: sampleProperty, )//LawDetailPage(law: law) ,
//     );
//   }
// }
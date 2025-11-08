
import 'package:casa/models/PropertyModel.dart';
import 'package:casa/screens/ParrainagePage.dart';
import 'package:casa/screens/BookingHistoryPage.dart';
import 'package:casa/screens/BookingVisitPage.dart';
import 'package:casa/screens/CommissionDashboardPage.dart';
import 'package:casa/screens/CreatePropertyPostPage.dart';
import 'package:casa/screens/HomePage.dart';
import 'package:casa/screens/PropertyDetailPage.dart';
import 'package:casa/screens/Splashcreen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../screens/BottomNavBar.dart';
import '../screens/OnboardingPage.dart';
import '../screens/auth/LoginScreen.dart';
import '../screens/auth/RegisterScreen.dart';
import 'Routes.dart';


class RoutesManager {
  static Route route(RouteSettings r) {
    switch (r.name) {
      case Routes.onbordingRoute:
        return MaterialPageRoute(builder: (_)=>OnboardingScreen());
      case Routes.loginRoute:
        return MaterialPageRoute(builder: (_)=>LoginScreen());
      case Routes.registerRoute:
        return MaterialPageRoute(builder: (_)=>UserRegistrationPage());
      case Routes.detailPageRoute:
        final PropertyModel property = r.arguments as PropertyModel;
        return MaterialPageRoute(builder: (_)=>PropertyDetailPage(property: property));
      case Routes.homeRoute:
        return MaterialPageRoute(builder: (_)=>HomePage());
      case Routes.splashRoute:
        return MaterialPageRoute(builder: (_)=>SplashScreen());
      case Routes.bottomPageRoute:
        return MaterialPageRoute(builder: (_)=>BottomNavBar());
      case Routes.commissionnaireDashboardPageRoute:
        return MaterialPageRoute(builder: (_)=>CommissionDashboardPage());
      case Routes.bookingVisitPageRoute:
        final PropertyModel property = r.arguments as PropertyModel;
        return MaterialPageRoute(builder: (_)=>BookingVisitPage(property: property));
      case Routes.bookingHistoryPageRoute:
        return MaterialPageRoute(builder: (_)=>BookingHistoryPage());
      case Routes.ParrainagePageRoute:
        return MaterialPageRoute(builder: (_)=>ParrainagePage());
      case Routes.createPropertyRoute:
        return MaterialPageRoute(builder: (_)=>CreatePropertyPostPage());
      // case Routes.visitPageRoute:
      //   final PropertyModel property = r.arguments as PropertyModel;
      //   return MaterialPageRoute(builder: (_)=>BookingVisitPage(property: property));
      default:
        return MaterialPageRoute(builder: (_) =>OnboardingScreen());
    }
  }
}

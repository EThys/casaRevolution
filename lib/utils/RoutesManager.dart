
import 'package:casa/models/PropertyModel.dart';
import 'package:casa/screens/FavoritesPage.dart';
import 'package:casa/screens/ParrainagePage.dart';
import 'package:casa/screens/BookingHistoryPage.dart';
import 'package:casa/screens/BookingVisitPage.dart';
import 'package:casa/screens/CommissionDashboardPage.dart';
import 'package:casa/screens/CreatePropertyPostPage.dart';
import 'package:casa/screens/EditPropertyPage.dart';
import 'package:casa/screens/HomePage.dart';
import 'package:casa/screens/PropertyDetailPage.dart';
import 'package:casa/screens/MyPropertiesPage.dart';
import 'package:casa/screens/MyServicesPage.dart';
import 'package:casa/screens/Splashcreen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../screens/BottomNavBar.dart';
import '../screens/OnboardingPage.dart';
import '../screens/auth/LoginScreen.dart';
import '../screens/auth/RegisterScreen.dart';
import '../screens/auth/ForgotPasswordScreen.dart';
import '../screens/auth/OTPVerificationScreen.dart';
import '../screens/auth/ResetPasswordScreen.dart';

import '../screens/CreateServicePostPage.dart';
import '../screens/QuickServiceRequestPage.dart';
import '../screens/AllReviewsPage.dart';
import '../screens/ServiceRequestDetailPage.dart';
import '../screens/MyServiceRequestsPage.dart';
import '../screens/ServiceRequestsForProvidersPage.dart';
import '../screens/RequestInterventionPage.dart';
import '../screens/NotificationPage.dart';
import '../screens/ServiceDetailPage.dart';
import '../screens/CreateAgencePage.dart';
import '../models/ServiceModel.dart';
import '../models/ServiceRequestModel.dart';
import '../models/PrestationModel.dart';
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
        if (r.arguments is Map<String, dynamic>) {
          final Map<String, dynamic> args = r.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (_) => PropertyDetailPage(
              property: args['property'] as PropertyModel,
              heroTag: args['heroTag'] as String?,
            ),
          );
        }
        final PropertyModel property = r.arguments as PropertyModel;
        return MaterialPageRoute(builder: (_) => PropertyDetailPage(property: property));
      case Routes.homeRoute:
        return MaterialPageRoute(builder: (_)=>HomePage());
      case Routes.splashRoute:
        return MaterialPageRoute(builder: (_)=>SplashScreen());
      case Routes.bottomPageRoute:
        final args = r.arguments as Map<String, dynamic>?;
        final bool shouldRefresh = args?['shouldRefresh'] ?? false;
        return MaterialPageRoute(builder: (_)=>BottomNavBar(shouldRefresh: shouldRefresh));
      case Routes.commissionnaireDashboardPageRoute:
        return MaterialPageRoute(builder: (_)=>CommissionDashboardPage());
      case Routes.bookingVisitPageRoute:
        final dynamic property = r.arguments;
        return MaterialPageRoute(builder: (_)=>BookingVisitPage(property: property));
      case Routes.bookingHistoryPageRoute:
        return MaterialPageRoute(builder: (_)=>BookingHistoryPage());
      case Routes.ParrainagePageRoute:
        return MaterialPageRoute(builder: (_)=>ParrainagePage());
      case Routes.favoriteRoute:
        return MaterialPageRoute(builder: (_)=>FavoritesPage());
      case Routes.myPropertiesRoute:
        return MaterialPageRoute(builder: (_)=>MyPropertiesPage());
      case Routes.myServicesRoute:
        return MaterialPageRoute(builder: (_)=>MyServicesPage());
      case Routes.createPropertyRoute:
        return MaterialPageRoute(builder: (_)=>CreatePropertyPostPage());
      case Routes.editPropertyRoute:
        return MaterialPageRoute(builder: (_)=>EditPropertyPage(property: r.arguments as PropertyModel));
      case Routes.forgotPasswordRoute:
        return MaterialPageRoute(builder: (_)=>ForgotPasswordScreen());
      case Routes.otpVerificationRoute:
        final Map<String, dynamic>? args = r.arguments as Map<String, dynamic>?;
        if (args != null && args['phoneNumber'] != null) {
          return MaterialPageRoute(
            builder: (_)=>OTPVerificationScreen(phoneNumber: args['phoneNumber']),
          );
        } else {
          // Si pas d'arguments, rediriger vers forgot password
          return MaterialPageRoute(builder: (_)=>ForgotPasswordScreen());
        }
      case Routes.resetPasswordRoute:
        final Map<String, dynamic>? args = r.arguments as Map<String, dynamic>?;
        if (args != null && args['userId'] != null) {
          return MaterialPageRoute(
            builder: (_)=>ResetPasswordScreen(
              userId: args['userId'] as int,
            ),
          );
        } else {
          // Si pas d'arguments, rediriger vers forgot password
          return MaterialPageRoute(builder: (_)=>ForgotPasswordScreen());
        }
      case Routes.createServiceRoute:
        return MaterialPageRoute(builder: (_)=>CreateServicePostPage());
      case Routes.createServicePostRoute:
        return MaterialPageRoute(builder: (_)=>CreateServicePostPage());
      case Routes.quickServiceRequestRoute:
        return MaterialPageRoute(builder: (_)=>QuickServiceRequestPage());
      case Routes.allReviewsRoute:
        final ServiceModel service = r.arguments as ServiceModel;
        return MaterialPageRoute(builder: (_)=>AllReviewsPage(service: service));
      case Routes.serviceRequestDetailRoute:
        final ServiceRequestModel request = r.arguments as ServiceRequestModel;
        return MaterialPageRoute(builder: (_)=>ServiceRequestDetailPage(request: request));
      case Routes.myServiceRequestsRoute:
        return MaterialPageRoute(builder: (_)=>MyServiceRequestsPage());
      case Routes.serviceRequestsForProvidersRoute:
        return MaterialPageRoute(builder: (_)=>ServiceRequestsForProvidersPage());
      case Routes.requestInterventionRoute:
        final PrestationModel service = r.arguments as PrestationModel;
        return MaterialPageRoute(builder: (_)=>RequestInterventionPage(service: service));
      case Routes.notificationPageRoute:
        return MaterialPageRoute(builder: (_)=>NotificationsPage());
      case Routes.serviceDetail:
        final PrestationModel service = r.arguments as PrestationModel;
        return MaterialPageRoute(builder: (_)=>ServiceDetailPage(service: service));
      case Routes.createAgenceRoute:
        return MaterialPageRoute(builder: (_)=>CreateAgencePage());
      // case Routes.visitPageRoute:
      //   final PropertyModel property = r.arguments as PropertyModel;
      //   return MaterialPageRoute(builder: (_)=>BookingVisitPage(property: property));
      default:
        return MaterialPageRoute(builder: (_) =>OnboardingScreen());
    }
  }
}

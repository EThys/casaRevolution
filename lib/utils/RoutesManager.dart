
import 'package:casa/models/PropertyModel.dart';
import 'package:casa/utils/property_detail_navigation.dart';
import 'package:casa/screens/FavoritesPage.dart';
import 'package:casa/screens/ParrainagePage.dart';
import 'package:casa/screens/BookingHistoryPage.dart';
import 'package:casa/screens/BookingVisitPage.dart';
import 'package:casa/screens/CommissionDashboardPage.dart';
import 'package:casa/screens/CreatePropertyPostPage.dart';
import 'package:casa/screens/EditPropertyPage.dart';
import 'package:casa/screens/HomePage.dart';
import 'package:casa/screens/HotelDetailPage.dart';
import 'package:casa/screens/PropertyDetailPage.dart';
import 'package:casa/screens/MyPropertiesPage.dart';
import 'package:casa/screens/MyHotelsPage.dart';
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
import '../screens/PrestationIdDetailLoader.dart';
import '../screens/CreateAgencePage.dart';
import '../screens/HelpSupportPage.dart';
import '../screens/PaymentSubscriptionPage.dart';
import '../screens/PaymentHistoryPage.dart';
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
        final Object? args = r.arguments;
        if (args is Map<String, dynamic>) {
          final map = args;
          final raw = map['property'];
          if (raw is PropertyModel) {
            final p = raw;
            if (p.propertyTypeId == 9) {
              return MaterialPageRoute(
                builder: (_) => EnrichedTerrainDetailHost(
                  property: p,
                  heroTag: map['heroTag'] as String?,
                ),
              );
            }
            if (p.propertyTypeId == 5) {
              return MaterialPageRoute(
                builder: (_) => HotelDetailPage(
                  property: p,
                  heroTag: map['heroTag'] as String?,
                ),
              );
            }
            return MaterialPageRoute(
              builder: (_) => PropertyDetailPage(
                property: p,
                heroTag: map['heroTag'] as String?,
              ),
            );
          }
          final pid = map['propertyId'] ?? map['property_id'];
          if (pid != null) {
            final id = int.tryParse(pid.toString());
            if (id != null) {
              final tidRaw = map['propertyTypeId'] ?? map['property_type_id'];
              final typeId =
                  tidRaw != null ? int.tryParse(tidRaw.toString()) : null;
              return MaterialPageRoute(
                builder: (_) => PropertyIdDetailLoader(
                  propertyId: id,
                  propertyTypeId: typeId,
                ),
              );
            }
          }
          return MaterialPageRoute(
            builder: (_) => const Scaffold(
              body: Center(
                child: Text('Navigation vers le détail : données invalides.'),
              ),
            ),
          );
        }
        if (args is PropertyModel) {
          final property = args;
          if (property.propertyTypeId == 9) {
            return MaterialPageRoute(
              builder: (_) => EnrichedTerrainDetailHost(property: property),
            );
          }
          if (property.propertyTypeId == 5) {
            return MaterialPageRoute(
              builder: (_) => HotelDetailPage(property: property),
            );
          }
          return MaterialPageRoute(
            builder: (_) => PropertyDetailPage(property: property),
          );
        }
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(
              child: Text('Navigation vers le détail : arguments manquants.'),
            ),
          ),
        );
      case Routes.hotelDetailPageRoute:
        final Object? hArgs = r.arguments;
        if (hArgs is Map<String, dynamic>) {
          final raw = hArgs['property'];
          if (raw is PropertyModel) {
            return MaterialPageRoute(
              builder: (_) => HotelDetailPage(
                property: raw,
                heroTag: hArgs['heroTag'] as String?,
              ),
            );
          }
        }
        if (hArgs is PropertyModel) {
          return MaterialPageRoute(
            builder: (_) => HotelDetailPage(property: hArgs),
          );
        }
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Hôtel : données invalides.')),
          ),
        );
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
        final dynamic args = r.arguments;
        if (args is Map<String, dynamic>) {
          final prop = args['property'];
          final cid = args['chambreId'];
          final int? chambreId = cid is int
              ? cid
              : (cid != null ? int.tryParse(cid.toString()) : null);
          final agenceVac = args['agenceVacanceBooking'] == true;
          final initialDate = args['initialVacanceDate']?.toString();
          final initialHeure = args['initialVacanceHeure']?.toString();
          return MaterialPageRoute(
            builder: (_) => BookingVisitPage(
              property: prop ?? args,
              chambreId: chambreId,
              agenceVacanceBooking: agenceVac,
              initialVacanceDate: initialDate,
              initialVacanceHeure: initialHeure,
            ),
          );
        }
        return MaterialPageRoute(
          builder: (_) => BookingVisitPage(property: args),
        );
      case Routes.bookingHistoryPageRoute:
        final bhArgs = r.arguments;
        var initialHostView = false;
        int? initialTabIndex;
        if (bhArgs is Map && bhArgs['initialHostView'] == true) {
          initialHostView = true;
        }
        if (bhArgs is Map && bhArgs['initialTabIndex'] != null) {
          initialTabIndex = int.tryParse(bhArgs['initialTabIndex'].toString());
        }
        return MaterialPageRoute(
          builder: (_) => BookingHistoryPage(
            initialHostView: initialHostView,
            initialTabIndex: initialTabIndex,
          ),
        );
      case Routes.ParrainagePageRoute:
        return MaterialPageRoute(builder: (_)=>ParrainagePage());
      case Routes.favoriteRoute:
        return MaterialPageRoute(builder: (_)=>FavoritesPage());
      case Routes.myPropertiesRoute:
        return MaterialPageRoute(builder: (_)=>MyPropertiesPage());
      case Routes.myHotelsRoute:
        return MaterialPageRoute(builder: (_)=> const MyHotelsPage());
      case Routes.myServicesRoute:
        final msArgs = r.arguments;
        int? msTab;
        if (msArgs is Map && msArgs['tab'] is int) {
          msTab = msArgs['tab'] as int;
        } else if (msArgs is int) {
          msTab = msArgs;
        }
        return MaterialPageRoute(
          builder: (_) => MyServicesPage(initialTabIndex: msTab),
        );
      case Routes.createPropertyRoute:
        final cpArgs = r.arguments;
        final openAfterAgency = cpArgs is Map &&
            cpArgs['openAfterAgencyVacanceStep2'] == true;
        return MaterialPageRoute(
          builder: (_) => CreatePropertyPostPage(
            openAfterAgencyVacanceStep2: openAfterAgency,
          ),
        );
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
        final args = r.arguments;
        if (args is Map) {
          final pidRaw = args['prestationId'] ?? args['prestation_id'];
          final prestationId =
              pidRaw != null ? int.tryParse(pidRaw.toString()) : null;
          if (prestationId != null) {
            int? sollicitationId;
            final sid = args['sollicitationId'] ?? args['sollicitation_id'];
            if (sid != null) {
              sollicitationId = int.tryParse(sid.toString());
            }
            final typeName = args['serviceTypeName']?.toString();
            return MaterialPageRoute(
              builder: (_) => PrestationIdDetailLoader(
                prestationId: prestationId,
                sollicitationId: sollicitationId,
                serviceTypeName: typeName,
              ),
            );
          }
          final raw = args['service'];
          if (raw is PrestationModel) {
            int? sollicitationId;
            final sid = args['sollicitationId'] ?? args['sollicitation_id'];
            if (sid != null) {
              sollicitationId = int.tryParse(sid.toString());
            }
            return MaterialPageRoute(
              builder: (_) => ServiceDetailPage(
                service: raw,
                sollicitationId: sollicitationId,
              ),
            );
          }
          return MaterialPageRoute(
            builder: (_) => const Scaffold(
              body: Center(
                child: Text('Navigation vers le détail : données invalides.'),
              ),
            ),
          );
        }
        if (args is! PrestationModel) {
          return MaterialPageRoute(builder: (_) => OnboardingScreen());
        }
        return MaterialPageRoute(
          builder: (_) => ServiceDetailPage(service: args),
        );
      case Routes.createAgenceRoute:
        return MaterialPageRoute(builder: (_)=>CreateAgencePage());
      case Routes.helpSupportRoute:
        return MaterialPageRoute(builder: (_)=>HelpSupportPage());
      case Routes.subscriptionPaymentRoute:
        return MaterialPageRoute(
          builder: (_) => const PaymentSubscriptionPage(),
        );
      case Routes.paymentHistoryRoute:
        final phArgs = r.arguments;
        int? highlightId;
        if (phArgs is Map) {
          final h = phArgs['highlightPaymentId'];
          if (h != null) highlightId = int.tryParse(h.toString());
        }
        return MaterialPageRoute(
          builder: (_) => PaymentHistoryPage(highlightPaymentId: highlightId),
        );
      // case Routes.visitPageRoute:
      //   final PropertyModel property = r.arguments as PropertyModel;
      //   return MaterialPageRoute(builder: (_)=>BookingVisitPage(property: property));
      default:
        return MaterialPageRoute(builder: (_) =>OnboardingScreen());
    }
  }
}

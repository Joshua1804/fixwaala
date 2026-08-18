import 'package:flutter/material.dart';

import '../../features/ai_assist/screens/ai_assist_screen.dart';
import '../../features/auth/screens/customer_onboarding_screen.dart';
import '../../features/auth/screens/email_auth_screen.dart';
import '../../features/auth/screens/email_verification_screen.dart';
import '../../features/auth/screens/password_reset_screen.dart';
import '../../features/auth/screens/provider_onboarding_screen.dart';
import '../../features/auth/screens/role_selection_screen.dart';
import '../../features/customer_ticket/screens/create_ticket_screen.dart';
import '../../features/customer_ticket/screens/my_tickets_screen.dart';
import '../../features/customer_ticket/screens/ticket_review_screen.dart';
import '../../features/geo_broadcast/screens/matching_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/payment/screens/simulated_payment_screen.dart';
import '../../features/provider_search/screens/provider_search_results_screen.dart';
import '../../features/provider_dashboard/screens/earnings_screen.dart';
import '../../features/provider_dashboard/screens/performance_screen.dart';
import '../../features/provider_dashboard/screens/provider_location_screen.dart';
import '../../features/provider_dashboard/screens/provider_dashboard_screen.dart';
import '../../features/provider_dashboard/screens/provider_skills_screen.dart';
import '../../features/provider_dashboard/screens/trust_score_screen.dart';
import '../../features/ratings/screens/rating_screen.dart';
import '../../features/reports_safety/screens/report_screen.dart';
import '../../features/reports_safety/screens/sos_screen.dart';
import '../../features/service_lifecycle/screens/active_jobs_screen.dart';
import '../../features/service_lifecycle/screens/completion_screen.dart';
import '../../features/service_lifecycle/screens/estimate_screen.dart';
import '../../features/service_lifecycle/screens/job_details_screen.dart';
import '../../features/service_lifecycle/screens/job_tracking_screen.dart';
import '../../features/service_lifecycle/screens/provider_inspection_estimate_screen.dart';
import '../../features/service_lifecycle/screens/status_update_screen.dart';
import '../../features/trust_gated_matching/screens/provider_profile_screen.dart';
import '../../features/trust_gated_matching/screens/provider_review_screen.dart';
import '../../home/customer_home_screen.dart';
import '../../home/provider_home_screen.dart';
import '../constants/legal_content.dart';
import '../widgets/splash_screen.dart';
import '../widgets/static_content_screen.dart';
import 'route_names.dart';

class AppRouter {
  AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case RouteNames.splash:
        return _page(const SplashScreen(), settings);

      // Module 1
      case RouteNames.roleSelection:
        return _page(const RoleSelectionScreen(), settings);
      case RouteNames.emailAuth:
        return _page(const EmailAuthScreen(), settings);
      case RouteNames.emailVerification:
        return _page(const EmailVerificationScreen(), settings);
      case RouteNames.passwordReset:
        return _page(const PasswordResetScreen(), settings);
      case RouteNames.customerOnboarding:
        return _page(const CustomerOnboardingScreen(), settings);
      case RouteNames.providerOnboarding:
        return _page(const ProviderOnboardingScreen(), settings);

      // Home shells
      case RouteNames.customerHome:
        return _page(const CustomerHomeScreen(), settings);
      case RouteNames.providerHome:
        return _page(const ProviderHomeScreen(), settings);

      // Module 3
      case RouteNames.createTicket:
        return _page(const CreateTicketScreen(), settings);
      case RouteNames.ticketReview:
        return _page(const TicketReviewScreen(), settings);
      case RouteNames.myTickets:
        return _page(const MyTicketsScreen(), settings);

      // Module 4
      case RouteNames.aiAssist:
        return _page(const AiAssistScreen(), settings);

      // Module 5
      case RouteNames.matchingProgress:
        return _page(const MatchingScreen(), settings);

      // Module 6
      case RouteNames.providerReview:
        return _page(const ProviderReviewScreen(), settings);
      case RouteNames.candidateProviderProfile:
        return _page(const ProviderProfileScreen(), settings);

      // Module 7
      case RouteNames.jobTracking:
        return _page(const JobTrackingScreen(), settings);
      case RouteNames.estimate:
        return _page(const EstimateScreen(), settings);
      case RouteNames.completion:
        return _page(const CompletionScreen(), settings);
      case RouteNames.providerActiveJobs:
        return _page(const ActiveJobsScreen(), settings);
      case RouteNames.providerJobDetails:
        return _page(const JobDetailsScreen(), settings);
      case RouteNames.providerStatusUpdate:
        return _page(const StatusUpdateScreen(), settings);
      case RouteNames.providerInspectionEstimate:
        return _page(const ProviderInspectionEstimateScreen(), settings);

      // Module 8
      case RouteNames.payment:
        return _page(const SimulatedPaymentScreen(), settings);

      // Module 9
      case RouteNames.rating:
        return _page(const RatingScreen(), settings);

      // Module 10
      case RouteNames.providerDashboard:
        return _page(const ProviderDashboardScreen(), settings);
      case RouteNames.providerPerformance:
        return _page(const PerformanceScreen(), settings);
      case RouteNames.providerEarnings:
        return _page(const EarningsScreen(), settings);
      case RouteNames.providerTrustScore:
        return _page(const TrustScoreScreen(), settings);
      case RouteNames.providerSkills:
        return _page(const ProviderSkillsScreen(), settings);

      // Static content — Privacy Policy and Terms are Play requirements.
      case RouteNames.privacyPolicy:
        return _page(
          const StaticContentScreen(document: LegalContent.privacyPolicy),
          settings,
        );
      case RouteNames.termsOfService:
        return _page(
          const StaticContentScreen(document: LegalContent.termsOfService),
          settings,
        );
      case RouteNames.about:
        return _page(
          const StaticContentScreen(document: LegalContent.about),
          settings,
        );
      case RouteNames.help:
        return _page(
          const StaticContentScreen(document: LegalContent.help),
          settings,
        );

      // Module 11
      case RouteNames.report:
        return _page(const ReportScreen(), settings);
      case RouteNames.sos:
        return _page(const SosScreen(), settings);

      // Notifications
      case RouteNames.notifications:
        return _page(const NotificationsScreen(), settings);

      // Provider search
      case RouteNames.providerSearchResults:
        return _page(const ProviderSearchResultsScreen(), settings);

      // Provider location
      case RouteNames.providerLocation:
        return _page(const ProviderLocationScreen(), settings);

      default:
        return _page(
          Scaffold(
            body: Center(child: Text('Unknown route: ${settings.name}')),
          ),
          settings,
        );
    }
  }

  static MaterialPageRoute _page(Widget child, RouteSettings settings) {
    return MaterialPageRoute(builder: (_) => child, settings: settings);
  }
}

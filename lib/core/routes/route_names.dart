class RouteNames {
  RouteNames._();

  // Bootstrap
  static const splash = '/';

  // Module 1 - Auth
  static const roleSelection = '/auth/role';
  static const emailAuth = '/auth/email';
  static const emailVerification = '/auth/verify-email';
  static const passwordReset = '/auth/reset-password';
  static const customerOnboarding = '/auth/onboarding/customer';
  static const providerOnboarding = '/auth/onboarding/provider';

  // Home shells
  static const customerHome = '/customer/home';
  static const providerHome = '/provider/home';

  // Module 3 - Ticket
  static const createTicket = '/ticket/create';
  static const ticketReview = '/ticket/review';
  static const myTickets = '/ticket/mine';

  // Module 4 - AI assist
  static const aiAssist = '/ticket/ai-assist';

  // Module 5 - Matching
  static const matchingProgress = '/match/progress';

  // Module 6 - Trust-gated matching
  static const providerReview = '/match/review';
  static const candidateProviderProfile = '/match/review/provider-profile';

  // Module 7 - Service lifecycle
  static const jobTracking = '/job/track';
  static const estimate = '/job/estimate';
  static const completion = '/job/completion';
  static const providerActiveJobs = '/provider/jobs';
  static const providerJobDetails = '/provider/jobs/details';
  static const providerStatusUpdate = '/provider/jobs/status';
  static const providerInspectionEstimate =
      '/provider/jobs/inspection-estimate';

  // Module 8 - Payment
  static const payment = '/payment';

  // Module 9 - Ratings
  static const rating = '/rating';

  // Module 10 - Provider dashboard
  static const providerDashboard = '/provider/dashboard';
  static const providerPerformance = '/provider/performance';
  static const providerEarnings = '/provider/earnings';
  static const providerTrustScore = '/provider/trust-score';
  static const providerSkills = '/provider/skills';

  // Static content
  static const privacyPolicy = '/legal/privacy';
  static const termsOfService = '/legal/terms';
  static const about = '/about';
  static const help = '/help';

  // Module 11 - Reports & safety
  static const report = '/report';
  static const sos = '/sos';

  // Notifications (admin announcements)
  static const notifications = '/notifications';

  // Provider search
  static const providerSearchResults = '/search/results';

  // Provider location
  static const providerLocation = '/provider/location';

  static const changeEmail = '/auth/change-email';
}

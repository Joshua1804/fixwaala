import 'package:flutter/material.dart';

import 'core/routes/app_router.dart';
import 'core/routes/route_names.dart';
import 'core/services/app_preferences_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/simulation_mode_banner.dart';

class FixwaalaApp extends StatefulWidget {
  const FixwaalaApp({super.key});

  @override
  State<FixwaalaApp> createState() => _FixwaalaAppState();
}

class _FixwaalaAppState extends State<FixwaalaApp> {
  late Stream<ThemeMode> _themeModeStream;

  @override
  void initState() {
    super.initState();
    _themeModeStream = AppPreferencesService.instance.themeModeStream;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ThemeMode>(
      stream: _themeModeStream,
      initialData: AppPreferencesService.instance.themeMode,
      builder: (context, snapshot) {
        return MaterialApp(
          title: 'Fixwaala',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: snapshot.data ?? ThemeMode.system,
          initialRoute: RouteNames.splash,
          onGenerateRoute: AppRouter.onGenerateRoute,
          // Wraps every route, so a build that is silently persisting nothing
          // announces itself no matter where the user is.
          builder: (context, child) =>
              SimulationModeBanner(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}

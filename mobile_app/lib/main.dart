// lib/main.dart
// SmartPulse v2 — Entry point

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/app_state.dart';
import 'services/api_service.dart';
import 'services/navigation_service.dart';
import 'services/auto_sensing_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/create_account_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/survey_screen.dart';
import 'screens/result_screen.dart';
import 'screens/account_screen.dart';
import 'screens/permission_screen.dart';
import 'screens/usage_diagnostic_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize backend URL detection
  await ApiService.initializeBackendUrl();

  // Initialize notification service
  await NotificationService.initialize();

  // Initialize AutoSensingService
  await AutoSensingService.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()..init()),
        Provider<ApiService>(create: (_) => ApiService()),
      ],
      child: const SmartPulseApp(),
    ),
  );
}

class SmartPulseApp extends StatelessWidget {
  const SmartPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return MaterialApp(
      navigatorKey: NavigationService.navigatorKey,
      title: 'SmartPulse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: state.themeMode,
      initialRoute: '/',
      routes: {
        '/': (_) => const SplashScreen(),
        '/login': (_) => const LoginScreen(),
        '/create_account': (_) => const CreateAccountScreen(),
        '/main': (_) => const DashboardScreen(),
        '/dashboard': (_) => const DashboardScreen(),
        '/home': (_) => const DashboardScreen(),
        '/survey': (_) => const SurveyScreen(),
        '/permission': (_) => const PermissionScreen(),
        '/result': (_) => const ResultScreen(),
        '/account': (_) => const AccountScreen(),
        '/diagnostic': (_) => const UsageDiagnosticScreen(),
      },
    );
  }
}

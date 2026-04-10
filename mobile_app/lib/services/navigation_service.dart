// lib/services/navigation_service.dart
//
// SmartPulse v2 — Navigation Service
// Centralized navigation management for smoother page transitions

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../services/api_service.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static BuildContext? get context => navigatorKey.currentContext;

  // Navigate with loading state management
  static Future<void> navigateWithLoading(
    String routeName, {
    Object? arguments,
    bool replace = false,
    bool clearStack = false,
  }) async {
    final context = NavigationService.context;
    if (context == null) return;

    try {
      // Show loading indicator
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      // Wait a bit for smooth transition
      await Future.delayed(const Duration(milliseconds: 300));

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // Navigate - check context is still valid after async delay
      if (!context.mounted) return;

      if (clearStack) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          routeName,
          (route) => false,
          arguments: arguments,
        );
      } else if (replace) {
        Navigator.of(context).pushReplacementNamed(
          routeName,
          arguments: arguments,
        );
      } else {
        Navigator.of(context).pushNamed(
          routeName,
          arguments: arguments,
        );
      }
    } catch (e) {
      print('Navigation error: $e');
      // Close loading dialog if still open
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  // Safe navigation with context checking
  static void navigateTo(String routeName, {Object? arguments}) {
    final context = NavigationService.context;
    if (context != null && context.mounted) {
      Navigator.of(context).pushNamed(routeName, arguments: arguments);
    }
  }

  // Safe replacement navigation
  static void navigateReplace(String routeName, {Object? arguments}) async {
    final context = NavigationService.context;
    if (context != null && context.mounted) {
      await Navigator.of(context)
          .pushReplacementNamed(routeName, arguments: arguments);
    }
  }

  // Clear navigation stack and navigate
  static void navigateClearStack(String routeName, {Object? arguments}) async {
    final context = NavigationService.context;
    if (context != null && context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        routeName,
        (route) => false,
        arguments: arguments,
      );
    }
  }

  // Go back
  static void goBack() {
    final context = NavigationService.context;
    if (context != null && context.mounted && Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
  }

  // Check if we can go back
  static bool canGoBack() {
    final context = NavigationService.context;
    if (context != null && context.mounted) {
      return Navigator.canPop(context);
    }
    return false;
  }

  // Auth-aware navigation
  static Future<void> navigateToAuthRequired(String routeName) async {
    final context = NavigationService.context;
    if (context == null) return;

    final appState = context.read<AppState>();
    if (!appState.isLoggedIn) {
      navigateTo(routeName);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please login to continue'),
        backgroundColor: Colors.orange,
      ),
    );
    navigateReplace('/login');
  }

  // Post-authentication navigation
  static Future<void> handlePostAuthNavigation() async {
    final context = NavigationService.context;
    if (context == null) return;

    try {
      // Check if backend is available
      final isConnected = await ApiService.checkBackendConnection();
      if (isConnected) {
        navigateClearStack('/main');
      } else if (context.mounted) {
        // Show warning about backend connection
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Backend not available. Some features may be limited.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );

        // Still navigate to main for demo mode
        navigateClearStack('/main');
      }
    } catch (e) {
      navigateToError('Navigation error: ${e.toString()}');
    }
  }

  // Error navigation
  static void navigateToError(String errorMessage) {
    final context = NavigationService.context;
    if (context == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(errorMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

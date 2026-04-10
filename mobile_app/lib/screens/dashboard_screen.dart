// lib/screens/dashboard_screen.dart
// SmartPulse v2 — Main Dashboard shell with bottom navigation
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'home_screen_fixed.dart';
import 'survey_screen.dart';
import 'result_screen.dart';
import 'history_screen.dart';
import 'account_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _tab = 0;

  final _screens = [
    const HomeScreenFixed(),
    const SurveyScreen(),
    const ResultScreen(),
    const HistoryScreen(),
    const AccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(index: _tab, children: _screens),
      bottomNavigationBar: BottomAppBar(
        color: isDark ? AppColors.cardDark : Colors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navBtn(0, Icons.home_outlined, Icons.home, 'Home'),
            _navBtn(1, Icons.psychology_outlined, Icons.psychology, 'Survey'),
            _navBtn(2, Icons.analytics_outlined, Icons.analytics, 'Result'),
            _navBtn(3, Icons.history_outlined, Icons.history, 'History'),
            _navBtn(4, Icons.person_outline, Icons.person, 'Account'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/diagnostic');
        },
        backgroundColor: Colors.red,
        tooltip: 'Run Usage Diagnostic',
        child: const Icon(Icons.bug_report, color: Colors.white),
      ),
    );
  }

  Widget _navBtn(int idx, IconData offIcon, IconData onIcon, String label) {
    final selected = _tab == idx;
    return InkWell(
      onTap: () => setState(() => _tab = idx),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(selected ? onIcon : offIcon,
              color: selected ? AppColors.primary : Colors.grey),
          Text(label,
              style: TextStyle(
                fontSize: 11,
                color: selected ? AppColors.primary : Colors.grey,
              )),
        ]),
      ),
    );
  }
}

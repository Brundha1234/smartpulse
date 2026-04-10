// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = state.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () => state.toggleTheme(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          // Avatar
          CircleAvatar(
            radius: 44,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            child: Text(
              user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'U',
              style: const TextStyle(
                  fontSize: 36,
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          Text(user?.name ?? 'User',
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(user?.email ?? '',
              style:
                  TextStyle(color: isDark ? AppColors.textDim : Colors.grey)),

          const SizedBox(height: 24),

          // User Details
          if (user != null) ...[
            _detailTile(context, Icons.person, 'Name', user.name),
            _detailTile(context, Icons.email, 'Email', user.email),
            _detailTile(context, Icons.cake, 'Age', '${user.age} years'),
            if (user.phone.isNotEmpty)
              _detailTile(context, Icons.phone, 'Phone', user.phone),
            if (user.gender.isNotEmpty)
              _detailTile(context, Icons.people, 'Gender', user.gender),
            const SizedBox(height: 16),
          ],

          // Stats
          Row(children: [
            _statTile(
                'Points', '${state.points}', Icons.star, AppColors.riskMedium),
            const SizedBox(width: 12),
            _statTile('Streak', '${state.streak}d', Icons.local_fire_department,
                AppColors.riskHigh),
          ]),

          const SizedBox(height: 24),

          // Settings tiles
          _tile(context, Icons.notifications, 'Notification Threshold',
              '${state.notifThreshold} per day'),
          _tile(context, Icons.lock_open, 'Unlock Threshold',
              '${state.unlockThreshold} per day'),
          _tile(context, Icons.phone_android, 'Screen Time Goal',
              '${state.goalHours.toStringAsFixed(0)}h per day'),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await state.logout();
                Navigator.of(context).pushReplacementNamed('/login');
              },
              icon: const Icon(Icons.logout, color: AppColors.riskHigh),
              label: const Text('Sign Out',
                  style: TextStyle(color: AppColors.riskHigh)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.riskHigh),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _statTile(String label, String value, IconData icon, Color color) =>
      Expanded(
          child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 12)),
        ]),
      ));

  Widget _tile(BuildContext ctx, IconData icon, String title, String sub) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
            child: Text(title,
                style: const TextStyle(fontWeight: FontWeight.w500))),
        Text(sub,
            style: TextStyle(
                color: isDark ? AppColors.textDim : Colors.grey, fontSize: 13)),
      ]),
    );
  }

  Widget _detailTile(
      BuildContext ctx, IconData icon, String label, String value) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                color: isDark ? AppColors.textDim : Colors.grey[600],
                fontSize: 14)),
      ]),
    );
  }
}

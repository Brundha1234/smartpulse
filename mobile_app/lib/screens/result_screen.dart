// lib/screens/result_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final pred = state.lastPrediction;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (pred == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Analysis Results',
              style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        backgroundColor: Colors.grey[50],
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Preview of what will be shown
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    Icon(Icons.analytics_outlined,
                        size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'Analysis Results Preview',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Once you have usage data, this screen will show:\n\n• Risk assessment with confidence score\n• Addiction level analysis\n• Personalized recommendations\n• Usage statistics breakdown\n• Trend insights',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.orange.shade600),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Complete the survey and grant permissions to start seeing your results',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    Color riskColor;
    try {
      final hex = pred.riskColor.replaceAll('#', '');
      riskColor = Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      riskColor = AppColors.riskMedium;
    }

    final IconData riskIcon = pred.addictionLevel == 'High'
        ? Icons.warning_amber_rounded
        : pred.addictionLevel == 'Medium'
            ? Icons.info_outline
            : Icons.check_circle_outline;
    final recommendations = _displayRecommendations(pred);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis Results',
            style: TextStyle(fontWeight: FontWeight.bold)),
        leading: BackButton(
            onPressed: () =>
                Navigator.of(context).pushReplacementNamed('/main')),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          // ── Risk gauge ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 25), width: 2),
            ),
            child: Column(children: [
              CircularPercentIndicator(
                radius: 70,
                lineWidth: 10,
                percent: pred.confidenceScore.clamp(0.0, 1.0),
                progressColor: riskColor,
                backgroundColor: riskColor.withValues(alpha: 0.15),
                circularStrokeCap: CircularStrokeCap.round,
                center: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(riskIcon, size: 28, color: riskColor),
                      const SizedBox(height: 4),
                      Text(
                        '${(pred.confidenceScore * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: riskColor),
                      ),
                    ]),
              ),
              const SizedBox(height: 16),
              Text('${pred.addictionLevel} Addiction Risk',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: riskColor)),
              const SizedBox(height: 8),
              Text(pred.message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14,
                      color:
                          isDark ? AppColors.textDim : Colors.grey.shade600)),
            ]),
          ),

          const SizedBox(height: 20),

          // ── Sensing summary ───────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Sensed Data Used',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 12),
                _dataRow(Icons.phone_android, 'Screen Time',
                    '${state.todayUsage.screenTime.toStringAsFixed(1)} h'),
                _dataRow(Icons.apps, 'Social App Usage',
                    '${state.todayUsage.appUsage.toStringAsFixed(1)} h'),
                _dataRow(Icons.nights_stay, 'Night Usage',
                    '${state.todayUsage.nightUsage.toStringAsFixed(1)} h'),
                _dataRow(Icons.lock_open, 'Unlock Count',
                    '${state.todayUsage.unlockCount}'),
                _dataRow(Icons.notifications, 'Notification Count',
                    '${state.todayUsage.notificationCount}'),
                _dataRow(
                    Icons.sentiment_dissatisfied,
                    'Stress / Anxiety / Depression',
                    '${state.stress} / ${state.anxiety} / ${state.depression}'),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Recommendations ───────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: riskColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: riskColor.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.lightbulb_outline, color: riskColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Recommendations',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.grey.shade900,
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                ...recommendations.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 10,
                              backgroundColor: riskColor.withValues(alpha: 0.2),
                              child: Text('${e.key + 1}',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade900,
                                      fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(
                              e.value,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: Colors.grey.shade900,
                                fontWeight: FontWeight.w500,
                              ),
                            )),
                          ]),
                    )),
              ],
            ),
          ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () =>
                  Navigator.of(context).pushReplacementNamed('/main'),
              icon: const Icon(Icons.dashboard),
              label: const Text('Back to Dashboard'),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _dataRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ]),
      );

  List<String> _displayRecommendations(dynamic prediction) {
    final level = prediction.addictionLevel.toString();
    switch (level) {
      case 'High':
        return const [
          'High alert: your current phone habits may be affecting your digital health. Take a deliberate break and reduce non-essential phone use today.',
          'Set strict app limits and keep the phone away during study, work, meals, and before sleep so your routine can stabilize.',
          'Turn off non-urgent notifications and avoid short repeated checks, because they quickly pull you back into longer sessions.',
          'Choose one offline activity now, like walking, reading, exercise, or talking with family, to interrupt the overuse cycle.',
        ];
      case 'Medium':
        return const [
          'Your usage is manageable, but this is the right time to bring it down before it grows into a stronger habit.',
          'Keep screen time lower by setting fixed app windows and avoiding unnecessary scrolling after finishing your main task.',
          'Reduce distractions by limiting notifications from social and entertainment apps, especially during focused hours.',
          'Try short digital breaks through the day so your phone use stays intentional instead of automatic.',
        ];
      case 'Low':
        return const [
          'Keep it up. Your current digital habits look healthy, so the goal now is to maintain the same balance consistently.',
          'Continue using your phone with purpose and keep offline routines strong so your screen time stays under control.',
          'Protect this progress by keeping notification noise low and avoiding late-night browsing when possible.',
          'Your current pattern is a good sign of digital health. Stay mindful and keep the same steady routine.',
        ];
      default:
        final current = List<String>.from(prediction.recommendations ?? const []);
        return current;
    }
  }
}

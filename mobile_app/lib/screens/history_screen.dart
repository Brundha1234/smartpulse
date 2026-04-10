// lib/screens/history_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../models/usage_data.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dailyPredictions = state.dailyPredictions;
    final dailyUsageData = state.dailyUsageData;
    final hist = state.history;
    final hasWeeklyUsage = dailyUsageData.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('History',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Weekly Prediction Trend Analysis
            if (dailyPredictions.isNotEmpty || hasWeeklyUsage) ...[
              _buildWeeklyPredictionTrend(
                  context, dailyPredictions, dailyUsageData, isDark),
              const SizedBox(height: 24),
            ],

            // Prediction History
            Text(
              'Prediction History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            hist.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.cardDark : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.history,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'History Preview',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Once you have usage data, this screen will show:\n\n• Daily prediction trends\n• Weekly usage patterns\n• Risk level progression\n• App usage analytics\n• Time-based insights\n• Personalized recommendations history',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.lightbulb_outline,
                                  color: Colors.orange.shade600, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Start tracking your usage to see your personalized history and trends',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: hist.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final p = hist[i];
                      Color rc;
                      try {
                        final hex = p.riskColor.replaceAll('#', '');
                        rc = Color(int.parse('FF$hex', radix: 16));
                      } catch (_) {
                        rc = AppColors.riskMedium;
                      }

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.cardDark : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: rc.withOpacity(0.3)),
                        ),
                        child: Row(children: [
                          CircleAvatar(
                            backgroundColor: rc.withOpacity(0.15),
                            child: Icon(
                                p.addictionLevel == 'High'
                                    ? Icons.warning_amber
                                    : Icons.check,
                                color: rc,
                                size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${p.addictionLevel} Risk',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: rc,
                                      fontSize: 14)),
                              Text(
                                  DateFormat('d MMM yyyy, h:mm a')
                                      .format(p.timestamp),
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? AppColors.textDim
                                          : Colors.grey)),
                            ],
                          )),
                          Text(
                              '${(p.confidenceScore * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: rc)),
                        ]),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyPredictionTrend(
      BuildContext context,
      Map<String, dynamic> dailyPredictions,
      Map<String, UsageData> dailyUsageData,
      bool isDark) {
    // Get last 7 days of predictions and usage data
    final now = DateTime.now();
    final weekData = <Map<String, dynamic>>[];

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateStr = date.toIso8601String().split('T')[0];
      final prediction = dailyPredictions[dateStr];
      final usageData = dailyUsageData[dateStr];

      weekData.add({
        'date': date,
        'dateStr': dateStr,
        'prediction': prediction,
        'usageData': usageData,
        'hasData': prediction != null,
        'hasUsageData': usageData != null,
      });
    }
    final predictionDays = weekData.where((d) => d['hasData'] == true).length;
    final usageDays = weekData.where((d) => d['hasUsageData'] == true).length;
    final trendSpots = weekData
        .asMap()
        .entries
        .map((entry) {
          final index = entry.key;
          final data = entry.value;
          final prediction = data['prediction'];

          if (prediction != null) {
            double riskValue = 0;
            if (prediction.addictionLevel == 'Low') {
              riskValue = 0;
            } else if (prediction.addictionLevel == 'Medium') {
              riskValue = 1;
            } else if (prediction.addictionLevel == 'High') {
              riskValue = 2;
            }
            return FlSpot(index.toDouble(), riskValue);
          }
          return null;
        })
        .whereType<FlSpot>()
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weekly Prediction Trend',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      predictionDays > 0
                          ? 'Daily automatic predictions across this week'
                          : 'Usage history is available. Daily predictions will appear here after completed sessions.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildTrendBadge(_getTrendIndicator(weekData), isDark),
            ],
          ),
          const SizedBox(height: 16),

          // Trend Chart
          SizedBox(
            height: 200,
            child: trendSpots.isEmpty
                ? Center(
                    child: Text(
                      'No completed daily predictions yet.\nKeep using SmartPulse and this chart will fill in automatically.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 1,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.grey.shade300,
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            reservedSize: 56,
                            getTitlesWidget: (value, meta) {
                              final labels = ['Low', 'Medium', 'High'];
                              if (value >= 0 && value < labels.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Text(
                                    labels[value.toInt()],
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value >= 0 && value < weekData.length) {
                                final date =
                                    weekData[value.toInt()]['date'] as DateTime;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    DateFormat('EEE').format(date),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: trendSpots,
                          isCurved: true,
                          color: AppColors.primary,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              final data = weekData[index];
                              final prediction = data['prediction'];
                              Color dotColor = Colors.grey;

                              if (prediction != null) {
                                if (prediction.addictionLevel == 'Low') {
                                  dotColor = Colors.green;
                                } else if (prediction.addictionLevel == 'Medium') {
                                  dotColor = Colors.orange;
                                } else if (prediction.addictionLevel == 'High') {
                                  dotColor = Colors.red;
                                }
                              }

                              return FlDotCirclePainter(
                                radius: 4,
                                color: dotColor,
                                strokeWidth: 2,
                                strokeColor: Colors.white,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppColors.primary.withOpacity(0.1),
                          ),
                        ),
                      ],
                      minY: -0.5,
                      maxY: 2.5,
                    ),
                  ),
          ),

          const SizedBox(height: 16),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildLegendItem('Low Risk', Colors.green),
              _buildLegendItem('Medium Risk', Colors.orange),
              _buildLegendItem('High Risk', Colors.red),
            ],
          ),

          const SizedBox(height: 16),

          // Summary Stats
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.backgroundDark : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildSummaryStat('Prediction Days', '$predictionDays/7'),
                ),
                Expanded(
                  child: _buildSummaryStat('Usage Saved', '$usageDays/7'),
                ),
                Expanded(
                  child: _buildSummaryStat(
                      'Most Common', _getMostCommonRiskLevel(weekData)),
                ),
                Expanded(
                  child: _buildSummaryStat('Trend', _getTrendIndicator(weekData)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Daily Usage Behavior Data
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Usage Behavior Data',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Last 7 days usage patterns and behavior metrics',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 16),

                // Usage data table
                ...weekData
                    .map((data) => _buildDailyUsageRow(data, isDark))
                    ,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildTrendBadge(String trend, bool isDark) {
    final normalized = trend.toLowerCase();
    final Color badgeColor;
    final IconData icon;

    if (normalized.contains('rising')) {
      badgeColor = Colors.red;
      icon = Icons.trending_up;
    } else if (normalized.contains('falling')) {
      badgeColor = Colors.green;
      icon = Icons.trending_down;
    } else if (normalized.contains('stable')) {
      badgeColor = Colors.orange;
      icon = Icons.trending_flat;
    } else {
      badgeColor = Colors.grey;
      icon = Icons.timeline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(isDark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withOpacity(0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: badgeColor),
          const SizedBox(width: 6),
          Text(
            trend,
            style: TextStyle(
              color: badgeColor,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  String _getMostCommonRiskLevel(List<Map<String, dynamic>> weekData) {
    final riskLevels = <String>[];
    for (final data in weekData) {
      final prediction = data['prediction'];
      if (prediction != null) {
        riskLevels.add(prediction.addictionLevel);
      }
    }

    if (riskLevels.isEmpty) return 'N/A';

    final counts = <String, int>{};
    for (final level in riskLevels) {
      counts[level] = (counts[level] ?? 0) + 1;
    }

    final mostCommon =
        counts.entries.reduce((a, b) => a.value > b.value ? a : b);
    return mostCommon.key.split(' ')[0];
  }

  String _getTrendIndicator(List<Map<String, dynamic>> weekData) {
    final values = <double>[];
    for (final data in weekData) {
      final prediction = data['prediction'];
      if (prediction != null) {
        double riskValue = 0;
        if (prediction.addictionLevel == 'Low') {
          riskValue = 0;
        } else if (prediction.addictionLevel == 'Medium')
          riskValue = 1;
        else if (prediction.addictionLevel == 'High') riskValue = 2;
        values.add(riskValue);
      }
    }

    if (values.length < 2) return 'Not enough';

    // Simple trend calculation
    final firstHalf = values.sublist(0, values.length ~/ 2);
    final secondHalf = values.sublist(values.length ~/ 2);

    final firstAvg = firstHalf.reduce((a, b) => a + b) / firstHalf.length;
    final secondAvg = secondHalf.reduce((a, b) => a + b) / secondHalf.length;

    if (secondAvg > firstAvg + 0.3) return 'Rising';
    if (secondAvg < firstAvg - 0.3) return 'Falling';
    return 'Stable';
  }

  Widget _buildDailyUsageRow(Map<String, dynamic> data, bool isDark) {
    final date = data['date'] as DateTime;
    final usageData = data['usageData'] as UsageData?;
    final hasUsageData = data['hasUsageData'] as bool;

    if (!hasUsageData || usageData == null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                DateFormat('MMM dd').format(date),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            Expanded(
              flex: 6,
              child: Text(
                'No usage data available',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Date row
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  DateFormat('MMM dd').format(date),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Screen ${usageData.screenTime.toStringAsFixed(1)}h',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Unlocks ${usageData.unlockCount}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.orange.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Notifs ${usageData.notificationCount}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.green.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (usageData.nightUsage > 0) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Night',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.purple.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  flex: 8,
                  child: Text(
                              '${usageData.nightUsage.toStringAsFixed(1)}h usage (10 PM - 6 AM)',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.purple.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (usageData.appBreakdown.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    '📊 Apps',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.teal.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  flex: 8,
                  child: Text(
                    '${usageData.appBreakdown.length} apps tracked',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.teal.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

}

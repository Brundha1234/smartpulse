// lib/models/prediction_result.dart
// SmartPulse v2 — Prediction result model

class PredictionResult {
  final String addictionLevel; // "Low" | "Medium" | "High"
  final double confidenceScore; // 0.0 – 1.0
  final String riskColor; // hex color string
  final String message;
  final List<String> recommendations;
  final DateTime timestamp;

  const PredictionResult({
    required this.addictionLevel,
    required this.confidenceScore,
    required this.riskColor,
    required this.message,
    required this.recommendations,
    required this.timestamp,
  });

  factory PredictionResult.fromJson(Map<String, dynamic> json) =>
      PredictionResult(
        addictionLevel: (json['addiction_level'] ??
                _normalizeRiskLevel(json['risk_level']?.toString()) ??
                'Unknown')
            as String,
        confidenceScore: _normalizeConfidence(
          json['confidence_score'] ?? json['confidence'],
        ),
        riskColor: (json['risk_color'] ??
                _colorForRisk(_normalizeRiskLevel(json['risk_level']?.toString()) ??
                    json['addiction_level']?.toString() ??
                    'Unknown'))
            as String,
        message: (json['message'] ??
                _messageForRisk(_normalizeRiskLevel(json['risk_level']?.toString()) ??
                    json['addiction_level']?.toString() ??
                    'Unknown'))
            as String,
        recommendations: _normalizeRecommendations(json['recommendations']),
        timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'addiction_level': addictionLevel,
        'confidence_score': confidenceScore,
        'risk_color': riskColor,
        'message': message,
        'recommendations': recommendations,
        'timestamp': timestamp.toIso8601String(),
      };

  static String _normalizeRiskLevel(String? value) {
    if (value == null || value.isEmpty) return 'Unknown';
    if (value.contains('High')) return 'High';
    if (value.contains('Medium')) return 'Medium';
    if (value.contains('Low')) return 'Low';
    return value;
  }

  static double _normalizeConfidence(dynamic value) {
    final raw = (value as num?)?.toDouble() ?? 0.0;
    return raw > 1.0 ? raw / 100.0 : raw;
  }

  static List<String> _normalizeRecommendations(dynamic value) {
    if (value is List) {
      return value.map((item) {
        if (item is String) return item;
        if (item is Map) {
          final title = item['title']?.toString();
          final description = item['description']?.toString();
          if (title != null && description != null) {
            return '$title: $description';
          }
          return title ?? description ?? item.toString();
        }
        return item.toString();
      }).toList();
    }
    return const [];
  }

  static String _colorForRisk(String risk) {
    switch (risk) {
      case 'High':
        return '#F44336';
      case 'Medium':
        return '#FFC107';
      case 'Low':
        return '#4CAF50';
      default:
        return '#9E9E9E';
    }
  }

  static String _messageForRisk(String risk) {
    switch (risk) {
      case 'High':
        return 'High addiction risk detected from your latest real device usage.';
      case 'Medium':
        return 'Moderate addiction risk detected from your latest real device usage.';
      case 'Low':
        return 'Your latest real device usage looks relatively healthy.';
      default:
        return 'Prediction completed, but the backend returned a custom response format.';
    }
  }
}

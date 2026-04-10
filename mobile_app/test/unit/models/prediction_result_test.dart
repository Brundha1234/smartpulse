// test/unit/models/prediction_result_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:smartpulse/models/prediction_result.dart';

void main() {
  group('PredictionResult Tests', () {
    test('should create PredictionResult with required parameters', () {
      final prediction = PredictionResult(
        addictionLevel: 'Medium',
        confidenceScore: 0.75,
        riskColor: '#FFA500',
        message: 'Moderate risk detected',
        recommendations: ['Reduce usage', 'Take breaks'],
        timestamp: DateTime.now(),
      );

      expect(prediction.addictionLevel, equals('Medium'));
      expect(prediction.confidenceScore, equals(0.75));
      expect(prediction.riskColor, equals('#FFA500'));
      expect(prediction.message, equals('Moderate risk detected'));
      expect(prediction.recommendations.length, equals(2));
      expect(prediction.recommendations.contains('Reduce usage'), isTrue);
    });

    test('should serialize to JSON correctly', () {
      final prediction = PredictionResult(
        addictionLevel: 'High',
        confidenceScore: 0.85,
        riskColor: '#FF0000',
        message: 'High risk detected',
        recommendations: ['Immediate action required'],
        timestamp: DateTime(2024, 4, 3, 6, 0),
      );

      final json = prediction.toJson();
      
      expect(json['addiction_level'], equals('High'));
      expect(json['confidence_score'], equals(0.85));
      expect(json['risk_color'], equals('#FF0000'));
      expect(json['message'], equals('High risk detected'));
      expect(json['recommendations'], contains('Immediate action required'));
      expect(json['timestamp'], equals('2024-04-03T06:00:00.000'));
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'addiction_level': 'Low',
        'confidence_score': 0.25,
        'risk_color': '#00FF00',
        'message': 'Low risk detected',
        'recommendations': ['Keep up the good work'],
        'timestamp': '2024-04-03T06:00:00.000',
      };

      final prediction = PredictionResult.fromJson(json);
      
      expect(prediction.addictionLevel, equals('Low'));
      expect(prediction.confidenceScore, equals(0.25));
      expect(prediction.riskColor, equals('#00FF00'));
      expect(prediction.message, equals('Low risk detected'));
      expect(prediction.recommendations, contains('Keep up the good work'));
      expect(prediction.timestamp.year, equals(2024));
      expect(prediction.timestamp.month, equals(4));
    });

    test('should handle null recommendations in JSON', () {
      final json = {
        'addiction_level': 'Medium',
        'confidence_score': 0.5,
        'risk_color': '#FFA500',
        'message': 'Medium risk detected',
        'recommendations': null,
        'timestamp': '2024-04-03T06:00:00.000',
      };

      final prediction = PredictionResult.fromJson(json);
      
      expect(prediction.recommendations, isEmpty);
    });

    test('should handle null timestamp in JSON', () {
      final json = {
        'addiction_level': 'Medium',
        'confidence_score': 0.5,
        'risk_color': '#FFA500',
        'message': 'Medium risk detected',
        'recommendations': ['Test'],
        'timestamp': null,
      };

      final prediction = PredictionResult.fromJson(json);
      
      expect(prediction.timestamp, isA<DateTime>());
      expect(prediction.timestamp.isBefore(DateTime.now().add(const Duration(seconds: 1))), isTrue);
    });

    test('should handle missing timestamp in JSON', () {
      final json = {
        'addiction_level': 'Medium',
        'confidence_score': 0.5,
        'risk_color': '#FFA500',
        'message': 'Medium risk detected',
        'recommendations': ['Test'],
      };

      final prediction = PredictionResult.fromJson(json);
      
      expect(prediction.timestamp, isA<DateTime>());
    });

    test('should validate addiction levels', () {
      final validLevels = ['Low', 'Medium', 'High'];
      
      for (final level in validLevels) {
        final prediction = PredictionResult(
          addictionLevel: level,
          confidenceScore: 0.5,
          riskColor: '#FFA500',
          message: 'Test',
          recommendations: ['Test'],
          timestamp: DateTime.now(),
        );
        
        expect(prediction.addictionLevel, equals(level));
      }
    });

    test('should validate confidence score range', () {
      final validScores = [0.0, 0.25, 0.5, 0.75, 1.0];
      
      for (final score in validScores) {
        final prediction = PredictionResult(
          addictionLevel: 'Medium',
          confidenceScore: score,
          riskColor: '#FFA500',
          message: 'Test',
          recommendations: ['Test'],
          timestamp: DateTime.now(),
        );
        
        expect(prediction.confidenceScore, equals(score));
        expect(prediction.confidenceScore, greaterThanOrEqualTo(0.0));
        expect(prediction.confidenceScore, lessThanOrEqualTo(1.0));
      }
    });
  });
}

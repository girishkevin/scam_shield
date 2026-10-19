import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:scam_shield/features/link_check/domain/link_analyzer.dart';
import 'package:scam_shield/features/message_scan/domain/message_analyzer.dart';
import 'package:scam_shield/features/message_scan/domain/scam_classifier.dart';

void main() {
  final json = jsonDecode(File('assets/ml/scam_model.json').readAsStringSync())
  as Map<String, dynamic>;
  final classifier = ScamClassifier.fromJson(json);

  const scamText =
      'Your SBI KYC is expired. Update now at http://sbi-kyc.xyz or your account will be blocked.';
  const genuineOtp =
      '123456 is your OTP for login. Do not share it with anyone.';

  test('Dart gives the same probabilities as the Python model', () {
    final vectors = (json['test_vectors'] as List).cast<Map<String, dynamic>>();
    expect(vectors, isNotEmpty);

    for (final v in vectors) {
      final p = classifier.predict(v['text'] as String).probability;
      expect(
        p,
        closeTo((v['p'] as num).toDouble(), 1e-5),
        reason: 'text: ${v['text']}',
      );
    }
  });

  test('an obvious scam scores high and a genuine OTP scores low', () {
    expect(classifier.predict(scamText).probability, greaterThan(0.7));
    expect(classifier.predict(genuineOtp).probability, lessThan(0.4));
  });

  test('top terms explain a scam prediction', () {
    expect(classifier.predict(scamText).topTerms, isNotEmpty);
  });

  test('the model can raise the risk score but never lower it', () {
    final withModel = MessageAnalyzer(classifier: classifier);
    final rulesOnly = MessageAnalyzer();
    const messages = [
      scamText,
      genuineOtp,
      'Rs 800.00 debited from A/c XX4821 via UPI. Avl Bal Rs 9,200.',
      'Share your OTP to receive your refund.',
      'Hi, are we still meeting for lunch tomorrow?',
      'Aapka account band ho jayega, turant verify karein',
    ];

    for (final m in messages) {
      expect(
        withModel.analyze(m).score,
        greaterThanOrEqualTo(rulesOnly.analyze(m).score),
        reason: m,
      );
    }
  });

  test('a genuine OTP message stays safe with the model switched on', () {
    final r = MessageAnalyzer(classifier: classifier).analyze(genuineOtp);
    expect(r.level, RiskLevel.safe);
  });

  test('the model adds an explanation for an obvious scam', () {
    final r = MessageAnalyzer(classifier: classifier).analyze(scamText);
    expect(r.hasTextSignal('ml_high'), isTrue);
  });
}
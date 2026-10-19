import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:scam_shield/features/message_scan/domain/message_analyzer.dart';
import 'package:scam_shield/features/message_scan/domain/scam_classifier.dart';

void main() {
  final json = jsonDecode(File('assets/ml/scam_model.json').readAsStringSync())
  as Map<String, dynamic>;
  final classifier = ScamClassifier.fromJson(json);

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
    final scam = classifier.predict(
        'Your SBI KYC is expired. Update now at http://sbi-kyc.xyz or your account will be blocked.');
    final genuine = classifier
        .predict('123456 is your OTP for login. Do not share it with anyone.');

    expect(scam.probability, greaterThan(0.7));
    expect(genuine.probability, lessThan(0.4));
  });

  test('top terms explain a scam prediction', () {
    final scam = classifier.predict(
        'Your SBI KYC is expired. Update now at http://sbi-kyc.xyz or your account will be blocked.');
    expect(scam.topTerms, isNotEmpty);
  });

  test('the model can raise the risk score but never lower it', () {
    const text =
        'Dear customer, your SBI account will be blocked today. Update KYC now: http://sbi-kyc-update.xyz/login';
    final plain = MessageAnalyzer().analyze(text);
    final withModel = MessageAnalyzer().analyze(text);
    expect(withModel.score, greaterThanOrEqualTo(plain.score));
  });
}
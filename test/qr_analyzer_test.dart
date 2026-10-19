import 'package:flutter_test/flutter_test.dart';
import 'package:scam_shield/features/link_check/domain/link_analyzer.dart';
import 'package:scam_shield/features/qr_scan/domain/qr_analyzer.dart';

void main() {
  final analyzer = QrAnalyzer();

  test('UPI payment QR is flagged for caution and details are parsed', () {
    final r = analyzer.analyze('upi://pay?pa=shop@okaxis&pn=Test%20Shop');
    expect(r.kind, QrKind.upi);
    expect(r.level, RiskLevel.suspicious);
    expect(r.hasSignal('upi_payment'), isTrue);
    expect(r.upi?.payeeAddress, 'shop@okaxis');
    expect(r.upi?.payeeName, 'Test Shop');
  });

  test('UPI QR with a pre-filled amount scores higher', () {
    final r = analyzer.analyze('upi://pay?pa=shop@okaxis&pn=Shop&am=500');
    expect(r.hasSignal('upi_amount'), isTrue);
    expect(r.score, 40);
  });

  test('UPI QR without a payee is dangerous', () {
    final r = analyzer.analyze('upi://pay?pn=Shop');
    expect(r.hasSignal('upi_no_payee'), isTrue);
    expect(r.level, RiskLevel.dangerous);
  });

  test('official link QR is safe', () {
    final r = analyzer.analyze('https://www.paytm.com');
    expect(r.kind, QrKind.link);
    expect(r.level, RiskLevel.safe);
  });

  test('phishing link QR is dangerous', () {
    final r = analyzer.analyze('https://paytm-kyc-update.xyz/verify');
    expect(r.kind, QrKind.link);
    expect(r.level, RiskLevel.dangerous);
  });

  test('plain text QR is safe', () {
    final r = analyzer.analyze('Hello, welcome to our shop');
    expect(r.kind, QrKind.text);
    expect(r.level, RiskLevel.safe);
  });

  test('scammy text QR goes through the message analyzer', () {
    final r =
    analyzer.analyze('Your account will be blocked. Share your OTP now.');
    expect(r.kind, QrKind.text);
    expect(r.hasSignal('otp_request'), isTrue);
    expect(r.level, RiskLevel.dangerous);
  });
}
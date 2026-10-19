import 'package:flutter_test/flutter_test.dart';
import 'package:scam_shield/features/link_check/domain/link_analyzer.dart';
import 'package:scam_shield/features/message_scan/domain/message_analyzer.dart';

void main() {
  final analyzer = MessageAnalyzer();

  test('genuine OTP message is safe', () {
    final r = analyzer.analyze(
        '123456 is your OTP for login. Do not share it with anyone.');
    expect(r.level, RiskLevel.safe);
    expect(r.hasTextSignal('otp_request'), isFalse);
  });

  test('asking for OTP is flagged', () {
    final r = analyzer.analyze('Share your OTP to receive your refund.');
    expect(r.hasTextSignal('otp_request'), isTrue);
  });

  test('fake KYC message with bad link is dangerous', () {
    final r = analyzer.analyze(
        'Dear customer, your SBI account will be blocked today. '
            'Update KYC now: http://sbi-kyc-update.xyz/login');
    expect(r.level, RiskLevel.dangerous);
    expect(r.hasTextSignal('account_blocked'), isTrue);
    expect(r.hasTextSignal('kyc_pressure'), isTrue);
    expect(r.linkResults, hasLength(1));
  });

  test('Hinglish threat is flagged', () {
    final r = analyzer
        .analyze('Aapka account band ho jayega, turant verify karein');
    expect(r.hasTextSignal('hinglish_threat'), isTrue);
    expect(r.hasTextSignal('urgency'), isTrue);
  });

  test('digital arrest pattern is flagged', () {
    final r = analyzer.analyze(
        'This is CBI. A parcel with drugs was found in your Aadhaar name. '
            'Join the video call now.');
    expect(r.hasTextSignal('authority_threat'), isTrue);
  });

  test('links are extracted and cleaned', () {
    final links = analyzer.extractLinks('Visit www.paytm.com, or bit.ly/abc!');
    expect(links, ['www.paytm.com', 'bit.ly/abc']);
  });
}
import 'package:flutter_test/flutter_test.dart';
import 'package:scam_shield/features/link_check/domain/link_analyzer.dart';

void main() {
  final analyzer = LinkAnalyzer();

  test('official brand domain is safe', () {
    final r = analyzer.analyze('https://www.paytm.com/');
    expect(r.level, RiskLevel.safe);
    expect(r.signals, isEmpty);
  });

  test('link without scheme is handled', () {
    final r = analyzer.analyze('www.paytm.com');
    expect(r.level, RiskLevel.safe);
  });

  test('fake KYC site impersonating a brand is dangerous', () {
    final r = analyzer.analyze('https://paytm-kyc-update.xyz/verify');
    expect(r.level, RiskLevel.dangerous);
    expect(r.hasSignal('brand_impersonation'), isTrue);
    expect(r.hasSignal('risky_tld'), isTrue);
    expect(r.hasSignal('urgency_words'), isTrue);
  });

  test('raw IP address login page is dangerous', () {
    final r = analyzer.analyze('http://192.168.1.1/login');
    expect(r.level, RiskLevel.dangerous);
    expect(r.hasSignal('ip_host'), isTrue);
    expect(r.hasSignal('no_https'), isTrue);
  });

  test('URL shortener is suspicious', () {
    final r = analyzer.analyze('bit.ly/abc123');
    expect(r.level, RiskLevel.suspicious);
    expect(r.hasSignal('shortener'), isTrue);
  });

  test('@ trick is detected', () {
    final r = analyzer.analyze('https://google.com@evil.com/');
    expect(r.hasSignal('userinfo'), isTrue);
  });

  test('punycode look-alike domain is flagged', () {
    final r = analyzer.analyze('https://xn--pypal-4ve.com');
    expect(r.hasSignal('punycode'), isTrue);
  });

  test('empty input is treated as malformed', () {
    final r = analyzer.analyze('   ');
    expect(r.hasSignal('malformed'), isTrue);
  });
}
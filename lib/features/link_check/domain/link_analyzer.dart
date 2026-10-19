// Rule-based link risk analyzer. Pure Dart, no Flutter dependencies,
// so it is easy to unit test and runs fully on-device.

enum RiskLevel { safe, suspicious, dangerous }

class RiskSignal {
  final String id;
  final String reason; // plain-language explanation shown to the user
  final int weight;

  const RiskSignal(this.id, this.reason, this.weight);
}

class LinkAnalysisResult {
  final String input;
  final int score; // 0-100
  final RiskLevel level;
  final List<RiskSignal> signals;

  const LinkAnalysisResult({
    required this.input,
    required this.score,
    required this.level,
    required this.signals,
  });

  bool hasSignal(String id) => signals.any((s) => s.id == id);
}

class LinkAnalyzer {
  static const _shorteners = {
    'bit.ly', 'tinyurl.com', 't.co', 'goo.gl', 'is.gd', 'cutt.ly',
    'rb.gy', 'shorturl.at', 'ow.ly', 'tiny.cc', 'rebrand.ly',
  };

  static const _riskyTlds = {
    'xyz', 'top', 'click', 'link', 'work', 'support', 'loan', 'win',
    'gq', 'tk', 'ml', 'cf', 'ga', 'icu', 'buzz', 'rest', 'monster',
  };

  // Registrable domains that use a 3-label suffix (e.g. sbi.co.in).
  static const _multiPartSuffixes = {
    'co.in', 'org.in', 'gov.in', 'nic.in', 'ac.in', 'net.in', 'res.in',
    'co.uk', 'com.au',
  };

  // Brand keyword -> official registrable domains.
  // This is a starter list: verify and extend it yourself.
  static const _brands = <String, Set<String>>{
    'paytm': {'paytm.com'},
    'phonepe': {'phonepe.com'},
    'gpay': {'google.com'},
    'sbi': {'sbi.co.in', 'onlinesbi.sbi'},
    'hdfc': {'hdfcbank.com'},
    'icici': {'icicibank.com'},
    'axis': {'axisbank.com'},
    'amazon': {'amazon.in', 'amazon.com'},
    'flipkart': {'flipkart.com'},
    'irctc': {'irctc.co.in'},
    'aadhaar': {'uidai.gov.in'},
    'incometax': {'incometax.gov.in'},
    'epfo': {'epfindia.gov.in', 'epfo.gov.in'},
    'npci': {'npci.org.in'},
  };

  static const _urgencyWords = [
    'verify', 'kyc', 'update', 'login', 'claim', 'reward', 'blocked',
    'suspend', 'otp', 'refund', 'prize', 'urgent',
  ];

  static final _schemeRegex = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://');
  static final _ipv4Regex = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$');

  LinkAnalysisResult analyze(String rawInput) {
    final input = rawInput.trim();
    final hasScheme = _schemeRegex.hasMatch(input);
    final uri = Uri.tryParse(hasScheme ? input : 'https://$input');

    if (input.isEmpty || uri == null || uri.host.isEmpty) {
      return LinkAnalysisResult(
        input: input,
        score: 50,
        level: RiskLevel.suspicious,
        signals: const [
          RiskSignal('malformed', 'This does not look like a valid link.', 50),
        ],
      );
    }

    final host = uri.host.toLowerCase();
    final labels = host.split('.');
    final registrable = _registrableDomain(labels);
    final tld = labels.last;
    final signals = <RiskSignal>[];

    if (hasScheme && uri.scheme != 'https') {
      signals.add(const RiskSignal(
          'no_https', 'The link is not encrypted (no HTTPS).', 10));
    }

    if (_ipv4Regex.hasMatch(host)) {
      signals.add(const RiskSignal('ip_host',
          'It uses a raw IP address instead of a website name.', 40));
    }

    if (_shorteners.contains(registrable)) {
      signals.add(const RiskSignal('shortener',
          'It is a shortened link, so the real destination is hidden.', 25));
    }

    if (_riskyTlds.contains(tld)) {
      signals.add(RiskSignal('risky_tld',
          'The ending ".$tld" is often used in scam websites.', 20));
    }

    if (uri.userInfo.isNotEmpty) {
      signals.add(const RiskSignal('userinfo',
          'It contains "@" to disguise the real website.', 30));
    }

    if (host.contains('xn--')) {
      signals.add(const RiskSignal('punycode',
          'The domain uses look-alike characters to imitate another site.', 30));
    }

    if (labels.length > 4) {
      signals.add(const RiskSignal(
          'many_subdomains', 'The address has too many subdomains.', 15));
    }

    if ('-'.allMatches(host).length >= 3) {
      signals.add(const RiskSignal(
          'many_hyphens', 'The domain has many hyphens, a common scam trick.', 10));
    }

    if (uri.hasPort && uri.port != 80 && uri.port != 443) {
      signals.add(const RiskSignal(
          'odd_port', 'It uses an unusual network port.', 10));
    }

    final impersonated = _impersonatedBrand(host, registrable);
    if (impersonated != null) {
      signals.add(RiskSignal('brand_impersonation',
          'The name "$impersonated" appears, but this is not its official website.',
          40));
    }

    final pathAndQuery = '${uri.path} ${uri.query}'.toLowerCase();
    if (_urgencyWords.any(pathAndQuery.contains)) {
      signals.add(const RiskSignal('urgency_words',
          'The link contains words often used to pressure victims.', 10));
    }

    if (input.length > 100) {
      signals.add(const RiskSignal('long_url', 'The link is unusually long.', 5));
    }

    final total = signals.fold<int>(0, (sum, s) => sum + s.weight);
    final score = total.clamp(0, 100);

    return LinkAnalysisResult(
      input: input,
      score: score,
      level: score < 25
          ? RiskLevel.safe
          : score < 55
          ? RiskLevel.suspicious
          : RiskLevel.dangerous,
      signals: signals,
    );
  }

  String _registrableDomain(List<String> labels) {
    if (labels.length >= 3) {
      final lastTwo = labels.sublist(labels.length - 2).join('.');
      if (_multiPartSuffixes.contains(lastTwo)) {
        return labels.sublist(labels.length - 3).join('.');
      }
    }
    if (labels.length >= 2) {
      return labels.sublist(labels.length - 2).join('.');
    }
    return labels.join('.');
  }

  String? _impersonatedBrand(String host, String registrable) {
    final tokens = host.split(RegExp(r'[.\-]'));
    for (final entry in _brands.entries) {
      final brand = entry.key;
      final mentioned =
      brand.length >= 5 ? host.contains(brand) : tokens.contains(brand);
      if (mentioned && !entry.value.contains(registrable)) {
        return brand;
      }
    }
    return null;
  }
}
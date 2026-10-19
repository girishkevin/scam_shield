import '../../link_check/domain/link_analyzer.dart';

class MessageAnalysisResult {
  final String message;
  final int score; // 0-100
  final RiskLevel level;
  final List<RiskSignal> textSignals;
  final List<LinkAnalysisResult> linkResults;

  const MessageAnalysisResult({
    required this.message,
    required this.score,
    required this.level,
    required this.textSignals,
    required this.linkResults,
  });

  bool hasTextSignal(String id) => textSignals.any((s) => s.id == id);
}

class _TextRule {
  final String id;
  final RegExp pattern;
  final String reason;
  final int weight;

  _TextRule(this.id, String pattern, this.reason, this.weight)
      : pattern = RegExp(pattern, caseSensitive: false, dotAll: true);
}

class MessageAnalyzer {
  MessageAnalyzer({LinkAnalyzer? linkAnalyzer})
      : _linkAnalyzer = linkAnalyzer ?? LinkAnalyzer();

  final LinkAnalyzer _linkAnalyzer;

  // The (?<!...) parts avoid flagging genuine warnings like "Do not share OTP".
  static final List<_TextRule> _rules = [
    _TextRule(
      'otp_request',
      r"(?<!not )(?<!never )(?<!n't )(?<!n’t )\b(share|send|tell|give|forward)\b.{0,25}\b(otp|pin|cvv|password)\b",
      'It asks you to share an OTP, PIN, CVV or password. Real banks never ask this.',
      35,
    ),
    _TextRule(
      'otp_request_hinglish',
      r'\botp\b.{0,15}\b(batao|bataiye|bhejo|bhejein|dijiye)\b',
      'It asks you to give your OTP. Real banks never ask this.',
      35,
    ),
    _TextRule(
      'account_blocked',
      r'\b(account|card|sim|upi|wallet)\b.{0,30}(block|suspend|deactivat|disabl|clos)',
      'It threatens to block or close your account, card or SIM.',
      25,
    ),
    _TextRule(
      'hinglish_threat',
      r'\b(band|block|suspend)\s+ho\s+(jayega|jaayega|jaega)\b',
      'It threatens that something will be blocked or closed.',
      25,
    ),
    _TextRule(
      'kyc_pressure',
      r'\bkyc\b.{0,30}(expire|pending|update|verify|incomplete)|(expire|pending|update|verify|incomplete).{0,30}\bkyc\b',
      'It says your KYC is pending or expired, a very common scam.',
      25,
    ),
    _TextRule(
      'fake_reward',
      r'\b(congratulations|you have won|you won|lucky draw|lottery|claim (your )?(prize|reward|gift|cashback))\b',
      'It promises a prize or reward you never applied for.',
      25,
    ),
    _TextRule(
      'authority_threat',
      r'\b(arrest|police|cbi|narcotics|customs|court|warrant)\b.{0,60}\b(parcel|aadhaar|money laundering|video call|transfer)\b',
      'It pretends to be police or a government agency, a "digital arrest" pattern.',
      30,
    ),
    _TextRule(
      'remote_access_app',
      r'\b(anydesk|teamviewer|quicksupport|rustdesk)\b',
      'It asks you to install a remote-access app. Scammers use these to control your phone.',
      35,
    ),
    _TextRule(
      'apk_install',
      r'\.apk\b',
      'It asks you to install an app file from outside the Play Store.',
      35,
    ),
    _TextRule(
      'advance_fee',
      r'\b(registration|processing|clearance|advance|delivery)\s+(fee|charge)s?\b',
      'It asks for an upfront fee, a common advance-fee scam.',
      25,
    ),
    _TextRule(
      'urgency',
      r'\b(urgent|immediately|within \d+ (hours?|hrs?|minutes?|mins?)|last chance|today only|expires? (today|soon)|act now|turant)\b',
      'It pressures you to act quickly.',
      15,
    ),
  ];

  static final RegExp _linkRegex = RegExp(
    r'(?:https?://|www\.)[^\s<>"]+'
    r'|\b[a-z0-9-]+(?:\.[a-z0-9-]+)*\.[a-z]{2,}/[^\s<>"]*'
    r'|\b[a-z0-9-]+(?:\.[a-z0-9-]+)*\.(?:com|in|net|org|xyz|top|click|link|info|online|site|shop|app|me|co)\b',
    caseSensitive: false,
  );

  List<String> extractLinks(String text) {
    final found = <String>{};
    for (final m in _linkRegex.allMatches(text)) {
      final cleaned = m.group(0)!.replaceAll(RegExp(r'[.,;:!?)\]]+$'), '');
      if (cleaned.isNotEmpty) found.add(cleaned);
    }
    return found.toList();
  }

  MessageAnalysisResult analyze(String rawMessage) {
    final text = rawMessage.trim();

    final textSignals = <RiskSignal>[
      for (final rule in _rules)
        if (rule.pattern.hasMatch(text))
          RiskSignal(rule.id, rule.reason, rule.weight),
    ];

    final linkResults = extractLinks(text).map(_linkAnalyzer.analyze).toList();

    final textScore = textSignals.fold<int>(0, (sum, s) => sum + s.weight);
    final worstLink =
    linkResults.fold<int>(0, (m, r) => r.score > m ? r.score : m);

    var score = textScore > worstLink ? textScore : worstLink;
    // Scary wording AND a risky link together is much more suspicious.
    if (textSignals.isNotEmpty && worstLink >= 25) score += 15;
    score = score.clamp(0, 100);

    return MessageAnalysisResult(
      message: text,
      score: score,
      level: score < 25
          ? RiskLevel.safe
          : score < 55
          ? RiskLevel.suspicious
          : RiskLevel.dangerous,
      textSignals: textSignals,
      linkResults: linkResults,
    );
  }
}
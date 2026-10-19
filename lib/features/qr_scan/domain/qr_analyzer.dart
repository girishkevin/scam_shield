import '../../link_check/domain/link_analyzer.dart';
import '../../message_scan/domain/message_analyzer.dart';

enum QrKind { link, upi, text }

class UpiDetails {
  final String? payeeAddress;
  final String? payeeName;
  final String? amount;

  const UpiDetails({this.payeeAddress, this.payeeName, this.amount});
}

class QrAnalysisResult {
  final String raw;
  final QrKind kind;
  final int score; // 0-100
  final RiskLevel level;
  final List<RiskSignal> signals;
  final UpiDetails? upi;

  const QrAnalysisResult({
    required this.raw,
    required this.kind,
    required this.score,
    required this.level,
    required this.signals,
    this.upi,
  });

  bool hasSignal(String id) => signals.any((s) => s.id == id);
}

class QrAnalyzer {
  QrAnalyzer({LinkAnalyzer? linkAnalyzer, MessageAnalyzer? messageAnalyzer})
      : _linkAnalyzer = linkAnalyzer ?? LinkAnalyzer(),
        _messageAnalyzer = messageAnalyzer ?? MessageAnalyzer();

  final LinkAnalyzer _linkAnalyzer;
  final MessageAnalyzer _messageAnalyzer;

  static final _urlLike = RegExp(
    r'^(?:https?://\S+|(?:[a-z0-9-]+\.)+[a-z]{2,}(?:[/?#]\S*)?)$',
    caseSensitive: false,
  );

  QrAnalysisResult analyze(String rawValue) {
    final raw = rawValue.trim();

    if (raw.toLowerCase().startsWith('upi://')) {
      return _analyzeUpi(raw);
    }

    if (_urlLike.hasMatch(raw)) {
      final r = _linkAnalyzer.analyze(raw);
      return QrAnalysisResult(
        raw: raw,
        kind: QrKind.link,
        score: r.score,
        level: r.level,
        signals: r.signals,
      );
    }

    final m = _messageAnalyzer.analyze(raw);
    return QrAnalysisResult(
      raw: raw,
      kind: QrKind.text,
      score: m.score,
      level: m.level,
      signals: [
        ...m.textSignals,
        for (final link in m.linkResults) ...link.signals,
      ],
    );
  }

  QrAnalysisResult _analyzeUpi(String raw) {
    final params = _queryParams(raw);
    final details = UpiDetails(
      payeeAddress: params['pa'],
      payeeName: params['pn'],
      amount: params['am'],
    );

    final signals = <RiskSignal>[
      const RiskSignal(
        'upi_payment',
        'This is a payment QR code. Scanning it sends money from your '
            'account. You never need to scan a QR code to receive money.',
        30,
      ),
    ];

    if ((details.amount ?? '').isNotEmpty) {
      signals.add(const RiskSignal(
          'upi_amount', 'The amount is already filled in for you.', 10));
    }

    if ((details.payeeAddress ?? '').isEmpty) {
      signals.add(const RiskSignal(
          'upi_no_payee', 'This QR code has no valid payee address.', 30));
    }

    final total = signals.fold<int>(0, (sum, s) => sum + s.weight);
    final score = total.clamp(0, 100);

    return QrAnalysisResult(
      raw: raw,
      kind: QrKind.upi,
      score: score,
      level: score < 25
          ? RiskLevel.safe
          : score < 55
          ? RiskLevel.suspicious
          : RiskLevel.dangerous,
      signals: signals,
      upi: details,
    );
  }

  Map<String, String> _queryParams(String raw) {
    final q = raw.contains('?') ? raw.substring(raw.indexOf('?') + 1) : '';
    final map = <String, String>{};
    for (final part in q.split('&')) {
      if (part.isEmpty) continue;
      final i = part.indexOf('=');
      final key = (i < 0 ? part : part.substring(0, i)).toLowerCase();
      final value = i < 0 ? '' : part.substring(i + 1);
      try {
        map[key] = Uri.decodeQueryComponent(value);
      } catch (_) {
        map[key] = value;
      }
    }
    return map;
  }
}
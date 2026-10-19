import '../../link_check/domain/link_analyzer.dart';

enum HistorySource { link, message, qr }

class HistoryEntry {
  final String id;
  final DateTime createdAt;
  final HistorySource source;
  final String content;
  final int score;
  final RiskLevel level;
  final List<String> reasons;

  const HistoryEntry({
    required this.id,
    required this.createdAt,
    required this.source,
    required this.content,
    required this.score,
    required this.level,
    required this.reasons,
  });

  static const _maxContent = 500;

  factory HistoryEntry.create({
    required HistorySource source,
    required String content,
    required int score,
    required RiskLevel level,
    required List<String> reasons,
  }) {
    final now = DateTime.now();
    final trimmed = content.trim();
    return HistoryEntry(
      id: now.microsecondsSinceEpoch.toString(),
      createdAt: now,
      source: source,
      content: trimmed.length > _maxContent
          ? '${trimmed.substring(0, _maxContent)}…'
          : trimmed,
      score: score,
      level: level,
      reasons: reasons,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'source': source.name,
    'content': content,
    'score': score,
    'level': level.name,
    'reasons': reasons,
  };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
    id: json['id'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    source: HistorySource.values.byName(json['source'] as String),
    content: json['content'] as String,
    score: json['score'] as int,
    level: RiskLevel.values.byName(json['level'] as String),
    reasons: (json['reasons'] as List).cast<String>(),
  );
}
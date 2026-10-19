import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart' show rootBundle;

class ScamPrediction {
  final double probability; // 0.0 - 1.0 chance the text is a scam
  final List<String> topTerms; // words that pushed it toward "scam"

  const ScamPrediction({required this.probability, required this.topTerms});
}

class _Term {
  const _Term(this.idf, this.weight);

  final double idf;
  final double weight;
}

/// Runs the TF-IDF + logistic regression model exported by ml/train.py.
/// The steps below must stay identical to train.py.
class ScamClassifier {
  ScamClassifier._(this._intercept, this._terms);

  factory ScamClassifier.fromJson(Map<String, dynamic> json) {
    final raw = json['terms'] as Map<String, dynamic>;
    final terms = <String, _Term>{
      for (final e in raw.entries)
        e.key: _Term(
          ((e.value as List)[0] as num).toDouble(),
          ((e.value as List)[1] as num).toDouble(),
        ),
    };
    return ScamClassifier._((json['intercept'] as num).toDouble(), terms);
  }

  static const assetPath = 'assets/ml/scam_model.json';

  static Future<ScamClassifier> loadAsset([String path = assetPath]) async {
    final text = await rootBundle.loadString(path);
    return ScamClassifier.fromJson(jsonDecode(text) as Map<String, dynamic>);
  }

  final double _intercept;
  final Map<String, _Term> _terms;

  static final _urlRe = RegExp(r'(?:https?://|www\.)[^ \t\r\n]+');
  static final _numRe = RegExp(r'[0-9]+');
  static final _tokenRe = RegExp(r'[a-z0-9_]{2,}');

  List<String> _tokens(String text) {
    final cleaned = text
        .toLowerCase()
        .replaceAll(_urlRe, ' urltoken ')
        .replaceAll(_numRe, ' numtoken ');
    return [for (final m in _tokenRe.allMatches(cleaned)) m.group(0)!];
  }

  ScamPrediction predict(String text) {
    final tokens = _tokens(text);

    // Single words plus pairs of neighbouring words.
    final grams = <String>[
      ...tokens,
      for (var i = 0; i < tokens.length - 1; i++) '${tokens[i]} ${tokens[i + 1]}',
    ];

    final counts = <String, int>{};
    for (final g in grams) {
      if (_terms.containsKey(g)) counts[g] = (counts[g] ?? 0) + 1;
    }

    // TF-IDF with sublinear term frequency, then L2 normalisation.
    final values = <String, double>{};
    var sumSquares = 0.0;
    counts.forEach((g, c) {
      final v = (1 + math.log(c)) * _terms[g]!.idf;
      values[g] = v;
      sumSquares += v * v;
    });
    final norm = math.sqrt(sumSquares);

    var z = _intercept;
    final contributions = <MapEntry<String, double>>[];
    if (norm > 0) {
      values.forEach((g, v) {
        final c = v / norm * _terms[g]!.weight;
        z += c;
        contributions.add(MapEntry(g, c));
      });
    }

    final probability = 1 / (1 + math.exp(-z));

    contributions.sort((a, b) => b.value.compareTo(a.value));
    final top = [
      for (final e in contributions)
        if (e.value > 0.05 && !e.key.contains('token')) e.key,
    ].take(3).toList();

    return ScamPrediction(probability: probability, topTerms: top);
  }
}
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/link_analyzer.dart';

final linkAnalyzerProvider = Provider<LinkAnalyzer>((ref) => LinkAnalyzer());

class LinkCheckNotifier extends Notifier<LinkAnalysisResult?> {
  @override
  LinkAnalysisResult? build() => null;

  void check(String input) {
    state = ref.read(linkAnalyzerProvider).analyze(input);
  }

  void clear() => state = null;
}

final linkCheckProvider =
NotifierProvider<LinkCheckNotifier, LinkAnalysisResult?>(
    LinkCheckNotifier.new);
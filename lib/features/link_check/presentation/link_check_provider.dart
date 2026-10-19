import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../history/presentation/history_provider.dart';
import '../domain/link_analyzer.dart';

final linkAnalyzerProvider = Provider<LinkAnalyzer>((ref) => LinkAnalyzer());

class LinkCheckNotifier extends Notifier<LinkAnalysisResult?> {
  @override
  LinkAnalysisResult? build() => null;

  void check(String input) {
    final result = ref.read(linkAnalyzerProvider).analyze(input);
    state = result;
    unawaited(ref.read(historyProvider.notifier).addLink(result));
  }

  void clear() => state = null;
}

final linkCheckProvider =
NotifierProvider<LinkCheckNotifier, LinkAnalysisResult?>(
    LinkCheckNotifier.new);
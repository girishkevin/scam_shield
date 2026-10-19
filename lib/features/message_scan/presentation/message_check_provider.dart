import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../history/presentation/history_provider.dart';
import '../domain/message_analyzer.dart';
import '../domain/scam_classifier.dart';

/// Loads the trained model once. If it fails, the app still works on rules alone.
final scamClassifierProvider = FutureProvider<ScamClassifier?>((ref) async {
  try {
    return await ScamClassifier.loadAsset();
  } catch (_) {
    return null;
  }
});

final messageAnalyzerProvider = Provider<MessageAnalyzer>((ref) {
  final loaded = ref.watch(scamClassifierProvider);
  final classifier = switch (loaded) {
    AsyncData(:final value) => value,
    _ => null,
  };
  return MessageAnalyzer(classifier: classifier);
});

class MessageCheckNotifier extends Notifier<MessageAnalysisResult?> {
  @override
  MessageAnalysisResult? build() => null;

  void check(String message) {
    final result = ref.read(messageAnalyzerProvider).analyze(message);
    state = result;
    unawaited(ref.read(historyProvider.notifier).addMessage(result));
  }

  void clear() => state = null;
}

final messageCheckProvider =
NotifierProvider<MessageCheckNotifier, MessageAnalysisResult?>(
    MessageCheckNotifier.new);
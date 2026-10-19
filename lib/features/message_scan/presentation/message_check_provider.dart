import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../history/presentation/history_provider.dart';
import '../domain/message_analyzer.dart';

final messageAnalyzerProvider =
Provider<MessageAnalyzer>((ref) => MessageAnalyzer());

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
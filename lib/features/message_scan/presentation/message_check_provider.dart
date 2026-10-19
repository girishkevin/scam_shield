import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/message_analyzer.dart';

final messageAnalyzerProvider =
Provider<MessageAnalyzer>((ref) => MessageAnalyzer());

class MessageCheckNotifier extends Notifier<MessageAnalysisResult?> {
  @override
  MessageAnalysisResult? build() => null;

  void check(String message) {
    state = ref.read(messageAnalyzerProvider).analyze(message);
  }

  void clear() => state = null;
}

final messageCheckProvider =
NotifierProvider<MessageCheckNotifier, MessageAnalysisResult?>(
    MessageCheckNotifier.new);
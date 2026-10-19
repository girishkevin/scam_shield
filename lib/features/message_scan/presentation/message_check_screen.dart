import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/risk_style.dart';
import '../../link_check/domain/link_analyzer.dart';
import '../domain/message_analyzer.dart';
import 'message_check_provider.dart';

class MessageCheckScreen extends ConsumerStatefulWidget {
  const MessageCheckScreen({super.key});

  @override
  ConsumerState<MessageCheckScreen> createState() => _MessageCheckScreenState();
}

class _MessageCheckScreenState extends ConsumerState<MessageCheckScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _analyze() {
    FocusScope.of(context).unfocus();
    ref.read(messageCheckProvider.notifier).check(_controller.text);
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _controller.text = data!.text!;
    }
  }

  void _clear() {
    _controller.clear();
    ref.read(messageCheckProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(messageCheckProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Check a message')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _controller,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Paste the SMS or message here',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _paste,
                icon: const Icon(Icons.content_paste),
                label: const Text('Paste'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _clear,
                icon: const Icon(Icons.clear),
                label: const Text('Clear'),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _analyze,
                icon: const Icon(Icons.shield_outlined),
                label: const Text('Analyze'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (result != null) _MessageResultView(result: result),
        ],
      ),
    );
  }
}

class _MessageResultView extends StatelessWidget {
  const _MessageResultView({required this.result});

  final MessageAnalysisResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final level = result.level;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          color: level.color.withValues(alpha: 0.12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(level.icon, color: level.color, size: 32),
                    const SizedBox(width: 12),
                    Text(
                      level.label,
                      style: theme.textTheme.titleLarge?.copyWith(
                          color: level.color, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Text('${result.score}/100',
                        style: theme.textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: result.score / 100,
                  color: level.color,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (result.textSignals.isNotEmpty) ...[
          Text('Warning signs in the message',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final s in result.textSignals)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  '),
                  Expanded(child: Text(s.reason)),
                ],
              ),
            ),
          const SizedBox(height: 12),
        ],
        if (result.linkResults.isNotEmpty) ...[
          Text('Links found (${result.linkResults.length})',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final link in result.linkResults) _LinkTile(link: link),
        ],
        if (result.textSignals.isEmpty && result.linkResults.isEmpty)
          const Text('No warning signs found in this message.'),
        const SizedBox(height: 12),
        Text(
          'No tool is 100% accurate. Never share OTPs, and verify by calling '
              'the official number, not one from the message.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({required this.link});

  final LinkAnalysisResult link;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(link.level.icon, color: link.level.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(link.input,
                      style: theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis),
                ),
                Text('${link.score}/100'),
              ],
            ),
            for (final s in link.signals)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 32),
                child: Text('• ${s.reason}',
                    style: theme.textTheme.bodySmall),
              ),
          ],
        ),
      ),
    );
  }
}
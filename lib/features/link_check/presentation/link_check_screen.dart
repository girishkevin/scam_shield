import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/link_analyzer.dart';
import 'link_check_provider.dart';

class LinkCheckScreen extends ConsumerStatefulWidget {
  const LinkCheckScreen({super.key});

  @override
  ConsumerState<LinkCheckScreen> createState() => _LinkCheckScreenState();
}

class _LinkCheckScreenState extends ConsumerState<LinkCheckScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _check() {
    FocusScope.of(context).unfocus();
    ref.read(linkCheckProvider.notifier).check(_controller.text);
  }

  void _clear() {
    _controller.clear();
    ref.read(linkCheckProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(linkCheckProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Scam Shield')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _controller,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _check(),
            decoration: InputDecoration(
              labelText: 'Paste a link to check',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: _clear,
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _check,
            icon: const Icon(Icons.shield_outlined),
            label: const Text('Check link'),
          ),
          const SizedBox(height: 24),
          if (result != null) _ResultCard(result: result),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final LinkAnalysisResult result;

  (Color, String, IconData) get _style => switch (result.level) {
    RiskLevel.safe => (Colors.green, 'Looks safe', Icons.check_circle),
    RiskLevel.suspicious =>
    (Colors.orange, 'Suspicious', Icons.warning_amber_rounded),
    RiskLevel.dangerous => (Colors.red, 'Dangerous', Icons.dangerous),
  };

  @override
  Widget build(BuildContext context) {
    final (color, label, icon) = _style;

    return Card(
      color: color.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 32),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: color, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text('${result.score}/100',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: result.score / 100,
              color: color,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 16),
            if (result.signals.isEmpty)
              const Text('No warning signs found in this link.')
            else ...[
              Text('Why this looks risky',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              for (final s in result.signals)
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
            ],
            const SizedBox(height: 12),
            Text(
              'No tool is 100% accurate. When in doubt, do not open the link.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/app_theme.dart';
import '../../../core/risk_style.dart';
import '../../../core/shared_text_provider.dart';
import '../../../core/widgets/score_ring.dart';
import '../../../core/widgets/soft_card.dart';
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

  void _runAnalysis(String text) {
    ref.read(messageCheckProvider.notifier).check(text);

    final level = ref.read(messageCheckProvider)?.level;
    if (level == RiskLevel.dangerous) {
      HapticFeedback.heavyImpact();
    } else if (level == RiskLevel.suspicious) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  void _analyze() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    FocusScope.of(context).unfocus();
    _runAnalysis(text);
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    _controller.text = text;
    setState(() {});
    _analyze();
  }

  void _clear() {
    _controller.clear();
    ref.read(messageCheckProvider.notifier).clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = ref.watch(messageCheckProvider);
    final bottomPad = MediaQuery.of(context).padding.bottom + 110;

    // Text shared into the app from other apps (Kotlin platform channel).
    ref.listen<String?>(sharedTextProvider, (previous, next) {
      if (next == null) return;
      _controller.text = next;
      setState(() {});
      _runAnalysis(next);
      ref.read(sharedTextProvider.notifier).clear();
    });

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Message check'),
            backgroundColor: theme.scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, bottomPad),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(
                  'Paste a message or share it from your messages app. '
                      'It is checked on your phone only.',
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _controller,
                  minLines: 5,
                  maxLines: 9,
                  keyboardType: TextInputType.multiline,
                  onChanged: (_) => setState(() {}),
                  style: theme.textTheme.bodyLarge,
                  decoration: const InputDecoration(
                    hintText: 'Paste the message you received',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _paste,
                        icon: const Icon(Icons.content_paste_rounded, size: 20),
                        label: const Text('Paste'),
                      ),
                    ),
                    if (_controller.text.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _clear,
                          icon: const Icon(Icons.close_rounded, size: 20),
                          label: const Text('Clear'),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _analyze,
                  icon: const Icon(Icons.shield_rounded),
                  label: const Text('Check message'),
                ),
                const SizedBox(height: 28),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 450),
                  switchInCurve: Curves.easeOutCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.04),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: result == null
                      ? const _EmptyState(key: ValueKey('empty'))
                      : _ResultSection(key: ValueKey(result), result: result),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.cobalt.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chat_bubble_rounded,
                size: 34, color: AppColors.cobalt),
          ),
          const SizedBox(height: 18),
          Text('Got a suspicious message?', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Paste it above, or use Share in your messages app and choose '
                'Scam Shield.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ResultSection extends StatelessWidget {
  const _ResultSection({super.key, required this.result});

  final MessageAnalysisResult result;

  String get _summary => switch (result.level) {
    RiskLevel.safe => 'No scam patterns found in this message.',
    RiskLevel.suspicious =>
    'Some parts look off. Check before you act on it.',
    RiskLevel.dangerous =>
    'This looks like a scam. Do not reply, tap links, or share codes.',
  };

  String _count(int n, String singular, String plural) =>
      '$n ${n == 1 ? singular : plural}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final level = result.level;
    final signals = result.textSignals.length;
    final links = result.linkResults.length;

    return Column(
      children: [
        SoftCard(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            children: [
              ScoreRing(score: result.score, color: level.color),
              const SizedBox(height: 18),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(level.icon, color: level.color, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    level.label,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(color: level.color),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _summary,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              Text(
                '${_count(signals, 'warning sign', 'warning signs')} and '
                    '${_count(links, 'link', 'links')} found',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        if (signals > 0) ...[
          const SizedBox(height: 16),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('What we noticed', style: theme.textTheme.titleMedium),
                const SizedBox(height: 14),
                for (final s in result.textSignals)
                  ReasonRow(text: s.reason, color: level.color),
              ],
            ),
          ),
        ],
        if (links > 0) ...[
          const SizedBox(height: 16),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(links == 1 ? 'Link in this message' : 'Links in this message',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 14),
                for (var i = 0; i < result.linkResults.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 28,
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.08),
                    ),
                  _LinkRow(link: result.linkResults[i]),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          'No tool is 100% accurate. Never share an OTP, and confirm by '
              'calling the official number, not one from the message.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.link});

  final LinkAnalysisResult link;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = link.level.color;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(link.level.icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                link.input,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(link.level.label,
                  style: theme.textTheme.bodySmall?.copyWith(color: color)),
              if (link.signals.isNotEmpty) const SizedBox(height: 8),
              for (final s in link.signals)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(s.reason, style: theme.textTheme.bodySmall),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '${link.score}',
          style: theme.textTheme.titleMedium?.copyWith(color: color),
        ),
      ],
    );
  }
}
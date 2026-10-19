import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/app_theme.dart';
import '../../../core/risk_style.dart';
import '../../../core/widgets/score_ring.dart';
import '../../../core/widgets/soft_card.dart';
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
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    FocusScope.of(context).unfocus();
    ref.read(linkCheckProvider.notifier).check(text);

    final level = ref.read(linkCheckProvider)?.level;
    if (level == RiskLevel.dangerous) {
      HapticFeedback.heavyImpact();
    } else if (level == RiskLevel.suspicious) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    _controller.text = text;
    setState(() {});
    _check();
  }

  void _clear() {
    _controller.clear();
    ref.read(linkCheckProvider.notifier).clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = ref.watch(linkCheckProvider);
    final bottomPad = MediaQuery.of(context).padding.bottom + 110;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Link check'),
            backgroundColor: theme.scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, bottomPad),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(
                  'Paste a link you received. Nothing leaves your phone.',
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _controller,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.go,
                  autocorrect: false,
                  enableSuggestions: false,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _check(),
                  style: theme.textTheme.bodyLarge,
                  decoration: InputDecoration(
                    hintText: 'https://example.com',
                    prefixIcon: const Icon(Icons.link_rounded),
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.cancel_rounded),
                      onPressed: _clear,
                    )
                        : TextButton(
                      onPressed: _paste,
                      child: const Text('Paste'),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _check,
                  icon: const Icon(Icons.shield_rounded),
                  label: const Text('Check link'),
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
            child: const Icon(Icons.shield_rounded,
                size: 36, color: AppColors.cobalt),
          ),
          const SizedBox(height: 18),
          Text('Check before you tap', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Scam links often copy real brands. Paste one above and Scam '
                'Shield will look for warning signs.',
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

  final LinkAnalysisResult result;

  String get _summary => switch (result.level) {
    RiskLevel.safe => 'No warning signs found in this link.',
    RiskLevel.suspicious =>
    'Some things look off. Think twice before opening it.',
    RiskLevel.dangerous => 'This link looks like a scam. Do not open it.',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final level = result.level;

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
              const SizedBox(height: 16),
              Text(
                result.input,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        if (result.signals.isNotEmpty) ...[
          const SizedBox(height: 16),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('What we found', style: theme.textTheme.titleMedium),
                const SizedBox(height: 14),
                for (final s in result.signals)
                  ReasonRow(text: s.reason, color: level.color),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          'No tool is 100% accurate. When in doubt, do not open the link.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/app_theme.dart';
import '../../../core/risk_style.dart';
import '../../../core/widgets/soft_card.dart';
import '../domain/history_entry.dart';
import 'history_lock.dart';
import 'history_provider.dart';

extension _SourceStyle on HistorySource {
  IconData get icon => switch (this) {
    HistorySource.link => Icons.link_rounded,
    HistorySource.message => Icons.chat_bubble_rounded,
    HistorySource.qr => Icons.qr_code_scanner_rounded,
  };

  String get label => switch (this) {
    HistorySource.link => 'Link',
    HistorySource.message => 'Message',
    HistorySource.qr => 'QR code',
  };
}

String _timeAgo(DateTime t) {
  final diff = DateTime.now().difference(t);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays < 7) return '${diff.inDays} d ago';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${t.day} ${months[t.month - 1]}';
}

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all history?'),
        content: const Text(
          'This permanently erases your scan history and its encryption key. '
              'It cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true) {
      HapticFeedback.mediumImpact();
      await ref.read(historyProvider.notifier).clear();
    }
  }

  List<Widget> _body(BuildContext context, WidgetRef ref, HistoryLockState lock) {
    final theme = Theme.of(context);

    if (lock == HistoryLockState.locked) {
      return [
        _LockedView(
          onUnlock: () => ref.read(historyLockProvider.notifier).unlock(),
        ),
      ];
    }

    final history = ref.watch(historyProvider);

    return [
      if (lock == HistoryLockState.unprotected) ...[
        SoftCard(
          padding: const EdgeInsets.all(16),
          tint: AppColors.caution.withValues(alpha: 0.12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lock_open_rounded,
                  color: AppColors.caution, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your phone has no screen lock, so anyone holding it can '
                      'open this tab. Set a PIN, pattern or fingerprint in your '
                      'phone settings.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurface),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
      ...history.when(
        loading: () => [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
        error: (_, _) => [
          Text('Could not open history.', style: theme.textTheme.bodyMedium),
        ],
        data: (entries) {
          if (entries.isEmpty) return [const _EmptyHistory()];
          return [
            Text(
              'Stored encrypted on this phone. Swipe left to delete one.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Dismissible(
                  key: ValueKey(e.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Icon(Icons.delete_rounded,
                        color: Colors.white),
                  ),
                  onDismissed: (_) {
                    HapticFeedback.mediumImpact();
                    ref.read(historyProvider.notifier).remove(e.id);
                  },
                  child: _EntryTile(
                    entry: e,
                    onTap: () => _showDetails(context, e),
                  ),
                ),
              ),
          ];
        },
      ),
    ];
  }

  void _showDetails(BuildContext context, HistoryEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _DetailSheet(entry: entry),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final lock = ref.watch(historyLockProvider);
    final bottomPad = MediaQuery.of(context).padding.bottom + 110;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('History'),
            backgroundColor: theme.scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            actions: [
              if (lock != HistoryLockState.locked)
                IconButton(
                  tooltip: 'Delete all',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => _confirmClear(context, ref),
                ),
            ],
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, bottomPad),
            sliver: SliverList(
              delegate: SliverChildListDelegate(_body(context, ref, lock)),
            ),
          ),
        ],
      ),
    );
  }
}

class _LockedView extends StatelessWidget {
  const _LockedView({required this.onUnlock});

  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SoftCard(
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 28),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: AppColors.cobalt.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_rounded,
                size: 36, color: AppColors.cobalt),
          ),
          const SizedBox(height: 18),
          Text('History is locked', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Your past checks are encrypted. Unlock with your fingerprint, '
                'face or screen lock to view them.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onUnlock,
            icon: const Icon(Icons.fingerprint_rounded),
            label: const Text('Unlock'),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

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
            child: const Icon(Icons.history_rounded,
                size: 34, color: AppColors.cobalt),
          ),
          const SizedBox(height: 18),
          Text('Nothing here yet', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Links, messages and QR codes you check will appear here, '
                'encrypted on your phone.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.onTap});

  final HistoryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = entry.level.color;

    return GestureDetector(
      onTap: onTap,
      child: SoftCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(entry.source.icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${entry.source.label} · ${_timeAgo(entry.createdAt)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${entry.score}',
                    style:
                    theme.textTheme.titleMedium?.copyWith(color: color)),
                Text(entry.level.label,
                    style: theme.textTheme.bodySmall?.copyWith(color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailSheet extends StatelessWidget {
  const _DetailSheet({required this.entry});

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = entry.level.color;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(entry.level.icon, color: color, size: 28),
                const SizedBox(width: 10),
                Text(entry.level.label,
                    style:
                    theme.textTheme.titleLarge?.copyWith(color: color)),
                const Spacer(),
                Text('${entry.score}/100',
                    style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${entry.source.label} · ${_timeAgo(entry.createdAt)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            SoftCard(
              child: SelectableText(
                entry.content,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            if (entry.reasons.isNotEmpty) ...[
              const SizedBox(height: 16),
              SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('What we noticed',
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 14),
                    for (final r in entry.reasons)
                      ReasonRow(text: r, color: color),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
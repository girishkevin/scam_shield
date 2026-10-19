import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../link_check/domain/link_analyzer.dart';
import '../../message_scan/domain/message_analyzer.dart';
import '../../qr_scan/domain/qr_analyzer.dart';
import '../data/history_store.dart';
import '../domain/history_entry.dart';

final historyStoreProvider = Provider<HistoryStore>((ref) => HistoryStore());

class HistoryNotifier extends AsyncNotifier<List<HistoryEntry>> {
  @override
  Future<List<HistoryEntry>> build() => ref.read(historyStoreProvider).load();

  Future<void> _persist(List<HistoryEntry> entries) async {
    state = AsyncData(entries);
    try {
      await ref.read(historyStoreProvider).save(entries);
    } catch (_) {
      // History is best-effort: a save problem must never break a scan.
    }
  }

  Future<void> add(HistoryEntry entry) async {
    final current = await future;
    await _persist(
      [entry, ...current].take(HistoryStore.maxEntries).toList(),
    );
  }

  Future<void> remove(String id) async {
    final current = await future;
    await _persist(current.where((e) => e.id != id).toList());
  }

  Future<void> clear() async {
    try {
      await ref.read(historyStoreProvider).clear();
    } catch (_) {}
    state = const AsyncData(<HistoryEntry>[]);
  }

  Future<void> addLink(LinkAnalysisResult r) => add(HistoryEntry.create(
    source: HistorySource.link,
    content: r.input,
    score: r.score,
    level: r.level,
    reasons: r.signals.map((s) => s.reason).toList(),
  ));

  Future<void> addMessage(MessageAnalysisResult r) => add(HistoryEntry.create(
    source: HistorySource.message,
    content: r.message,
    score: r.score,
    level: r.level,
    reasons: [
      ...r.textSignals.map((s) => s.reason),
      for (final l in r.linkResults) ...l.signals.map((s) => s.reason),
    ],
  ));

  Future<void> addQr(QrAnalysisResult r) => add(HistoryEntry.create(
    source: HistorySource.qr,
    content: r.raw,
    score: r.score,
    level: r.level,
    reasons: r.signals.map((s) => s.reason).toList(),
  ));
}

final historyProvider =
AsyncNotifierProvider<HistoryNotifier, List<HistoryEntry>>(
    HistoryNotifier.new);
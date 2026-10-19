import 'package:flutter_riverpod/flutter_riverpod.dart';

class SharedTextNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String text) => state = text;

  void clear() => state = null;
}

final sharedTextProvider =
NotifierProvider<SharedTextNotifier, String?>(SharedTextNotifier.new);
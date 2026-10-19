import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/shared_text_provider.dart';
import 'features/link_check/presentation/link_check_screen.dart';
import 'features/message_scan/presentation/message_check_screen.dart';

void main() {
  runApp(const ProviderScope(child: ScamShieldApp()));
}

class ScamShieldApp extends StatelessWidget {
  const ScamShieldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scam Shield',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  static const _channel = MethodChannel('scam_shield/share');
  int _index = 0;

  static const _screens = [
    LinkCheckScreen(),
    MessageCheckScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSharedText') {
        _handleShared(call.arguments as String?);
      }
    });
    _channel.invokeMethod<String>('getInitialText').then(_handleShared);
  }

  void _handleShared(String? text) {
    if (!mounted || text == null || text.trim().isEmpty) return;
    setState(() => _index = 1); // jump to the Message tab
    ref.read(sharedTextProvider.notifier).set(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.link), label: 'Link'),
          NavigationDestination(icon: Icon(Icons.sms_outlined), label: 'Message'),
        ],
      ),
    );
  }
}
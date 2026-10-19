import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/app_theme.dart';
import 'core/shared_text_provider.dart';
import 'core/widgets/floating_nav_bar.dart';
import 'features/link_check/presentation/link_check_screen.dart';
import 'features/message_scan/presentation/message_check_screen.dart';
import 'features/qr_scan/presentation/qr_scan_screen.dart';

void main() {
  runApp(const ProviderScope(child: ScamShieldApp()));
}

class ScamShieldApp extends StatelessWidget {
  const ScamShieldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scam Shield',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      scrollBehavior: const _BounceScrollBehavior(),
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
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: [
          const LinkCheckScreen(),
          const MessageCheckScreen(),
          QrScanScreen(active: _index == 2),
        ],
      ),
      bottomNavigationBar: FloatingNavBar(
        currentIndex: _index,
        onChanged: (i) => setState(() => _index = i),
        items: const [
          NavItem(
            icon: Icons.link_rounded,
            activeIcon: Icons.link_rounded,
            label: 'Link',
          ),
          NavItem(
            icon: Icons.chat_bubble_outline_rounded,
            activeIcon: Icons.chat_bubble_rounded,
            label: 'Message',
          ),
          NavItem(
            icon: Icons.qr_code_scanner_rounded,
            activeIcon: Icons.qr_code_scanner_rounded,
            label: 'Scan',
          ),
        ],
      ),
    );
  }
}

class _BounceScrollBehavior extends MaterialScrollBehavior {
  const _BounceScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) =>
      child;
}
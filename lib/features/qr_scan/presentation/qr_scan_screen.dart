import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/app_theme.dart';
import '../../../core/risk_style.dart';
import '../../../core/widgets/score_ring.dart';
import '../../../core/widgets/soft_card.dart';
import '../../link_check/domain/link_analyzer.dart';
import '../domain/qr_analyzer.dart';
import '../../history/presentation/history_provider.dart';

final qrAnalyzerProvider = Provider<QrAnalyzer>((ref) => QrAnalyzer());

class QrScanScreen extends ConsumerStatefulWidget {
  const QrScanScreen({super.key, required this.active});

  /// True only while this tab is visible, so the camera is off otherwise.
  final bool active;

  @override
  ConsumerState<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends ConsumerState<QrScanScreen>
    with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
    autoStart: false,
  );

  QrAnalysisResult? _result;
  bool _torchOn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.active) _startCamera();
  }

  @override
  void didUpdateWidget(covariant QrScanScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active == oldWidget.active) return;
    if (widget.active && _result == null) {
      _startCamera();
    } else if (!widget.active) {
      _stopCamera();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (widget.active && _result == null) _startCamera();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _stopCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller.dispose());
    super.dispose();
  }

  Future<void> _startCamera() async {
    try {
      await _controller.start();
    } catch (_) {}
  }

  Future<void> _stopCamera() async {
    try {
      await _controller.stop();
    } catch (_) {}
    if (mounted && _torchOn) setState(() => _torchOn = false);
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
      if (mounted) setState(() => _torchOn = !_torchOn);
    } catch (_) {}
  }

  void _onDetect(BarcodeCapture capture) {
    if (_result != null) return;
    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .firstOrNull;
    if (raw == null || raw.trim().isEmpty) return;

    final result = ref.read(qrAnalyzerProvider).analyze(raw);
    unawaited(ref.read(historyProvider.notifier).addQr(result));
    _stopCamera();

    if (result.level == RiskLevel.dangerous) {
      HapticFeedback.heavyImpact();
    } else if (result.level == RiskLevel.suspicious) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }

    setState(() => _result = result);
  }

  void _scanAgain() {
    setState(() => _result = null);
    _startCamera();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = _result;
    final bottomPad = MediaQuery.of(context).padding.bottom + 110;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Scan QR'),
            backgroundColor: theme.scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, bottomPad),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(
                  'Point the camera at a QR code. Scam Shield checks it '
                      'without opening anything.',
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
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
                      ? _CameraCard(
                    key: const ValueKey('camera'),
                    controller: _controller,
                    active: widget.active,
                    onDetect: _onDetect,
                    torchOn: _torchOn,
                    onTorch: _toggleTorch,
                  )
                      : _QrResultSection(
                    key: ValueKey(result),
                    result: result,
                    onScanAgain: _scanAgain,
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraCard extends StatelessWidget {
  const _CameraCard({
    super.key,
    required this.controller,
    required this.active,
    required this.onDetect,
    required this.torchOn,
    required this.onTorch,
  });

  final MobileScannerController controller;
  final bool active;
  final void Function(BarcodeCapture) onDetect;
  final bool torchOn;
  final VoidCallback onTorch;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Colors.black),
            if (active)
              MobileScanner(
                controller: controller,
                onDetect: onDetect,
                errorBuilder: (context, error) =>
                    _CameraError(code: error.errorCode),
              ),
            CustomPaint(
              painter: _ViewfinderPainter(
                  color: Colors.white.withValues(alpha: 0.92)),
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: _RoundButton(
                icon: torchOn
                    ? Icons.flash_on_rounded
                    : Icons.flash_off_rounded,
                onTap: onTorch,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.code});

  final MobileScannerErrorCode code;

  @override
  Widget build(BuildContext context) {
    final denied = code == MobileScannerErrorCode.permissionDenied;

    return ColoredBox(
      color: Colors.black,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.no_photography_rounded,
                color: Colors.white70, size: 44),
            const SizedBox(height: 16),
            Text(
              denied
                  ? 'Camera access is off. Allow it for Scam Shield in your '
                  'phone settings to scan codes.'
                  : 'The camera is not available right now.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: Color(0x66000000),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _ViewfinderPainter extends CustomPainter {
  _ViewfinderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    const inset = 40.0;
    const len = 36.0;
    final l = inset;
    final t = inset;
    final r = size.width - inset;
    final b = size.height - inset;

    final path = Path()
      ..moveTo(l, t + len)
      ..lineTo(l, t)
      ..lineTo(l + len, t)
      ..moveTo(r - len, t)
      ..lineTo(r, t)
      ..lineTo(r, t + len)
      ..moveTo(r, b - len)
      ..lineTo(r, b)
      ..lineTo(r - len, b)
      ..moveTo(l + len, b)
      ..lineTo(l, b)
      ..lineTo(l, b - len);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ViewfinderPainter old) => old.color != color;
}

String _orNotProvided(String? v) =>
    (v == null || v.trim().isEmpty) ? 'Not provided' : v;

class _QrResultSection extends StatelessWidget {
  const _QrResultSection({
    super.key,
    required this.result,
    required this.onScanAgain,
  });

  final QrAnalysisResult result;
  final VoidCallback onScanAgain;

  String get _summary {
    if (result.kind == QrKind.upi) {
      return result.level == RiskLevel.dangerous
          ? 'This payment code looks broken or fake. Do not pay.'
          : 'This code will ask you to pay. Only continue if you are paying '
          'someone you trust.';
    }
    return switch (result.level) {
      RiskLevel.safe => 'No warning signs found in this code.',
      RiskLevel.suspicious => 'Some things look off. Think twice before '
          'opening it.',
      RiskLevel.dangerous => 'This code looks like a scam. Do not open it.',
    };
  }

  Widget _detailCard(BuildContext context) {
    final theme = Theme.of(context);

    switch (result.kind) {
      case QrKind.upi:
        final u = result.upi;
        final amount = (u?.amount ?? '').trim();
        return SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Payment details', style: theme.textTheme.titleMedium),
              const SizedBox(height: 14),
              _DetailRow(label: 'Pay to', value: _orNotProvided(u?.payeeName)),
              _DetailRow(
                  label: 'UPI ID', value: _orNotProvided(u?.payeeAddress)),
              _DetailRow(
                  label: 'Amount',
                  value: amount.isEmpty ? 'You choose' : '₹$amount'),
            ],
          ),
        );
      case QrKind.link:
      case QrKind.text:
        return SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.kind == QrKind.link
                    ? 'Link in this QR code'
                    : 'Text in this QR code',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              SelectableText(
                result.raw,
                maxLines: 6,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        );
    }
  }

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
              Text(_summary,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _detailCard(context),
        if (result.signals.isNotEmpty) ...[
          const SizedBox(height: 16),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('What we noticed', style: theme.textTheme.titleMedium),
                const SizedBox(height: 14),
                for (final s in result.signals)
                  ReasonRow(text: s.reason, color: level.color),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        SoftCard(
          padding: const EdgeInsets.all(16),
          tint: AppColors.cobalt.withValues(alpha: 0.08),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lock_outline_rounded,
                  color: AppColors.cobalt, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Scam Shield never opens links for you. This code was '
                      'checked on your phone only.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurface),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onScanAgain,
          icon: const Icon(Icons.qr_code_scanner_rounded),
          label: const Text('Scan another code'),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.titleSmall),
          ),
        ],
      ),
    );
  }
}
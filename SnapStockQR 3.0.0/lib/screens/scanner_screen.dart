import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../ui/app_theme.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with WidgetsBindingObserver {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  bool _scanned = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.value.isInitialized) return;
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_scanned) unawaited(_safeStart());
        return;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        unawaited(_safeStop());
        return;
    }
  }

  Future<void> _safeStart() async {
    try {
      await _controller.start();
    } catch (_) {
      // El widget de cámara mostrará el error correspondiente.
    }
  }

  Future<void> _safeStop() async {
    try {
      await _controller.stop();
    } catch (_) {
      // La cámara puede haberse detenido ya por el sistema.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_safeStop());
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value != null && value.isNotEmpty) {
        _scanned = true;
        unawaited(_safeStop());
        Navigator.pop(context, value);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Escanear artículo'),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest.shortestSide.clamp(230.0, 320.0);
            return Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                  errorBuilder: (context, error, child) => _ScannerError(
                    onRetry: _safeStart,
                  ),
                ),
                IgnorePointer(
                  child: CustomPaint(painter: _ScannerOverlayPainter(size)),
                ),
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 28,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const Text(
                          'Alinee el código dentro del marco',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      ValueListenableBuilder<MobileScannerState>(
                        valueListenable: _controller,
                        builder: (context, state, child) => Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton.filled(
                              tooltip: state.torchState == TorchState.on
                                  ? 'Apagar linterna'
                                  : 'Encender linterna',
                              onPressed:
                                  state.torchState == TorchState.unavailable
                                      ? null
                                      : _controller.toggleTorch,
                              icon: Icon(
                                state.torchState == TorchState.on
                                    ? Icons.flash_on_rounded
                                    : Icons.flash_off_rounded,
                              ),
                            ),
                            const SizedBox(width: 16),
                            IconButton.filled(
                              tooltip: 'Cambiar cámara',
                              onPressed: (state.availableCameras ?? 0) < 2
                                  ? null
                                  : _controller.switchCamera,
                              icon: const Icon(Icons.cameraswitch_rounded),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ScannerError extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _ScannerError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                color: AppColors.textMuted,
                size: 52,
              ),
              const SizedBox(height: 16),
              Text(
                'No fue posible iniciar la cámara',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Revise el permiso de cámara e inténtelo nuevamente.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final double squareSize;

  const _ScannerOverlayPainter(this.squareSize);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final rect = Rect.fromCenter(
      center: center.translate(0, -28),
      width: squareSize,
      height: squareSize,
    );
    final outer = Path()..addRect(Offset.zero & size);
    final inner = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(26)));
    canvas.drawPath(
      Path.combine(PathOperation.difference, outer, inner),
      Paint()..color = Colors.black.withValues(alpha: 0.58),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(26)),
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) =>
      oldDelegate.squareSize != squareSize;
}

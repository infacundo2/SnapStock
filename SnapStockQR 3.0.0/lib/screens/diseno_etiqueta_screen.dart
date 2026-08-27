import 'package:flutter/material.dart';

import '../services/print_service.dart';
import '../ui/app_theme.dart';
import '../widgets/app_components.dart';

class DisenoEtiquetaScreen extends StatefulWidget {
  const DisenoEtiquetaScreen({super.key});

  @override
  State<DisenoEtiquetaScreen> createState() => _DisenoEtiquetaScreenState();
}

class _DisenoEtiquetaScreenState extends State<DisenoEtiquetaScreen> {
  double _width = 100;
  double _height = 30;
  int _columns = 2;
  double _qrX = 114;
  double _qrY = 6;
  int _qrSize = 5;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await PrintService.obtenerAjustesEtiqueta();
    if (!mounted) return;
    setState(() {
      _width = (settings['ancho'] as num).toDouble();
      _height = (settings['alto'] as num).toDouble();
      _columns = (settings['columnas'] as num).toInt();
      _qrX = (settings['qrX'] as num).toDouble();
      _qrY = (settings['qrY'] as num).toDouble();
      _qrSize = (settings['qrSize'] as num).toInt();
      _clampPosition();
      _loading = false;
    });
  }

  void _clampPosition() {
    final columnDots = (_width * 8 / _columns).round();
    final heightDots = (_height * 8).round();
    final qrDots = _qrSize * 30;
    _qrX = _qrX.clamp(0, (columnDots - qrDots).clamp(0, columnDots).toDouble());
    _qrY = _qrY.clamp(0, (heightDots - qrDots).clamp(0, heightDots).toDouble());
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await PrintService.guardarAjustesEtiqueta(
        ancho: _width,
        alto: _height,
        columnas: _columns,
        qrX: _qrX,
        qrY: _qrY,
        qrSize: _qrSize,
      );
      if (mounted) showAppMessage(context, 'Diseño de etiqueta guardado.');
    } catch (_) {
      if (mounted) {
        showAppMessage(
          context,
          'No fue posible guardar el diseño.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _reset() {
    setState(() {
      _width = 100;
      _height = 30;
      _columns = 2;
      _qrX = 114;
      _qrY = 6;
      _qrSize = 5;
      _clampPosition();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diseño de etiqueta'),
        actions: [
          IconButton(
            tooltip: 'Restablecer diseño',
            onPressed: _loading || _saving ? null : _reset,
            icon: const Icon(Icons.restart_alt_rounded),
          ),
          IconButton(
            tooltip: 'Guardar diseño',
            onPressed: _loading || _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 820;
                  if (wide) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _buildPreview()),
                          const SizedBox(width: 20),
                          SizedBox(
                            width: 390,
                            child: SingleChildScrollView(
                              child: _buildControls(),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    child: Column(
                      children: [
                        SizedBox(height: 300, child: _buildPreview()),
                        const SizedBox(height: 18),
                        _buildControls(),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildPreview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppSectionTitle('Vista previa'),
            const SizedBox(height: 6),
            const Text(
              'Arrastre el QR para posicionarlo dentro de la primera columna.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: _width / _height,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final scale = constraints.maxWidth / _width;
                      final qrPixels =
                          (_qrSize * 3.75 * scale).clamp(34.0, 150.0);
                      final xPixels = _qrX / 8 * scale;
                      final yPixels = _qrY / 8 * scale;
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x55000000),
                              blurRadius: 18,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Stack(
                          clipBehavior: Clip.hardEdge,
                          children: [
                            if (_columns == 2)
                              Center(
                                child: Container(
                                  width: 1,
                                  color: Colors.black12,
                                ),
                              ),
                            Positioned(
                              left: xPixels,
                              top: yPixels,
                              child: GestureDetector(
                                onPanUpdate: (details) {
                                  setState(() {
                                    _qrX += details.delta.dx / scale * 8;
                                    _qrY += details.delta.dy / scale * 8;
                                    _clampPosition();
                                  });
                                },
                                child: _PreviewQr(size: qrPixels),
                              ),
                            ),
                            if (_columns == 2)
                              Positioned(
                                left: constraints.maxWidth / 2 + xPixels,
                                top: yPixels,
                                child: IgnorePointer(
                                  child: _PreviewQr(
                                    size: qrPixels,
                                    secondary: true,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${_width.toStringAsFixed(0)} × ${_height.toStringAsFixed(0)} mm · '
              'X ${_qrX.round()} / Y ${_qrY.round()} puntos',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppSectionTitle('Configuración'),
            const SizedBox(height: 16),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 1,
                  icon: Icon(Icons.crop_portrait_rounded),
                  label: Text('1 columna'),
                ),
                ButtonSegment(
                  value: 2,
                  icon: Icon(Icons.view_column_outlined),
                  label: Text('2 columnas'),
                ),
              ],
              selected: {_columns},
              onSelectionChanged: (value) => setState(() {
                _columns = value.first;
                _clampPosition();
              }),
            ),
            const SizedBox(height: 20),
            _slider(
              label: 'Escala del QR',
              value: _qrSize.toDouble(),
              min: 2,
              max: 10,
              display: '$_qrSize×',
              divisions: 8,
              onChanged: (value) => setState(() {
                _qrSize = value.round();
                _clampPosition();
              }),
            ),
            _slider(
              label: 'Ancho de etiqueta',
              value: _width,
              min: 40,
              max: 110,
              display: '${_width.round()} mm',
              divisions: 70,
              onChanged: (value) => setState(() {
                _width = value;
                _clampPosition();
              }),
            ),
            _slider(
              label: 'Alto de etiqueta',
              value: _height,
              min: 15,
              max: 100,
              display: '${_height.round()} mm',
              divisions: 85,
              onChanged: (value) => setState(() {
                _height = value;
                _clampPosition();
              }),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(_saving ? 'Guardando…' : 'Guardar diseño'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slider({
    required String label,
    required double value,
    required double min,
    required double max,
    required String display,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              Text(
                display,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _PreviewQr extends StatelessWidget {
  final double size;
  final bool secondary;

  const _PreviewQr({required this.size, this.secondary = false});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: secondary ? 'Copia del código QR' : 'Código QR arrastrable',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: secondary ? Colors.black26 : AppColors.primary,
            width: secondary ? 1 : 2,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(Icons.qr_code_2_rounded,
            color: Colors.black, size: size * .86),
      ),
    );
  }
}

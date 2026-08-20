import 'package:flutter/material.dart';
import '../services/print_service.dart';

class DisenoEtiquetaScreen extends StatefulWidget {
  const DisenoEtiquetaScreen({super.key});

  @override
  State<DisenoEtiquetaScreen> createState() => _DisenoEtiquetaScreenState();
}

class _DisenoEtiquetaScreenState extends State<DisenoEtiquetaScreen> {
  double anchoEtiqueta = 100.0;
  double altoEtiqueta = 30.0;
  int columnas = 2;
  double posX = 114.0;
  double posY = 6.0;
  int qrSize = 5;

  @override
  void initState() {
    super.initState();
    _cargarAjustes();
  }

  Future<void> _cargarAjustes() async {
    final ajustes = await PrintService.obtenerAjustesEtiqueta();
    setState(() {
      anchoEtiqueta = ajustes['ancho'];
      altoEtiqueta = ajustes['alto'];
      columnas = ajustes['columnas'];
      posX = ajustes['qrX'];
      posY = ajustes['qrY'];
      qrSize = ajustes['qrSize'];
    });
  }

  void _guardar() async {
    await PrintService.guardarAjustesEtiqueta(
      ancho: anchoEtiqueta,
      alto: altoEtiqueta,
      columnas: columnas,
      qrX: posX,
      qrY: posY,
      qrSize: qrSize,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Configuración de etiqueta guardada"),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Escala base para representar mm en pantalla
    double escalaVista = 4.0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Diseño de Etiqueta"),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _guardar,
            tooltip: "Guardar diseño",
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 15),
            child: Text(
              "ARRASTRA EL QR PARA POSICIONAR",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 11,
                letterSpacing: 1.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // ÁREA DE PREVISUALIZACIÓN CON FITTEDBOX PARA EVITAR LIMITACIONES
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Container(
                    width: anchoEtiqueta * escalaVista,
                    height: altoEtiqueta * escalaVista,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.red.shade900, width: 2),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Guía central para 2 columnas
                        if (columnas == 2)
                          Center(
                            child: Container(
                              width: 1,
                              color: Colors.grey.shade300,
                            ),
                          ),

                        // QR ARRASTRABLE
                        Positioned(
                          left: posX * (escalaVista / 8),
                          top: posY * (escalaVista / 8),
                          child: GestureDetector(
                            onPanUpdate: (details) {
                              setState(() {
                                posX += details.delta.dx * (8 / escalaVista);
                                posY += details.delta.dy * (8 / escalaVista);
                              });
                            },
                            child: Container(
                              width: qrSize * 15.0,
                              height: qrSize * 15.0,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.blue.withValues(alpha: 0.5),
                                  width: 1,
                                ),
                              ),
                              child: const Icon(
                                Icons.qr_code_2,
                                color: Colors.black,
                                size: 40,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // PANEL DE CONTROL INFERIOR
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Formato:",
                      style: TextStyle(color: Colors.white),
                    ),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 1, label: Text("1 Col")),
                        ButtonSegment(value: 2, label: Text("2 Cols")),
                      ],
                      selected: {columnas},
                      onSelectionChanged: (val) =>
                          setState(() => columnas = val.first),
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? Colors.red.shade900
                              : Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                _controlSlider(
                  "Tamaño del QR",
                  qrSize.toDouble(),
                  2,
                  10,
                  (v) => setState(() => qrSize = v.toInt()),
                ),
                _controlSlider(
                  "Ancho (mm)",
                  anchoEtiqueta,
                  40,
                  110,
                  (v) => setState(() => anchoEtiqueta = v),
                ),
                _controlSlider(
                  "Alto (mm)",
                  altoEtiqueta,
                  15,
                  100,
                  (v) => setState(() => altoEtiqueta = v),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _guardar,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text("CONFIRMAR DISEÑO"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade900,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _controlSlider(
    String label,
    double val,
    double min,
    double max,
    Function(double) onCh,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            Text(
              "${val.toStringAsFixed(0)} mm",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Slider(
          value: val,
          min: min,
          max: max,
          activeColor: Colors.red.shade900,
          inactiveColor: Colors.white10,
          onChanged: onCh,
        ),
      ],
    );
  }
}

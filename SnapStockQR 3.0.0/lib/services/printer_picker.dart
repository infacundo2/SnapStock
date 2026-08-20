import 'package:flutter/material.dart';
import 'print_service.dart';

class PrinterPicker {
  static Future<void> mostrar(BuildContext context) async {
    // Cargamos los datos ANTES de mostrar el diálogo para asegurar persistencia visual
    final String? ipGuardada = await PrintService.obtenerIpGuardada();
    final String? nombreGuardado = await PrintService.obtenerNombreGuardado();

    final TextEditingController ipController = TextEditingController(
      text: ipGuardada ?? "",
    );
    final TextEditingController nameController = TextEditingController(
      text: nombreGuardado ?? "",
    );
    bool probando = false;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text("Configurar Impresora de Red"),
            scrollable: true,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Configura la PC que comparte la impresora (Protocolo LPR/Port 515):",
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: ipController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "IP del Equipo / Servidor",
                    hintText: "Ej: 192.168.1.100",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.computer),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: "Nombre de la Impresora",
                    hintText: "Ej: Barpos_ZPL",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.print),
                  ),
                ),
                const SizedBox(height: 15),
                if (probando)
                  const CircularProgressIndicator()
                else
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey.shade800,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      final ip = ipController.text.trim();
                      if (ip.isEmpty) return;

                      setState(() => probando = true);
                      final resultado = await PrintService.probarConexion(ip);
                      setState(() => probando = false);

                      if (context.mounted) {
                        bool exito = resultado == "OK";
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(
                              exito ? "Conexión Exitosa" : "Fallo de Conexión",
                            ),
                            content: Text(
                              exito
                                  ? "Se pudo establecer contacto con la IP $ip en el puerto 515."
                                  : "Error: $resultado\n\nVerifique:\n1. Que el servicio LPD esté activo.\n2. El Firewall de la PC.\n3. Que estén en la misma red Wi-Fi.",
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text("ENTENDIDO"),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.settings_input_component),
                    label: const Text("TESTEAR PUERTO 515"),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("CANCELAR"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final ip = ipController.text.trim();
                  final name = nameController.text.trim();
                  if (ip.isEmpty || name.isEmpty) return;

                  await PrintService.guardarConfiguracion(ip, name);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Configurado: $name en $ip")),
                    );
                  }
                },
                child: const Text("GUARDAR"),
              ),
            ],
          ),
        );
      },
    );
  }
}

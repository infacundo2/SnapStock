import 'package:flutter/material.dart';

import '../ui/app_theme.dart';
import '../widgets/app_components.dart';
import 'print_service.dart';

class PrinterPicker {
  static Future<void> mostrar(BuildContext context) async {
    final savedHost = await PrintService.obtenerIpGuardada();
    final savedQueue = await PrintService.obtenerNombreGuardado();
    if (!context.mounted) return;

    final hostController = TextEditingController(text: savedHost ?? '');
    final queueController = TextEditingController(text: savedQueue ?? '');
    final formKey = GlobalKey<FormState>();
    var testing = false;
    var saving = false;
    String? testResult;
    bool? testSucceeded;

    try {
      final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Impresora de red'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: SizedBox(
                  width: 440,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Configure el equipo que comparte la impresora mediante LPR en el puerto 515.',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: hostController,
                        enabled: !testing && !saving,
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        textCapitalization: TextCapitalization.none,
                        decoration: const InputDecoration(
                          labelText: 'IP o nombre del equipo',
                          hintText: '192.168.1.100',
                          prefixIcon: Icon(Icons.computer_outlined),
                        ),
                        validator: (value) {
                          final clean = value?.trim() ?? '';
                          if (clean.isEmpty) return 'Ingrese una dirección.';
                          if (clean.contains(RegExp(r'[\s/\\]'))) {
                            return 'Ingrese sólo la IP o nombre del equipo.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: queueController,
                        enabled: !testing && !saving,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'Nombre de cola LPR',
                          hintText: 'Barpos_ZPL',
                          prefixIcon: Icon(Icons.print_outlined),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Ingrese el nombre de la cola.'
                                : null,
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: testing || saving
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setDialogState(() {
                                  testing = true;
                                  testResult = null;
                                  testSucceeded = null;
                                });
                                final result =
                                    await PrintService.probarConexion(
                                  hostController.text,
                                );
                                if (!dialogContext.mounted) return;
                                setDialogState(() {
                                  testing = false;
                                  testSucceeded = result == 'OK';
                                  testResult = result == 'OK'
                                      ? 'Conexión correcta al puerto 515.'
                                      : result;
                                });
                              },
                        icon: testing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.cable_rounded),
                        label:
                            Text(testing ? 'Comprobando…' : 'Probar conexión'),
                      ),
                      if (testResult != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (testSucceeded == true
                                    ? AppColors.success
                                    : Theme.of(context).colorScheme.error)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                testSucceeded == true
                                    ? Icons.check_circle_outline
                                    : Icons.error_outline,
                                color: testSucceeded == true
                                    ? AppColors.success
                                    : Theme.of(context).colorScheme.error,
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Text(testResult!)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: testing || saving
                    ? null
                    : () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: testing || saving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => saving = true);
                        try {
                          await PrintService.guardarConfiguracion(
                            hostController.text,
                            queueController.text,
                          );
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext, true);
                          }
                        } catch (error) {
                          if (!dialogContext.mounted) return;
                          setDialogState(() {
                            saving = false;
                            testSucceeded = false;
                            testResult = error
                                .toString()
                                .replaceFirst('Exception: ', '')
                                .trim();
                          });
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Guardar'),
              ),
            ],
          ),
        ),
      );

      if (saved == true && context.mounted) {
        showAppMessage(context, 'Configuración de impresora guardada.');
      }
    } finally {
      hostController.dispose();
      queueController.dispose();
    }
  }
}

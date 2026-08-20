import 'package:flutter/material.dart';
import 'dart:io';
import '../models/registro_model.dart';

class DetalleScreen extends StatelessWidget {
  final Registro registro;

  const DetalleScreen({super.key, required this.registro});

  @override
  Widget build(BuildContext context) {
    final fotos = registro.listaFotos;

    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Fondo oscuro elegante
      appBar: AppBar(
        title: Text(
          registro.nombre,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Galería de fotos con estilo tarjeta
            if (fotos.isNotEmpty)
              SizedBox(
                height: 400,
                child: PageView.builder(
                  itemCount: fotos.length,
                  itemBuilder: (context, index) {
                    final path = fotos[index];
                    return Container(
                      margin: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: path.startsWith('http')
                            ? Image.network(
                                path,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.broken_image, size: 100),
                              )
                            : Image.file(File(path), fit: BoxFit.cover),
                      ),
                    );
                  },
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Categoría y Fecha con estilo moderno
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade900.withValues(alpha: 0.2),
                          border: Border.all(color: Colors.red.shade900),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          registro.categoria.toUpperCase(),
                          style: TextStyle(
                            color: Colors.red.shade100,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        registro.fecha,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),
                  const Text(
                    "INFORMACIÓN GENERAL",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(color: Colors.grey),
                  const SizedBox(height: 15),

                  Text(
                    registro.nombre,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 25),
                  const Text(
                    "OBSERVACIONES / CONTENIDO",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Text(
                    registro.observaciones.isEmpty
                        ? "Sin observaciones adicionales."
                        : registro.observaciones,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.9),
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 50),
                  Center(
                    child: Text(
                      "UUID: ${registro.uuid}",
                      style: const TextStyle(
                        color: Colors.white24,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../models/registro_model.dart';
import '../database/db_helper.dart';
import '../services/print_service.dart';
import '../services/api_service.dart';
import 'package:uuid/uuid.dart';

class FormularioScreen extends StatefulWidget {
  final Registro? registroEdicion;

  const FormularioScreen({super.key, this.registroEdicion});

  @override
  State<FormularioScreen> createState() => _FormularioScreenState();
}

class _FormularioScreenState extends State<FormularioScreen> {
  final _nombreController = TextEditingController();
  final _obsController = TextEditingController();
  final _nuevaCategoriaController = TextEditingController();
  String _categoriaSeleccionada = 'General';
  final List<String> _categoriasExistentes = [
    'General',
    'Inventario',
    'Personal',
    'Otros',
  ];
  List<String> _listaFotosPaths = [];
  bool _subiendo = false;
  int? _idRecienCreado;
  String? _uuidFijo;

  @override
  void initState() {
    super.initState();
    _cargarCategoriasDesdeServidor();
    if (widget.registroEdicion != null) {
      _nombreController.text = widget.registroEdicion!.nombre;
      _obsController.text = widget.registroEdicion!.observaciones;
      _categoriaSeleccionada = widget.registroEdicion!.categoria;
      _listaFotosPaths = widget.registroEdicion!.listaFotos;
      _uuidFijo = widget.registroEdicion!.uuid;
      if (!_categoriasExistentes.contains(_categoriaSeleccionada)) {
        _categoriasExistentes.insert(
          _categoriasExistentes.length - 1,
          _categoriaSeleccionada,
        );
      }
    } else {
      _uuidFijo = const Uuid().v4();
    }
  }

  Future<void> _cargarCategoriasDesdeServidor() async {
    try {
      final categorias = await ApiService.obtenerCategorias();
      if (!mounted) return;
      setState(() {
        for (var cat in categorias) {
          if (!_categoriasExistentes.contains(cat)) {
            _categoriasExistentes.insert(_categoriasExistentes.length - 1, cat);
          }
        }
      });
    } on ApiException catch (error) {
      if (mounted && !error.isUnauthorized) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _agregarFoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );
    if (photo != null) {
      setState(() {
        _listaFotosPaths.add(photo.path);
      });
    }
  }

  void _mostrarErrorCentro(String mensaje) {
    showDialog(
      context: context,
      builder: (context) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 30),
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.red.shade800, width: 2),
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red.shade400,
                  size: 50,
                ),
                const SizedBox(height: 20),
                const Text(
                  "ERROR DE SISTEMA",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  mensaje,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.red.shade300,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 25),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade900,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "CERRAR AVISO",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _mostrarDialogoImpresion(Registro registro, {bool esEdicion = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(esEdicion ? "Cambios Guardados" : "Registro Guardado"),
        content: const Text("¿Desea imprimir la etiqueta QR?"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pop(context, true);
            },
            child: const Text("NO"),
          ),
          ElevatedButton(
            onPressed: () async {
              final dialogNavigator = Navigator.of(dialogContext);
              final pageNavigator = Navigator.of(context);
              try {
                await PrintService.imprimirEtiqueta(registro);
                if (!mounted) return;
                dialogNavigator.pop();
                pageNavigator.pop(true);
              } catch (e) {
                if (!mounted) return;
                dialogNavigator.pop();
                _mostrarErrorCentro(e.toString().replaceAll("Exception:", ""));
              }
            },
            child: const Text("SÍ, IMPRIMIR"),
          ),
        ],
      ),
    );
  }

  Future<void> _guardarArticulo() async {
    if (_listaFotosPaths.isEmpty || _nombreController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Faltan datos obligatorios")),
      );
      return;
    }
    setState(() {
      _subiendo = true;
    });
    try {
      String catFinal = _categoriaSeleccionada == 'Otros'
          ? _nuevaCategoriaController.text
          : _categoriaSeleccionada;
      if (catFinal.isEmpty) catFinal = 'General';

      // RECOPILAMOS TODAS LAS FOTOS NUEVAS (ARCHIVOS LOCALES)
      List<File> fotosNuevas = [];
      for (var path in _listaFotosPaths) {
        if (!path.startsWith('http')) {
          fotosNuevas.add(File(path));
        }
      }

      final registro = Registro(
        id: widget.registroEdicion?.id ?? _idRecienCreado,
        uuid: _uuidFijo!,
        nombre: _nombreController.text,
        fecha: widget.registroEdicion?.fecha ??
            DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now()),
        observaciones: _obsController.text,
        categoria: catFinal,
        fotoPaths: _listaFotosPaths.join(
          ',',
        ), // Enviamos la lista completa de rutas al servidor
      );

      final exito = await ApiService.guardar(registro, fotosNuevas);

      if (exito) {
        if (registro.id == null) {
          _idRecienCreado = await DbHelper.insertar(registro);
          registro.id = _idRecienCreado;
        } else {
          await DbHelper.actualizar(registro);
        }
        if (!mounted) return;
        setState(() {
          _subiendo = false;
        });
        _mostrarDialogoImpresion(
          registro,
          esEdicion: widget.registroEdicion != null || _idRecienCreado != null,
        );
      } else {
        throw Exception("Error al conectar con el servidor corporativo.");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _subiendo = false;
      });
      _mostrarErrorCentro(e.toString().replaceAll("Exception:", ""));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.registroEdicion == null
              ? 'Nuevo Corporativo'
              : 'Editar Corporativo',
        ),
        actions: [
          if (widget.registroEdicion != null)
            IconButton(
              icon: const Icon(Icons.print, color: Colors.white),
              tooltip: "Solo Imprimir",
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await PrintService.imprimirEtiqueta(widget.registroEdicion!);
                  if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text("Enviado a impresora")),
                    );
                  }
                } catch (e) {
                  if (!mounted) return;
                  _mostrarErrorCentro(
                    e.toString().replaceAll("Exception:", ""),
                  );
                }
              },
            ),
        ],
      ),
      body: _subiendo
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 150,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _listaFotosPaths.length + 1,
                            itemBuilder: (context, index) {
                              if (index == _listaFotosPaths.length) {
                                return GestureDetector(
                                  onTap: _agregarFoto,
                                  child: Container(
                                    width: 120,
                                    margin: const EdgeInsets.only(right: 10),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.add_a_photo,
                                      size: 40,
                                      color: Colors.grey,
                                    ),
                                  ),
                                );
                              }
                              final path = _listaFotosPaths[index];
                              return Stack(
                                children: [
                                  Container(
                                    width: 120,
                                    margin: const EdgeInsets.only(right: 10),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: path.startsWith('http')
                                          ? Image.network(
                                              path,
                                              fit: BoxFit.cover,
                                            )
                                          : Image.file(
                                              File(path),
                                              fit: BoxFit.cover,
                                            ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 15,
                                    top: 5,
                                    child: GestureDetector(
                                      onTap: () => setState(
                                        () => _listaFotosPaths.removeAt(index),
                                      ),
                                      child: const CircleAvatar(
                                        backgroundColor: Colors.red,
                                        radius: 12,
                                        child: Icon(
                                          Icons.close,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _nombreController,
                          decoration: const InputDecoration(
                            labelText: 'Nombre del Artículo',
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue: _categoriasExistentes.contains(
                            _categoriaSeleccionada,
                          )
                              ? _categoriaSeleccionada
                              : 'General',
                          items: _categoriasExistentes
                              .map(
                                (cat) => DropdownMenuItem(
                                  value: cat,
                                  child: Text(cat),
                                ),
                              )
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _categoriaSeleccionada = val!),
                          decoration: const InputDecoration(
                            labelText: 'Categoría',
                          ),
                        ),
                        if (_categoriaSeleccionada == 'Otros')
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: TextField(
                              controller: _nuevaCategoriaController,
                              decoration: const InputDecoration(
                                labelText: 'Nombre de la Nueva Categoría',
                              ),
                            ),
                          ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _obsController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Observaciones Técnicas',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(60),
                      backgroundColor: Colors.red.shade900,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _guardarArticulo,
                    child: Text(
                      widget.registroEdicion == null
                          ? "GUARDAR ARTÍCULO"
                          : "GUARDAR CAMBIOS",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../database/db_helper.dart';
import '../models/registro_model.dart';
import '../services/api_service.dart';
import '../services/print_service.dart';
import '../ui/app_theme.dart';
import '../widgets/app_components.dart';

class FormularioScreen extends StatefulWidget {
  final Registro? registroEdicion;

  const FormularioScreen({super.key, this.registroEdicion});

  @override
  State<FormularioScreen> createState() => _FormularioScreenState();
}

class _FormularioScreenState extends State<FormularioScreen> {
  static const _maxPhotos = 8;

  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _obsController = TextEditingController();
  final _nuevaCategoriaController = TextEditingController();
  final _picker = ImagePicker();
  final List<String> _categorias = [
    'General',
    'Inventario',
    'Personal',
    'Otros',
  ];

  late final String _uuid;
  String _categoriaSeleccionada = 'General';
  List<String> _fotos = [];
  bool _guardando = false;
  bool _cargandoCategorias = true;

  @override
  void initState() {
    super.initState();
    final registro = widget.registroEdicion;
    _uuid = registro?.uuid ?? const Uuid().v4();
    if (registro != null) {
      _nombreController.text = registro.nombre;
      _obsController.text = registro.observaciones;
      _categoriaSeleccionada = registro.categoria;
      _fotos = List<String>.of(registro.listaFotos);
      if (!_categorias.contains(_categoriaSeleccionada)) {
        _categorias.insert(_categorias.length - 1, _categoriaSeleccionada);
      }
    }
    _cargarCategorias();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _obsController.dispose();
    _nuevaCategoriaController.dispose();
    super.dispose();
  }

  Future<void> _cargarCategorias() async {
    try {
      final categorias = await ApiService.obtenerCategorias();
      if (!mounted) return;
      setState(() {
        for (final categoria in categorias) {
          final clean = categoria.trim();
          if (clean.isNotEmpty && !_categorias.contains(clean)) {
            _categorias.insert(_categorias.length - 1, clean);
          }
        }
        _cargandoCategorias = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _cargandoCategorias = false);
      await _handleApiError(error);
    }
  }

  Future<void> _elegirOrigenFoto() async {
    if (_fotos.length >= _maxPhotos) {
      showAppMessage(
        context,
        'Puede adjuntar hasta $_maxPhotos fotografías.',
        error: true,
      );
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Agregar fotografía',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Tomar una foto'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Elegir desde galería'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null) return;

    try {
      if (source == ImageSource.camera) {
        final photo = await _picker.pickImage(
          source: source,
          imageQuality: 78,
          maxWidth: 2200,
        );
        if (photo != null && mounted) {
          setState(() => _fotos.add(photo.path));
        }
      } else {
        final remaining = _maxPhotos - _fotos.length;
        final photos = await _picker.pickMultiImage(
          imageQuality: 78,
          maxWidth: 2200,
          limit: remaining,
        );
        if (mounted && photos.isNotEmpty) {
          setState(() {
            _fotos.addAll(photos.take(remaining).map((photo) => photo.path));
          });
        }
      }
    } catch (_) {
      if (mounted) {
        showAppMessage(
          context,
          'No fue posible acceder a la cámara o galería.',
          error: true,
        );
      }
    }
  }

  Future<void> _guardarArticulo() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate() || _guardando) return;
    if (_fotos.isEmpty) {
      showAppMessage(
        context,
        'Agregue al menos una fotografía del artículo.',
        error: true,
      );
      return;
    }

    final localPhotos = <File>[];
    for (final path in _fotos.where((path) => !path.startsWith('http'))) {
      final file = File(path);
      if (!await file.exists()) {
        if (mounted) {
          showAppMessage(
            context,
            'Una fotografía ya no está disponible. Elimínela y agréguela nuevamente.',
            error: true,
          );
        }
        return;
      }
      localPhotos.add(file);
    }

    setState(() => _guardando = true);
    final isEditing = widget.registroEdicion != null;
    try {
      final categoria = _categoriaSeleccionada == 'Otros'
          ? _nuevaCategoriaController.text.trim()
          : _categoriaSeleccionada.trim();
      final registro = Registro(
        id: widget.registroEdicion?.id,
        uuid: _uuid,
        nombre: _nombreController.text.trim(),
        fecha: widget.registroEdicion?.fecha ??
            DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now()),
        observaciones: _obsController.text.trim(),
        categoria: categoria,
        fotoPaths: _fotos.join(','),
      );

      registro.fotoPaths = await ApiService.guardar(registro, localPhotos);
      await DbHelper.guardar(registro);
      if (!mounted) return;
      setState(() {
        _fotos = List<String>.of(registro.listaFotos);
        _guardando = false;
      });
      await _mostrarDialogoImpresion(registro, isEditing: isEditing);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _guardando = false);
      await _handleApiError(error);
    } catch (_) {
      if (!mounted) return;
      setState(() => _guardando = false);
      showAppMessage(
        context,
        'No fue posible guardar el artículo.',
        error: true,
      );
    }
  }

  Future<void> _mostrarDialogoImpresion(
    Registro registro, {
    required bool isEditing,
  }) async {
    var printing = false;
    String? printError;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: const Icon(
            Icons.check_circle_rounded,
            color: AppColors.success,
            size: 42,
          ),
          title: Text(isEditing ? 'Cambios guardados' : 'Artículo guardado'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('¿Desea imprimir ahora la etiqueta QR?'),
              if (printError != null) ...[
                const SizedBox(height: 14),
                Text(
                  printError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed:
                  printing ? null : () => Navigator.pop(dialogContext, true),
              child: const Text('Cerrar'),
            ),
            FilledButton.icon(
              onPressed: printing
                  ? null
                  : () async {
                      setDialogState(() {
                        printing = true;
                        printError = null;
                      });
                      try {
                        await PrintService.imprimirEtiqueta(registro);
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (error) {
                        if (!dialogContext.mounted) return;
                        setDialogState(() {
                          printing = false;
                          printError = error
                              .toString()
                              .replaceFirst('Exception: ', '')
                              .trim();
                        });
                      }
                    },
              icon: printing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.print_outlined),
              label: Text(printing ? 'Imprimiendo…' : 'Imprimir'),
            ),
          ],
        ),
      ),
    );
    if (result == true && mounted) Navigator.pop(context, true);
  }

  Future<void> _imprimirActual() async {
    if (_guardando || widget.registroEdicion == null) return;
    setState(() => _guardando = true);
    try {
      await PrintService.imprimirEtiqueta(widget.registroEdicion!);
      if (mounted) showAppMessage(context, 'Etiqueta enviada a la impresora.');
    } catch (error) {
      if (mounted) {
        showAppMessage(
          context,
          error.toString().replaceFirst('Exception: ', '').trim(),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _handleApiError(ApiException error) async {
    if (error.isUnauthorized) {
      await ApiService.clearSession();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      return;
    }
    showAppMessage(context, error.message, error: true);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.registroEdicion != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Editar artículo' : 'Nuevo artículo'),
        actions: [
          if (editing)
            IconButton(
              tooltip: 'Imprimir etiqueta actual',
              onPressed: _guardando ? null : _imprimirActual,
              icon: const Icon(Icons.print_outlined),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            Form(
              key: _formKey,
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    constraints.maxWidth >= 700 ? 28 : 16,
                    12,
                    constraints.maxWidth >= 700 ? 28 : 16,
                    24 + MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppSectionTitle(
                            'Fotografías',
                            trailing: '${_fotos.length}/$_maxPhotos',
                          ),
                          const SizedBox(height: 12),
                          _PhotoStrip(
                            photos: _fotos,
                            canAdd: _fotos.length < _maxPhotos,
                            onAdd: _elegirOrigenFoto,
                            onRemove: (index) =>
                                setState(() => _fotos.removeAt(index)),
                          ),
                          const SizedBox(height: 26),
                          const AppSectionTitle('Información del artículo'),
                          const SizedBox(height: 12),
                          LayoutBuilder(
                            builder: (context, fieldConstraints) {
                              final twoColumns =
                                  fieldConstraints.maxWidth >= 680;
                              final width = twoColumns
                                  ? (fieldConstraints.maxWidth - 14) / 2
                                  : fieldConstraints.maxWidth;
                              return Wrap(
                                spacing: 14,
                                runSpacing: 14,
                                children: [
                                  SizedBox(
                                    width: width,
                                    child: TextFormField(
                                      controller: _nombreController,
                                      enabled: !_guardando,
                                      textCapitalization:
                                          TextCapitalization.sentences,
                                      maxLength: 200,
                                      decoration: const InputDecoration(
                                        labelText: 'Nombre del artículo',
                                        prefixIcon:
                                            Icon(Icons.inventory_2_outlined),
                                        counterText: '',
                                      ),
                                      validator: (value) {
                                        final clean = value?.trim() ?? '';
                                        if (clean.isEmpty) {
                                          return 'Ingrese el nombre del artículo.';
                                        }
                                        if (clean.length < 2) {
                                          return 'Use al menos 2 caracteres.';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  SizedBox(
                                    width: width,
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _categorias.contains(
                                        _categoriaSeleccionada,
                                      )
                                          ? _categoriaSeleccionada
                                          : 'General',
                                      isExpanded: true,
                                      items: _categorias
                                          .map(
                                            (category) => DropdownMenuItem(
                                              value: category,
                                              child: Text(
                                                category,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          )
                                          .toList(growable: false),
                                      onChanged: _guardando
                                          ? null
                                          : (value) => setState(
                                                () => _categoriaSeleccionada =
                                                    value ?? 'General',
                                              ),
                                      decoration: InputDecoration(
                                        labelText: _cargandoCategorias
                                            ? 'Cargando categorías…'
                                            : 'Categoría',
                                        prefixIcon:
                                            const Icon(Icons.sell_outlined),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          if (_categoriaSeleccionada == 'Otros') ...[
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _nuevaCategoriaController,
                              enabled: !_guardando,
                              maxLength: 100,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(
                                labelText: 'Nueva categoría',
                                prefixIcon: Icon(Icons.add_box_outlined),
                                counterText: '',
                              ),
                              validator: (value) {
                                if (_categoriaSeleccionada != 'Otros') {
                                  return null;
                                }
                                final clean = value?.trim() ?? '';
                                return clean.length < 2
                                    ? 'Ingrese una categoría válida.'
                                    : null;
                              },
                            ),
                          ],
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _obsController,
                            enabled: !_guardando,
                            minLines: 4,
                            maxLines: 8,
                            maxLength: 4000,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              labelText: 'Observaciones técnicas',
                              alignLabelWithHint: true,
                              prefixIcon: Icon(Icons.notes_rounded),
                            ),
                          ),
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: _guardando ? null : _guardarArticulo,
                            icon: const Icon(Icons.save_outlined),
                            label: Text(
                              editing ? 'Guardar cambios' : 'Guardar artículo',
                            ),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(56),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_guardando)
              const Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: Color(0x55000000),
                    child: Center(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 18,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              ),
                              SizedBox(width: 14),
                              Text('Procesando…'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PhotoStrip extends StatelessWidget {
  final List<String> photos;
  final bool canAdd;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  const _PhotoStrip({
    required this.photos,
    required this.canAdd,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return Semantics(
        button: true,
        label: 'Agregar fotografía obligatoria',
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onAdd,
          child: Container(
            height: 142,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 38,
                  color: AppColors.primary,
                ),
                SizedBox(height: 10),
                Text(
                  'Agregar fotografía',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 4),
                Text(
                  'Cámara o galería',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 142,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length + (canAdd ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          if (index == photos.length) {
            return OutlinedButton(
              onPressed: onAdd,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(112, 142),
                padding: const EdgeInsets.all(12),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined, size: 30),
                  SizedBox(height: 8),
                  Text('Agregar'),
                ],
              ),
            );
          }

          final path = photos[index];
          final image = path.startsWith('http')
              ? Image.network(
                  path,
                  fit: BoxFit.cover,
                  cacheWidth: 320,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : const Center(child: CircularProgressIndicator()),
                  errorBuilder: (_, __, ___) => const _BrokenPhoto(),
                )
              : Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  cacheWidth: 320,
                  errorBuilder: (_, __, ___) => const _BrokenPhoto(),
                );
          return SizedBox(
            width: 128,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: ColoredBox(
                      color: AppColors.surfaceRaised,
                      child: image,
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: IconButton.filled(
                    tooltip: 'Quitar fotografía ${index + 1}',
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xCC111318),
                      minimumSize: const Size(42, 42),
                    ),
                    onPressed: () => onRemove(index),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BrokenPhoto extends StatelessWidget {
  const _BrokenPhoto();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.broken_image_outlined,
        color: AppColors.textMuted,
        size: 32,
      ),
    );
  }
}

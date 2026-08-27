import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/registro_model.dart';
import '../ui/app_theme.dart';
import '../widgets/app_components.dart';

class DetalleScreen extends StatefulWidget {
  final Registro registro;

  const DetalleScreen({super.key, required this.registro});

  @override
  State<DetalleScreen> createState() => _DetalleScreenState();
}

class _DetalleScreenState extends State<DetalleScreen> {
  final _pageController = PageController();
  int _currentPhoto = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final registro = widget.registro;
    final photos = registro.listaFotos;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          registro.nombre,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final height =
                          (constraints.maxWidth * 0.62).clamp(250.0, 500.0);
                      return _PhotoGallery(
                        photos: photos,
                        height: height,
                        controller: _pageController,
                        current: _currentPhoto,
                        onChanged: (index) =>
                            setState(() => _currentPhoto = index),
                        onOpen: (path) => _openPhoto(path),
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.primary.withValues(alpha: 0.13),
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.55),
                                ),
                              ),
                              child: Text(
                                registro.categoria,
                                style: const TextStyle(
                                  color: Color(0xFFFFA5A5),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.schedule_rounded,
                                    size: 16,
                                    color: AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      registro.fecha,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 26),
                        const AppSectionTitle('Información general'),
                        const SizedBox(height: 10),
                        Text(
                          registro.nombre,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontSize: 28),
                        ),
                        const SizedBox(height: 26),
                        const AppSectionTitle('Observaciones'),
                        const SizedBox(height: 10),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Text(
                              registro.observaciones.trim().isEmpty
                                  ? 'Sin observaciones adicionales.'
                                  : registro.observaciones,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    color: registro.observaciones.trim().isEmpty
                                        ? AppColors.textMuted
                                        : Colors.white,
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 26),
                        const AppSectionTitle('Identificador'),
                        const SizedBox(height: 10),
                        Material(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: _copyUuid,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: SelectableText(
                                      registro.uuid,
                                      style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Icon(
                                    Icons.copy_rounded,
                                    size: 20,
                                    color: AppColors.textMuted,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _copyUuid() async {
    await Clipboard.setData(ClipboardData(text: widget.registro.uuid));
    if (mounted) showAppMessage(context, 'UUID copiado.');
  }

  Future<void> _openPhoto(String path) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (dialogContext) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Center(child: _RecordImage(path: path)),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton.filled(
                  tooltip: 'Cerrar imagen',
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoGallery extends StatelessWidget {
  final List<String> photos;
  final double height;
  final PageController controller;
  final int current;
  final ValueChanged<int> onChanged;
  final ValueChanged<String> onOpen;

  const _PhotoGallery({
    required this.photos,
    required this.height,
    required this.controller,
    required this.current,
    required this.onChanged,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return Container(
        height: 250,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported_outlined,
              size: 44,
              color: AppColors.textMuted,
            ),
            SizedBox(height: 10),
            Text(
              'Sin fotografías',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 5),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Este artículo todavía no tiene imágenes asociadas.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: height,
          child: PageView.builder(
            controller: controller,
            itemCount: photos.length,
            onPageChanged: onChanged,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Semantics(
                button: true,
                label: 'Fotografía ${index + 1} de ${photos.length}. Abrir.',
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => onOpen(photos[index]),
                  child: Hero(
                    tag: 'record-photo-${photos[index]}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: ColoredBox(
                        color: AppColors.surface,
                        child: _RecordImage(path: photos[index]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (photos.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              photos.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: index == current ? 20 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color:
                      index == current ? AppColors.primary : AppColors.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _RecordImage extends StatelessWidget {
  final String path;

  const _RecordImage({required this.path});

  @override
  Widget build(BuildContext context) {
    if (path.startsWith('http')) {
      return Image.network(
        path,
        fit: BoxFit.contain,
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : const Center(child: CircularProgressIndicator()),
        errorBuilder: (_, __, ___) => const _ImageError(),
      );
    }
    return Image.file(
      File(path),
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const _ImageError(),
    );
  }
}

class _ImageError extends StatelessWidget {
  const _ImageError();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 42,
            color: AppColors.textMuted,
          ),
          SizedBox(height: 8),
          Text(
            'No fue posible cargar la imagen',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

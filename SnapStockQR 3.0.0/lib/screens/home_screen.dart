import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/db_helper.dart';
import '../models/registro_model.dart';
import '../services/api_service.dart';
import '../services/excel_service.dart';
import '../services/printer_picker.dart';
import '../ui/app_theme.dart';
import '../widgets/app_components.dart';
import 'detalle_screen.dart';
import 'diseno_etiqueta_screen.dart';
import 'formulario_screen.dart';
import 'scanner_screen.dart';
import 'usuarios_screen.dart';

class HomeScreen extends StatefulWidget {
  final bool esAdmin;
  final String? initialRegistroUuid;

  const HomeScreen({
    super.key,
    required this.esAdmin,
    this.initialRegistroUuid,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  List<Registro> _registros = const [];
  List<Registro> _filtrados = const [];
  final Set<String> _seleccionados = {};
  final Set<String> _eliminando = {};
  bool _cargando = true;
  bool _sinConexion = false;
  bool _buscandoRegistro = false;
  String? _errorCarga;
  String _userName = 'Usuario';

  bool get _modoSeleccion => _seleccionados.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_aplicarFiltro);
    if (widget.esAdmin) {
      _cargarDatos();
    } else {
      _cargando = false;
    }
    _obtenerInfoUsuario();
    final pendingUuid = widget.initialRegistroUuid;
    if (pendingUuid != null && pendingUuid.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _abrirRegistroPorUuid(pendingUuid),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _obtenerInfoUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _userName = prefs.getString('userName') ?? 'Usuario');
    }
  }

  Future<void> _cargarDatos() async {
    if (!widget.esAdmin) return;
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });
    try {
      final lista = await ApiService.obtenerTodos();
      await DbHelper.reemplazarTodos(lista);
      if (!mounted) return;
      setState(() {
        _registros = lista;
        _filtrados = _filtrar(lista);
        _sinConexion = false;
        _cargando = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.isUnauthorized) {
        setState(() => _cargando = false);
        await _handleApiError(error);
        return;
      }

      final cache = await DbHelper.obtenerTodos();
      if (!mounted) return;
      setState(() {
        _registros = cache;
        _filtrados = _filtrar(cache);
        _sinConexion = true;
        _errorCarga = error.message;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _errorCarga = 'No fue posible leer el inventario guardado.';
      });
    }
  }

  void _aplicarFiltro() {
    if (!mounted) return;
    setState(() {
      _filtrados = _filtrar(_registros);
      _seleccionados.removeWhere(
        (uuid) => !_filtrados.any((item) => item.uuid == uuid),
      );
    });
  }

  List<Registro> _filtrar(List<Registro> source) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return List<Registro>.of(source);
    return source.where((record) {
      return record.nombre.toLowerCase().contains(query) ||
          record.categoria.toLowerCase().contains(query) ||
          record.observaciones.toLowerCase().contains(query) ||
          record.uuid.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  void _toggleSeleccion(String uuid) {
    if (!widget.esAdmin) return;
    setState(() {
      if (!_seleccionados.add(uuid)) _seleccionados.remove(uuid);
    });
  }

  void _seleccionarTodos() {
    setState(() {
      if (_filtrados.isNotEmpty && _seleccionados.length == _filtrados.length) {
        _seleccionados.clear();
      } else {
        _seleccionados
          ..clear()
          ..addAll(_filtrados.map((record) => record.uuid));
      }
    });
  }

  Future<void> _exportar(List<Registro> registros) async {
    if (registros.isEmpty) {
      showAppMessage(context, 'No hay registros para exportar.', error: true);
      return;
    }
    try {
      await ExcelService.exportarRegistros(registros);
    } catch (_) {
      if (mounted) {
        showAppMessage(
          context,
          'No fue posible crear o compartir el archivo Excel.',
          error: true,
        );
      }
    }
  }

  Future<void> _abrirEscaner() async {
    final resultado = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
    if (resultado == null || !mounted) return;
    final uri = Uri.tryParse(resultado.trim());
    final uuid = uri != null &&
            uri.scheme == 'fotocatalogo' &&
            uri.host == 'registro' &&
            uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last
        : null;
    if (uuid == null || uuid.isEmpty) {
      showAppMessage(
        context,
        'El código QR no pertenece a SnapStock.',
        error: true,
      );
      return;
    }
    await _abrirRegistroPorUuid(uuid);
  }

  Future<void> _abrirRegistroPorUuid(String uuid) async {
    if (_buscandoRegistro) return;
    setState(() => _buscandoRegistro = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final registro = await ApiService.buscarPorUuid(uuid);
      await prefs.remove('pendingRegistroUuid');
      if (!mounted) return;
      if (registro == null) {
        showAppMessage(
          context,
          'No se encontró el registro en el servidor.',
          error: true,
        );
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetalleScreen(registro: registro)),
      );
    } on ApiException catch (error) {
      if (mounted) await _handleApiError(error);
    } finally {
      if (mounted) setState(() => _buscandoRegistro = false);
    }
  }

  Future<void> _handleApiError(ApiException error) async {
    if (error.isUnauthorized) {
      await ApiService.clearSession();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      return;
    }
    if (mounted) showAppMessage(context, error.message, error: true);
  }

  Future<void> _abrirFormulario([Registro? registro]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FormularioScreen(registroEdicion: registro),
      ),
    );
    if (changed == true) await _cargarDatos();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 700;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmarSalida();
      },
      child: Scaffold(
        appBar: AppBar(
          title: _modoSeleccion
              ? Text('${_seleccionados.length} seleccionados')
              : const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('SnapStock QR'),
                    Text(
                      'Inventario corporativo',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
          actions: [
            if (_modoSeleccion) ...[
              IconButton(
                tooltip: _seleccionados.length == _filtrados.length
                    ? 'Quitar selección'
                    : 'Seleccionar todo',
                onPressed: _seleccionarTodos,
                icon: Icon(
                  _seleccionados.length == _filtrados.length
                      ? Icons.deselect_rounded
                      : Icons.select_all_rounded,
                ),
              ),
              IconButton(
                tooltip: 'Exportar selección',
                onPressed: () => _exportar(
                  _registros
                      .where((item) => _seleccionados.contains(item.uuid))
                      .toList(growable: false),
                ),
                icon: const Icon(Icons.ios_share_rounded),
              ),
              IconButton(
                tooltip: 'Cancelar selección',
                onPressed: () => setState(_seleccionados.clear),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ],
        ),
        drawer: _buildDrawer(),
        body: SafeArea(
          top: false,
          child: Stack(
            children: [
              Column(
                children: [
                  if (_sinConexion)
                    AppStatusBanner(
                      icon: Icons.cloud_off_outlined,
                      color: AppColors.warning,
                      message:
                          'Sin conexión: mostrando la última copia guardada.',
                      onTap: _cargarDatos,
                    ),
                  ContentConstraint(
                    padding: EdgeInsets.fromLTRB(
                      wide ? 24 : 16,
                      14,
                      wide ? 24 : 16,
                      12,
                    ),
                    child: Column(
                      children: [
                        FilledButton.icon(
                          onPressed: _buscandoRegistro ? null : _abrirEscaner,
                          icon: const Icon(Icons.qr_code_scanner_rounded),
                          label: const Text('Escanear código QR'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                          ),
                        ),
                        if (widget.esAdmin) ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: _searchController,
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: 'Buscar nombre, categoría o UUID',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: _searchController.text.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Limpiar búsqueda',
                                      onPressed: _searchController.clear,
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: widget.esAdmin
                        ? _buildAdminBody()
                        : _buildOperatorBody(),
                  ),
                ],
              ),
              if (_buscandoRegistro)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x66000000),
                    child: Center(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
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
                              Text('Buscando artículo…'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        floatingActionButton: widget.esAdmin
            ? wide
                ? FloatingActionButton.extended(
                    onPressed: _abrirFormulario,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Nuevo artículo'),
                  )
                : FloatingActionButton(
                    tooltip: 'Nuevo artículo',
                    onPressed: _abrirFormulario,
                    child: const Icon(Icons.add_rounded),
                  )
            : null,
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.16),
                    child: Text(
                      _userName.isEmpty ? 'U' : _userName[0].toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.esAdmin ? 'Administrador' : 'Consulta',
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            if (widget.esAdmin) ...[
              _drawerItem(
                Icons.group_outlined,
                'Gestión de usuarios',
                () => _openDrawerPage(const UsuariosScreen()),
              ),
              _drawerItem(
                Icons.print_outlined,
                'Configurar impresora',
                () async {
                  Navigator.pop(context);
                  await PrinterPicker.mostrar(context);
                },
              ),
              _drawerItem(
                Icons.design_services_outlined,
                'Diseño de etiqueta',
                () => _openDrawerPage(const DisenoEtiquetaScreen()),
              ),
              _drawerItem(
                Icons.ios_share_outlined,
                'Exportar inventario',
                () {
                  Navigator.pop(context);
                  _exportar(_filtrados);
                },
              ),
            ],
            const Spacer(),
            const Divider(),
            _drawerItem(
              Icons.logout_rounded,
              'Cerrar sesión',
              () {
                Navigator.pop(context);
                _confirmarSalida();
              },
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color? color,
  }) {
    return ListTile(
      minTileHeight: 54,
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: onTap,
    );
  }

  void _openDrawerPage(Widget page) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Widget _buildAdminBody() {
    if (_cargando) {
      return Center(
        child: Semantics(
          label: 'Cargando inventario',
          child: const CircularProgressIndicator(),
        ),
      );
    }
    if (_filtrados.isEmpty) {
      return RefreshIndicator(
        onRefresh: _cargarDatos,
        child: AppEmptyState(
          icon: _searchController.text.isEmpty
              ? Icons.inventory_2_outlined
              : Icons.search_off_rounded,
          title: _searchController.text.isEmpty
              ? 'Inventario vacío'
              : 'Sin coincidencias',
          message: _errorCarga ??
              (_searchController.text.isEmpty
                  ? 'Agregue el primer artículo con el botón inferior.'
                  : 'Pruebe con otro nombre, categoría o UUID.'),
          actionLabel: _errorCarga == null ? null : 'Reintentar',
          onAction: _errorCarga == null ? null : _cargarDatos,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final grid = constraints.maxWidth >= 720;
        final padding =
            EdgeInsets.fromLTRB(grid ? 24 : 12, 4, grid ? 24 : 12, 96);
        return RefreshIndicator(
          onRefresh: _cargarDatos,
          child: grid
              ? GridView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: padding,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 118,
                  ),
                  itemCount: _filtrados.length,
                  itemBuilder: (_, index) => _InventoryTile(
                    registro: _filtrados[index],
                    selected: _seleccionados.contains(_filtrados[index].uuid),
                    deleting: _eliminando.contains(_filtrados[index].uuid),
                    selectionMode: _modoSeleccion,
                    onTap: () => _onItemTap(_filtrados[index]),
                    onLongPress: () => _toggleSeleccion(_filtrados[index].uuid),
                    onAction: (action) =>
                        _onItemAction(action, _filtrados[index]),
                  ),
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: padding,
                  itemCount: _filtrados.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, index) => _InventoryTile(
                    registro: _filtrados[index],
                    selected: _seleccionados.contains(_filtrados[index].uuid),
                    deleting: _eliminando.contains(_filtrados[index].uuid),
                    selectionMode: _modoSeleccion,
                    onTap: () => _onItemTap(_filtrados[index]),
                    onLongPress: () => _toggleSeleccion(_filtrados[index].uuid),
                    onAction: (action) =>
                        _onItemAction(action, _filtrados[index]),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildOperatorBody() {
    return const AppEmptyState(
      icon: Icons.qr_code_scanner_rounded,
      title: 'Listo para consultar',
      message:
          'Escanee la etiqueta QR de un artículo para abrir su información.',
    );
  }

  void _onItemTap(Registro registro) {
    if (_modoSeleccion) {
      _toggleSeleccion(registro.uuid);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetalleScreen(registro: registro)),
      );
    }
  }

  Future<void> _onItemAction(String action, Registro registro) async {
    switch (action) {
      case 'view':
        _onItemTap(registro);
        return;
      case 'edit':
        await _abrirFormulario(registro);
        return;
      case 'delete':
        await _confirmarEliminacion(registro);
        return;
    }
  }

  Future<void> _confirmarEliminacion(Registro registro) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Eliminar artículo',
      message:
          '¿Desea eliminar “${registro.nombre}”? También se eliminarán sus fotografías del servidor.',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (!confirmed || !mounted || _eliminando.contains(registro.uuid)) return;

    setState(() => _eliminando.add(registro.uuid));
    try {
      await ApiService.eliminar(registro.uuid);
      await DbHelper.eliminarPorUuid(registro.uuid);
      if (!mounted) return;
      setState(() {
        _registros = _registros
            .where((item) => item.uuid != registro.uuid)
            .toList(growable: false);
        _filtrados = _filtrar(_registros);
        _seleccionados.remove(registro.uuid);
      });
      showAppMessage(context, 'Artículo eliminado correctamente.');
    } on ApiException catch (error) {
      if (mounted) await _handleApiError(error);
    } finally {
      if (mounted) setState(() => _eliminando.remove(registro.uuid));
    }
  }

  Future<void> _confirmarSalida() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Cerrar sesión',
      message: '¿Desea cerrar la sesión de $_userName?',
      confirmLabel: 'Cerrar sesión',
      destructive: true,
    );
    if (!confirmed) return;
    await ApiService.clearSession();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }
}

class _InventoryTile extends StatelessWidget {
  final Registro registro;
  final bool selected;
  final bool deleting;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ValueChanged<String> onAction;

  const _InventoryTile({
    required this.registro,
    required this.selected,
    required this.deleting,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final photos = registro.listaFotos;
    final photo = photos.isEmpty ? null : photos.first;
    return Semantics(
      selected: selected,
      button: true,
      label: '${registro.nombre}, categoría ${registro.categoria}',
      child: Card(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.13)
            : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: deleting ? null : onTap,
          onLongPress: deleting ? null : onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                _Thumbnail(path: photo, selected: selected),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        registro.nombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.sell_outlined,
                            size: 15,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              registro.categoria,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (deleting)
                  const Padding(
                    padding: EdgeInsets.all(13),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  )
                else if (!selectionMode)
                  PopupMenuButton<String>(
                    tooltip: 'Opciones de ${registro.nombre}',
                    onSelected: onAction,
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'view',
                        child: _MenuEntry(Icons.visibility_outlined, 'Ver'),
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        child: _MenuEntry(Icons.edit_outlined, 'Editar'),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: _MenuEntry(
                          Icons.delete_outline,
                          'Eliminar',
                          destructive: true,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final String? path;
  final bool selected;

  const _Thumbnail({required this.path, required this.selected});

  @override
  Widget build(BuildContext context) {
    Widget image;
    if (path == null) {
      image =
          const Icon(Icons.inventory_2_outlined, color: AppColors.textMuted);
    } else if (path!.startsWith('http')) {
      image = Image.network(
        path!,
        fit: BoxFit.cover,
        cacheWidth: 180,
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
        errorBuilder: (_, __, ___) => const Icon(
          Icons.broken_image_outlined,
          color: AppColors.textMuted,
        ),
      );
    } else {
      image = Image.file(
        File(path!),
        fit: BoxFit.cover,
        cacheWidth: 180,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.broken_image_outlined,
          color: AppColors.textMuted,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: SizedBox(
        width: 76,
        height: 76,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: AppColors.surfaceRaised, child: image),
            if (selected)
              ColoredBox(
                color: AppColors.primary.withValues(alpha: 0.68),
                child: const Icon(Icons.check_rounded, color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }
}

class _MenuEntry extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool destructive;

  const _MenuEntry(this.icon, this.label, {this.destructive = false});

  @override
  Widget build(BuildContext context) {
    final color = destructive ? Theme.of(context).colorScheme.error : null;
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}

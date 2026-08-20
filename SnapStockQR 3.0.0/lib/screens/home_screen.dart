import 'package:flutter/material.dart';
import '../models/registro_model.dart';
import '../services/api_service.dart';
import '../services/excel_service.dart';
import '../services/printer_picker.dart';
import 'formulario_screen.dart';
import 'detalle_screen.dart';
import 'scanner_screen.dart';
import 'usuarios_screen.dart';
import 'diseno_etiqueta_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  List<Registro> registros = [];
  List<Registro> registrosFiltrados = [];
  String filtroBusqueda = "";
  bool modoSeleccion = false;
  Set<int> idsSeleccionados = {};
  bool _cargando = true;
  String _userName = "Usuario";

  @override
  void initState() {
    super.initState();
    if (widget.esAdmin) {
      _cargarDatos();
    } else {
      _cargando = false;
    }
    _obtenerInfoUsuario();
    if (widget.initialRegistroUuid != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _abrirRegistroPorUuid(widget.initialRegistroUuid!);
      });
    }
  }

  Future<void> _obtenerInfoUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _userName = prefs.getString('userName') ?? "Usuario";
    });
  }

  Future<void> _cargarDatos() async {
    if (!widget.esAdmin) return;
    setState(() => _cargando = true);
    try {
      final lista = await ApiService.obtenerTodos();
      if (!mounted) return;
      setState(() {
        registros = lista;
        registrosFiltrados = _filtrar(lista);
        _cargando = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _cargando = false);
      await _handleApiError(error);
    }
  }

  void _aplicarFiltro() {
    setState(() {
      registrosFiltrados = _filtrar(registros);
    });
  }

  List<Registro> _filtrar(List<Registro> source) {
    final query = filtroBusqueda.toLowerCase();
    return source.where((record) {
      return record.nombre.toLowerCase().contains(query) ||
          record.categoria.toLowerCase().contains(query) ||
          record.observaciones.toLowerCase().contains(query);
    }).toList();
  }

  void _toggleSeleccion(int id) {
    if (!widget.esAdmin) return;
    setState(() {
      if (idsSeleccionados.contains(id)) {
        idsSeleccionados.remove(id);
        if (idsSeleccionados.isEmpty) modoSeleccion = false;
      } else {
        idsSeleccionados.add(id);
        modoSeleccion = true;
      }
    });
  }

  void _seleccionarTodos() {
    setState(() {
      if (idsSeleccionados.length == registrosFiltrados.length) {
        idsSeleccionados.clear();
        modoSeleccion = false;
      } else {
        idsSeleccionados = registrosFiltrados
            .where((record) => record.id != null)
            .map((record) => record.id!)
            .toSet();
        modoSeleccion = true;
      }
    });
  }

  Future<void> _abrirEscaner() async {
    final String? resultado = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
    if (resultado == null || !mounted) return;
    final uri = Uri.tryParse(resultado);
    final uuid = uri != null &&
            uri.scheme == 'fotocatalogo' &&
            uri.host == 'registro' &&
            uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last
        : null;
    if (uuid == null) {
      _showMessage('El código QR no pertenece a SnapStock.');
      return;
    }
    await _abrirRegistroPorUuid(uuid);
  }

  Future<void> _abrirRegistroPorUuid(String uuid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pendingRegistroUuid');
      final registro = await ApiService.buscarPorUuid(uuid);
      if (!mounted) return;
      if (registro == null) {
        _showMessage('No se encontró el registro en el servidor.');
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetalleScreen(registro: registro)),
      );
    } on ApiException catch (error) {
      if (mounted) await _handleApiError(error);
    }
  }

  Future<void> _handleApiError(ApiException error) async {
    if (error.isUnauthorized) {
      await ApiService.clearSession();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      return;
    }
    _showMessage(error.message);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        _confirmarSalida();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'SnapStock QR',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              Text(
                'v3.0.0',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.red.shade900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          actions: [
            if (modoSeleccion) ...[
              IconButton(
                icon: Icon(
                  idsSeleccionados.length == registrosFiltrados.length
                      ? Icons.deselect
                      : Icons.select_all,
                ),
                tooltip: "Seleccionar todos",
                onPressed: _seleccionarTodos,
              ),
              IconButton(
                icon: const Icon(
                  Icons.file_download,
                  color: Colors.greenAccent,
                ),
                tooltip: "Exportar marcados",
                onPressed: () {
                  final aExportar = registros
                      .where((r) => idsSeleccionados.contains(r.id))
                      .toList();
                  ExcelService.exportarRegistros(aExportar);
                },
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  modoSeleccion = false;
                  idsSeleccionados.clear();
                }),
              ),
            ],
          ],
          bottom: widget.esAdmin
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(60),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      style: const TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                        hintText: 'Buscar en servidor...',
                        hintStyle: const TextStyle(color: Colors.grey),
                        fillColor: Colors.white,
                        filled: true,
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.grey,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (v) {
                        filtroBusqueda = v;
                        _aplicarFiltro();
                      },
                    ),
                  ),
                )
              : null,
        ),
        drawer: Drawer(
          backgroundColor: const Color(0xFF121212),
          child: Column(
            children: [
              UserAccountsDrawerHeader(
                decoration: BoxDecoration(color: Colors.red.shade900),
                currentAccountPicture: const CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 40, color: Colors.black),
                ),
                accountName: Text(
                  _userName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                accountEmail: Text(
                  widget.esAdmin
                      ? "Administrador de Inventario"
                      : "Operador de Consulta",
                ),
              ),
              if (widget.esAdmin) ...[
                ListTile(
                  leading: const Icon(Icons.group, color: Colors.white),
                  title: const Text(
                    "Gestión de Usuarios",
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const UsuariosScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.print, color: Colors.white),
                  title: const Text(
                    "Configurar Impresora",
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    PrinterPicker.mostrar(context);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.settings_overscan,
                    color: Colors.white,
                  ),
                  title: const Text(
                    "Diseño de Etiqueta",
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DisenoEtiquetaScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.file_download, color: Colors.white),
                  title: const Text(
                    "Exportar todo el inventario",
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    ExcelService.exportarRegistros(registrosFiltrados);
                  },
                ),
                const Divider(color: Colors.grey),
              ],
              const Spacer(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text(
                  "Cerrar Sesión",
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmarSalida();
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(15.0),
              child: ElevatedButton.icon(
                onPressed: _abrirEscaner,
                icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                label: const Text(
                  "ESCANEAR CÓDIGO QR",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(60),
                  backgroundColor: Colors.red.shade900,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const Divider(),
            Expanded(child: widget.esAdmin ? _cuerpoAdmin() : _cuerpoUsuario()),
          ],
        ),
        floatingActionButton: widget.esAdmin
            ? FloatingActionButton(
                backgroundColor: Colors.red.shade900,
                foregroundColor: Colors.white,
                onPressed: () async {
                  final res = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FormularioScreen()),
                  );
                  if (res == true) _cargarDatos();
                },
                child: const Icon(Icons.add_a_photo),
              )
            : null,
      ),
    );
  }

  Widget _cuerpoAdmin() {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _cargarDatos,
      child: ListView.builder(
        itemCount: registrosFiltrados.length,
        itemBuilder: (context, index) {
          final item = registrosFiltrados[index];
          final sel = idsSeleccionados.contains(item.id);
          final firstPhoto =
              item.listaFotos.isEmpty ? null : item.listaFotos.first;
          return Card(
            elevation: sel ? 4 : 1,
            color: sel ? Colors.red.shade900.withAlpha(30) : null,
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: ListTile(
              leading: GestureDetector(
                onTap:
                    item.id == null ? null : () => _toggleSeleccion(item.id!),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: firstPhoto == null
                          ? const SizedBox(
                              width: 50,
                              height: 50,
                              child: Icon(Icons.image_not_supported_outlined),
                            )
                          : Image.network(
                              firstPhoto,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.broken_image),
                            ),
                    ),
                    if (sel)
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.red.withAlpha(100),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Icon(Icons.check, color: Colors.white),
                      ),
                  ],
                ),
              ),
              title: Text(
                item.nombre,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(item.categoria),
              trailing: PopupMenuButton(
                onSelected: (val) async {
                  if (val == 'ver') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DetalleScreen(registro: item),
                      ),
                    );
                  } else if (val == 'editar') {
                    final res = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FormularioScreen(registroEdicion: item),
                      ),
                    );
                    if (res == true) _cargarDatos();
                  } else if (val == 'borrar') {
                    _confirmarEliminacion(item);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'ver',
                    child: ListTile(
                      leading: Icon(Icons.visibility),
                      title: Text('Ver'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'editar',
                    child: ListTile(
                      leading: Icon(Icons.edit),
                      title: Text('Editar'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'borrar',
                    child: ListTile(
                      leading: Icon(Icons.delete, color: Colors.red),
                      title: Text('Eliminar'),
                    ),
                  ),
                ],
              ),
              onTap: () {
                if (modoSeleccion) {
                  if (item.id != null) _toggleSeleccion(item.id!);
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DetalleScreen(registro: item),
                    ),
                  );
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _cuerpoUsuario() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40.0),
        child: Text(
          "Panel Corporativo v3.0\nEscanee un código QR para ver detalles",
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  void _confirmarEliminacion(Registro registro) async {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Eliminar Registro"),
        content: Text("¿Desea eliminar '${registro.nombre}' del servidor?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("CANCELAR"),
          ),
          TextButton(
            onPressed: () async {
              final dialogNavigator = Navigator.of(dialogContext);
              try {
                await ApiService.eliminar(registro.uuid);
                if (!mounted) return;
                dialogNavigator.pop();
                await _cargarDatos();
              } on ApiException catch (error) {
                if (!mounted) return;
                dialogNavigator.pop();
                await _handleApiError(error);
              }
            },
            child: const Text("ELIMINAR", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmarSalida() async {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Gestión de Sesión"),
        content: const Text("¿Desea cerrar la sesión actual?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("CANCELAR"),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              await ApiService.clearSession();
              if (!mounted) return;
              navigator.pushNamedAndRemoveUntil('/login', (_) => false);
            },
            child: const Text(
              "CERRAR SESIÓN",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../ui/app_theme.dart';
import '../widgets/app_components.dart';

class UsuariosScreen extends StatefulWidget {
  const UsuariosScreen({super.key});

  @override
  State<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<UsuariosScreen> {
  List<Map<String, dynamic>> _usuarios = const [];
  final Set<int> _eliminando = {};
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarUsuarios();
  }

  Future<void> _cargarUsuarios() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final data = await ApiService.obtenerUsuarios();
      if (!mounted) return;
      setState(() {
        _usuarios = data
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false);
        _cargando = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = error.message;
      });
      await _handleError(error);
    }
  }

  Future<void> _mostrarDialogoNuevoUsuario() async {
    final nombreController = TextEditingController();
    final passController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var role = 1;
    var saving = false;
    var hidePassword = true;
    String? submitError;

    try {
      final created = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Nuevo usuario'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nombreController,
                        enabled: !saving,
                        autofocus: true,
                        maxLength: 100,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Nombre de usuario',
                          prefixIcon: Icon(Icons.person_outline),
                          counterText: '',
                        ),
                        validator: (value) {
                          final clean = value?.trim() ?? '';
                          return clean.length < 2
                              ? 'Use al menos 2 caracteres.'
                              : null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: passController,
                        enabled: !saving,
                        obscureText: hidePassword,
                        maxLength: 128,
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          helperText: 'Mínimo 8 caracteres',
                          prefixIcon: const Icon(Icons.lock_outline),
                          counterText: '',
                          suffixIcon: IconButton(
                            tooltip: hidePassword
                                ? 'Mostrar contraseña'
                                : 'Ocultar contraseña',
                            onPressed: saving
                                ? null
                                : () => setDialogState(
                                      () => hidePassword = !hidePassword,
                                    ),
                            icon: Icon(
                              hidePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) => (value?.length ?? 0) < 8
                            ? 'Use al menos 8 caracteres.'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<int>(
                        initialValue: role,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                            value: 1,
                            child: Text('Consulta'),
                          ),
                          DropdownMenuItem(
                            value: 2,
                            child: Text('Administrador'),
                          ),
                        ],
                        onChanged: saving
                            ? null
                            : (value) => setDialogState(
                                  () => role = value ?? 1,
                                ),
                        decoration: const InputDecoration(
                          labelText: 'Rol',
                          prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                        ),
                      ),
                      if (submitError != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          submitError!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
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
                onPressed:
                    saving ? null : () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() {
                          saving = true;
                          submitError = null;
                        });
                        try {
                          await ApiService.crearUsuario(
                            nombreController.text.trim(),
                            passController.text,
                            role,
                          );
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext, true);
                          }
                        } on ApiException catch (error) {
                          if (!dialogContext.mounted) return;
                          if (error.isUnauthorized) {
                            Navigator.pop(dialogContext, false);
                            await _handleError(error);
                            return;
                          }
                          setDialogState(() {
                            saving = false;
                            submitError = error.message;
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
                    : const Text('Crear usuario'),
              ),
            ],
          ),
        ),
      );
      if (created == true && mounted) {
        showAppMessage(context, 'Usuario creado correctamente.');
        await _cargarUsuarios();
      }
    } finally {
      nombreController.dispose();
      passController.dispose();
    }
  }

  Future<void> _confirmarEliminar(Map<String, dynamic> user) async {
    final id = _asInt(user['id']);
    if (id == null || _eliminando.contains(id)) return;
    final name = user['nombre']?.toString() ?? 'este usuario';
    final confirmed = await showConfirmDialog(
      context,
      title: 'Eliminar usuario',
      message: '¿Desea eliminar la cuenta “$name”?',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _eliminando.add(id));
    try {
      await ApiService.eliminarUsuario(id);
      if (!mounted) return;
      showAppMessage(context, 'Usuario eliminado.');
      await _cargarUsuarios();
    } on ApiException catch (error) {
      if (mounted) await _handleError(error);
    } finally {
      if (mounted) setState(() => _eliminando.remove(id));
    }
  }

  Future<void> _handleError(ApiException error) async {
    if (error.isUnauthorized) {
      await ApiService.clearSession();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      return;
    }
    if (mounted) showAppMessage(context, error.message, error: true);
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 700;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de usuarios'),
        actions: [
          IconButton(
            tooltip: 'Actualizar usuarios',
            onPressed: _cargando ? null : _cargarUsuarios,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : _usuarios.isEmpty
                ? RefreshIndicator(
                    onRefresh: _cargarUsuarios,
                    child: AppEmptyState(
                      icon: Icons.group_off_outlined,
                      title: 'No hay usuarios para mostrar',
                      message: _error ??
                          'Cree una cuenta para comenzar a administrar accesos.',
                      actionLabel: _error == null ? null : 'Reintentar',
                      onAction: _error == null ? null : _cargarUsuarios,
                    ),
                  )
                : ContentConstraint(
                    maxWidth: 820,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                    child: RefreshIndicator(
                      onRefresh: _cargarUsuarios,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _usuarios.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, index) {
                          final user = _usuarios[index];
                          final type = _asInt(user['tipo']) ?? 1;
                          final id = _asInt(user['id']);
                          final deleting =
                              id != null && _eliminando.contains(id);
                          return Card(
                            child: ListTile(
                              minTileHeight: 76,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: type == 2
                                    ? AppColors.primary.withValues(alpha: 0.18)
                                    : AppColors.surfaceRaised,
                                foregroundColor: type == 2
                                    ? AppColors.primary
                                    : AppColors.textMuted,
                                child: Icon(
                                  type == 2
                                      ? Icons.admin_panel_settings_outlined
                                      : Icons.person_outline,
                                ),
                              ),
                              title: Text(
                                user['nombre']?.toString() ?? 'Sin nombre',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                type == 2 ? 'Administrador' : 'Consulta',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                ),
                              ),
                              trailing: deleting
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : IconButton(
                                      tooltip: 'Eliminar usuario',
                                      onPressed: id == null
                                          ? null
                                          : () => _confirmarEliminar(user),
                                      icon: Icon(
                                        Icons.delete_outline_rounded,
                                        color:
                                            Theme.of(context).colorScheme.error,
                                      ),
                                    ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
      ),
      floatingActionButton: wide
          ? FloatingActionButton.extended(
              onPressed: _mostrarDialogoNuevoUsuario,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Nuevo usuario'),
            )
          : FloatingActionButton(
              tooltip: 'Nuevo usuario',
              onPressed: _mostrarDialogoNuevoUsuario,
              child: const Icon(Icons.person_add_alt_1_rounded),
            ),
    );
  }
}

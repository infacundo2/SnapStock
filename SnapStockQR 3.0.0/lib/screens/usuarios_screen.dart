import 'package:flutter/material.dart';

import '../services/api_service.dart';

class UsuariosScreen extends StatefulWidget {
  const UsuariosScreen({super.key});

  @override
  State<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<UsuariosScreen> {
  List<dynamic> _usuarios = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarUsuarios();
  }

  Future<void> _cargarUsuarios() async {
    setState(() => _cargando = true);
    try {
      final data = await ApiService.obtenerUsuarios();
      if (!mounted) return;
      setState(() {
        _usuarios = data;
        _cargando = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _cargando = false);
      await _handleError(error);
    }
  }

  Future<void> _mostrarDialogoNuevoUsuario() async {
    final nombreController = TextEditingController();
    final passController = TextEditingController();
    var tipoSeleccionado = 1;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nuevo Usuario'),
          backgroundColor: const Color(0xFF1A1A1A),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de usuario',
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: passController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña (mínimo 8 caracteres)',
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<int>(
                  initialValue: tipoSeleccionado,
                  dropdownColor: Colors.black,
                  items: const [
                    DropdownMenuItem(
                      value: 1,
                      child: Text('Usuario (Solo Consulta)'),
                    ),
                    DropdownMenuItem(
                      value: 2,
                      child: Text('Admin (Control Total)'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => tipoSeleccionado = value);
                    }
                  },
                  decoration: const InputDecoration(labelText: 'Tipo de Rol'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade900,
              ),
              onPressed: () async {
                final name = nombreController.text.trim();
                final password = passController.text;
                if (name.isEmpty || password.length < 8) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Complete el nombre y use una contraseña de al menos 8 caracteres.',
                      ),
                    ),
                  );
                  return;
                }

                try {
                  await ApiService.crearUsuario(
                    name,
                    password,
                    tipoSeleccionado,
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  await _cargarUsuarios();
                } on ApiException catch (error) {
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  if (mounted) await _handleError(error);
                }
              },
              child: const Text('CREAR', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    nombreController.dispose();
    passController.dispose();
  }

  Future<void> _eliminarUsuario(int id) async {
    try {
      await ApiService.eliminarUsuario(id);
      await _cargarUsuarios();
    } on ApiException catch (error) {
      if (mounted) await _handleError(error);
    }
  }

  Future<void> _handleError(ApiException error) async {
    if (error.isUnauthorized) {
      await ApiService.clearSession();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestión de Usuarios')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarUsuarios,
              child: ListView.builder(
                itemCount: _usuarios.length,
                itemBuilder: (context, index) {
                  final user = _usuarios[index] as Map<String, dynamic>;
                  final type = user['tipo'] is int
                      ? user['tipo'] as int
                      : int.tryParse(user['tipo'].toString()) ?? 1;
                  final id = user['id'] is int
                      ? user['id'] as int
                      : int.parse(user['id'].toString());
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: type == 2
                          ? Colors.red.shade900
                          : Colors.grey.shade800,
                      child: Text(type == 2 ? 'A' : 'U'),
                    ),
                    title: Text(
                      user['nombre']?.toString() ?? 'Sin nombre',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      type == 2 ? 'Administrador' : 'Usuario Estándar',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _eliminarUsuario(id),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red.shade900,
        foregroundColor: Colors.white,
        onPressed: _mostrarDialogoNuevoUsuario,
        child: const Icon(Icons.person_add),
      ),
    );
  }
}

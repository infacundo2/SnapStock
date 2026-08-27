import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../ui/app_theme.dart';
import '../widgets/app_components.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _passController = TextEditingController();
  bool _cargando = false;
  bool _ocultarPassword = true;

  @override
  void dispose() {
    _nombreController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate() || _cargando) return;

    setState(() => _cargando = true);
    try {
      final response = await ApiService.login(
        _nombreController.text.trim(),
        _passController.text,
      );
      if (response == null) {
        throw const ApiException('Usuario o contraseña incorrectos.');
      }

      final typeValue = response['tipo'];
      final tipo = typeValue is int
          ? typeValue
          : int.tryParse(typeValue?.toString() ?? '') ?? 1;
      await ApiService.saveSession(response);
      final prefs = await SharedPreferences.getInstance();
      final pendingUuid = prefs.getString('pendingRegistroUuid');
      TextInput.finishAutofillContext();

      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            esAdmin: tipo == 2,
            initialRegistroUuid: pendingUuid,
          ),
        ),
      );
    } on ApiException catch (error) {
      if (mounted) showAppMessage(context, error.message, error: true);
    } catch (_) {
      if (mounted) {
        showAppMessage(
          context,
          'No fue posible iniciar sesión. Inténtelo nuevamente.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLocal = ApiService.baseUrl.contains('192.168.');
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.symmetric(
              horizontal: constraints.maxWidth < 420 ? 20 : 32,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 48,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: AutofillGroup(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Hero(
                              tag: 'snapstock-logo',
                              child: Container(
                                width: 112,
                                height: 112,
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(color: AppColors.border),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.14,
                                      ),
                                      blurRadius: 28,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(22),
                                  child: Image.asset(
                                    'assets/icon.png',
                                    semanticLabel: 'Logo de SnapStock QR',
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'SnapStock QR',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontSize: 30),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Inventario corporativo',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 14),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: (isLocal
                                        ? AppColors.warning
                                        : AppColors.success)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                isLocal ? 'Servidor local' : 'Servidor público',
                                style: TextStyle(
                                  color: isLocal
                                      ? AppColors.warning
                                      : AppColors.success,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Iniciar sesión',
                                    style:
                                        Theme.of(context).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Ingrese con sus credenciales corporativas.',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  TextFormField(
                                    controller: _nombreController,
                                    enabled: !_cargando,
                                    autofillHints: const [
                                      AutofillHints.username
                                    ],
                                    textInputAction: TextInputAction.next,
                                    textCapitalization: TextCapitalization.none,
                                    autocorrect: false,
                                    decoration: const InputDecoration(
                                      labelText: 'Usuario',
                                      prefixIcon: Icon(Icons.person_outline),
                                    ),
                                    validator: (value) =>
                                        value == null || value.trim().isEmpty
                                            ? 'Ingrese su nombre de usuario.'
                                            : null,
                                  ),
                                  const SizedBox(height: 14),
                                  TextFormField(
                                    controller: _passController,
                                    enabled: !_cargando,
                                    obscureText: _ocultarPassword,
                                    autofillHints: const [
                                      AutofillHints.password
                                    ],
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) => _iniciarSesion(),
                                    decoration: InputDecoration(
                                      labelText: 'Contraseña',
                                      prefixIcon:
                                          const Icon(Icons.lock_outline),
                                      suffixIcon: IconButton(
                                        tooltip: _ocultarPassword
                                            ? 'Mostrar contraseña'
                                            : 'Ocultar contraseña',
                                        onPressed: () => setState(
                                          () => _ocultarPassword =
                                              !_ocultarPassword,
                                        ),
                                        icon: Icon(
                                          _ocultarPassword
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                        ),
                                      ),
                                    ),
                                    validator: (value) =>
                                        value == null || value.isEmpty
                                            ? 'Ingrese su contraseña.'
                                            : null,
                                  ),
                                  const SizedBox(height: 22),
                                  FilledButton(
                                    onPressed:
                                        _cargando ? null : _iniciarSesion,
                                    child: AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 180),
                                      child: _cargando
                                          ? const SizedBox(
                                              key: ValueKey('loading'),
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text(
                                              'Ingresar',
                                              key: ValueKey('label'),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'v3.0.0',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

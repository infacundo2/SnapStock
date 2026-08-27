import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/registro_model.dart';
import 'screens/detalle_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';
import 'ui/app_theme.dart';
import 'widgets/app_components.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<Uri>? _linkSubscription;
  late final Future<Map<String, dynamic>> _sessionFuture;
  String? _handlingUuid;

  @override
  void initState() {
    super.initState();
    _sessionFuture = _loadSession();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    try {
      final appLinks = AppLinks();
      _linkSubscription = appLinks.uriLinkStream.listen(
        _handleLink,
        onError: (_) =>
            _showMessage('No fue posible abrir el enlace recibido.'),
      );
      final initialLink = await appLinks.getInitialAppLink();
      if (initialLink != null) await _handleLink(initialLink);
    } catch (_) {
      _showMessage('No fue posible procesar el enlace de SnapStock.');
    }
  }

  Future<void> _handleLink(Uri uri) async {
    if (uri.scheme != 'fotocatalogo' || uri.host != 'registro') return;
    final uuid = uri.pathSegments.isEmpty ? null : uri.pathSegments.last;
    if (uuid == null || uuid.isEmpty) return;
    if (_handlingUuid == uuid) return;
    _handlingUuid = uuid;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pendingRegistroUuid', uuid);
    if (!await ApiService.hasActiveSession()) {
      _showLogin();
      _handlingUuid = null;
      return;
    }

    try {
      final Registro? registro = await ApiService.buscarPorUuid(uuid);
      await WidgetsBinding.instance.endOfFrame;
      final navigator = _navigatorKey.currentState;
      if (registro != null && navigator != null) {
        await prefs.remove('pendingRegistroUuid');
        await navigator.push(
          MaterialPageRoute(builder: (_) => DetalleScreen(registro: registro)),
        );
      } else if (registro == null) {
        await prefs.remove('pendingRegistroUuid');
        _showMessage('No se encontró el registro solicitado.');
      }
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await prefs.setString('pendingRegistroUuid', uuid);
        await ApiService.clearSession();
        _showLogin();
      } else {
        _showMessage(error.message);
      }
    } finally {
      _handlingUuid = null;
    }
  }

  void _showLogin() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    });
  }

  void _showMessage(String message) {
    final context = _navigatorKey.currentContext;
    if (context != null) {
      showAppMessage(context, message, error: true);
    }
  }

  Future<Map<String, dynamic>> _loadSession() async {
    final active = await ApiService.hasActiveSession();
    final prefs = await SharedPreferences.getInstance();
    return {
      'active': active,
      'userType': prefs.getInt('userType') ?? 1,
      'pendingUuid': prefs.getString('pendingRegistroUuid'),
    };
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'SnapStockQR',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: FutureBuilder<Map<String, dynamic>>(
        future: _sessionFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const LoginScreen();
          }
          if (!snapshot.hasData) {
            return Scaffold(
              body: SafeArea(
                child: Center(
                  child: Semantics(
                    label: 'Cargando sesión',
                    child: const CircularProgressIndicator(),
                  ),
                ),
              ),
            );
          }

          final session = snapshot.data!;
          if (session['active'] != true) return const LoginScreen();
          return HomeScreen(
            esAdmin: session['userType'] == 2,
            initialRegistroUuid: session['pendingUuid'] as String?,
          );
        },
      ),
      routes: {'/login': (context) => const LoginScreen()},
    );
  }
}

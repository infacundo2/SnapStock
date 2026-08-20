import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/registro_model.dart';
import 'screens/detalle_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    final appLinks = AppLinks();
    _linkSubscription = appLinks.uriLinkStream.listen(_handleLink);
    final initialLink = await appLinks.getInitialAppLink();
    if (initialLink != null) await _handleLink(initialLink);
  }

  Future<void> _handleLink(Uri uri) async {
    if (uri.scheme != 'fotocatalogo' || uri.host != 'registro') return;
    final uuid = uri.pathSegments.isEmpty ? null : uri.pathSegments.last;
    if (uuid == null || uuid.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    if (!await ApiService.hasActiveSession()) {
      await prefs.setString('pendingRegistroUuid', uuid);
      _showLogin();
      return;
    }

    try {
      final Registro? registro = await ApiService.buscarPorUuid(uuid);
      final navigator = _navigatorKey.currentState;
      if (registro != null && navigator != null) {
        await prefs.remove('pendingRegistroUuid');
        navigator.push(
          MaterialPageRoute(builder: (_) => DetalleScreen(registro: registro)),
        );
      }
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await prefs.setString('pendingRegistroUuid', uuid);
        await ApiService.clearSession();
        _showLogin();
      } else {
        _showMessage(error.message);
      }
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
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
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.dark(
          primary: Colors.red.shade900,
          secondary: Colors.redAccent,
          surface: const Color(0xFF1A1A1A),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
          centerTitle: true,
        ),
        useMaterial3: true,
      ),
      home: FutureBuilder<Map<String, dynamic>>(
        future: _loadSession(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
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

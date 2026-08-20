import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nombreController = TextEditingController();
  final _passController = TextEditingController();
  bool _cargando = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    if (_nombreController.text.isEmpty || _passController.text.isEmpty) return;

    setState(() {
      _cargando = true;
    });
    try {
      // LLAMADA A TU NUEVA API CORPORATIVA
      final response = await ApiService.login(
        _nombreController.text.trim(),
        _passController.text.trim(),
      );

      if (response != null) {
        final int tipo = response['tipo'] is int
            ? response['tipo'] as int
            : int.parse(response['tipo'].toString());
        await ApiService.saveSession(response);
        final prefs = await SharedPreferences.getInstance();
        final pendingUuid = prefs.getString('pendingRegistroUuid');

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => HomeScreen(
                esAdmin: tipo == 2,
                initialRegistroUuid: pendingUuid,
              ),
            ),
          );
        }
      } else {
        throw Exception("Usuario o contraseña incorrectos");
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message), backgroundColor: Colors.red),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Acceso denegado"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _cargando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red.shade900, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withAlpha(25),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.qr_code_scanner,
                  size: 80,
                  color: Colors.red.shade900,
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                "SnapStock QR",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                "v3.0.0",
                style: TextStyle(
                  color: Colors.red.shade900,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 4,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 60),
              TextField(
                controller: _nombreController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "USUARIO",
                  labelStyle: const TextStyle(color: Colors.grey),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.red.shade900,
                      width: 2,
                    ),
                  ),
                  prefixIcon: Icon(
                    Icons.person_outline,
                    color: Colors.red.shade900,
                  ),
                ),
              ),
              const SizedBox(height: 25),
              TextField(
                controller: _passController,
                obscureText: true,
                onSubmitted: (_) => _iniciarSesion(),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "CONTRASEÑA",
                  labelStyle: const TextStyle(color: Colors.grey),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.red.shade900,
                      width: 2,
                    ),
                  ),
                  prefixIcon: Icon(
                    Icons.lock_open_outlined,
                    color: Colors.red.shade900,
                  ),
                ),
              ),
              const SizedBox(height: 50),
              _cargando
                  ? CircularProgressIndicator(color: Colors.red.shade900)
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade900,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(55),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                        elevation: 10,
                      ),
                      onPressed: _iniciarSesion,
                      child: const Text(
                        "INGRESAR AL SERVIDOR",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

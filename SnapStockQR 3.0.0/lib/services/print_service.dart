import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/registro_model.dart';

class PrintService {
  static const int lprPort = 515;

  // --- MÉTODOS DE CONFIGURACIÓN DE IMPRESORA ---
  static Future<void> guardarConfiguracion(String ip, String nombre) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('printer_ip', ip);
    await prefs.setString('printer_name', nombre);
  }

  static Future<String?> obtenerIpGuardada() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('printer_ip');
  }

  static Future<String?> obtenerNombreGuardado() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('printer_name');
  }

  /// Método de depuración para probar la conexión al puerto 515 (LPD/LPR)
  static Future<String> probarConexion(String ip) async {
    try {
      // Intentamos conectar al puerto 515 (estándar para colas de impresión compartidas)
      final socket = await Socket.connect(
        ip,
        lprPort,
        timeout: const Duration(seconds: 4),
      );
      socket.destroy();
      return "OK";
    } on SocketException catch (e) {
      // Capturamos el error específico del sistema
      return "Error de red: ${e.message} (Código: ${e.osError?.errorCode})";
    } on TimeoutException {
      return "Tiempo de espera agotado. Verifique que la IP sea correcta y que el Firewall no bloquee el puerto 515.";
    } catch (e) {
      return "Error inesperado: $e";
    }
  }

  // --- MÉTODOS PARA DISEÑO DE ETIQUETA ---
  static Future<void> guardarAjustesEtiqueta({
    required double ancho,
    required double alto,
    required int columnas,
    required double qrX,
    required double qrY,
    required int qrSize,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('label_width', ancho);
    await prefs.setDouble('label_height', alto);
    await prefs.setInt('label_cols', columnas);
    await prefs.setDouble('qr_x', qrX);
    await prefs.setDouble('qr_y', qrY);
    await prefs.setInt('qr_size', qrSize);
  }

  static Future<Map<String, dynamic>> obtenerAjustesEtiqueta() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'ancho': prefs.getDouble('label_width') ?? 100.0,
      'alto': prefs.getDouble('label_height') ?? 30.0,
      'columnas': prefs.getInt('label_cols') ?? 2,
      'qrX': prefs.getDouble('qr_x') ?? 114.0,
      'qrY': prefs.getDouble('qr_y') ?? 6.0,
      'qrSize': prefs.getInt('qr_size') ?? 5,
    };
  }

  static Future<void> imprimirEtiqueta(Registro reg) async {
    String? ip = await obtenerIpGuardada();
    String? nombre = await obtenerNombreGuardado();
    Map<String, dynamic> ajustes = await obtenerAjustesEtiqueta();

    if (ip == null || nombre == null || ip.isEmpty || nombre.isEmpty) {
      throw Exception(
        "Por favor, configure la IP y el nombre de la impresora en los ajustes.",
      );
    }

    int dotPW = (ajustes['ancho'] * 8).toInt();
    int dotLL = (ajustes['alto'] * 8).toInt();
    int qrX = ajustes['qrX'].toInt();
    int qrY = ajustes['qrY'].toInt();
    int qrS = ajustes['qrSize'];
    int cols = ajustes['columnas'];

    Socket? socket;
    try {
      socket = await Socket.connect(
        ip,
        lprPort,
        timeout: const Duration(seconds: 5),
      ).catchError((e) => throw Exception("No se pudo conectar a la IP $ip."));

      final iterator = StreamIterator(socket);
      socket.add([0x02]);
      socket.write("$nombre\n");
      await socket.flush();
      await _esperarOk(iterator, "reconocer impresora");

      String zplData = "^XA^PW$dotPW^LL$dotLL";
      zplData +=
          "^FO$qrX,$qrY^BQN,2,$qrS^FDQA,fotocatalogo://registro/${reg.uuid}^FS";

      if (cols == 2) {
        int offsetX = (dotPW / 2).toInt();
        zplData +=
            "^FO${qrX + offsetX},$qrY^BQN,2,$qrS^FDQA,fotocatalogo://registro/${reg.uuid}^FS";
      }

      zplData += "^XZ\n";
      Uint8List dataBytes = utf8.encode(zplData);

      String host = "android";
      String jobNum = "123";

      socket.add([0x03]);
      socket.write("${dataBytes.length} dfA$jobNum$host\n");
      await socket.flush();
      await _esperarOk(iterator, "preparar datos");

      socket.add(dataBytes);
      socket.add([0x00]);
      await socket.flush();
      await _esperarOk(iterator, "enviar ZPL");

      String controlContent = "H$host\nPadmin\nldfA$jobNum$host\n";
      Uint8List controlBytes = utf8.encode(controlContent);
      socket.add([0x02]);
      socket.write("${controlBytes.length} cfA$jobNum$host\n");
      await socket.flush();
      await _esperarOk(iterator, "finalizar");

      socket.add(controlBytes);
      socket.add([0x00]);
      await socket.flush();
      await _esperarOk(iterator, "completar");
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception:", ""));
    } finally {
      socket?.destroy();
    }
  }

  static Future<void> _esperarOk(
    StreamIterator<Uint8List> iterator,
    String paso,
  ) async {
    if (await iterator.moveNext().timeout(const Duration(seconds: 5))) {
      final respuesta = iterator.current;
      if (respuesta.isEmpty || respuesta[0] != 0) {
        throw Exception("Error en $paso.");
      }
    }
  }
}

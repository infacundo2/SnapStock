import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/registro_model.dart';

class PrintService {
  static const int lprPort = 515;
  static const _connectionTimeout = Duration(seconds: 5);

  static Future<void> guardarConfiguracion(String host, String queue) async {
    final cleanHost = host.trim();
    final cleanQueue = queue.trim();
    if (!_isSafeLprValue(cleanHost) || !_isSafeLprValue(cleanQueue)) {
      throw Exception('La dirección o el nombre de cola no son válidos.');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('printer_ip', cleanHost);
    await prefs.setString('printer_name', cleanQueue);
  }

  static Future<String?> obtenerIpGuardada() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('printer_ip');
  }

  static Future<String?> obtenerNombreGuardado() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('printer_name');
  }

  static Future<String> probarConexion(String host) async {
    final cleanHost = host.trim();
    if (!_isSafeLprValue(cleanHost)) return 'Dirección no válida.';
    Socket? socket;
    try {
      socket = await Socket.connect(
        cleanHost,
        lprPort,
        timeout: const Duration(seconds: 4),
      );
      return 'OK';
    } on SocketException catch (error) {
      return 'No se pudo conectar: ${error.message}.';
    } on TimeoutException {
      return 'Tiempo de espera agotado. Revise la red y el puerto 515.';
    } catch (_) {
      return 'No fue posible comprobar la impresora.';
    } finally {
      socket?.destroy();
    }
  }

  static Future<void> guardarAjustesEtiqueta({
    required double ancho,
    required double alto,
    required int columnas,
    required double qrX,
    required double qrY,
    required int qrSize,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('label_width', ancho.clamp(40.0, 110.0));
    await prefs.setDouble('label_height', alto.clamp(15.0, 100.0));
    await prefs.setInt('label_cols', columnas.clamp(1, 2));
    await prefs.setDouble('qr_x', qrX.clamp(0.0, ancho * 8));
    await prefs.setDouble('qr_y', qrY.clamp(0.0, alto * 8));
    await prefs.setInt('qr_size', qrSize.clamp(2, 10));
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

  static Future<void> imprimirEtiqueta(Registro registro) async {
    final host = (await obtenerIpGuardada())?.trim();
    final queue = (await obtenerNombreGuardado())?.trim();
    final settings = await obtenerAjustesEtiqueta();
    if (host == null ||
        queue == null ||
        !_isSafeLprValue(host) ||
        !_isSafeLprValue(queue)) {
      throw Exception(
        'Configure la dirección y el nombre de cola de la impresora.',
      );
    }

    final widthDots = ((settings['ancho'] as double) * 8).round();
    final heightDots = ((settings['alto'] as double) * 8).round();
    final qrSize = settings['qrSize'] as int;
    final columns = settings['columnas'] as int;
    final estimatedQrDots = qrSize * 30;
    final columnWidth = columns == 2 ? widthDots ~/ 2 : widthDots;
    final qrX = (settings['qrX'] as double)
        .round()
        .clamp(0, (columnWidth - estimatedQrDots).clamp(0, columnWidth));
    final qrY = (settings['qrY'] as double)
        .round()
        .clamp(0, (heightDots - estimatedQrDots).clamp(0, heightDots));

    var zpl = '^XA^PW$widthDots^LL$heightDots';
    zpl +=
        '^FO$qrX,$qrY^BQN,2,$qrSize^FDQA,fotocatalogo://registro/${registro.uuid}^FS';
    if (columns == 2) {
      zpl +=
          '^FO${qrX + columnWidth},$qrY^BQN,2,$qrSize^FDQA,fotocatalogo://registro/${registro.uuid}^FS';
    }
    zpl += '^XZ\n';

    final data = Uint8List.fromList(utf8.encode(zpl));
    final jobNumber = (DateTime.now().millisecondsSinceEpoch % 1000)
        .toString()
        .padLeft(3, '0');
    const clientHost = 'snapstock';
    final dataName = 'dfA$jobNumber$clientHost';
    final controlName = 'cfA$jobNumber$clientHost';
    final control = Uint8List.fromList(
      utf8.encode(
        'H$clientHost\n'
        'Psnapstock\n'
        'l$dataName\n'
        'U$dataName\n'
        'N${_safeJobName(registro.nombre)}\n',
      ),
    );

    Socket? socket;
    StreamIterator<Uint8List>? iterator;
    try {
      socket = await Socket.connect(
        host,
        lprPort,
        timeout: _connectionTimeout,
      );
      socket.setOption(SocketOption.tcpNoDelay, true);
      iterator = StreamIterator<Uint8List>(socket);

      socket.add([0x02]);
      socket.write('$queue\n');
      await socket.flush();
      await _waitForAck(iterator, 'abrir la cola de impresión');

      await _sendLprFile(
        socket,
        iterator,
        command: 0x02,
        name: controlName,
        bytes: control,
        step: 'enviar el archivo de control',
      );
      await _sendLprFile(
        socket,
        iterator,
        command: 0x03,
        name: dataName,
        bytes: data,
        step: 'enviar la etiqueta',
      );
    } on TimeoutException {
      throw Exception('La impresora no respondió dentro del tiempo esperado.');
    } on SocketException {
      throw Exception('No se pudo conectar con la impresora $host:$lprPort.');
    } catch (error) {
      if (error is Exception) rethrow;
      throw Exception('No fue posible completar la impresión.');
    } finally {
      await iterator?.cancel();
      socket?.destroy();
    }
  }

  static Future<void> _sendLprFile(
    Socket socket,
    StreamIterator<Uint8List> iterator, {
    required int command,
    required String name,
    required Uint8List bytes,
    required String step,
  }) async {
    socket.add([command]);
    socket.write('${bytes.length} $name\n');
    await socket.flush();
    await _waitForAck(iterator, step);

    socket.add(bytes);
    socket.add([0x00]);
    await socket.flush();
    await _waitForAck(iterator, step);
  }

  static Future<void> _waitForAck(
    StreamIterator<Uint8List> iterator,
    String step,
  ) async {
    final hasData = await iterator.moveNext().timeout(_connectionTimeout);
    if (!hasData || iterator.current.isEmpty) {
      throw Exception('La impresora cerró la conexión al $step.');
    }
    if (iterator.current.first != 0) {
      throw Exception('La impresora rechazó la operación al $step.');
    }
  }

  static bool _isSafeLprValue(String value) {
    return value.isNotEmpty &&
        value.length <= 255 &&
        !value.contains(RegExp(r'[\r\n\x00]'));
  }

  static String _safeJobName(String value) {
    final clean = value.replaceAll(RegExp(r'[\r\n\x00]'), ' ').trim();
    if (clean.isEmpty) return 'SnapStock QR';
    return clean.substring(0, clean.length > 80 ? 80 : clean.length);
  }
}

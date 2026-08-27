import 'dart:io';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/registro_model.dart';

class ExcelService {
  static Future<void> exportarRegistros(List<Registro> registros) async {
    final excel = Excel.createExcel();
    final sheetObject = excel['Inventario'];
    excel.delete('Sheet1');

    final headerStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString("#B7262E"),
      fontColorHex: ExcelColor.fromHexString("#FFFFFF"),
      bold: true,
      fontFamily: getFontFamily(FontFamily.Arial),
    );

    // CORRECCIÓN: Usando la propiedad correcta para ajustar texto
    final wrapStyle = CellStyle(
      textWrapping: TextWrapping.WrapText,
      verticalAlign: VerticalAlign.Top,
    );

    const headers = [
      "UUID",
      "Nombre",
      "Categoría",
      "Fecha",
      "Observaciones",
      "Num. Fotos",
    ];
    for (var i = 0; i < headers.length; i++) {
      final cell = sheetObject.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
      );
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    for (var i = 0; i < registros.length; i++) {
      final reg = registros[i];
      final row = i + 1;

      sheetObject
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = TextCellValue(
        reg.uuid,
      );
      sheetObject
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
          .value = TextCellValue(
        reg.nombre,
      );
      sheetObject
          .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
          .value = TextCellValue(
        reg.categoria,
      );
      sheetObject
          .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
          .value = TextCellValue(
        reg.fecha,
      );

      final obsCell = sheetObject.cell(
        CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row),
      );
      obsCell.value = TextCellValue(reg.observaciones);
      obsCell.cellStyle = wrapStyle;

      sheetObject
          .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
          .value = IntCellValue(
        reg.listaFotos.length,
      );
    }

    sheetObject.setColumnWidth(0, 38);
    sheetObject.setColumnWidth(1, 28);
    sheetObject.setColumnWidth(2, 20);
    sheetObject.setColumnWidth(3, 20);
    sheetObject.setColumnWidth(4, 44);
    sheetObject.setColumnWidth(5, 12);

    final fileBytes = excel.save();
    if (fileBytes == null) return;

    final directory = await getTemporaryDirectory();
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filePath = "${directory.path}/Inventario_SnapStock_$stamp.xlsx";
    final file = File(filePath);
    await file.writeAsBytes(fileBytes, flush: true);

    await Share.shareXFiles([
      XFile(filePath),
    ], text: 'Reporte de Inventario - SnapStock QR');
  }
}

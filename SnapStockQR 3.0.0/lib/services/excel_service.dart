import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/registro_model.dart';

class ExcelService {
  static Future<void> exportarRegistros(List<Registro> registros) async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Inventario'];
    excel.delete('Sheet1');

    CellStyle headerStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString("#4F81BD"),
      fontColorHex: ExcelColor.fromHexString("#FFFFFF"),
      bold: true,
      fontFamily: getFontFamily(FontFamily.Arial),
    );

    // CORRECCIÓN: Usando la propiedad correcta para ajustar texto
    CellStyle wrapStyle = CellStyle(
      textWrapping: TextWrapping.WrapText,
      verticalAlign: VerticalAlign.Top,
    );

    List<String> headers = [
      "UUID",
      "Nombre",
      "Categoría",
      "Fecha",
      "Observaciones",
      "Num. Fotos",
    ];
    for (var i = 0; i < headers.length; i++) {
      var cell = sheetObject.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
      );
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    for (var i = 0; i < registros.length; i++) {
      var reg = registros[i];
      int row = i + 1;

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

      var obsCell = sheetObject.cell(
        CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row),
      );
      obsCell.value = TextCellValue(reg.observaciones);
      obsCell.cellStyle = wrapStyle;

      sheetObject
          .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
          .value = IntCellValue(
        reg.listaFotos.length,
      );

      sheetObject.setColumnWidth(4, 40.0);
    }

    var fileBytes = excel.save();
    if (fileBytes == null) return;

    final directory = await getTemporaryDirectory();
    final filePath = "${directory.path}/Inventario_SnapStockQR.xlsx";
    final file = File(filePath);
    await file.writeAsBytes(fileBytes);

    await Share.shareXFiles([
      XFile(filePath),
    ], text: 'Reporte de Inventario - SnapStock QR');
  }
}

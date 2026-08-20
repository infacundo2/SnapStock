import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foto_catalogo/screens/login_screen.dart';

void main() {
  testWidgets('muestra el acceso de SnapStock QR', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('SnapStock QR'), findsOneWidget);
    expect(find.text('USUARIO'), findsOneWidget);
    expect(find.text('CONTRASEÑA'), findsOneWidget);
    expect(find.text('INGRESAR AL SERVIDOR'), findsOneWidget);
    expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);
  });
}

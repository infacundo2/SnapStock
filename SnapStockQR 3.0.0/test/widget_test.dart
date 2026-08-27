import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foto_catalogo/models/registro_model.dart';
import 'package:foto_catalogo/screens/detalle_screen.dart';
import 'package:foto_catalogo/screens/login_screen.dart';
import 'package:foto_catalogo/ui/app_theme.dart';

Widget _testApp() => MaterialApp(
      theme: AppTheme.dark,
      home: const LoginScreen(),
    );

void main() {
  testWidgets('muestra un acceso completo de SnapStock QR', (tester) async {
    await tester.pumpWidget(_testApp());

    expect(find.text('SnapStock QR'), findsOneWidget);
    expect(find.text('Inventario corporativo'), findsOneWidget);
    expect(find.text('Usuario'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('valida credenciales vacías sin llamar al servidor',
      (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.tap(find.text('Ingresar'));
    await tester.pump();

    expect(find.text('Ingrese su nombre de usuario.'), findsOneWidget);
    expect(find.text('Ingrese su contraseña.'), findsOneWidget);
  });

  testWidgets('se adapta a una pantalla angosta sin desbordar', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp());
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Ingresar'), findsOneWidget);
  });

  testWidgets('el detalle vacío se adapta a teléfono y tablet', (tester) async {
    final registro = Registro(
      uuid: 'registro-prueba',
      nombre: 'Equipo sin fotografía',
      fecha: '2026-08-27T12:00:00Z',
      observaciones: 'Registro utilizado para validar el diseño responsive.',
      categoria: 'Equipos',
      fotoPaths: '',
    );

    for (final size in const [Size(320, 568), Size(1024, 768)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: DetalleScreen(registro: registro),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Equipo sin fotografía'), findsWidgets);
      expect(find.text('Sin fotografías'), findsOneWidget);
    }

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}

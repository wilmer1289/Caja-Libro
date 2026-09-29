import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_caja/core/saludo.dart';
import 'package:mi_caja/core/tema.dart';
import 'package:mi_caja/datos/auth/autenticador.dart';
import 'package:mi_caja/datos/auth/autenticador_local.dart';
import 'package:mi_caja/ui/login/login_escritorio.dart';
import 'package:mi_caja/ui/login/login_movil.dart';
import 'package:mi_caja/ui/login/login_pagina.dart';
import 'package:mi_caja/ui/login/personajes.dart';

/// Los personajes animan en bucle (flote y parpadeo), así que `pumpAndSettle`
/// nunca terminaría: en este archivo se avanza el reloj a mano con `pump`.
void main() {
  late bool entro;

  Widget armar() {
    entro = false;
    return MaterialApp(
      theme: construirTema(),
      home: LoginPagina(
        autenticador: const AutenticadorLocal(),
        onEntrar: (_) => entro = true,
      ),
    );
  }

  Personajes personajes(WidgetTester tester) =>
      tester.widget<Personajes>(find.byType(Personajes));

  Finder campoUsuario() => find.byType(TextField).first;
  Finder campoClave() => find.byType(TextField).last;

  group('cuentas locales', () {
    test('entra con el usuario y la contraseña correctos', () async {
      final resultado = await const AutenticadorLocal().entrar(
        usuario: 'usuario',
        clave: 'usuario123',
      );
      expect(resultado, isA<EntradaOk>());
    });

    test('no le importan las mayúsculas ni los espacios del usuario', () async {
      // El teclado del celular pone mayúscula inicial solo; eso no debería
      // dejar a nadie afuera.
      final resultado = await const AutenticadorLocal().entrar(
        usuario: '  Usuario ',
        clave: 'usuario123',
      );
      expect(resultado, isA<EntradaOk>());
    });

    test('la contraseña sí distingue mayúsculas', () async {
      final resultado = await const AutenticadorLocal().entrar(
        usuario: 'usuario',
        clave: 'Usuario123',
      );
      expect(resultado, isA<EntradaFallida>());
    });

    test(
      'un usuario que no existe da el mismo mensaje que una clave mala',
      () async {
        final noExiste = await const AutenticadorLocal().entrar(
          usuario: 'juan',
          clave: 'usuario123',
        );
        final claveMala = await const AutenticadorLocal().entrar(
          usuario: 'usuario',
          clave: 'otra',
        );

        expect(noExiste, isA<EntradaFallida>());
        expect(claveMala, isA<EntradaFallida>());
        expect(
          (noExiste as EntradaFallida).mensaje,
          (claveMala as EntradaFallida).mensaje,
        );
      },
    );
  });

  group('saludo por hora', () {
    test('cambia con el momento del día', () {
      expect(Saludo.porHora(DateTime(2026, 9, 17, 7)), 'Buenos días');
      expect(Saludo.porHora(DateTime(2026, 9, 17, 15)), 'Buenas tardes');
      expect(Saludo.porHora(DateTime(2026, 9, 17, 21)), 'Buenas noches');
    });

    test('los cortes caen a las 12 y a las 19', () {
      // Las seis de la tarde todavía es tarde, no noche.
      expect(Saludo.porHora(DateTime(2026, 9, 17, 11, 59)), 'Buenos días');
      expect(Saludo.porHora(DateTime(2026, 9, 17, 12)), 'Buenas tardes');
      expect(Saludo.porHora(DateTime(2026, 9, 17, 18, 59)), 'Buenas tardes');
      expect(Saludo.porHora(DateTime(2026, 9, 17, 19)), 'Buenas noches');
    });
  });

  testWidgets('en pantalla ancha usa el login de escritorio', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(armar());
    await tester.pump();

    expect(find.byType(LoginEscritorio), findsOneWidget);
    expect(find.byType(LoginMovil), findsNothing);
  });

  testWidgets('en celular usa el login apilado', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(armar());
    await tester.pump();

    expect(find.byType(LoginMovil), findsOneWidget);
    expect(find.byType(LoginEscritorio), findsNothing);
  });

  testWidgets('no deja entrar con el formulario vacío y dice qué falta', (
    tester,
  ) async {
    await tester.pumpWidget(armar());
    await tester.pump();

    await tester.tap(find.text('Entrar a mi caja'));
    await tester.pump();

    expect(find.text('Escribe tu usuario'), findsOneWidget);
    expect(find.text('Escribe tu contraseña'), findsOneWidget);
    expect(entro, isFalse);
  });

  testWidgets('con credenciales equivocadas avisa y no entra', (tester) async {
    await tester.pumpWidget(armar());
    await tester.pump();

    await tester.enterText(campoUsuario(), 'usuario');
    await tester.enterText(campoClave(), 'la-que-no-es');
    await tester.tap(find.text('Entrar a mi caja'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Usuario o contraseña incorrectos'), findsOneWidget);
    expect(entro, isFalse);
  });

  testWidgets('el aviso desaparece apenas se corrige el campo', (tester) async {
    await tester.pumpWidget(armar());
    await tester.pump();

    await tester.enterText(campoUsuario(), 'usuario');
    await tester.enterText(campoClave(), 'mal');
    await tester.tap(find.text('Entrar a mi caja'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Usuario o contraseña incorrectos'), findsOneWidget);

    await tester.enterText(campoClave(), 'usuario1');
    await tester.pump();
    expect(find.text('Usuario o contraseña incorrectos'), findsNothing);
  });

  testWidgets('con las credenciales correctas entra, después del festejo', (
    tester,
  ) async {
    await tester.pumpWidget(armar());
    await tester.pump();

    await tester.enterText(campoUsuario(), 'usuario');
    await tester.enterText(campoClave(), 'usuario123');
    await tester.tap(find.text('Entrar a mi caja'));
    await tester.pump();
    await tester.pump();

    // Primero saltan y dicen "¡Vamos!"; recién después se pasa a la app.
    expect(find.text('¡Vamos!'), findsOneWidget);
    expect(entro, isFalse);

    await tester.pump(duracionFestejo + const Duration(milliseconds: 50));
    expect(entro, isTrue);
  });

  testWidgets('los personajes cambian de ánimo con lo que pasa', (
    tester,
  ) async {
    await tester.pumpWidget(armar());
    await tester.pump();
    expect(personajes(tester).animo, Animo.normal);

    await tester.enterText(campoUsuario(), 'usuario');
    await tester.enterText(campoClave(), 'mal');
    await tester.tap(find.text('Entrar a mi caja'));
    await tester.pump();
    await tester.pump();
    expect(personajes(tester).animo, Animo.triste);

    // Al corregir, se reponen.
    await tester.enterText(campoClave(), 'usuario123');
    await tester.pump();
    expect(personajes(tester).animo, Animo.normal);
  });

  testWidgets('no ofrece registrarse: las cuentas se crean a mano', (
    tester,
  ) async {
    await tester.pumpWidget(armar());
    await tester.pump();

    expect(find.textContaining('Regístrate'), findsNothing);
    expect(find.textContaining('No tienes cuenta'), findsNothing);
  });

  testWidgets('los personajes cierran los ojos al escribir la contraseña', (
    tester,
  ) async {
    await tester.pumpWidget(armar());
    await tester.pump();

    expect(personajes(tester).ojosCerrados, isFalse);

    // Foco en el campo de contraseña: se tapan los ojos.
    await tester.tap(campoClave());
    await tester.pump();
    expect(personajes(tester).ojosCerrados, isTrue);

    // Foco en el usuario: los vuelven a abrir.
    await tester.tap(campoUsuario());
    await tester.pump();
    expect(personajes(tester).ojosCerrados, isFalse);
  });

  testWidgets('si se revela la contraseña, los ojos se abren de nuevo', (
    tester,
  ) async {
    await tester.pumpWidget(armar());
    await tester.pump();

    await tester.tap(campoClave());
    await tester.pump();
    expect(personajes(tester).ojosCerrados, isTrue);

    // El ojito: no hay nada que espiar si el usuario ya la puso a la vista.
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();

    expect(personajes(tester).ojosCerrados, isFalse);
    expect(tester.widget<TextField>(campoClave()).obscureText, isFalse);

    // Y al volver a ocultarla, se cierran.
    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pump();

    expect(personajes(tester).ojosCerrados, isTrue);
  });
}

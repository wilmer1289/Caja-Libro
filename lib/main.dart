import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/tema.dart';
import 'datos/repositorio/repositorio_demo.dart';
import 'datos/repositorio/repositorio_movimientos.dart';
import 'dominio/pcge.dart';
import 'estado/estado_caja.dart';
import 'ui/puerta.dart';
import 'ui/widgets/banner_demo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Los nombres de meses y el formato de moneda en español se cargan una sola
  // vez al arrancar; sin esto, Formato reventaría en el primer build.
  await initializeDateFormatting('es_PE');

  // El plan contable, para poder poner código y denominación en los formatos.
  await Pcge.cargar();

  // La licencia OFL de Plus Jakarta Sans exige viajar con la fuente; así
  // además aparece en la pantalla de licencias de la app.
  LicenseRegistry.addLicense(() async* {
    final texto = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(const ['Plus Jakarta Sans'], texto);
  });

  runApp(const MiCajaApp());
}

class MiCajaApp extends StatelessWidget {
  const MiCajaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      // El repositorio se arma acá y baja por el árbol: las pantallas reciben
      // el estado ya listo y nunca construyen su propia conexión a la base.
      //
      // En la web no hay SQLite ni sistema de archivos, así que ahí corre el
      // repositorio de demostración: los mismos datos de ejemplo para
      // cualquiera que abra el link, que nunca tocan una base real y se
      // pierden al recargar la página.
      create: (_) =>
          EstadoCaja(kIsWeb ? RepositorioDemo() : RepositorioMovimientos()),
      child: MaterialApp(
        title: 'Mi Caja',
        debugShowCheckedModeBanner: false,
        theme: construirTema(),
        locale: const Locale('es', 'PE'),
        supportedLocales: const [Locale('es', 'PE'), Locale('es')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: kIsWeb
            ? const Column(
                children: [
                  BannerDemo(),
                  Expanded(child: Puerta()),
                ],
              )
            : const Puerta(),
      ),
    );
  }
}

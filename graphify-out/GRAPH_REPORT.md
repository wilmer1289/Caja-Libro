# Graph Report - Libro-caja  (2026-09-25)

## Corpus Check
- 109 files · ~73,439 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1643 nodes · 2343 edges · 95 communities (84 shown, 7 thin omitted)
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 54 edges (avg confidence: 0.86)
- Token cost: 229,336 input · 0 output

## Community Hubs (Navigation)
- Personajes del login (pintor)
- Config, dependencias y correcciones
- Ventana Datos del negocio
- Tabla del Formato 1.1/1.2
- Ventana Entró / Salió
- Libro oficial y asientos
- Exportación a PDF
- Pantalla de login
- Estado de la app (EstadoCaja)
- Modelo Movimiento
- Filtros del historial
- Catálogo de categorías
- Página de formatos oficiales
- Armazón Inicio y navegación
- Libro mayor (dominio)
- Tema y paleta de colores
- Página Caja y bancos
- Páginas que leen EstadoCaja
- Base SQLite y exportación CSV
- Barra lateral plegable
- Página Resumen (dashboard)
- Pruebas de correcciones y mayor
- Repositorio de movimientos
- Pruebas del armazón Inicio
- DAOs de SQLite
- Tarjetas de saldo
- Capturas de documentos
- Panel de personajes y adornos
- Capturas de la app completa
- Pintores y fondo grafito
- Bloques privados de páginas
- Puerta y transición de entrada
- Página de reportes
- Ventana Flutter de Windows
- Formato de moneda y fechas
- Plan contable PCGE
- Recibo imprimible
- Widgets con estado de hover
- Secciones de la app
- Ventana Win32 (implementación)
- Modelo Negocio
- Dominio del recibo
- Pruebas del login
- Pruebas del formato oficial
- Resumen del mes
- Fila de movimiento
- Encabezado de página
- Pruebas del dominio
- Series de gráficos
- Enums Tipo/Medio/Cuenta
- Bloque de asiento resumen
- Arranque main.dart
- Tarjeta de cuenta
- Estado vacío
- Animación Aparece
- Fuente remota (stub nube)
- Distintivo y dato chico
- Punto de entrada Windows
- Esqueleto de carga
- Efecto presionable
- Anillo de enfoque
- Win32Window (interfaz)
- Mensajes y DPI de Win32
- Esquema y migración SQLite
- Monto en letras
- Globo de diálogo
- Animación al entrar
- Ícono adaptable (primer plano)
- Ícono del lanzador Android
- Marca Mi Caja
- Resultado de autenticación
- Login de escritorio
- Efecto elevable
- Logo pintado
- Autenticador local
- Saludo por hora
- Login móvil
- Cálculo de IGV
- Lectura de importes
- Periodos de fechas
- Registro de plugins Windows
- Win32 Point
- Win32 Size
- MainActivity Android
- Columnas de la hoja
- Widget Personajes
- Widget HojaFormato
- Widget LoginPagina
- Exclusiones del analizador
- Licencia OFL de la fuente
- Tipo String?

## God Nodes (most connected - your core abstractions)
1. `_` - 48 edges
2. `EstadoCaja` - 38 edges
3. `Win32Window` - 21 edges
4. `MessageHandler` - 12 edges
5. `FlutterWindow` - 10 edges
6. `Create` - 10 edges
7. `WndProc` - 10 edges
8. `Correction tests (test/correcciones_test.dart)` - 9 edges
9. `MessageHandler` - 8 edges
10. `mi_caja.db (local SQLite database)` - 8 edges

## Surprising Connections (you probably didn't know these)
- `Cloud sync not configured (data stays local)` --semantically_similar_to--> `Offline operation requirement (section 2.3)`  [INFERRED] [semantically similar]
  LEEME_CORRECCIONES.md → pubspec.yaml
- `mi_caja.db (local SQLite database)` --conceptually_related_to--> `path_provider`  [INFERRED]
  LEEME_CORRECCIONES.md → pubspec.yaml
- `mi_caja.db (local SQLite database)` --conceptually_related_to--> `sqflite / sqflite_common_ffi (SQLite)`  [INFERRED]
  LEEME_CORRECCIONES.md → pubspec.yaml
- `LEEME_CORRECCIONES.md (Mi Caja corrections notes)` --conceptually_related_to--> `captura test tag (screenshot tests)`  [INFERRED]
  LEEME_CORRECCIONES.md → dart_test.yaml
- `Windows release build (flutter build windows --release)` --conceptually_related_to--> `Windows install bundle (data, flutter_assets, DLLs, AOT)`  [INFERRED]
  LEEME_CORRECCIONES.md → windows/CMakeLists.txt

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Windows native build and install pipeline** — windows_cmakelists_mi_caja_binary, windows_runner_cmakelists_runner_target, windows_flutter_cmakelists_flutter_library, windows_flutter_cmakelists_flutter_wrapper_app, windows_flutter_cmakelists_flutter_assemble, windows_cmakelists_install_bundle [EXTRACTED 1.00]
- **Assets bundled in the app for offline operation** — pubspec_offline_first, pubspec_pcge_json, pubspec_jakarta_font_family [EXTRACTED 1.00]
- **Corrections covered by correcciones_test.dart** — leeme_correcciones_pruebas_correcciones, leeme_correcciones_importes_en_centavos, leeme_correcciones_saldos_iniciales, leeme_correcciones_grafico_saldo, leeme_correcciones_formato_arrastre, leeme_correcciones_csv_proteccion_formulas, leeme_correcciones_exportacion_perfil_bancario, leeme_correcciones_marcado_respaldos [EXTRACTED 1.00]
- **ic_launcher exported across all five Android mipmap densities** — android_app_src_main_res_mipmap_mdpi_ic_launcher, android_app_src_main_res_mipmap_hdpi_ic_launcher, android_app_src_main_res_mipmap_xhdpi_ic_launcher, android_app_src_main_res_mipmap_xxhdpi_ic_launcher, android_app_src_main_res_mipmap_xxxhdpi_ic_launcher, android_app_src_main_res_mipmap_xxxhdpi_ic_launcher_android_mipmap_density_buckets [INFERRED 0.95]
- **ic_launcher_foreground density bucket set (mdpi to xxxhdpi)** — android_app_src_main_res_mipmap_mdpi_ic_launcher_foreground, android_app_src_main_res_mipmap_hdpi_ic_launcher_foreground, android_app_src_main_res_mipmap_xhdpi_ic_launcher_foreground, android_app_src_main_res_mipmap_xxhdpi_ic_launcher_foreground, android_app_src_main_res_mipmap_xxxhdpi_ic_launcher_foreground, android_app_src_main_res_adaptive_icon_foreground_layer [INFERRED 0.95]

## Communities (95 total, 7 thin omitted)

### Community 0 - "Personajes del login (pintor)"
Cohesion: 0.04
Nodes (53): anchoCerrado, aplicar, borde, build, caidaCerrado, color, colorBoca, colorOjo (+45 more)

### Community 1 - "Config, dependencias y correcciones"
Cohesion: 0.06
Nodes (42): flutter_lints recommended lint set, Plus Jakarta Sans, SIL Open Font License 1.1, captura test tag (screenshot tests), LEEME_CORRECCIONES.md (Mi Caja corrections notes), Demo login and unencrypted SQLite, Shared SQLite open across concurrent requests, CSV formula-injection protection (+34 more)

### Community 2 - "Ventana Datos del negocio"
Cohesion: 0.04
Nodes (46): abrir, _aCentavos, _aTexto, _AvisoError, ayuda, bajada, _banco, _Bloque (+38 more)

### Community 3 - "Tabla del Formato 1.1/1.2"
Cohesion: 0.04
Nodes (44): double?, alineacion, _altura, _alturaGrupo, ancho, _anchoEtiqueta, anchos, _BarraTitulo (+36 more)

### Community 4 - "Ventana Entró / Salió"
Cohesion: 0.05
Nodes (43): bool?, abierto, abrir, activo, _afectoIgv, _Aviso, build, _Cabecera (+35 more)

### Community 5 - "Libro oficial y asientos"
Cohesion: 0.05
Nodes (42): acreedor, armar, asientos, codigo, codigoCuenta, contraparte, cuadra, cuenta (+34 more)

### Community 6 - "Exportación a PDF"
Cohesion: 0.05
Nodes (40): dart:typed_data, Font?, _asiento, _borde, _cabecera, _cabeceraTabla, _cargarFuentes, centro (+32 more)

### Community 7 - "Pantalla de login"
Cohesion: 0.05
Nodes (38): Animo get, anchoEscritorioLogin, _animo, autenticador, _avisarOlvido, _AvisoError, _BotonEntrar, build (+30 more)

### Community 8 - "Estado de la app (EstadoCaja)"
Cohesion: 0.05
Nodes (36): DateTimeRange?, ../../dominio/mayor.dart, Bolsillo, aplicarFiltro, bolsillo, _cargando, cargar, deshacerEliminacion (+28 more)

### Community 9 - "Modelo Movimiento"
Cohesion: 0.06
Nodes (35): Categoria? get, Cuenta get, int?, actualizadoEn, aMapa, baseCentavos, categoria, categoriaId (+27 more)

### Community 10 - "Filtros del historial"
Cohesion: 0.06
Nodes (35): ../../dominio/periodo.dart, BarraFiltros, _BarraFiltrosState, BotonFiltro, _busqueda, _CampoFecha, createState, _desde (+27 more)

### Community 11 - "Catálogo de categorías"
Cohesion: 0.06
Nodes (35): afectoIgv, afp, agua, alquiler, anticipos, cobrosFiado, comun, comunesDe (+27 more)

### Community 12 - "Página de formatos oficiales"
Cohesion: 0.06
Nodes (34): bloque_asiento.dart, DateTime get, ../../datos/export/exportador.dart, hoja_formato.dart, accion, activa, amplio, bajada (+26 more)

### Community 13 - "Armazón Inicio y navegación"
Cohesion: 0.06
Nodes (34): ../../core/saludo.dart, dashboard/dashboard_pagina.dart, formatos/formatos_pagina.dart, historial/historial_pagina.dart, _alDesplazar, _alternarBarra, _anchoEscritorio, _BarraInferior (+26 more)

### Community 14 - "Libro mayor (dominio)"
Cohesion: 0.06
Nodes (35): _, armar, banco, caja, cantidad, cantidadDe, cuenta, deMedio (+27 more)

### Community 15 - "Tema y paleta de colores"
Cohesion: 0.06
Nodes (32): areaToque, borde, bordeFuerte, brilloFoco, construirTema, cromo, cromoAlto, cromoTexto (+24 more)

### Community 16 - "Página Caja y bancos"
Cohesion: 0.06
Nodes (32): accion, amplio, _anchoFecha, _anchoMedio, _anchoMonto, _anchoSaldo, bajada, bolsillo (+24 more)

### Community 17 - "Páginas que leen EstadoCaja"
Cohesion: 0.08
Nodes (29): barra_filtros.dart, ChangeNotifier, ../formatos/recibo_hoja.dart, EstadoCaja, build, _Cuentas, DashboardPagina, _GraficoCategorias (+21 more)

### Community 18 - "Base SQLite y exportación CSV"
Cohesion: 0.07
Nodes (27): dart:convert, dart:io, ../../dominio/libro_oficial.dart, esquema.dart, Future, _abriendo, abrir, BaseDatos (+19 more)

### Community 19 - "Barra lateral plegable"
Cohesion: 0.07
Nodes (29): ../../dominio/resumen.dart, activa, ancho, anchoPlegada, BarraLateral, build, conTexto, createState (+21 more)

### Community 20 - "Página Resumen (dashboard)"
Cohesion: 0.07
Nodes (29): accion, amplio, bajada, _Cargando, color, _colores, _contar, de (+21 more)

### Community 21 - "Pruebas de correcciones y mayor"
Cohesion: 0.08
Nodes (25): package:mi_caja/datos/db/esquema.dart, package:mi_caja/datos/export/exportador.dart, package:mi_caja/datos/local/movimiento_dao.dart, package:mi_caja/datos/local/negocio_dao.dart, package:mi_caja/dominio/enums.dart, package:mi_caja/dominio/importe.dart, package:mi_caja/dominio/libro_oficial.dart, package:mi_caja/dominio/mayor.dart (+17 more)

### Community 22 - "Repositorio de movimientos"
Cohesion: 0.08
Nodes (22): ../../dominio/categoria.dart, ../../dominio/enums.dart, ../../dominio/igv.dart, ../../dominio/importe.dart, _dao, editar, eliminar, guardarNegocio (+14 more)

### Community 23 - "Pruebas del armazón Inicio"
Cohesion: 0.08
Nodes (23): RepositorioMovimientos, package:mi_caja/datos/repositorio/repositorio_movimientos.dart, package:mi_caja/estado/estado_caja.dart, package:mi_caja/ui/inicio.dart, package:mi_caja/ui/negocio/negocio_pagina.dart, package:mi_caja/ui/registro/registro_hoja.dart, _RepositorioEnMemoria, armar (+15 more)

### Community 24 - "DAOs de SQLite"
Cohesion: 0.10
Nodes (21): Database?, ../db/base_datos.dart, ../db/esquema.dart, ../../dominio/negocio.dart, async, database, guardar, guardarVarios (+13 more)

### Community 25 - "Tarjetas de saldo"
Cohesion: 0.09
Nodes (22): build, centavos, child, clip, color, colores, createState, destacada (+14 more)

### Community 26 - "Capturas de documentos"
Cohesion: 0.09
Nodes (21): dart:ui, package:flutter/rendering.dart, package:mi_caja/datos/export/exportador_pdf.dart, package:mi_caja/ui/formatos/bloque_asiento.dart, package:mi_caja/ui/formatos/hoja_formato.dart, package:mi_caja/ui/formatos/recibo_hoja.dart, package:mi_caja/ui/widgets/logo.dart, capturar (+13 more)

### Community 27 - "Panel de personajes y adornos"
Cohesion: 0.10
Nodes (20): dart:math, globo.dart, _Adornos, _Amplio, animo, build, _Compacto, conFondo (+12 more)

### Community 28 - "Capturas de la app completa"
Cohesion: 0.10
Nodes (20): _app, _capturar, _cargarFuentes, _datos, escritorio, _esperar, familia, guardarNegocio (+12 more)

### Community 29 - "Pintores y fondo grafito"
Cohesion: 0.11
Nodes (19): CustomPainter, _FormaGlobo, _ArcoNaranja, _PintorPersonajes, build, child, CirculoAdorno, color (+11 more)

### Community 30 - "Bloques privados de páginas"
Cohesion: 0.10
Nodes (20): _Bienvenida, _Cabecera, _Leyenda, _Recientes, _SinEgresos, _Alternador, _Aviso, _BotonExportar (+12 more)

### Community 31 - "Puerta y transición de entrada"
Cohesion: 0.11
Nodes (18): ../datos/auth/autenticador.dart, ../datos/auth/autenticador_local.dart, inicio.dart, autenticador, avance, build, _conTransicion, createState (+10 more)

### Community 32 - "Página de reportes"
Cohesion: 0.11
Nodes (18): ../../dominio/series.dart, actual, amplio, _Barras, build, claves, color, _estiloCabecera (+10 more)

### Community 33 - "Ventana Flutter de Windows"
Cohesion: 0.12
Nodes (16): FlutterViewController, unique_ptr, DartProject, HWND, LPARAM, LRESULT, UINT, WPARAM (+8 more)

### Community 34 - "Formato de moneda y fechas"
Cohesion: 0.11
Nodes (18): capitalizar, compacto, _dia, _diaCorto, diaMes, fecha, fechaCorta, fechaRelativa (+10 more)

### Community 35 - "Plan contable PCGE"
Cohesion: 0.11
Nodes (18): buscar, caja, cargar, cargarDePrueba, cuentaCorriente, _cuentas, denominacion, denominacionConPadre (+10 more)

### Community 36 - "Recibo imprimible"
Cohesion: 0.11
Nodes (17): ../../datos/export/abrir_archivo.dart, ../../datos/export/exportador_pdf.dart, ../../dominio/recibo.dart, abrir, build, _Campo, createState, etiqueta (+9 more)

### Community 37 - "Widgets con estado de hover"
Cohesion: 0.17
Nodes (18): _Acciones, _AccionesState, _RenglonMedio, _RenglonMedioState, Puerta, _PuertaState, BotonPlegar, _BotonPlegarState (+10 more)

### Community 38 - "Secciones de la app"
Cohesion: 0.11
Nodes (17): bajada, cajaYBancos, etiqueta, etiquetaCorta, formatos, historial, iCajaYBancos, icono (+9 more)

### Community 39 - "Ventana Win32 (implementación)"
Cohesion: 0.18
Nodes (14): wchar_t, Scale(), Create, Destroy, SetQuitOnClose, Show, UpdateTheme, Win32Window::Win32Window() (+6 more)

### Community 40 - "Modelo Negocio"
Cohesion: 0.12
Nodes (16): bool get, aMapa, completo, completoParaBanco, copiarCon, cuentaCorriente, desdeMapa, direccion (+8 more)

### Community 41 - "Dominio del recibo"
Cohesion: 0.12
Nodes (16): Negocio, concepto, emitible, esIngreso, identificaContraparte, lineaConformidad, montoEnLetras, movimiento (+8 more)

### Community 42 - "Pruebas del login"
Cohesion: 0.12
Nodes (16): package:flutter_test/flutter_test.dart, package:mi_caja/core/saludo.dart, package:mi_caja/core/tema.dart, package:mi_caja/datos/auth/autenticador.dart, package:mi_caja/datos/auth/autenticador_local.dart, package:mi_caja/ui/login/login_escritorio.dart, package:mi_caja/ui/login/login_movil.dart, package:mi_caja/ui/login/login_pagina.dart (+8 more)

### Community 43 - "Pruebas del formato oficial"
Cohesion: 0.12
Nodes (15): package:mi_caja/dominio/monto_en_letras.dart, package:mi_caja/dominio/recibo.dart, required DateTime fecha,
  int, armar, categoriaId, centavos, contraparte, eliminadoEn (+7 more)

### Community 44 - "Resumen del mes"
Cohesion: 0.13
Nodes (14): double get, int get, cantidadEntroMes, cantidadSalioMes, de, entroMes, flujoPositivo, proporcionGastada (+6 more)

### Community 45 - "Fila de movimiento"
Cohesion: 0.14
Nodes (14): Movimiento, build, child, createState, _ctrl, _Destello, _DestelloState, dispose (+6 more)

### Community 46 - "Encabezado de página"
Cohesion: 0.13
Nodes (14): acciones, bajada, build, compacto, elevado, Encabezado, estrecho, nombre (+6 more)

### Community 47 - "Pruebas del dominio"
Cohesion: 0.13
Nodes (14): package:mi_caja/dominio/categoria.dart, package:mi_caja/dominio/igv.dart, package:mi_caja/dominio/pcge.dart, package:mi_caja/dominio/periodo.dart, package:mi_caja/dominio/series.dart, required int centavos,
  MedioPago, categoriaId, centavos (+6 more)

### Community 48 - "Series de gráficos"
Cohesion: 0.14
Nodes (13): categoria.dart, DateTime, enums.dart, Categoria, categoria, centavos, dia, egresosPorCategoria (+5 more)

### Community 49 - "Enums Tipo/Medio/Cuenta"
Cohesion: 0.14
Nodes (13): codigoPcge, codigoTabla1, columnaFormato, comunes, Cuenta, desdeBd, EstadoSync, etiqueta (+5 more)

### Community 50 - "Bloque de asiento resumen"
Cohesion: 0.15
Nodes (12): ../../core/formato.dart, AsientoResumen, LineaAsiento, asiento, BloqueAsiento, _borde, build, _Cabecera (+4 more)

### Community 51 - "Arranque main.dart"
Cohesion: 0.15
Nodes (12): datos/repositorio/repositorio_movimientos.dart, dominio/pcge.dart, ../../estado/estado_caja.dart, build, cargar, initializeDateFormatting, main, MiCajaApp (+4 more)

### Community 52 - "Tarjeta de cuenta"
Cohesion: 0.15
Nodes (12): elevable.dart, bajada, build, centavos, conFlecha, elegida, icono, onTap (+4 more)

### Community 53 - "Estado vacío"
Cohesion: 0.17
Nodes (12): accion, build, _Buscando, _BuscandoState, createState, _ctrl, dispose, EstadoVacio (+4 more)

### Community 54 - "Animación Aparece"
Cohesion: 0.17
Nodes (11): Animation, Duration, build, child, createState, _ctrl, _curva, desplazamiento (+3 more)

### Community 55 - "Fuente remota (stub nube)"
Cohesion: 0.18
Nodes (10): ../../dominio/movimiento.dart, fuente_remota.dart, bajar, disponible, FuenteRemota, bajar, disponible, FuenteRemotaNula (+2 more)

### Community 56 - "Distintivo y dato chico"
Cohesion: 0.17
Nodes (11): IconData?, _aclarar, build, color, DatoChico, Distintivo, etiqueta, icono (+3 more)

### Community 57 - "Punto de entrada Windows"
Cohesion: 0.24
Nodes (9): _In_, _In_opt_, vector, wWinMain(), string, wchar_t, CreateAndAttachConsole(), GetCommandLineArguments() (+1 more)

### Community 58 - "Esqueleto de carga"
Cohesion: 0.18
Nodes (10): AnimationController, alto, ancho, build, createState, _ctrl, dispose, EsqueletoLista (+2 more)

### Community 59 - "Efecto presionable"
Cohesion: 0.18
Nodes (10): build, child, createState, _ctrl, dispose, escala, _hundir, _resorte (+2 more)

### Community 60 - "Anillo de enfoque"
Cohesion: 0.22
Nodes (9): Color?, activo, build, child, color, createState, Enfoque, _EnfoqueState (+1 more)

### Community 61 - "Win32Window (interfaz)"
Cohesion: 0.27
Nodes (10): RECT, OnCreate, HWND, Win32Window, child_content_, GetClientArea, OnCreate, quit_on_close_ (+2 more)

### Community 62 - "Mensajes y DPI de Win32"
Cohesion: 0.36
Nodes (10): HWND, LPARAM, LRESULT, UINT, WPARAM, EnableFullDpiSupportIfAvailable(), GetHandle, GetThisFromHandle (+2 more)

### Community 63 - "Esquema y migración SQLite"
Cohesion: 0.22
Nodes (8): crearMovimientos, crearNegocio, Esquema, indices, migracionV2, tablaMovimientos, tablaNegocio, version

### Community 64 - "Monto en letras"
Cohesion: 0.22
Nodes (8): _centenas, _decenas, _entero, _hasta999, MontoEnLetras, soles, _tope, _unidades

### Community 65 - "Globo de diálogo"
Cohesion: 0.25
Nodes (7): _altoCola, build, cola, GloboDialogo, paint, shouldRepaint, texto

### Community 66 - "Animación al entrar"
Cohesion: 0.29
Nodes (7): AlEntrar, _AlEntrarState, build, createState, initState, _listo, package:flutter/material.dart

### Community 67 - "Ícono adaptable (primer plano)"
Cohesion: 0.57
Nodes (7): Adaptive Icon Foreground Layer (ic_launcher_foreground), ic_launcher_foreground.png (hdpi, 162x162), ic_launcher_foreground.png (mdpi, 108x108), ic_launcher_foreground.png (xhdpi, 216x216), ic_launcher_foreground.png (xxhdpi, 324x324), ic_launcher_foreground.png (xxxhdpi, 432x432), Orange Smiling Semicircle Mascot (app brand mark)

### Community 68 - "Ícono del lanzador Android"
Cohesion: 0.48
Nodes (7): ic_launcher.png (hdpi, 72px launcher icon), ic_launcher.png (mdpi, 48px launcher icon), ic_launcher.png (xhdpi, 96px launcher icon), ic_launcher.png (xxhdpi, 144px launcher icon), ic_launcher.png (xxxhdpi, 192px launcher icon), Android Mipmap Density Buckets (mdpi/hdpi/xhdpi/xxhdpi/xxxhdpi), Libro-caja App Launcher Icon (smiling orange semicircle mascot)

### Community 69 - "Marca Mi Caja"
Cohesion: 0.29
Nodes (6): ../../core/tema.dart, build, conBajada, grande, MarcaMiCaja, logo.dart

### Community 70 - "Resultado de autenticación"
Cohesion: 0.38
Nodes (6): EntradaFallida, EntradaOk, entrar, mensaje, nombre, ResultadoEntrada

### Community 71 - "Login de escritorio"
Cohesion: 0.29
Nodes (6): anchoPanelLogin, build, formulario, LoginEscritorio, panel, ../widgets/fondo_cromo.dart

### Community 72 - "Efecto elevable"
Cohesion: 0.33
Nodes (6): build, child, createState, Elevable, _ElevableState, _encima

### Community 73 - "Logo pintado"
Cohesion: 0.29
Nodes (6): build, LogoMiCaja, paint, _PintorLogo, shouldRepaint, tamano

### Community 74 - "Autenticador local"
Cohesion: 0.33
Nodes (5): autenticador.dart, Autenticador, AutenticadorLocal, _cuentas, entrar

### Community 75 - "Saludo por hora"
Cohesion: 0.33
Nodes (5): bienvenida, lema, lemaApoyo, porHora, Saludo

### Community 76 - "Login móvil"
Cohesion: 0.33
Nodes (5): build, formulario, LoginMovil, panel, Widget?

### Community 77 - "Cálculo de IGV"
Cohesion: 0.40
Nodes (4): agregar, desagregar, Igv, tasa

### Community 78 - "Lectura de importes"
Cohesion: 0.40
Nodes (4): Importe, leer, maximoCentavos, static const

### Community 79 - "Periodos de fechas"
Cohesion: 0.40
Nodes (4): etiqueta, Periodo, rango, _soloFecha

### Community 81 - "Win32 Point"
Cohesion: 0.50
Nodes (3): Point, x, y

### Community 82 - "Win32 Size"
Cohesion: 0.50
Nodes (3): Size, height, width

### Community 84 - "Columnas de la hoja"
Cohesion: 0.67
Nodes (3): _Bloque, _Columna, _Grupo

### Community 85 - "Widget Personajes"
Cohesion: 0.67
Nodes (3): Personajes, _PersonajesState, TickerProviderStateMixin

## Knowledge Gaps
- **1023 isolated node(s):** `Formato`, `_numero`, `_dia`, `_diaCorto`, `_mes` (+1018 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 1154 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **7 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `_` connect `Libro mayor (dominio)` to `Estado de la app (EstadoCaja)`, `Dominio del recibo`, `Resumen del mes`, `Fila de movimiento`, `Encabezado de página`, `Lectura de importes`, `Series de gráficos`, `Enums Tipo/Medio/Cuenta`?**
  _High betweenness centrality (0.038) - this node is a cross-community bridge._
- **Why does `Negocio` connect `Dominio del recibo` to `Libro oficial y asientos`, `Modelo Negocio`, `Estado de la app (EstadoCaja)`, `Libro mayor (dominio)`, `Pruebas del armazón Inicio`, `Capturas de la app completa`?**
  _High betweenness centrality (0.016) - this node is a cross-community bridge._
- **Why does `EstadoCaja` connect `Páginas que leen EstadoCaja` to `Página de reportes`, `Ventana Datos del negocio`, `Ventana Entró / Salió`, `Estado de la app (EstadoCaja)`, `Filtros del historial`, `Página de formatos oficiales`, `Armazón Inicio y navegación`, `Página Caja y bancos`, `Página Resumen (dashboard)`?**
  _High betweenness centrality (0.012) - this node is a cross-community bridge._
- **What connects `Formato`, `_numero`, `_dia` to the rest of the system?**
  _1023 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Personajes del login (pintor)` be split into smaller, more focused modules?**
  _Cohesion score 0.037037037037037035 - nodes in this community are weakly interconnected._
- **Should `Config, dependencias y correcciones` be split into smaller, more focused modules?**
  _Cohesion score 0.05550416281221091 - nodes in this community are weakly interconnected._
- **Should `Ventana Datos del negocio` be split into smaller, more focused modules?**
  _Cohesion score 0.043478260869565216 - nodes in this community are weakly interconnected._
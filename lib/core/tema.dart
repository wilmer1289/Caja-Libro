import 'package:flutter/material.dart';

/// Paleta y tokens visuales de Mi Caja.
///
/// La idea: **contenido claro y cálido, marco oscuro, un solo acento**. Las
/// páginas son blanco cálido; la barra lateral, el panel del login y la
/// tarjeta del saldo son grafito; y el naranja del personaje es el color de
/// la marca: botones principales, la opción activa del menú, los íconos que
/// importan.
///
/// El grafito tira a marrón y no a azul a propósito. Un gris frío junto al
/// naranja se ve sucio; uno cálido lo acompaña.
///
/// Los colores de ingreso/egreso son apagados —verde salvia, rojo terracota—
/// para que convivan con el naranja sin competir con él. Nunca se usan solos:
/// siempre van con una flecha (↑/↓), así la app no depende del color (§5).
class Tokens {
  static const tipografia = 'Jakarta';

  // --- Cromo oscuro: barra lateral, panel del login, tarjeta del saldo ---
  static const cromo = Color(0xFF292724);
  static const cromoAlto = Color(0xFF36332F);
  static const cromoTexto = Color(0xFFF7F6F3);
  static const cromoTexto2 = Color(0xFFB4AEA7);

  // --- Marca ---
  /// Naranja principal: botones, selección del menú, íconos importantes.
  static const marca = Color(0xFFF97316);

  /// El mismo naranja más hondo, para texto chico sobre fondo claro (un link,
  /// una etiqueta): el naranja puro no llega a leerse bien en letra chica.
  static const marcaOscura = Color(0xFFE0600B);

  /// Naranja suave: fondo de lo seleccionado y de las tarjetas destacadas.
  static const marcaSuave = Color(0xFFFFF1E6);

  // --- Plata que entra y que sale ---
  /// Verde apagado, sólo para cantidades positivas.
  static const entro = Color(0xFF3E8E6D);

  /// El mismo verde más claro, para lo que no es texto sobre fondo oscuro:
  /// puntos, brillos, el pulso de la tarjeta del saldo.
  static const entroVivo = Color(0xFF5BAE8B);
  static const entroSuave = Color(0xFFE9F3EE);

  /// Rojo terracota: más elegante que un rojo fuerte, y no grita.
  static const salio = Color(0xFFC95F54);
  static const salioVivo = Color(0xFFE08A80);
  static const salioSuave = Color(0xFFF9ECEA);

  // --- Contenido claro, en tonos cálidos ---
  static const texto = Color(0xFF24211F);
  static const texto2 = Color(0xFF77716B);
  static const borde = Color(0xFFE5E1DC);
  static const bordeFuerte = Color(0xFFD6D0C9);
  static const fondo = Color(0xFFF7F6F3);
  static const superficie = Color(0xFFFFFFFF);

  /// Crema de la baldosa del logo y de los personajes claros: sobre grafito,
  /// un blanco puro encandila.
  static const escenario = Color(0xFFF1EBDF);

  /// Área mínima de toque pensada para dedos reales (§5, accesibilidad táctil).
  static const areaToque = 48.0;
  static const radio = 12.0;
  static const radioGrande = 20.0;

  /// Degradado de la barra lateral, el panel del login y la tarjeta del saldo.
  static const degradadoCromo = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [cromoAlto, cromo],
  );

  /// Sombra de las tarjetas: una corta que las apoya y una larga y muy suave
  /// que las despega del fondo. Tiñe de marrón y no de negro: sobre un fondo
  /// cálido, una sombra negra pura se ve gris y sucia.
  static const sombraTarjeta = [
    BoxShadow(color: Color(0x082A1A0C), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0B2A1A0C), blurRadius: 18, offset: Offset(0, 4)),
  ];

  /// Sombra de lo que flota encima de todo: menús, diálogos, botones flotantes.
  static const sombraFlotante = [
    BoxShadow(color: Color(0x142A1A0C), blurRadius: 6, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x1F2A1A0C), blurRadius: 40, offset: Offset(0, 18)),
  ];

  /// Brillo de un campo con el foco: un anillo suave en vez de sólo cambiar
  /// el color del borde.
  static List<BoxShadow> brilloFoco(Color color) => [
    BoxShadow(color: color.withValues(alpha: 0.16), spreadRadius: 4),
  ];
}

ThemeData construirTema() {
  final esquema =
      ColorScheme.fromSeed(
        seedColor: Tokens.marca,
        primary: Tokens.marca,
        onPrimary: Colors.white,
        surface: Tokens.superficie,
        error: Tokens.salio,
      ).copyWith(
        // Material 3 tiñe las superficies elevadas con el color primario. Con un
        // naranja de marca eso deja las tarjetas y los menús color durazno.
        surfaceTint: Colors.transparent,
        onSurface: Tokens.texto,
        onSurfaceVariant: Tokens.texto2,
        outline: Tokens.bordeFuerte,
        outlineVariant: Tokens.borde,
        primaryContainer: Tokens.marcaSuave,
        onPrimaryContainer: Tokens.marcaOscura,
        secondaryContainer: Tokens.marcaSuave,
        onSecondaryContainer: Tokens.texto,
      );

  final redondeado = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(Tokens.radio),
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: Tokens.tipografia,
    colorScheme: esquema,
    scaffoldBackgroundColor: Tokens.fondo,
    dividerColor: Tokens.borde,
    dividerTheme: const DividerThemeData(color: Tokens.borde, thickness: 1),
    // Tarjetas planas con un borde fino y una sombra que casi no se ve: en la
    // referencia se despegan del fondo por el blanco, no por la sombra.
    cardTheme: CardThemeData(
      elevation: 0,
      color: Tokens.superficie,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tokens.radioGrande),
        side: const BorderSide(color: Tokens.borde),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Tokens.superficie,
      hintStyle: TextStyle(color: Tokens.texto2.withValues(alpha: 0.75)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Tokens.radio),
        borderSide: const BorderSide(color: Tokens.borde),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Tokens.radio),
        borderSide: const BorderSide(color: Tokens.borde),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Tokens.radio),
        borderSide: const BorderSide(color: Tokens.marca, width: 1.6),
      ),
      prefixIconColor: WidgetStateColor.resolveWith(
        (estados) => estados.contains(WidgetState.focused)
            ? Tokens.marca
            : Tokens.texto2,
      ),
      suffixIconColor: Tokens.texto2,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Tokens.marca,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, Tokens.areaToque),
        textStyle: const TextStyle(
          fontFamily: Tokens.tipografia,
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
        ),
        shape: redondeado,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, Tokens.areaToque),
        foregroundColor: Tokens.texto,
        backgroundColor: Tokens.superficie,
        side: const BorderSide(color: Tokens.borde),
        textStyle: const TextStyle(
          fontFamily: Tokens.tipografia,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        shape: redondeado,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Tokens.marcaOscura,
        textStyle: const TextStyle(
          fontFamily: Tokens.tipografia,
          fontWeight: FontWeight.w600,
        ),
        shape: redondeado,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: Tokens.texto2),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Tokens.superficie,
      selectedColor: Tokens.marcaSuave,
      side: WidgetStateBorderSide.resolveWith(
        (estados) => BorderSide(
          color: estados.contains(WidgetState.selected)
              ? Tokens.marca.withValues(alpha: 0.55)
              : Tokens.borde,
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      // Ojo: el chip sólo resuelve por estado el *color* del texto. Un
      // `WidgetStateTextStyle` entero se pierde al mezclarse y la etiqueta
      // sale sin letra. Por eso el color va por estado y el peso de la
      // elegida, en `secondaryLabelStyle`, que es el que usa ChoiceChip.
      labelStyle: TextStyle(
        fontFamily: Tokens.tipografia,
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
        color: WidgetStateColor.resolveWith(
          (estados) => estados.contains(WidgetState.selected)
              ? Tokens.marcaOscura
              : Tokens.texto,
        ),
      ),
      secondaryLabelStyle: const TextStyle(
        fontFamily: Tokens.tipografia,
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: Tokens.marcaOscura,
      ),
      checkmarkColor: Tokens.marcaOscura,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (estados) =>
            estados.contains(WidgetState.selected) ? Colors.white : null,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (estados) =>
            estados.contains(WidgetState.selected) ? Tokens.marca : null,
      ),
    ),
    // Los avisos de abajo, en el grafito de la marca y no en gris: son la voz
    // de la app confirmando algo, que se note que es ella.
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Tokens.cromo,
      contentTextStyle: const TextStyle(
        fontFamily: Tokens.tipografia,
        fontSize: 14,
        color: Tokens.cromoTexto,
      ),
      actionTextColor: Tokens.marca,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: Tokens.cromo,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(
        fontFamily: Tokens.tipografia,
        fontSize: 12,
        color: Tokens.cromoTexto,
      ),
      waitDuration: const Duration(milliseconds: 400),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Tokens.superficie,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: const TextStyle(
        fontFamily: Tokens.tipografia,
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: Tokens.texto,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Tokens.superficie,
      surfaceTintColor: Colors.transparent,
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: Tokens.superficie,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: Tokens.cromo,
      headerForegroundColor: Tokens.cromoTexto,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      todayBorder: const BorderSide(color: Tokens.marca, width: 1.5),
      dayShape: const WidgetStatePropertyAll(CircleBorder()),
      rangeSelectionBackgroundColor: Tokens.marcaSuave,
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(Tokens.superficie),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(8),
        shadowColor: const WidgetStatePropertyAll(Color(0x662A1A0C)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Tokens.borde),
          ),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 6),
        ),
      ),
    ),
    menuButtonTheme: MenuButtonThemeData(
      style: MenuItemButton.styleFrom(
        foregroundColor: Tokens.texto,
        iconColor: Tokens.texto2,
        textStyle: const TextStyle(
          fontFamily: Tokens.tipografia,
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
        minimumSize: const Size(180, 42),
        padding: const EdgeInsets.symmetric(horizontal: 14),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Tokens.marca,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: const WidgetStatePropertyAll(6),
      radius: const Radius.circular(8),
      thumbColor: WidgetStatePropertyAll(Tokens.texto2.withValues(alpha: 0.28)),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: Tokens.marca,
      selectionColor: Tokens.marca.withValues(alpha: 0.22),
      selectionHandleColor: Tokens.marca,
    ),
  );
}

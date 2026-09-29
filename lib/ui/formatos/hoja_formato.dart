import 'package:flutter/material.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../dominio/enums.dart';
import '../../dominio/libro_oficial.dart';

/// El Formato 1.1 / 1.2 dibujado como el documento que es.
///
/// Esta pantalla es la única de la app donde aparecen las palabras DEUDOR y
/// ACREEDOR: en el resto se dice "Entró" y "Salió" (§1). Acá no se puede, y
/// tampoco hace falta —el que abre esta sección es el contador, o el dueño
/// llevándole algo al contador.
///
/// El ancho de las columnas es fijo con un reparto del sobrante: los formatos
/// oficiales tienen una forma reconocible y estirar "N° DE OPER." hasta 200px
/// en un monitor grande la desarma. El sobrante se lo llevan las dos columnas
/// de texto, que son las que de verdad lo necesitan.
class HojaFormato extends StatefulWidget {
  const HojaFormato({super.key, required this.libro, this.filtro});

  final LibroOficial libro;

  /// Si viene, sólo se muestran las operaciones que pasan el filtro, y en
  /// lugar del cuadre va la suma de lo mostrado: un formato filtrado no
  /// cuadra, y mostrar un cuadre con filas escondidas sería engañoso.
  final bool Function(FilaFormato fila)? filtro;

  @override
  State<HojaFormato> createState() => _HojaFormatoState();
}

class _HojaFormatoState extends State<HojaFormato> {
  /// Para dejar la barra de desplazamiento horizontal siempre a la vista;
  /// `Scrollbar` la exige cuando el pulgar es permanente.
  final _horizontal = ScrollController();

  LibroOficial get libro => widget.libro;

  bool get _esCaja => libro.cuenta == Cuenta.caja;

  @override
  void dispose() {
    _horizontal.dispose();
    super.dispose();
  }

  /// Las columnas del formato, agrupadas como en el original: "CUENTA CONTABLE
  /// ASOCIADA" abarca código y denominación, y "SALDOS Y MOVIMIENTOS" abarca
  /// las dos de importes.
  List<_Bloque> get _bloques => [
    const _Columna(
      'N° DE\nOPER.',
      60,
      alineacion: TextAlign.center,
      minimoPropio: 48,
    ),
    // La fecha no se encoge: bajo 104, "01/09/2026" se parte en dos.
    const _Columna('FECHA DE\nLA OPER.', 104, alineacion: TextAlign.center),
    if (!_esCaja)
      const _Columna(
        'MEDIO DE\nPAGO (T1)',
        76,
        alineacion: TextAlign.center,
        minimoPropio: 60,
      ),
    const _Columna(
      'DESCRIPCIÓN DE LA OPERACIÓN',
      180,
      elastica: 0.55,
      minimoPropio: 118,
    ),
    if (!_esCaja) ...[
      const _Columna(
        'APELLIDOS Y\nNOMBRES,\nRAZÓN SOCIAL',
        150,
        minimoPropio: 96,
      ),
      // 118/104: más angosta, "0092-448713" se parte en dos renglones.
      const _Columna(
        'N° DE\nTRANSACC.\nBANCARIA',
        118,
        alineacion: TextAlign.center,
        minimoPropio: 104,
      ),
    ],
    _Grupo('CUENTA CONTABLE ASOCIADA', const [
      _Columna('CÓDIGO', 68, alineacion: TextAlign.center, minimoPropio: 56),
      _Columna('DENOMINACIÓN', 150, elastica: 0.45, minimoPropio: 96),
    ]),
    // Los importes se encogen lo justo: tienen que seguir entrando en una
    // línea, porque un monto partido en dos renglones no se lee.
    const _Grupo('SALDOS Y MOVIMIENTOS', [
      _Columna(
        'DEUDOR (+)',
        112,
        alineacion: TextAlign.right,
        minimoPropio: 94,
      ),
      _Columna(
        'ACREEDOR (-)',
        112,
        alineacion: TextAlign.right,
        minimoPropio: 94,
      ),
    ]),
  ];

  /// Reparte el ancho entre las columnas.
  ///
  /// Tres casos, en orden: si sobra lugar lo toman las dos columnas de texto,
  /// que son las que lo aprovechan; si falta, todas ceden a la vez —cada una
  /// en proporción a lo que puede ceder— hasta su mínimo; y si ni con los
  /// mínimos entra, ahí recién la tabla se desplaza de lado.
  ///
  /// El caso del medio es el que importa: el Formato 1.2 tiene diez columnas y
  /// en una pantalla de 1280 no cabía. Encogerlo un poco se lee mucho mejor que
  /// tener que arrastrar la tabla para ver los importes.
  Map<_Columna, double> _repartir(List<_Columna> columnas, double disponible) {
    final preferido = columnas.fold<double>(0, (s, c) => s + c.ancho);

    if (disponible >= preferido) {
      final sobrante = (disponible - preferido).clamp(0.0, 600.0);
      return {for (final c in columnas) c: c.ancho + sobrante * c.elastica};
    }

    final piso = columnas.fold<double>(0, (s, c) => s + c.minimo);
    if (disponible <= piso) return {for (final c in columnas) c: c.minimo};

    // Cuánto hay que recortar, sobre cuánto se puede recortar en total.
    final parte = (preferido - disponible) / (preferido - piso);
    return {
      for (final c in columnas) c: c.ancho - (c.ancho - c.minimo) * parte,
    };
  }

  @override
  Widget build(BuildContext context) {
    final bloques = _bloques;
    final columnas = [for (final b in bloques) ...b.columnas];

    return LayoutBuilder(
      builder: (context, limites) {
        // El `LayoutBuilder` mide por fuera de la hoja, y la hoja tiene borde:
        // sin descontarlo, la tabla se arma dos píxeles más ancha que el hueco
        // donde va a entrar y desborda.
        final disponible = limites.maxWidth - _bordeHoja * 2;

        final anchos = _repartir(columnas, disponible);
        final total = anchos.values.fold<double>(0, (s, a) => s + a);

        final hoja = SizedBox(
          width: total,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CabeceraTabla(bloques: bloques, anchos: anchos),
              for (var i = 0; i < libro.filas.length; i++)
                // El saldo inicial no es una operación: con un filtro puesto
                // no va, porque no es algo que se busque.
                if (widget.filtro == null ||
                    (i > 0 && widget.filtro!(libro.filas[i])))
                  _Fila(
                    fila: libro.filas[i],
                    columnas: columnas,
                    anchos: anchos,
                    esSaldoInicial: i == 0,
                    esCaja: _esCaja,
                  ),
              _Cuadre(
                libro: libro,
                columnas: columnas,
                anchos: anchos,
                filtradas: widget.filtro == null
                    ? null
                    : [
                        for (final f in libro.filas.skip(1))
                          if (widget.filtro!(f)) f,
                      ],
              ),
            ],
          ),
        );

        return Container(
          decoration: BoxDecoration(
            color: Tokens.superficie,
            borderRadius: BorderRadius.circular(Tokens.radioGrande),
            border: Border.all(color: Tokens.borde, width: _bordeHoja),
            boxShadow: Tokens.sombraTarjeta,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _BarraTitulo(libro: libro),
              _DatosDelNegocio(libro: libro),
              if (total <= disponible)
                hoja
              else
                // La barra se deja siempre visible: en una pantalla angosta la
                // tabla se corta, y sin la barra no hay nada que diga que se
                // puede correr de lado para ver los importes.
                Scrollbar(
                  controller: _horizontal,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _horizontal,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(bottom: 10),
                    child: hoja,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Estructura de columnas
// ---------------------------------------------------------------------------

sealed class _Bloque {
  const _Bloque();

  /// Ancho preferido: el que tiene cuando la ventana da de sobra.
  double get ancho;

  /// Hasta dónde puede encogerse antes de que la tabla tenga que desplazarse.
  double get minimo;

  List<_Columna> get columnas;
}

class _Columna extends _Bloque {
  const _Columna(
    this.titulo,
    this.ancho, {
    this.alineacion = TextAlign.left,
    this.elastica = 0,
    this.minimoPropio,
  });

  final String titulo;
  @override
  final double ancho;
  final TextAlign alineacion;

  /// Qué parte del ancho sobrante se lleva, de 0 a 1. Sólo las columnas de
  /// texto crecen.
  final double elastica;

  /// Sin mínimo propio, la columna no se encoge: es el caso de la fecha, que
  /// abajo de su ancho parte "01/09/2026" en dos renglones.
  final double? minimoPropio;

  @override
  double get minimo => minimoPropio ?? ancho;

  @override
  List<_Columna> get columnas => [this];
}

/// Dos columnas bajo un título común, como las merges del formato oficial.
class _Grupo extends _Bloque {
  const _Grupo(this.titulo, this.columnas);

  final String titulo;
  @override
  final List<_Columna> columnas;

  @override
  double get ancho => columnas.fold(0, (s, c) => s + c.ancho);

  @override
  double get minimo => columnas.fold(0, (s, c) => s + c.minimo);
}

// ---------------------------------------------------------------------------
// Piezas del documento
// ---------------------------------------------------------------------------

/// El grosor del marco de la hoja. Se descuenta al repartir las columnas.
const _bordeHoja = 1.0;

const _bordeCelda = BorderSide(color: Tokens.borde);

/// Los importes en cifras tabulares: sin esto los números bailan de fila en
/// fila y una columna de montos deja de leerse en vertical.
const _cifras = TextStyle(
  fontSize: 12.5,
  color: Tokens.texto,
  fontFeatures: [FontFeature.tabularFigures()],
);

class _BarraTitulo extends StatelessWidget {
  const _BarraTitulo({required this.libro});

  final LibroOficial libro;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
      decoration: const BoxDecoration(gradient: Tokens.degradadoCromo),
      child: Row(
        children: [
          Expanded(
            child: Text(
              libro.titulo,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                height: 1.35,
                color: Tokens.cromoTexto,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // El código de la cuenta va en la esquina, como en la hoja del curso.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Text(
              libro.rotuloCuenta,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Tokens.cromoTexto,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// PERÍODO / RUC / RAZÓN SOCIAL, y para el 1.2 también el banco.
class _DatosDelNegocio extends StatelessWidget {
  const _DatosDelNegocio({required this.libro});

  final LibroOficial libro;

  @override
  Widget build(BuildContext context) {
    final n = libro.negocio;
    final periodo =
        '${Formato.mesSolo(libro.desde).toUpperCase()} - ${libro.desde.year}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: const BoxDecoration(
        color: Tokens.fondo,
        border: Border(bottom: _bordeCelda),
      ),
      child: Wrap(
        spacing: 32,
        runSpacing: 10,
        children: [
          _Dato('PERÍODO', periodo),
          _Dato(n.documento.length == 11 ? 'RUC' : 'DNI', n.documento),
          _Dato(
            'APELLIDOS Y NOMBRES, DENOMINACIÓN O RAZÓN SOCIAL',
            n.razonSocial,
          ),
          if (libro.cuenta == Cuenta.banco) ...[
            _Dato('ENTIDAD FINANCIERA', n.entidadFinanciera),
            _Dato('CÓDIGO DE LA CUENTA CORRIENTE', n.cuentaCorriente),
          ],
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.etiqueta, this.valor);

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          etiqueta,
          style: const TextStyle(
            fontSize: 9.5,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w700,
            color: Tokens.texto2,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          // Un dato en blanco se marca: es más útil ver el hueco que un vacío
          // que parece intencional.
          valor.trim().isEmpty ? '—' : valor,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: valor.trim().isEmpty ? Tokens.marcaOscura : Tokens.texto,
          ),
        ),
      ],
    );
  }
}

class _CabeceraTabla extends StatelessWidget {
  const _CabeceraTabla({required this.bloques, required this.anchos});

  final List<_Bloque> bloques;
  final Map<_Columna, double> anchos;

  // Tres renglones y no dos: cuando la tabla se encoge, "APELLIDOS Y NOMBRES,
  // RAZÓN SOCIAL" necesita partirse en tres o queda cortado con puntos
  // suspensivos, y un encabezado a medias no dice qué hay en la columna.
  static const _altura = 62.0;
  static const _alturaGrupo = 20.0;

  double _ancho(_Bloque b) =>
      b.columnas.fold<double>(0, (s, c) => s + anchos[c]!);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF1EEE9),
        border: Border(bottom: BorderSide(color: Tokens.bordeFuerte)),
      ),
      // Sin `stretch`: las celdas ya traen su altura, y estirar dentro de una
      // lista que no acota el alto pediria altura infinita.
      child: Row(
        children: [
          for (final bloque in bloques)
            SizedBox(
              width: _ancho(bloque),
              child: switch (bloque) {
                // Una columna suelta ocupa las dos alturas: su título se
                // centra en todo el alto de la cabecera.
                _Columna() => _CeldaCabecera(
                  titulo: bloque.titulo,
                  altura: _altura,
                  alineacion: TextAlign.center,
                ),
                _Grupo() => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CeldaCabecera(
                      titulo: bloque.titulo,
                      altura: _alturaGrupo,
                      alineacion: TextAlign.center,
                      conBordeAbajo: true,
                    ),
                    SizedBox(
                      height: _altura - _alturaGrupo,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final c in bloque.columnas)
                            SizedBox(
                              width: anchos[c]!,
                              child: _CeldaCabecera(
                                titulo: c.titulo,
                                altura: _altura - _alturaGrupo,
                                alineacion: TextAlign.center,
                                // La última del grupo no lleva línea a la
                                // derecha: la pone el bloque siguiente.
                                sinBordeDerecho: c == bloque.columnas.last,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              },
            ),
        ],
      ),
    );
  }
}

class _CeldaCabecera extends StatelessWidget {
  const _CeldaCabecera({
    required this.titulo,
    required this.altura,
    required this.alineacion,
    this.conBordeAbajo = false,
    this.sinBordeDerecho = false,
  });

  final String titulo;
  final double altura;
  final TextAlign alineacion;
  final bool conBordeAbajo;
  final bool sinBordeDerecho;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: altura,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        border: Border(
          right: sinBordeDerecho ? BorderSide.none : _bordeCelda,
          bottom: conBordeAbajo ? _bordeCelda : BorderSide.none,
        ),
      ),
      child: Text(
        titulo,
        textAlign: alineacion,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 9.5,
          height: 1.25,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w700,
          color: Tokens.texto2,
        ),
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({
    required this.fila,
    required this.columnas,
    required this.anchos,
    required this.esSaldoInicial,
    required this.esCaja,
  });

  final FilaFormato fila;
  final List<_Columna> columnas;
  final Map<_Columna, double> anchos;
  final bool esSaldoInicial;
  final bool esCaja;

  List<String> get _valores => [
    fila.numero?.toString() ?? '',
    fila.fecha == null ? '' : Formato.fecha(fila.fecha!),
    if (!esCaja) fila.medioTabla1 ?? '',
    fila.descripcion,
    if (!esCaja) ...[fila.contraparte ?? '', fila.numeroTransaccion ?? ''],
    fila.codigoCuenta ?? '',
    fila.denominacion ?? '',
    fila.deudor == 0 ? '' : Formato.monto(fila.deudor / 100),
    fila.acreedor == 0 ? '' : Formato.monto(fila.acreedor / 100),
  ];

  @override
  Widget build(BuildContext context) {
    final valores = _valores;
    // Las dos últimas son siempre los importes; se tiñen apenas para que la
    // vista siga la columna sin tener que leer el encabezado otra vez.
    final primerImporte = columnas.length - 2;

    return Container(
      decoration: BoxDecoration(
        color: esSaldoInicial ? const Color(0xFFFBFAF8) : Tokens.superficie,
        border: const Border(bottom: _bordeCelda),
      ),
      // `IntrinsicHeight` hace que todas las celdas midan lo que la mas alta:
      // sin eso, una descripcion de dos renglones deja las lineas divisorias
      // de las demas columnas cortadas por la mitad.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < columnas.length; i++)
              _Celda(
                texto: valores[i],
                ancho: anchos[columnas[i]]!,
                alineacion: columnas[i].alineacion,
                negrita: esSaldoInicial,
                fondo: switch (i) {
                  _ when i == primerImporte => Tokens.entro.withValues(
                    alpha: 0.05,
                  ),
                  _ when i == primerImporte + 1 => Tokens.salio.withValues(
                    alpha: 0.035,
                  ),
                  _ => null,
                },
                ultima: i == columnas.length - 1,
              ),
          ],
        ),
      ),
    );
  }
}

class _Celda extends StatelessWidget {
  const _Celda({
    required this.texto,
    required this.ancho,
    required this.alineacion,
    this.negrita = false,
    this.fondo,
    this.ultima = false,
  });

  final String texto;
  final double ancho;
  final TextAlign alineacion;
  final bool negrita;
  final Color? fondo;
  final bool ultima;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ancho,
      constraints: const BoxConstraints(minHeight: 38),
      alignment: switch (alineacion) {
        TextAlign.center => Alignment.center,
        TextAlign.right => Alignment.centerRight,
        _ => Alignment.centerLeft,
      },
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
      decoration: BoxDecoration(
        color: fondo,
        border: Border(right: ultima ? BorderSide.none : _bordeCelda),
      ),
      child: Text(
        texto,
        textAlign: alineacion,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: _cifras.copyWith(
          fontWeight: negrita ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}

/// SUBTOTAL, SALDO FINAL y TOTALES: el cierre del formato.
///
/// El saldo final va cruzado —si el deudor pesa más, la diferencia se abona—
/// y por eso las dos columnas terminan dando lo mismo. Eso es el cuadre, y es
/// la razón de ser de un libro de caja.
class _Cuadre extends StatelessWidget {
  const _Cuadre({
    required this.libro,
    required this.columnas,
    required this.anchos,
    this.filtradas,
  });

  final LibroOficial libro;

  /// Con un filtro puesto: sólo la suma de lo que se ve.
  final List<FilaFormato>? filtradas;
  final List<_Columna> columnas;
  final Map<_Columna, double> anchos;

  /// Ancho de todo lo que va antes de las dos columnas de importes; ahí se
  /// alinea la etiqueta, pegada a la derecha.
  double get _anchoEtiqueta => columnas
      .take(columnas.length - 2)
      .fold<double>(0, (s, c) => s + anchos[c]!);

  @override
  Widget build(BuildContext context) {
    final importes = columnas.sublist(columnas.length - 2);

    Widget linea({
      required String etiqueta,
      required int deudor,
      required int acreedor,
      required Color fondo,
      required Color texto,
      bool fuerte = false,
      Border? borde,
    }) {
      return Container(
        decoration: BoxDecoration(color: fondo, border: borde),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: _anchoEtiqueta,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.fromLTRB(9, 11, 14, 11),
                child: Text(
                  etiqueta,
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.7,
                    fontWeight: FontWeight.w700,
                    color: texto,
                  ),
                ),
              ),
              for (var i = 0; i < importes.length; i++)
                Container(
                  width: anchos[importes[i]]!,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: texto.withValues(alpha: 0.18)),
                    ),
                  ),
                  child: Text(
                    Formato.monto((i == 0 ? deudor : acreedor) / 100),
                    style: _cifras.copyWith(
                      color: texto,
                      fontWeight: fuerte ? FontWeight.w800 : FontWeight.w700,
                      fontSize: fuerte ? 13.5 : 12.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    final filtradas = this.filtradas;
    if (filtradas != null) {
      return linea(
        etiqueta: filtradas.length == 1
            ? 'SUMA DE LO MOSTRADO (1 OPERACIÓN)'
            : 'SUMA DE LO MOSTRADO (${filtradas.length} OPERACIONES)',
        deudor: filtradas.fold(0, (s, f) => s + f.deudor),
        acreedor: filtradas.fold(0, (s, f) => s + f.acreedor),
        fondo: Tokens.marcaSuave,
        texto: Tokens.texto,
        fuerte: true,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        linea(
          etiqueta: 'SUBTOTAL',
          deudor: libro.subtotalDeudor,
          acreedor: libro.subtotalAcreedor,
          fondo: Tokens.fondo,
          texto: Tokens.texto,
          borde: const Border(bottom: _bordeCelda),
        ),
        linea(
          etiqueta: 'SALDO FINAL',
          deudor: libro.saldoFinalDeudor,
          acreedor: libro.saldoFinalAcreedor,
          fondo: Tokens.fondo,
          texto: Tokens.texto2,
          borde: const Border(
            // Doble línea antes de los totales, como en un libro de papel.
            bottom: BorderSide(color: Tokens.bordeFuerte, width: 2),
          ),
        ),
        linea(
          etiqueta: 'TOTALES',
          deudor: libro.totalDeudor,
          acreedor: libro.totalAcreedor,
          fondo: Tokens.cromo,
          texto: Tokens.cromoTexto,
          fuerte: true,
        ),
      ],
    );
  }
}

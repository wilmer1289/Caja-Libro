import '../core/formato.dart';
import 'boleta.dart';
import 'efectivo.dart';
import 'enums.dart';
import 'jornada.dart';
import 'monto_en_letras.dart';
import 'movimiento.dart';
import 'negocio.dart';
import 'recibo.dart';

/// Los papeles del negocio —boleta, recibo, acta de cierre, resumen de
/// cajas— descritos una sola vez, pieza por pieza.
///
/// De esta descripción salen dos dibujos: el PDF que se imprime y la vista
/// en pantalla. Como los dos leen lo mismo, lo que se ve es lo que se
/// imprime, y un cambio en un documento se hace en un solo lugar.
///
/// Las medidas van en puntos de PDF (una hoja A4 mide 595 × 842): la vista
/// en pantalla dibuja la hoja a ese tamaño y después la escala.
class HojaDoc {
  const HojaDoc({
    required this.bloques,
    this.ancho = anchoA4,
    this.alto,
    this.margen = const MargenDoc(30, 30, 30, 26),
    this.pie,
  });

  static const anchoA4 = 595.0;
  static const altoA4 = 842.0;

  final List<BloqueDoc> bloques;
  final double ancho;

  /// Alto fijo. Sin él, la hoja mide lo que su contenido y el PDF sigue en
  /// otra página si hace falta.
  final double? alto;

  final MargenDoc margen;

  /// La línea del pie de cada página, en los documentos de varias páginas.
  final PieDoc? pie;

  /// Más ancha que alta: va en A4 apaisado.
  bool get apaisada => ancho > anchoA4;
}

class MargenDoc {
  const MargenDoc(this.izquierda, this.arriba, this.derecha, this.abajo);
  final double izquierda;
  final double arriba;
  final double derecha;
  final double abajo;
}

enum AlineacionDoc { izquierda, centro, derecha }

class ColumnaDoc {
  const ColumnaDoc(this.titulo)
    : ancho = null,
      alineacion = AlineacionDoc.izquierda;

  const ColumnaDoc.derecha(this.titulo, {this.ancho})
    : alineacion = AlineacionDoc.derecha;

  const ColumnaDoc.centro(this.titulo, {this.ancho})
    : alineacion = AlineacionDoc.centro;

  final String titulo;

  /// Sin ancho, la columna ocupa lo que sobre.
  final double? ancho;
  final AlineacionDoc alineacion;
}

/// Una pieza del documento.
sealed class BloqueDoc {
  const BloqueDoc();
}

/// El logo, el negocio al centro y el recuadro con el RUC, el tipo de
/// documento y el número.
class EncabezadoDoc extends BloqueDoc {
  const EncabezadoDoc({
    required this.razonSocial,
    required this.documento,
    required this.titulo,
    required this.numero,
    this.direccion = '',
    this.subtitulo,
    this.anchoRecuadro = 182,
  });

  final String razonSocial;
  final String documento;
  final String direccion;
  final String titulo;
  final String? subtitulo;
  final String numero;
  final double anchoRecuadro;

  String get nombre => razonSocial.trim().isEmpty
      ? 'TU NEGOCIO'
      : razonSocial.trim().toUpperCase();

  /// "R.U.C." con 11 dígitos, "D.N.I." con 8.
  String get tipoDocumento =>
      documento.trim().length == 8 ? 'D.N.I.' : 'R.U.C.';

  String get lineaDocumento =>
      '$tipoDocumento ${documento.trim().isEmpty ? '—' : documento.trim()}';

  /// Las iniciales del negocio para el logo: "Bodega Santa Rosa" → "BS".
  String get iniciales {
    final palabras = razonSocial
        .split(RegExp(r'\s+'))
        .where((p) => RegExp(r'^[A-Za-zÁÉÍÓÚÑáéíóúñ]').hasMatch(p))
        .toList();
    if (palabras.isEmpty) return 'MC';
    return palabras.take(2).map((p) => p[0].toUpperCase()).join();
  }
}

/// La caja redondeada con "Rótulo : valor", en una o dos columnas.
class DatosDoc extends BloqueDoc {
  const DatosDoc(this.filas, {this.columnas = 1, this.anchoRotulo = 70});

  final List<(String, String)> filas;
  final int columnas;
  final double anchoRotulo;

  /// Las filas de cada columna, de arriba abajo.
  List<List<(String, String)>> get porColumna {
    final n = (filas.length / columnas).ceil();
    return [
      for (var c = 0; c < columnas; c++) filas.skip(c * n).take(n).toList(),
    ];
  }
}

/// La fila de casilleros: título arriba y dato abajo.
class CeldasDoc extends BloqueDoc {
  const CeldasDoc(this.items, {this.alto = 32});

  final List<(String, String)> items;
  final double alto;
}

/// La tabla del detalle. Con [rellenar], ocupa todo el alto que sobre y sus
/// líneas verticales llegan hasta abajo, como en un talonario.
class TablaDoc extends BloqueDoc {
  const TablaDoc({
    required this.columnas,
    required this.filas,
    this.total,
    this.rellenar = false,
    this.vacio,
  });

  final List<ColumnaDoc> columnas;
  final List<List<String>> filas;
  final List<String>? total;
  final bool rellenar;

  /// Qué decir si no hay filas.
  final String? vacio;

  bool get muestraVacio => filas.isEmpty && vacio != null;
}

/// "SON: …" a la izquierda, los totales a la derecha; el último, el que
/// manda, más grande y con una línea encima.
class SonTotalesDoc extends BloqueDoc {
  const SonTotalesDoc({
    required this.son,
    required this.totales,
    this.detalle,
    this.anchoTotales = 200,
  });

  final String son;
  final String? detalle;
  final List<(String, String)> totales;
  final double anchoTotales;
}

/// Un título chico de sección.
class SeccionDoc extends BloqueDoc {
  const SeccionDoc(this.texto);
  final String texto;
}

class FirmasDoc extends BloqueDoc {
  const FirmasDoc(this.firmas, {this.margen = 26});

  /// Nombre y rol de cada firma.
  final List<(String, String)> firmas;
  final double margen;
}

class PieDoc extends BloqueDoc {
  const PieDoc(this.texto, {this.derecha = 'Mi Caja'});
  final String texto;
  final String derecha;
}

class EspacioDoc extends BloqueDoc {
  const EspacioDoc(this.alto);
  final double alto;
}

/// La línea punteada por donde se corta la hoja.
class CorteDoc extends BloqueDoc {
  const CorteDoc();
}

/// Varios bloques uno al lado del otro, con el mismo ancho.
class LadoALadoDoc extends BloqueDoc {
  const LadoALadoDoc(this.bloques, {this.separacion = 10});
  final List<BloqueDoc> bloques;
  final double separacion;
}

/// Una columna de bloques que se estira hasta llenar el alto que le toca.
/// Así el recibo ocupa justo media hoja.
class MitadDoc extends BloqueDoc {
  const MitadDoc(this.bloques);
  final List<BloqueDoc> bloques;
}

/// Arma cada documento con sus piezas.
class Documentos {
  static String _monto(int centavos) => Formato.monto(centavos / 100);

  static String _fechaHora(DateTime d) =>
      '${Formato.fecha(d)} · ${Formato.hora(d)}';

  // --- Boleta ---

  static HojaDoc boleta(Boleta boleta) {
    final m = boleta.movimiento;
    final n = boleta.negocio;
    final d = boleta.desglose;
    final total = _monto(boleta.total);

    return HojaDoc(
      alto: HojaDoc.altoA4,
      bloques: [
        EncabezadoDoc(
          razonSocial: n.razonSocial,
          documento: n.documento,
          direccion: n.direccion,
          titulo: 'BOLETA DE VENTA',
          subtitulo: 'DE CONTROL INTERNO',
          numero: m.numeroBoleta == null
              ? 'N° al guardar'
              : 'N° ${boleta.numeroImpreso}',
        ),
        const EspacioDoc(12),
        DatosDoc([
          ('Cliente', boleta.cliente),
          (boleta.tipoDocumento, boleta.documentoCliente),
        ]),
        const EspacioDoc(8),
        CeldasDoc([
          ('FECHA DE EMISIÓN', Formato.fecha(m.fecha)),
          ('HORA', Formato.hora(m.creadoEn)),
          ('MEDIO DE PAGO', m.medio.etiqueta),
          ('MONEDA', 'SOLES'),
          ('COND. DE PAGO', 'CONTADO'),
        ]),
        const EspacioDoc(8),
        TablaDoc(
          columnas: const [
            ColumnaDoc.centro('CANT.', ancho: 42),
            ColumnaDoc.centro('U.M.', ancho: 46),
            ColumnaDoc('DESCRIPCIÓN'),
            ColumnaDoc.derecha('P. UNIT.', ancho: 70),
            ColumnaDoc.derecha('IMPORTE', ancho: 76),
          ],
          filas: [
            ['1', 'UND', boleta.descripcion, total, total],
          ],
          rellenar: true,
        ),
        const EspacioDoc(8),
        SonTotalesDoc(
          son: boleta.montoEnLetras,
          detalle: m.detalleEfectivo == null ? null : boleta.medioDetallado,
          totales: [
            (
              d.igv > 0 ? 'OP. GRAVADA (S/)' : 'OP. INAFECTA (S/)',
              _monto(d.base),
            ),
            ('IGV ${Boleta.tasaIgvPorcentaje}% (S/)', _monto(d.igv)),
            ('IMPORTE TOTAL (S/)', total),
          ],
        ),
        const EspacioDoc(16),
        const PieDoc(
          'Boleta de venta de control interno del negocio. No es un '
          'comprobante de pago electrónico y no se informa a SUNAT.   '
          '¡Gracias por su compra!',
        ),
      ],
    );
  }

  // --- Recibo ---

  /// Márgenes y alto de media hoja: el recibo va dos veces en una A4.
  static const _margenRecibo = MargenDoc(30, 26, 30, 26);
  static const _corteRecibo = 14.0;
  static const altoMitadRecibo =
      (HojaDoc.altoA4 - 26 - 26 - _corteRecibo * 2) / 2;

  static List<BloqueDoc> _mitadRecibo(Recibo recibo, String ejemplar) {
    final m = recibo.movimiento;
    final n = recibo.negocio;
    final importe = _monto(m.centavos);

    return [
      EncabezadoDoc(
        razonSocial: n.razonSocial,
        documento: n.documento,
        direccion: n.direccion,
        titulo: recibo.esIngreso ? 'RECIBO DE INGRESO' : 'RECIBO DE EGRESO',
        subtitulo: 'DE CAJA · $ejemplar',
        numero: recibo.movimiento.numeroRecibo == null
            ? 'N° al guardar'
            : 'N° ${recibo.numero}',
      ),
      const EspacioDoc(9),
      DatosDoc([
        (recibo.esIngreso ? 'Recibí de' : 'Pagado a', m.contraparte ?? ''),
        ('DNI / RUC', m.documentoContraparte ?? ''),
      ]),
      const EspacioDoc(7),
      CeldasDoc([
        ('FECHA', Formato.fecha(m.fecha)),
        ('OPERACIÓN N°', m.numero == 0 ? 'Al guardar' : '${m.numero}'),
        ('MEDIO DE PAGO', m.medio.etiqueta),
        ('MONEDA', 'SOLES'),
      ], alto: 30),
      const EspacioDoc(7),
      TablaDoc(
        columnas: const [
          ColumnaDoc('POR CONCEPTO DE'),
          ColumnaDoc.centro('CUENTA', ancho: 60),
          ColumnaDoc.derecha('IMPORTE', ancho: 80),
        ],
        filas: [
          [recibo.concepto, m.cuentaDelFormato, importe],
        ],
        rellenar: true,
      ),
      const EspacioDoc(7),
      SonTotalesDoc(
        son: recibo.montoEnLetras,
        detalle: m.detalleEfectivo == null ? null : recibo.medioDetallado,
        totales: [('IMPORTE TOTAL (S/)', importe)],
        anchoTotales: 180,
      ),
      const EspacioDoc(30),
      FirmasDoc([
        (recibo.tesorero, 'Tesorería'),
        (m.contraparte ?? '', recibo.rolContraparte),
      ]),
    ];
  }

  /// La hoja A4 entera: original arriba, copia abajo.
  static HojaDoc recibo(Recibo recibo) => HojaDoc(
    alto: HojaDoc.altoA4,
    margen: _margenRecibo,
    bloques: [
      MitadDoc(_mitadRecibo(recibo, 'ORIGINAL')),
      const EspacioDoc(_corteRecibo),
      const CorteDoc(),
      const EspacioDoc(_corteRecibo),
      MitadDoc(_mitadRecibo(recibo, 'COPIA')),
    ],
  );

  /// Sólo el original, para mirarlo en pantalla: la copia es igual.
  static HojaDoc reciboOriginal(Recibo recibo) => HojaDoc(
    alto: altoMitadRecibo + 26 + 26,
    margen: _margenRecibo,
    bloques: [MitadDoc(_mitadRecibo(recibo, 'ORIGINAL'))],
  );

  // --- Acta de cierre de caja ---

  static HojaDoc actaCierre(
    Jornada caja,
    List<Movimiento> movimientos, {
    String direccion = '',
  }) {
    final legado = caja.inicio == InicioCaja.libro;
    final conteo = caja.conteoCierre ?? Conteo.vacio;

    List<List<String>> filasConteo(List<int> denominaciones) => [
      for (final d in denominaciones)
        [
          Denominacion.etiqueta(d),
          '${conteo.cantidadDe(d)}',
          _monto(conteo.cantidadDe(d) * d),
        ],
    ];

    int suma(List<int> denominaciones) =>
        denominaciones.fold(0, (s, d) => s + conteo.cantidadDe(d) * d);

    const columnasConteo = [
      ColumnaDoc('DENOMINACIÓN'),
      ColumnaDoc.centro('CANT.', ancho: 44),
      ColumnaDoc.derecha('SUBTOTAL', ancho: 70),
    ];

    return HojaDoc(
      pie: PieDoc(
        'Acta de cierre de la caja N° ${caja.numero}. Los movimientos en '
        'efectivo entran solos al registrarse y no se editan desde la caja.',
      ),
      bloques: [
        EncabezadoDoc(
          razonSocial: caja.negocio,
          documento: caja.documento,
          direccion: direccion,
          titulo: 'CIERRE DE CAJA',
          subtitulo: 'ACTA DE ARQUEO',
          numero: 'CAJA N° ${caja.numero}',
        ),
        const EspacioDoc(12),
        DatosDoc(
          [
            ('Responsable', caja.responsable),
            ('Abrió', _fechaHora(caja.abiertaEn)),
            ('Empezó', caja.descripcionInicio),
            ('Supervisor', caja.supervisor),
            (
              'Cerró',
              caja.cerradaEn == null ? 'Abierta' : _fechaHora(caja.cerradaEn!),
            ),
            ('Resultado', caja.estadoTexto),
          ],
          columnas: 2,
          anchoRotulo: 58,
        ),
        const EspacioDoc(8),
        CeldasDoc([
          (legado ? 'SEGÚN EL LIBRO' : 'EMPEZÓ CON', _monto(caja.apertura)),
          ('ENTRÓ', _monto(caja.entradas)),
          ('SALIÓ', _monto(caja.salidas)),
          ('DEBERÍA HABER', _monto(caja.esperado)),
          ('CONTADO', _monto(caja.contado)),
          ('DIFERENCIA', _monto(caja.diferencia)),
        ]),
        const EspacioDoc(14),
        SeccionDoc('MOVIMIENTOS EN EFECTIVO (${movimientos.length})'),
        TablaDoc(
          columnas: const [
            ColumnaDoc.centro('N°', ancho: 34),
            ColumnaDoc.centro('HORA', ancho: 40),
            ColumnaDoc('DESCRIPCIÓN'),
            ColumnaDoc.derecha('ENTRÓ', ancho: 72),
            ColumnaDoc.derecha('SALIÓ', ancho: 72),
          ],
          filas: [
            for (final m in movimientos)
              [
                '${m.numero}',
                Formato.hora(m.creadoEn),
                m.descripcionFormato,
                m.tipo == Tipo.entro ? _monto(m.centavos) : '',
                m.tipo == Tipo.salio ? _monto(m.centavos) : '',
              ],
          ],
          vacio: legado
              ? 'Este arqueo se hizo con la versión anterior de la app: '
                    'comparó lo contado con el saldo de todo el libro.'
              : 'No hubo movimientos en efectivo mientras la caja estuvo '
                    'abierta.',
          total: movimientos.isEmpty
              ? null
              : ['', '', 'TOTAL', _monto(caja.entradas), _monto(caja.salidas)],
        ),
        const EspacioDoc(14),
        const SeccionDoc('CONTEO DEL EFECTIVO'),
        LadoALadoDoc([
          TablaDoc(
            columnas: columnasConteo,
            filas: filasConteo(Denominacion.billetes),
            total: ['BILLETES', '', _monto(suma(Denominacion.billetes))],
          ),
          TablaDoc(
            columnas: columnasConteo,
            filas: filasConteo(Denominacion.monedas),
            total: ['MONEDAS', '', _monto(suma(Denominacion.monedas))],
          ),
        ]),
        const EspacioDoc(10),
        SonTotalesDoc(
          son: MontoEnLetras.soles(caja.contado),
          detalle: 'Con esto terminó la caja.',
          totales: [
            ('DEBERÍA HABER (S/)', _monto(caja.esperado)),
            ('DIFERENCIA (S/)', _monto(caja.diferencia)),
            ('TERMINÓ CON (S/)', _monto(caja.contado)),
          ],
        ),
        if (caja.observacion.trim().isNotEmpty) ...[
          const EspacioDoc(10),
          DatosDoc([('Observación', caja.observacion)]),
        ],
        const EspacioDoc(50),
        FirmasDoc([
          (caja.responsable, 'Responsable de caja'),
          (caja.supervisor, 'Supervisor'),
        ], margen: 40),
      ],
    );
  }

  // --- Resumen de cajas ---

  static String rangoDe(ResumenCajas r) {
    if (r.vacio) return '—';
    final a = Formato.fecha(r.cajas.last.abiertaEn);
    final b = Formato.fecha(r.cajas.first.cerradaEn ?? DateTime.now());
    return a == b ? a : '$a – $b';
  }

  static HojaDoc resumenCajas(ResumenCajas r, {required Negocio negocio}) {
    return HojaDoc(
      ancho: HojaDoc.altoA4,
      margen: const MargenDoc(28, 26, 28, 22),
      pie: PieDoc(
        'Resumen de cajas · ${r.periodo.etiqueta}. Entró y salió cuentan sólo '
        'el efectivo que pasó por cada caja.',
      ),
      bloques: [
        EncabezadoDoc(
          razonSocial: negocio.razonSocial,
          documento: negocio.documento,
          direccion: negocio.direccion,
          titulo: 'RESUMEN DE CAJAS',
          subtitulo: r.periodo.etiqueta.toUpperCase(),
          numero: rangoDe(r),
          anchoRecuadro: 210,
        ),
        const EspacioDoc(12),
        CeldasDoc([
          ('CAJAS', '${r.cajas.length}'),
          ('ENTRÓ EN EFECTIVO', _monto(r.entradas)),
          ('SALIÓ EN EFECTIVO', _monto(r.salidas)),
          ('QUEDÓ (ENTRÓ − SALIÓ)', _monto(r.neto)),
          ('FALTANTES', _monto(r.faltantes)),
          ('SOBRANTES', _monto(r.sobrantes)),
          ('SE GUARDÓ AL ABRIR', _monto(r.apartado)),
        ]),
        const EspacioDoc(14),
        TablaDoc(
          columnas: const [
            ColumnaDoc.centro('CAJA', ancho: 36),
            ColumnaDoc.centro('ABRIÓ', ancho: 98),
            ColumnaDoc.centro('CERRÓ', ancho: 98),
            ColumnaDoc('RESPONSABLE'),
            ColumnaDoc.derecha('EMPEZÓ CON', ancho: 64),
            ColumnaDoc.derecha('ENTRÓ', ancho: 64),
            ColumnaDoc.derecha('SALIÓ', ancho: 64),
            ColumnaDoc.derecha('DEBERÍA', ancho: 64),
            ColumnaDoc.derecha('CONTADO', ancho: 64),
            ColumnaDoc.derecha('DIFERENCIA', ancho: 60),
            ColumnaDoc.derecha('APARTE', ancho: 56),
          ],
          filas: [
            for (final c in r.cajas.reversed)
              [
                '${c.numero}',
                _fechaHora(c.abiertaEn),
                c.cerradaEn == null ? 'Abierta' : _fechaHora(c.cerradaEn!),
                c.responsable,
                _monto(c.apertura),
                _monto(c.entradas),
                _monto(c.salidas),
                _monto(c.esperado),
                c.abierta ? '—' : _monto(c.contado),
                c.abierta ? '—' : _monto(c.diferencia),
                c.apartado > 0 ? _monto(c.apartado) : '',
              ],
          ],
          vacio: 'No hay cajas en este período.',
          total: r.vacio
              ? null
              : [
                  '',
                  '',
                  '',
                  'TOTAL',
                  '',
                  _monto(r.entradas),
                  _monto(r.salidas),
                  '',
                  '',
                  _monto(r.diferencias),
                  _monto(r.apartado),
                ],
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../datos/export/exportador_pdf.dart';
import '../../datos/export/impresion.dart';
import '../../datos/local/evidencias.dart';
import '../../datos/local/selector_voucher.dart';
import '../../datos/ocr/lector_voucher.dart';
import '../../dominio/banco.dart';
import '../../dominio/boleta.dart';
import '../../dominio/categoria.dart';
import '../../dominio/efectivo.dart';
import '../../dominio/enums.dart';
import '../../dominio/igv.dart';
import '../../dominio/importe.dart';
import '../../dominio/lectura_voucher.dart';
import '../../dominio/movimiento.dart';
import '../../dominio/pcge.dart';
import '../../dominio/recibo.dart';
import '../../estado/estado_caja.dart';
import 'nueva_categoria.dart';
import 'paso_comprobante.dart';
import 'paso_datos.dart';
import 'paso_efectivo.dart';
import 'paso_mercaderia.dart';
import 'paso_voucher.dart';
import 'pie_registro.dart';
import 'registro_componentes.dart';

/// Formulario de registro. Se abre ya sabiendo si es entrada o salida: el
/// usuario toca "Entró" o "Salió", nunca un formulario neutro donde después
/// tiene que elegir el signo (§4.1).
///
/// En efectivo, el documento de la contraparte está plegado: una bodega anota
/// monto, categoría y listo. Por banco, todo lo que pide el Formato 1.2 —el
/// voucher, el N° de operación, quién pagó, su vínculo— va en un paso propio,
/// "Voucher", después de los datos.
class RegistroHoja extends StatefulWidget {
  const RegistroHoja({
    super.key,
    required this.tipo,
    this.enDialogo = false,
    this.onAbrirCaja,
  });

  final Tipo tipo;

  /// Lleva a abrir la caja. En efectivo no se registra sin una caja
  /// abierta, y el aviso ofrece ir directo a abrirla.
  final VoidCallback? onAbrirCaja;

  /// En escritorio el formulario va en una ventana centrada, no en una hoja
  /// que sube desde abajo: esa es la forma del celular, y en un monitor de
  /// 1920px ocupa todo el ancho para pedir cuatro datos.
  final bool enDialogo;

  /// Devuelve el movimiento guardado, con sus números, o null si se cerró sin
  /// guardar.
  static Future<Movimiento?> abrir(
    BuildContext context,
    Tipo tipo, {
    VoidCallback? onAbrirCaja,
  }) {
    final esEscritorio = MediaQuery.sizeOf(context).width >= 900;

    if (!esEscritorio) {
      return showModalBottomSheet<Movimiento>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Tokens.superficie,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        useSafeArea: true,
        builder: (_) => ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.94,
          ),
          child: RegistroHoja(tipo: tipo, onAbrirCaja: onAbrirCaja),
        ),
      );
    }

    return showGeneralDialog<Movimiento>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      barrierColor: Tokens.cromo.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, _, _) {
        // Ancha: en escritorio sobra pantalla, y a lo ancho el formulario
        // entra en dos columnas sin tener que desplazarse para guardar.
        final pantalla = MediaQuery.sizeOf(context);
        return Center(
          child: SizedBox(
            width: (pantalla.width - 64).clamp(320.0, 880.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: (pantalla.height - 48).clamp(360.0, 820.0),
              ),
              child: Material(
                color: Tokens.superficie,
                clipBehavior: Clip.antiAlias,
                elevation: 24,
                shadowColor: const Color(0x552A1A0C),
                borderRadius: BorderRadius.circular(24),
                child: RegistroHoja(
                  tipo: tipo,
                  enDialogo: true,
                  onAbrirCaja: onAbrirCaja,
                ),
              ),
            ),
          ),
        );
      },
      // Entra creciendo apenas: un diálogo que aparece de golpe se siente
      // duro, y uno que crece desde cero se siente lento.
      transitionBuilder: (context, animacion, _, hijo) {
        final curva = CurvedAnimation(
          parent: animacion,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeIn,
        );
        return FadeTransition(
          opacity: curva,
          child: ScaleTransition(
            scale: Tween(begin: 0.96, end: 1.0).animate(curva),
            child: hijo,
          ),
        );
      },
    );
  }

  @override
  State<RegistroHoja> createState() => _RegistroHojaState();
}

/// Los pasos del registro. Sólo aparecen los que hacen falta: en efectivo
/// siempre se anota con cuánto pagó y el vuelto, porque de eso vive el cierre
/// de caja; por banco, el voucher, porque de eso vive el Libro Bancos.
enum _Paso {
  datos('Datos'),
  mercaderia('Mercadería'),
  voucher('Voucher'),
  pago('Pago en efectivo'),
  comprobante('Comprobante');

  const _Paso(this.etiqueta);
  final String etiqueta;
}

class _RegistroHojaState extends State<RegistroHoja> {
  final _monto = TextEditingController();
  final _concepto = TextEditingController();
  final _costoMercaderia = TextEditingController();
  String? _mercaderiaId;
  bool _ventaEsServicio = false;

  bool get _compraMercaderia => _categoriaId == 'mercaderia';
  bool get _venta => _categoriaId == 'ventas';
  bool get _pideMercaderia => _compraMercaderia || _venta;

  String? get _errorMercaderia {
    if (!_intentoMercaderia || !_pideMercaderia || _mercaderiaId != null) {
      return null;
    }
    if (_venta && _ventaEsServicio) return null;
    return 'Elige o crea un tipo de mercadería';
  }

  String? get _errorCostoMercaderia {
    if (!_intentoMercaderia ||
        !_venta ||
        _ventaEsServicio ||
        _mercaderiaId == null) {
      return null;
    }
    final costo = Importe.leer(_costoMercaderia.text);
    return costo == null || costo <= 0
        ? 'Escribe un costo en soles mayor que cero'
        : null;
  }

  final _contraparte = TextEditingController();
  final _documento = TextEditingController();
  final _transaccion = TextEditingController();
  late final TextEditingController _tesorero;

  late DateTime _fecha;
  late MedioPago _medio;
  String? _categoriaId;

  bool _masDatos = false;

  /// La cuenta del plan contable elegida en "¿En qué exactamente?". Sólo la
  /// piden las categorías "Otros": las demás ya saben su cuenta.
  String? _cuentaElegida;

  /// Lo que salió mal al guardar. Va dentro de la ventana: un aviso abajo en
  /// la app quedaría tapado por ella.
  String? _errorGuardar;

  /// Los errores aparecen recién cuando el usuario ya intentó guardar. Validar
  /// en vivo no es gritarle apenas abre la pantalla.
  bool _intentoGuardar = false;

  /// El paso de mercadería valida por su cuenta: llegar a él no es haberlo
  /// intentado completar.
  bool _intentoMercaderia = false;
  bool _guardando = false;

  // --- Los pasos ---
  int _indicePaso = 0;

  /// Recibo interno para imprimir y firmar. Sirve también en una venta.
  late bool _conRecibo;

  /// Con qué billetes se pagó (en efectivo es un paso fijo).
  Conteo _entregado = Conteo.vacio;

  /// El vuelto que registró manualmente quien atiende. Null = aún no anotado.
  Conteo? _vueltoManual;
  bool _intentoPago = false;

  bool _tesoreroFijo = false;

  // --- El voucher (sólo por banco) ---
  ArchivoVoucher? _voucher;
  bool _leyendo = false;
  LecturaVoucher? _lectura;
  String? _errorLectura;
  String? _bancoTercero;
  Vinculo _vinculo = Vinculo.tercero;
  DocumentoPago _documentoPago = DocumentoPago.factura;
  Situacion _situacion = Situacion.cartera;
  bool _intentoVoucher = false;

  Categoria? get _categoria =>
      _categoriaId == null ? null : Categoria.porId(_categoriaId!);

  /// El IGV se determina automáticamente por la categoría.
  bool get _afectoIgv => _categoria?.afectoIgv ?? false;

  bool get _emiteBoleta =>
      _categoria != null && Boleta.corresponde(_categoria!);

  /// Desde S/ 700, la boleta lleva nombre y documento del cliente.
  bool get _exigeCliente => _emiteBoleta && Boleta.exigeCliente(_centavos ?? 0);

  bool get _enEfectivo => _medio == MedioPago.efectivo;
  bool get _enBanco => _medio.cuenta == Cuenta.banco;

  List<_Paso> get _pasos => [
    _Paso.datos,
    if (_pideMercaderia) _Paso.mercaderia,
    if (_enBanco) _Paso.voucher,
    if (_enEfectivo) _Paso.pago,
    if (_conRecibo) _Paso.comprobante,
  ];

  _Paso get _paso => _pasos[_indicePaso.clamp(0, _pasos.length - 1)];
  bool get _ultimoPaso => _indicePaso >= _pasos.length - 1;

  int get _vueltoEsperado => _entregado.total - (_centavos ?? 0);

  Conteo get _vuelto => _vueltoManual ?? Conteo.vacio;

  @override
  void initState() {
    super.initState();
    final estado = context.read<EstadoCaja>();
    _fecha = DateTime.now();
    _medio = estado.ultimoMedio;
    _categoriaId = widget.tipo == Tipo.entro
        ? estado.ultimaCategoriaIngreso
        : estado.ultimaCategoriaEgreso;
    _conRecibo = estado.reciboPorDefecto;
    _tesorero = TextEditingController(text: estado.negocio.tesorero)
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _costoMercaderia.dispose();
    _monto.dispose();
    _concepto.dispose();
    _contraparte.dispose();
    _documento.dispose();
    _transaccion.dispose();
    _tesorero.dispose();
    super.dispose();
  }

  /// Convierte lo escrito a centavos enteros. Acepta coma o punto porque en
  /// Perú se escriben las dos. Devuelve null si no es un monto válido.
  int? get _centavos {
    final valor = Importe.leer(_monto.text);
    return valor != null && valor > 0 ? valor : null;
  }

  String? get _errorMonto {
    if (!_intentoGuardar) return null;
    if (_monto.text.trim().isEmpty) return 'Escribe cuánto fue';
    if (_centavos == null) return 'Ese monto no se entiende. Ejemplo: 25.50';
    return null;
  }

  String? get _errorCategoria {
    if (!_intentoGuardar) return null;
    if (_categoriaId == null) return 'Elige en qué va';
    return null;
  }

  String? get _errorCuenta {
    if (!_intentoGuardar) return null;
    if ((_categoria?.pideCuenta ?? false) && _cuentaElegida == null) {
      return 'Elige la cuenta de la lista: es la que va al formato';
    }
    return null;
  }

  /// El cliente se pide donde está su campo: en efectivo en los datos, por
  /// banco en el voucher.
  bool get _intentoCliente => _enBanco ? _intentoVoucher : _intentoGuardar;

  String? get _errorNombre {
    if (!_intentoCliente || !_exigeCliente) return null;
    if (_contraparte.text.trim().isEmpty) {
      return 'Desde S/ 700 la boleta lleva el nombre del cliente';
    }
    return null;
  }

  String? get _errorDocumento {
    if (!_intentoCliente || !_exigeCliente) return null;
    final doc = _documento.text.trim();
    if (doc.isEmpty) return 'Desde S/ 700 la boleta lleva el DNI o RUC';
    if (doc.length != 8 && doc.length != 11) {
      return 'El DNI tiene 8 dígitos y el RUC 11';
    }
    return null;
  }

  String? get _errorPago {
    if (!_intentoPago || _paso != _Paso.pago) return null;
    final monto = _centavos ?? 0;
    if (_entregado.estaVacio) {
      return 'Registra los billetes y monedas entregados.';
    }
    if (_entregado.total < monto) {
      return 'Lo entregado (${Formato.soles(_entregado.total / 100)}) no '
          'alcanza para ${Formato.soles(monto / 100)}.';
    }
    if (_vuelto.total != _vueltoEsperado) {
      return 'El vuelto suma ${Formato.soles(_vuelto.total / 100)} y '
          'debería ser ${Formato.soles(_vueltoEsperado / 100)}.';
    }
    return null;
  }

  /// El Formato 1.2 tiene una columna para el N° de la transacción bancaria:
  /// sin él, la operación no se puede ubicar en el estado de cuenta.
  String? get _errorTransaccion {
    if (!_intentoVoucher || !_enBanco) return null;
    return _transaccion.text.trim().isEmpty
        ? 'Escribe el N° de operación que trae el voucher'
        : null;
  }

  /// Hasta S/ 700 el voucher es opcional; desde ahí, obligatorio. Es el mismo
  /// tope desde el que la boleta pide el DNI.
  String? get _errorVoucher {
    if (!_intentoVoucher || !_enBanco || _voucher != null) return null;
    return (_centavos ?? 0) >= Movimiento.umbralVoucherCentavos
        ? 'Desde S/ 700 adjunta el voucher: es la prueba de la operación.'
        : null;
  }

  /// El documento y la situación sólo cuentan donde se preguntan.
  DocumentoPago get _documentoFinal => (_categoria?.cancelaDocumento ?? false)
      ? _documentoPago
      : DocumentoPago.factura;

  Situacion get _situacionFinal =>
      (_categoria?.cancelaDocumento ?? false) && widget.tipo == Tipo.entro
      ? _situacion
      : Situacion.cartera;

  /// El vínculo se elige en el paso del voucher: en efectivo no se ve, así
  /// que no se aplica.
  Vinculo get _vinculoFinal => _enBanco ? _vinculo : Vinculo.tercero;

  /// La cuenta que irá al formato, para mostrarla mientras se elige.
  String get _cuentaDelFormato {
    final c = _categoria;
    if (c == null) return '';
    if (c.pideCuenta) return _cuentaElegida ?? c.cuentaAsociada;
    return ReglasCuenta.para(
      c,
      vinculo: _vinculoFinal,
      documento: _documentoFinal,
      situacion: _situacionFinal,
    );
  }

  /// Ley de Bancarización: desde S/ 2,000 no se registra en efectivo. Antes
  /// era sólo un aviso; ahora no deja guardar hasta cambiar el medio.
  bool get _bloqueaBancarizacion {
    final c = _centavos;
    return c != null &&
        c >= Movimiento.umbralBancarizacionCentavos &&
        _medio == MedioPago.efectivo;
  }

  /// El efectivo entra y sale de la caja del día: con la caja cerrada no
  /// hay dónde ponerlo, y no deja seguir hasta abrirla o cambiar el medio.
  bool get _bloqueaCajaCerrada =>
      _enEfectivo && context.read<EstadoCaja>().cajaAbierta == null;

  void _irAAbrirCaja() {
    Navigator.of(context).pop();
    widget.onAbrirCaja?.call();
  }

  Future<void> _elegirFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (mounted && elegida != null) setState(() => _fecha = elegida);
  }

  void _elegirCategoria(Categoria c) {
    setState(() {
      _categoriaId = c.id;
      _mercaderiaId = null;
      _costoMercaderia.clear();
      _ventaEsServicio = false;
      _intentoMercaderia = false;
      // La cuenta elegida es de "Otros": con otra categoría ya no aplica.
      if (!c.pideCuenta) _cuentaElegida = null;
      if (_exigeCliente) _masDatos = true;
    });
  }

  Future<void> _agregarCategoria() async {
    final nueva = await NuevaCategoriaDialogo.abrir(context, widget.tipo);
    if (nueva != null && mounted) _elegirCategoria(nueva);
  }

  /// Lo del primer paso está completo y se puede seguir.
  bool _datosValidos() {
    setState(() {
      _intentoGuardar = true;
      _errorGuardar = null;
      if (_exigeCliente) _masDatos = true;
    });
    return _centavos != null &&
        _categoriaId != null &&
        _errorCuenta == null &&
        _errorNombre == null &&
        _errorDocumento == null &&
        !_bloqueaBancarizacion &&
        !_bloqueaCajaCerrada;
  }

  /// El paso de mercadería está completo. El aviso de costo no bloquea: sólo
  /// se exige que el costo exista cuando hay un tipo elegido en una venta.
  bool _mercaderiaValida() {
    setState(() {
      _intentoMercaderia = true;
      _errorGuardar = null;
    });
    return _errorMercaderia == null && _errorCostoMercaderia == null;
  }

  bool _voucherValido() {
    setState(() {
      _intentoVoucher = true;
      _errorGuardar = null;
    });
    return _errorTransaccion == null &&
        _errorVoucher == null &&
        _errorNombre == null &&
        _errorDocumento == null;
  }

  /// Toma la foto o elige el archivo, lo adjunta y, si el equipo puede, lo
  /// lee para llenar lo que falte.
  Future<void> _adjuntar({required bool camara}) async {
    final selector = SelectorVoucher.instancia;
    ArchivoVoucher? archivo;
    try {
      archivo = camara
          ? await selector.tomarFoto()
          : await selector.elegirArchivo();
    } on FormatException catch (e) {
      if (mounted) setState(() => _errorLectura = e.message);
      return;
    } catch (e) {
      if (mounted) {
        setState(() => _errorLectura = 'No se pudo abrir el voucher: $e');
      }
      return;
    }
    if (archivo == null || !mounted) return;

    final puedeLeer = LectorVoucher.disponible;
    setState(() {
      _voucher = archivo;
      _lectura = null;
      _errorLectura = null;
      _leyendo = puedeLeer;
    });
    if (!puedeLeer) return;

    try {
      final lectura = await LectorVoucher.leer(archivo);
      if (!mounted) return;
      setState(() {
        _lectura = lectura;
        _aplicarLectura(lectura);
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorLectura =
              'El voucher quedó adjunto, pero no se pudo leer. Escribe los '
              'datos a mano.',
        );
      }
    } finally {
      if (mounted) setState(() => _leyendo = false);
    }
  }

  /// Llena sólo lo que está vacío: lo que el usuario ya escribió manda.
  void _aplicarLectura(LecturaVoucher? lectura) {
    if (lectura == null) return;
    if (_transaccion.text.trim().isEmpty && lectura.numeroOperacion != null) {
      _transaccion.text = lectura.numeroOperacion!;
    }
    if (_contraparte.text.trim().isEmpty && lectura.nombre != null) {
      _contraparte.text = lectura.nombre!;
    }
    // En un pago por transferencia el voucher es del banco del negocio, no
    // del otro: ahí el banco leído no dice nada del tercero.
    final banco = lectura.banco;
    if (_bancoTercero == null &&
        banco != null &&
        EntidadesBancarias.para(_medio).contains(banco) &&
        (_medio == MedioPago.yape || widget.tipo == Tipo.entro)) {
      _bancoTercero = banco;
    }
  }

  void _usarMontoLeido() {
    final centavos = _lectura?.centavos;
    if (centavos == null) return;
    setState(() => _monto.text = (centavos / 100).toStringAsFixed(2));
  }

  void _usarFechaLeida() {
    final fecha = _lectura?.fecha;
    if (fecha == null || fecha.isAfter(DateTime.now())) return;
    setState(() => _fecha = fecha);
  }

  void _continuar() {
    if (_paso == _Paso.datos && !_datosValidos()) return;
    if (_paso == _Paso.mercaderia && !_mercaderiaValida()) return;
    if (_paso == _Paso.voucher && !_voucherValido()) return;
    if (_paso == _Paso.pago) {
      setState(() => _intentoPago = true);
      if (_errorPago != null) return;
    }
    setState(() => _indicePaso++);
  }

  void _atras() => setState(() => _indicePaso--);

  /// El movimiento tal como quedaría, sin números todavía. Es lo que muestra
  /// la vista previa del recibo.
  Movimiento _provisional() {
    final centavos = _centavos ?? 0;
    final categoria = _categoria ?? Categoria.otrosEgresos;
    final cuenta = categoria.pideCuenta ? _cuentaElegida : null;
    final ahora = DateTime.now();
    return Movimiento(
      id: '',
      numero: 0,
      tipo: widget.tipo,
      centavos: centavos,
      categoriaId: categoria.id,
      concepto: _conceptoFinal(cuenta),
      medio: _medio,
      fecha: _fecha,
      creadoEn: ahora,
      actualizadoEn: ahora,
      cuentaAsociada: cuenta,
      igvCentavos: _afectoIgv ? Igv.desagregar(centavos).igv : 0,
      contraparte: _limpio(_contraparte),
      documentoContraparte: _limpio(_documento),
      tesorero: _tesorero.text.trim(),
      detalleEfectivo: _detalleFinal(),
      mercaderiaId: _pideMercaderia ? _mercaderiaId : null,
      mercaderiaNombre: _pideMercaderia
          ? context
                .read<EstadoCaja>()
                .mercaderias
                .where((m) => m.id == _mercaderiaId)
                .firstOrNull
                ?.nombre
          : null,
      costoCentavos: _venta
          ? (_ventaEsServicio ? 0 : Importe.leer(_costoMercaderia.text))
          : null,
      sync: EstadoSync.local,
    );
  }

  static String? _limpio(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  /// En "Otros" sin detalle, el nombre de la cuenta hace de detalle: en la
  /// lista se lee "Alquileres" en vez de un "Otros" que no dice nada.
  String _conceptoFinal(String? cuenta) {
    final detalle = _concepto.text.trim();
    return detalle.isEmpty && cuenta != null
        ? Pcge.instancia.denominacion(cuenta)
        : detalle;
  }

  DetalleEfectivo? _detalleFinal() => _enEfectivo
      ? DetalleEfectivo(entregado: _entregado, vuelto: _vuelto)
      : null;

  bool get _hayComprobanteParaImprimir => _conRecibo || _emiteBoleta;

  /// `imprimir` dice qué papeles mandar a la impresora después de guardar;
  /// null es guardar sin imprimir.
  Future<void> _guardar({QueImprimir? imprimir}) async {
    if (_guardando) return;
    if (!_datosValidos()) {
      // Si falla algo del primer paso estando en otro, se vuelve a él.
      if (_indicePaso != 0) setState(() => _indicePaso = 0);
      return;
    }
    if (!_mercaderiaValida()) {
      final paso = _pasos.indexOf(_Paso.mercaderia);
      if (paso >= 0 && _indicePaso != paso) {
        setState(() => _indicePaso = paso);
      }
      return;
    }
    if (_enBanco && !_voucherValido()) {
      setState(() => _indicePaso = _pasos.indexOf(_Paso.voucher));
      return;
    }
    if (_enEfectivo) {
      setState(() => _intentoPago = true);
      final monto = _centavos!;
      if (_entregado.estaVacio ||
          _entregado.total < monto ||
          _vuelto.total != _entregado.total - monto) {
        setState(() => _indicePaso = _pasos.indexOf(_Paso.pago));
        return;
      }
    }

    setState(() => _guardando = true);

    final estado = context.read<EstadoCaja>();
    final navegador = Navigator.of(context);
    final mensajero = ScaffoldMessenger.of(context);
    final categoria = _categoria!;
    final cuenta = categoria.pideCuenta ? _cuentaElegida : null;

    try {
      // El voucher se guarda primero: el movimiento lleva su nombre.
      final voucher = _enBanco ? _voucher : null;
      final rutaVoucher = voucher == null
          ? null
          : await AlmacenEvidencias.instancia.guardar(voucher);
      final nuevo = await estado.registrar(
        tipo: widget.tipo,
        centavos: _centavos!,
        categoriaId: categoria.id,
        concepto: _conceptoFinal(cuenta),
        cuentaAsociada: cuenta,
        medio: _medio,
        fecha: _fecha,
        contraparte: _limpio(_contraparte),
        documentoContraparte: _limpio(_documento),
        numeroTransaccion: _enBanco ? _limpio(_transaccion) : null,
        bancoTercero: _enBanco ? _bancoTercero : null,
        vinculo: _vinculoFinal,
        documentoPago: _documentoFinal,
        situacion: _situacionFinal,
        rutaFoto: rutaVoucher,
        conIgv: _afectoIgv,
        conRecibo: _conRecibo,
        tesorero: _tesorero.text,
        detalleEfectivo: _detalleFinal(),
        mercaderiaId: _pideMercaderia ? _mercaderiaId : null,
        costoCentavos: _venta
            ? (_ventaEsServicio ? 0 : Importe.leer(_costoMercaderia.text))
            : null,
      );
      if (_conRecibo && _tesoreroFijo) {
        await estado.usarTesorero(_tesorero.text);
      }

      // Recién ahora, con los números asignados, se imprime si se pulsó
      // explícitamente el ícono de impresora.
      String? avisoImpresion;
      if (imprimir != null && _hayComprobanteParaImprimir) {
        final negocio = estado.negocio;
        final imprimeRecibo = imprimir != QueImprimir.boleta;
        final imprimeBoleta = imprimir != QueImprimir.recibo;
        try {
          if (_conRecibo && imprimeRecibo) {
            final recibo = Recibo(negocio: negocio, movimiento: nuevo);
            await Impresion.imprimir(
              await ExportadorPdf.recibo(recibo),
              ExportadorPdf.nombreRecibo(recibo),
            );
          }
          if (_emiteBoleta && imprimeBoleta && nuevo.numeroBoleta != null) {
            final boleta = Boleta(negocio: negocio, movimiento: nuevo);
            await Impresion.imprimir(
              await ExportadorPdf.boleta(boleta),
              ExportadorPdf.nombreBoleta(boleta),
            );
          }
        } catch (e) {
          avisoImpresion = 'Quedó guardado, pero no se pudo imprimir: $e';
        }
      }

      if (!mounted) return;
      navegador.pop(nuevo);
      if (avisoImpresion != null) {
        mensajero.showSnackBar(SnackBar(content: Text(avisoImpresion)));
      }
    } on ArgumentError catch (e) {
      if (mounted) setState(() => _errorGuardar = '${e.message}');
    } catch (e) {
      if (mounted) setState(() => _errorGuardar = 'No se pudo guardar. $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entro = widget.tipo == Tipo.entro;
    final color = entro ? Tokens.entro : Tokens.salio;
    final centavos = _centavos;

    final pasoDatos = PasoDatos(
      tipo: widget.tipo,
      enDialogo: widget.enDialogo,
      monto: _monto,
      centavos: centavos,
      errorMonto: _errorMonto,
      categoria: _categoria,
      categoriaId: _categoriaId,
      errorCategoria: _errorCategoria,
      cuentaElegida: _cuentaElegida,
      errorCuenta: _errorCuenta,
      medio: _medio,
      fecha: _fecha,
      concepto: _concepto,
      contraparte: _contraparte,
      documento: _documento,
      transaccion: _transaccion,
      exigeCliente: _exigeCliente,
      errorNombre: _errorNombre,
      errorDocumento: _errorDocumento,
      masDatos: _masDatos,
      conRecibo: _conRecibo,
      enEfectivo: _enEfectivo,
      emiteBoleta: _emiteBoleta,
      bloqueaBancarizacion: _bloqueaBancarizacion,
      bloqueaCajaCerrada: _bloqueaCajaCerrada,
      onMontoChanged: (_) => setState(() {
        if (_exigeCliente) _masDatos = true;
      }),
      onMontoSubmitted: (_) => _ultimoPaso ? _guardar() : _continuar(),
      onContraparteChanged: (_) => setState(() {}),
      onDocumentoChanged: (_) => setState(() {}),
      onElegirCategoria: _elegirCategoria,
      onAgregarCategoria: widget.tipo == Tipo.salio ? _agregarCategoria : null,
      onElegirCuenta: (cuenta) => setState(() => _cuentaElegida = cuenta),
      onElegirMedio: (medio) => setState(() => _medio = medio),
      onElegirFecha: _elegirFecha,
      onCambiarMasDatos: (abierto) => setState(() => _masDatos = abierto),
      onCambiarRecibo: (valor) => setState(() {
        _conRecibo = valor;
        _indicePaso = 0;
      }),
    );

    final pasoMercaderia = PasoMercaderia(
      venta: _venta,
      seleccionada: _mercaderiaId,
      esServicio: _ventaEsServicio,
      costo: _costoMercaderia,
      fecha: _fecha,
      errorTipo: _errorMercaderia,
      errorCosto: _errorCostoMercaderia,
      onSeleccionar: (id) => setState(() {
        _mercaderiaId = id;
        if (id != null) {
          _ventaEsServicio = false;
        } else {
          _costoMercaderia.clear();
        }
      }),
      onServicio: (esServicio) => setState(() {
        _ventaEsServicio = esServicio;
        _mercaderiaId = null;
        _costoMercaderia.clear();
      }),
      onCosto: () => setState(() {}),
    );

    final pasoPago = PasoEfectivo(
      tipo: widget.tipo,
      monto: centavos ?? 0,
      entregado: _entregado,
      vuelto: _vuelto,
      onEntregado: (conteo) => setState(() {
        _entregado = conteo;
        _vueltoManual = null;
      }),
      onVuelto: (conteo) => setState(() => _vueltoManual = conteo),
      error: _errorPago,
    );

    final estado = context.watch<EstadoCaja>();
    final pasoVoucher = PasoVoucher(
      tipo: widget.tipo,
      medio: _medio,
      categoria: _categoria,
      centavos: centavos ?? 0,
      fecha: _fecha,
      enDialogo: widget.enDialogo,
      cuenta: _cuentaDelFormato,
      bancoNegocio: estado.negocio.entidadFinanciera,
      transaccion: _transaccion,
      contraparte: _contraparte,
      documento: _documento,
      bancoTercero: _bancoTercero,
      vinculo: _vinculo,
      documentoPago: _documentoPago,
      situacion: _situacion,
      archivo: _voucher,
      leyendo: _leyendo,
      lectura: _lectura,
      errorLectura: _errorLectura,
      errorTransaccion: _errorTransaccion,
      errorVoucher: _errorVoucher,
      errorNombre: _errorNombre,
      errorDocumento: _errorDocumento,
      exigeCliente: _exigeCliente,
      duplicado: _enBanco
          ? estado.conNumeroDeOperacion(_transaccion.text)
          : null,
      onTomarFoto: () => _adjuntar(camara: true),
      onElegirArchivo: () => _adjuntar(camara: false),
      onQuitarArchivo: () => setState(() {
        _voucher = null;
        _lectura = null;
        _errorLectura = null;
      }),
      onBanco: (banco) => setState(() => _bancoTercero = banco),
      onVinculo: (vinculo) => setState(() => _vinculo = vinculo),
      onDocumentoPago: (documento) =>
          setState(() => _documentoPago = documento),
      onSituacion: (situacion) => setState(() => _situacion = situacion),
      onUsarMonto: _usarMontoLeido,
      onUsarFecha: _usarFechaLeida,
      onCambio: (_) => setState(() {}),
    );

    final pasoComprobante = PasoComprobante(
      movimiento: _provisional(),
      negocio: context.watch<EstadoCaja>().negocio,
      conBoleta: _emiteBoleta,
      tesorero: _tesorero,
      tesoreroFijo: _tesoreroFijo,
      onTesoreroFijo: (valor) => setState(() => _tesoreroFijo = valor),
    );

    final cuerpo = switch (_paso) {
      _Paso.datos => pasoDatos,
      _Paso.mercaderia => pasoMercaderia,
      _Paso.voucher => pasoVoucher,
      _Paso.pago => pasoPago,
      _Paso.comprobante => pasoComprobante,
    };

    final cabecera = CabeceraRegistro(
      entro: entro,
      color: color,
      enDialogo: widget.enDialogo,
      onCerrar: () => Navigator.of(context).pop(),
    );

    if (widget.enDialogo) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          cabecera,
          if (_pasos.length > 1)
            IndicadorPasos(
              pasos: [for (final paso in _pasos) paso.etiqueta],
              actual: _indicePaso,
              color: color,
            ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 22, 28, 22),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: KeyedSubtree(key: ValueKey(_paso), child: cuerpo),
              ),
            ),
          ),
          _pie(color),
        ],
      );
    }

    final contenido = Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Tokens.bordeFuerte,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          cabecera,
          if (_pasos.length > 1) ...[
            const SizedBox(height: 10),
            IndicadorPasos(
              pasos: [for (final paso in _pasos) paso.etiqueta],
              actual: _indicePaso,
              color: color,
              compacto: true,
            ),
          ],
          const SizedBox(height: 18),
          cuerpo,
          if (_errorGuardar != null) ...[
            const SizedBox(height: 14),
            AvisoRegistro(_errorGuardar!, bloquea: true),
          ],
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: SingleChildScrollView(child: contenido)),
          _pie(color, compacto: true),
        ],
      ),
    );
  }

  /// Pie de acciones consistente en celular y escritorio.
  /// En el último paso permite guardar o guardar e imprimir.
  Widget _pie(Color color, {bool compacto = false}) {
    return PieRegistro(
      color: color,
      ultimoPaso: _ultimoPaso,
      hayBoleta: _emiteBoleta,
      hayRecibo: _conRecibo,
      guardando: _guardando,
      bloqueaBancarizacion: _bloqueaBancarizacion,
      bloqueaCajaCerrada: _bloqueaCajaCerrada,
      errorGuardar: _errorGuardar,
      compacto: compacto,
      onAtras: _indicePaso == 0 ? () => Navigator.of(context).pop() : _atras,
      onContinuar: _continuar,
      onGuardar: () => _guardar(),
      onGuardarEImprimir: (que) => _guardar(imprimir: que),
      onAbrirCaja: widget.onAbrirCaja == null ? null : _irAAbrirCaja,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../datos/export/exportador_pdf.dart';
import '../../datos/export/impresion.dart';
import '../../dominio/boleta.dart';
import '../../dominio/categoria.dart';
import '../../dominio/efectivo.dart';
import '../../dominio/enums.dart';
import '../../dominio/igv.dart';
import '../../dominio/importe.dart';
import '../../dominio/movimiento.dart';
import '../../dominio/pcge.dart';
import '../../dominio/recibo.dart';
import '../../estado/estado_caja.dart';
import 'campo_cuenta.dart';
import 'nueva_categoria.dart';
import 'paso_comprobante.dart';
import 'paso_efectivo.dart';

/// Formulario de registro. Se abre ya sabiendo si es entrada o salida: el
/// usuario toca "Entró" o "Salió", nunca un formulario neutro donde después
/// tiene que elegir el signo (§4.1).
///
/// Los datos que pide el Formato 1.1 —documento de la contraparte, N° de la
/// transacción bancaria— están, pero plegados. Una bodega anota monto,
/// categoría y listo; una empresa formal abre "Datos para el comprobante" y
/// completa el resto. Si todo eso estuviera siempre a la vista, el formulario
/// de todos los días tendría nueve campos en lugar de cuatro.
class RegistroHoja extends StatefulWidget {
  const RegistroHoja({super.key, required this.tipo, this.enDialogo = false});

  final Tipo tipo;

  /// En escritorio el formulario va en una ventana centrada, no en una hoja
  /// que sube desde abajo: esa es la forma del celular, y en un monitor de
  /// 1920px ocupa todo el ancho para pedir cuatro datos.
  final bool enDialogo;

  /// Devuelve el movimiento guardado, con sus números, o null si se cerró sin
  /// guardar.
  static Future<Movimiento?> abrir(BuildContext context, Tipo tipo) {
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
          child: RegistroHoja(tipo: tipo),
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
                child: RegistroHoja(tipo: tipo, enDialogo: true),
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

/// Los pasos del registro. Sólo aparecen los que hacen falta: un cobro por
/// Yape sin recibo se guarda en uno; en efectivo siempre se anota con cuánto
/// pagó y el vuelto, porque de eso vive el cierre de caja.
enum _Paso {
  datos('Datos'),
  pago('Pago en efectivo'),
  comprobante('Comprobante');

  const _Paso(this.etiqueta);
  final String etiqueta;
}

class _RegistroHojaState extends State<RegistroHoja> {
  final _monto = TextEditingController();
  final _concepto = TextEditingController();
  final _contraparte = TextEditingController();
  final _documento = TextEditingController();
  final _transaccion = TextEditingController();
  late final TextEditingController _tesorero;

  late DateTime _fecha;
  late MedioPago _medio;
  String? _categoriaId;

  /// El usuario puede desmarcar el IGV en un caso puntual: no toda compra de
  /// mercadería viene con factura.
  bool? _conIgv;

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
  bool _guardando = false;

  // --- Los pasos ---
  int _indicePaso = 0;

  /// Recibo interno para imprimir y firmar. Sirve también en una venta.
  late bool _conRecibo;

  /// Con qué billetes se pagó (en efectivo es un paso fijo).
  Conteo _entregado = Conteo.vacio;

  /// El vuelto que cambió a mano quien atiende. Null = el sugerido.
  Conteo? _vueltoManual;
  bool _intentoPago = false;

  bool _tesoreroFijo = false;
  bool _imprimirRecibo = true;
  bool _imprimirBoleta = false;

  Categoria? get _categoria =>
      _categoriaId == null ? null : Categoria.porId(_categoriaId!);

  /// Si la operación lleva IGV: lo que diga la categoría, salvo que el usuario
  /// lo haya cambiado a mano.
  bool get _afectoIgv => _conIgv ?? (_categoria?.afectoIgv ?? false);

  bool get _emiteBoleta =>
      _categoria != null && Boleta.corresponde(_categoria!);

  /// Desde S/ 700, la boleta lleva nombre y documento del cliente.
  bool get _exigeCliente => _emiteBoleta && Boleta.exigeCliente(_centavos ?? 0);

  bool get _enEfectivo => _medio == MedioPago.efectivo;

  List<_Paso> get _pasos => [
    _Paso.datos,
    if (_enEfectivo) _Paso.pago,
    if (_conRecibo) _Paso.comprobante,
  ];

  _Paso get _paso => _pasos[_indicePaso.clamp(0, _pasos.length - 1)];
  bool get _ultimoPaso => _indicePaso >= _pasos.length - 1;

  int get _vueltoEsperado => _entregado.total - (_centavos ?? 0);

  Conteo get _vuelto =>
      _vueltoManual ??
      Conteo.sugerir(_vueltoEsperado < 0 ? 0 : _vueltoEsperado);

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

  String? get _errorNombre {
    if (!_intentoGuardar || !_exigeCliente) return null;
    if (_contraparte.text.trim().isEmpty) {
      return 'Desde S/ 700 la boleta lleva el nombre del cliente';
    }
    return null;
  }

  String? get _errorDocumento {
    if (!_intentoGuardar || !_exigeCliente) return null;
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
      return 'Marca con qué billetes o monedas se pagó. Si fue justo, toca '
          '"Exacto".';
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

  /// Ley de Bancarización: desde S/ 2,000 no se registra en efectivo. Antes
  /// era sólo un aviso; ahora no deja guardar hasta cambiar el medio.
  bool get _bloqueaBancarizacion {
    final c = _centavos;
    return c != null &&
        c >= Movimiento.umbralBancarizacionCentavos &&
        _medio == MedioPago.efectivo;
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
      // La cuenta elegida es de "Otros": con otra categoría ya no aplica.
      if (!c.pideCuenta) _cuentaElegida = null;
      // Al cambiar de categoría vuelve a mandar lo que ella dice del IGV: si
      // el usuario lo desmarcó para una compra sin factura, no tiene por qué
      // arrastrarse a la siguiente.
      _conIgv = null;
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
        !_bloqueaBancarizacion;
  }

  void _continuar() {
    if (_paso == _Paso.datos && !_datosValidos()) return;
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

  bool get _vaAImprimir =>
      (_conRecibo && _imprimirRecibo) || (_emiteBoleta && _imprimirBoleta);

  Future<void> _guardar() async {
    if (_guardando) return;
    if (!_datosValidos()) {
      // Si falla algo del primer paso estando en otro, se vuelve a él.
      if (_indicePaso != 0) setState(() => _indicePaso = 0);
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
        numeroTransaccion: _medio.cuenta == Cuenta.banco
            ? _limpio(_transaccion)
            : null,
        conIgv: _afectoIgv,
        conRecibo: _conRecibo,
        tesorero: _tesorero.text,
        detalleEfectivo: _detalleFinal(),
      );
      if (_conRecibo && _tesoreroFijo) {
        await estado.usarTesorero(_tesorero.text);
      }

      // Recién ahora, con los números asignados, se imprime.
      String? avisoImpresion;
      if (_vaAImprimir) {
        final negocio = estado.negocio;
        try {
          if (_conRecibo && _imprimirRecibo) {
            final recibo = Recibo(negocio: negocio, movimiento: nuevo);
            await Impresion.imprimir(
              await ExportadorPdf.recibo(recibo),
              ExportadorPdf.nombreRecibo(recibo),
            );
          }
          if (_emiteBoleta && _imprimirBoleta && nuevo.numeroBoleta != null) {
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

    // --- Las piezas del primer paso. Se arman una vez y se acomodan después
    // en una columna (celular, ventana angosta) o en dos (escritorio). ---

    final monto = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Etiqueta('¿Cuánto fue?'),
        TextField(
          controller: _monto,
          autofocus: true,
          // Enter sigue: guarda si no hay más pasos, o pasa al siguiente.
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _ultimoPaso ? _guardar() : _continuar(),
          // Teclado numérico con decimales (§5, entradas optimizadas).
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: color,
          ),
          decoration: InputDecoration(
            prefixText: 'S/ ',
            prefixStyle: TextStyle(
              fontFamily: Tokens.tipografia,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color.withValues(alpha: 0.7),
            ),
            hintText: '0.00',
            errorText: _errorMonto,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Tokens.radio),
              borderSide: BorderSide(color: color, width: 1.8),
            ),
          ),
          onChanged: (_) => setState(() {
            if (_exigeCliente) _masDatos = true;
          }),
        ),

        // El desglose del IGV va pegado al monto, no en otra sección: es una
        // lectura del mismo número, no un dato aparte que haya que llenar.
        if (_categoria?.afectoIgv ?? false) ...[
          const SizedBox(height: 10),
          _Igv(
            activo: _afectoIgv,
            centavos: centavos,
            onCambiar: (v) => setState(() => _conIgv = v),
          ),
        ],

        if (_bloqueaBancarizacion) ...[
          const SizedBox(height: 10),
          const _Aviso(
            'Desde S/ 2,000 no se puede en efectivo (Ley de Bancarización). '
            'Elige Yape / Plin, transferencia, depósito o tarjeta para poder '
            'guardar.',
            bloquea: true,
          ),
        ],
      ],
    );

    final categorias = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Etiqueta('¿En qué?'),
        _Categorias(
          tipo: widget.tipo,
          elegida: _categoriaId,
          onElegir: _elegirCategoria,
          // El "+" es para lo que se paga seguido y no está en la lista.
          onAgregar: widget.tipo == Tipo.salio ? _agregarCategoria : null,
        ),
        if (_errorCategoria != null) ...[
          const SizedBox(height: 6),
          Text(
            _errorCategoria!,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
        // "Otros" abre el plan contable: se escribe y se elige la cuenta.
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: (_categoria?.pideCuenta ?? false)
              ? Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _Etiqueta('¿En qué exactamente?'),
                      CampoCuentaPcge(
                        tipo: widget.tipo,
                        elegida: _cuentaElegida,
                        error: _errorCuenta,
                        onElegir: (c) => setState(() => _cuentaElegida = c),
                      ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );

    final medios = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Etiqueta('¿Cómo se pagó?'),
        _Medios(elegido: _medio, onElegir: (m) => setState(() => _medio = m)),
      ],
    );

    final cuando = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Etiqueta('¿Cuándo?'),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _elegirFecha,
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Text(Formato.fechaRelativa(_fecha)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 50),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ),
      ],
    );

    final detalle = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Etiqueta('Detalle (opcional)'),
        TextField(
          controller: _concepto,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Ej. Venta del día, pago de luz…',
          ),
        ),
      ],
    );

    final contraparte = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _Etiqueta(
          _exigeCliente
              ? 'Cliente (obligatorio desde S/ 700)'
              : entro
              ? 'Cliente (opcional)'
              : 'Proveedor (opcional)',
        ),
        TextField(
          controller: _contraparte,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'Nombre',
            errorText: _errorNombre,
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );

    final masDatos = _MasDatos(
      abierto: _masDatos,
      onCambiar: (v) => setState(() => _masDatos = v),
      children: [
        _Etiqueta(_exigeCliente ? 'DNI o RUC (obligatorio)' : 'DNI o RUC'),
        TextField(
          controller: _documento,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
            LengthLimitingTextInputFormatter(11),
          ],
          decoration: InputDecoration(
            hintText: 'Va impreso en el recibo y la boleta',
            errorText: _errorDocumento,
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (_medio.cuenta == Cuenta.banco) ...[
          const SizedBox(height: 14),
          const _Etiqueta('N° de transacción bancaria'),
          TextField(
            controller: _transaccion,
            decoration: const InputDecoration(
              hintText: 'El código del voucher o la operación',
            ),
          ),
        ],
      ],
    );

    // Lo que el negocio entrega: recibo, detalle del efectivo, boleta.
    final comprobantes = _Comprobantes(
      tipo: widget.tipo,
      conRecibo: _conRecibo,
      onRecibo: (v) => setState(() {
        _conRecibo = v;
        _indicePaso = 0;
      }),
      enEfectivo: _enEfectivo,
      emiteBoleta: _emiteBoleta,
      exigeCliente: _exigeCliente,
    );

    final cabecera = _Cabecera(
      entro: entro,
      color: color,
      enDialogo: widget.enDialogo,
      onCerrar: () => Navigator.of(context).pop(),
    );

    Widget pasoPago() => PasoEfectivo(
      tipo: widget.tipo,
      monto: centavos ?? 0,
      cajaAbierta: context.watch<EstadoCaja>().cajaAbierta != null,
      entregado: _entregado,
      vuelto: _vuelto,
      onEntregado: (c) => setState(() {
        _entregado = c;
        _vueltoManual = null;
      }),
      onVuelto: (c) => setState(() => _vueltoManual = c),
      onSugerirVuelto: () => setState(() => _vueltoManual = null),
      error: _errorPago,
    );

    Widget pasoComprobante() => PasoComprobante(
      movimiento: _provisional(),
      negocio: context.watch<EstadoCaja>().negocio,
      conBoleta: _emiteBoleta,
      tesorero: _tesorero,
      tesoreroFijo: _tesoreroFijo,
      onTesoreroFijo: (v) => setState(() => _tesoreroFijo = v),
    );

    // --- En el diálogo de escritorio: dos columnas. A la izquierda lo que
    // se llena siempre (cuánto, en qué, cómo); a la derecha lo que se llena
    // a veces (cuándo, detalle, cliente, comprobantes). ---
    if (widget.enDialogo) {
      return LayoutBuilder(
        builder: (context, medidas) {
          final dosColumnas = medidas.maxWidth >= 720;

          final datos = dosColumnas
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 11,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          monto,
                          const SizedBox(height: 22),
                          categorias,
                          const SizedBox(height: 22),
                          medios,
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 28),
                      height: 360,
                      color: Tokens.borde,
                    ),
                    Expanded(
                      flex: 9,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          cuando,
                          const SizedBox(height: 18),
                          detalle,
                          const SizedBox(height: 18),
                          contraparte,
                          const SizedBox(height: 6),
                          masDatos,
                          const SizedBox(height: 14),
                          comprobantes,
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    monto,
                    const SizedBox(height: 18),
                    categorias,
                    const SizedBox(height: 18),
                    medios,
                    const SizedBox(height: 18),
                    cuando,
                    const SizedBox(height: 18),
                    detalle,
                    const SizedBox(height: 14),
                    contraparte,
                    const SizedBox(height: 6),
                    masDatos,
                    const SizedBox(height: 14),
                    comprobantes,
                  ],
                );

          final cuerpo = switch (_paso) {
            _Paso.datos => datos,
            _Paso.pago => pasoPago(),
            _Paso.comprobante => pasoComprobante(),
          };

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              cabecera,
              if (_pasos.length > 1)
                _IndicadorPasos(
                  pasos: [for (final p in _pasos) p.etiqueta],
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
              // El pie queda fijo: por largo que sea el formulario, el
              // botón de guardar siempre está a la vista.
              _pie(color, entro),
            ],
          );
        },
      );
    }

    // --- En el celular: una columna, en una hoja que sube desde abajo. ---
    final cuerpoMovil = switch (_paso) {
      _Paso.datos => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          monto,
          const SizedBox(height: 18),
          categorias,
          const SizedBox(height: 18),
          medios,
          const SizedBox(height: 18),
          cuando,
          const SizedBox(height: 18),
          detalle,
          const SizedBox(height: 14),
          contraparte,
          const SizedBox(height: 6),
          masDatos,
          const SizedBox(height: 14),
          comprobantes,
        ],
      ),
      _Paso.pago => pasoPago(),
      _Paso.comprobante => pasoComprobante(),
    };

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
            _IndicadorPasos(
              pasos: [for (final p in _pasos) p.etiqueta],
              actual: _indicePaso,
              color: color,
              compacto: true,
            ),
          ],
          const SizedBox(height: 18),
          cuerpoMovil,
          if (_errorGuardar != null) ...[
            const SizedBox(height: 14),
            _Aviso(_errorGuardar!, bloquea: true),
          ],
        ],
      ),
    );

    return Padding(
      // Sube con el teclado para que el botón de guardar nunca quede tapado.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: SingleChildScrollView(child: contenido)),
          _pie(color, entro, compacto: true),
        ],
      ),
    );
  }

  /// El pie: volver o cancelar a la izquierda; seguir, o elegir qué imprimir
  /// y guardar, a la derecha.
  Widget _pie(Color color, bool entro, {bool compacto = false}) {
    final hayError = _errorGuardar != null || _bloqueaBancarizacion;

    final siguiente = _ultimoPaso
        ? FilledButton.icon(
            onPressed: _guardando || _bloqueaBancarizacion ? null : _guardar,
            style: FilledButton.styleFrom(
              backgroundColor: color,
              minimumSize: const Size(0, 52),
              padding: const EdgeInsets.symmetric(horizontal: 24),
            ),
            icon: _guardando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    _vaAImprimir ? Icons.print_rounded : Icons.check_rounded,
                    size: 20,
                  ),
            label: Text(
              _vaAImprimir
                  ? 'Guardar e imprimir'
                  : entro
                  ? 'Guardar entrada'
                  : 'Guardar salida',
            ),
          )
        : FilledButton.icon(
            onPressed: _bloqueaBancarizacion ? null : _continuar,
            style: FilledButton.styleFrom(
              backgroundColor: color,
              minimumSize: const Size(0, 52),
              padding: const EdgeInsets.symmetric(horizontal: 24),
            ),
            icon: const Icon(Icons.arrow_forward_rounded, size: 20),
            label: const Text('Continuar'),
          );

    final atras = OutlinedButton(
      onPressed: _indicePaso == 0 ? () => Navigator.of(context).pop() : _atras,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20),
      ),
      child: Text(_indicePaso == 0 ? 'Cancelar' : 'Atrás'),
    );

    // Qué imprimir al guardar: sólo en el último paso, y sólo lo que aplica.
    final imprimir = _ultimoPaso && (_conRecibo || _emiteBoleta)
        ? Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Padding(
                padding: EdgeInsets.only(right: 2),
                child: Icon(
                  Icons.print_outlined,
                  size: 17,
                  color: Tokens.texto2,
                ),
              ),
              if (_conRecibo)
                FilterChip(
                  label: const Text('Recibo'),
                  selected: _imprimirRecibo,
                  onSelected: (v) => setState(() => _imprimirRecibo = v),
                ),
              if (_emiteBoleta)
                FilterChip(
                  label: const Text('Boleta'),
                  selected: _imprimirBoleta,
                  onSelected: (v) => setState(() => _imprimirBoleta = v),
                ),
            ],
          )
        : null;

    final mensaje = hayError
        ? Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 17,
                color: Tokens.salio,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  _errorGuardar ?? 'Cambia el medio de pago para guardar',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Tokens.salio,
                  ),
                ),
              ),
            ],
          )
        : imprimir ?? const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.fromLTRB(
        compacto ? 16 : 28,
        12,
        compacto ? 16 : 28,
        compacto ? 16 : 18,
      ),
      decoration: const BoxDecoration(
        color: Tokens.fondo,
        border: Border(top: BorderSide(color: Tokens.borde)),
      ),
      child: compacto
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hayError || imprimir != null) ...[
                  mensaje,
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    atras,
                    const SizedBox(width: 10),
                    Expanded(child: siguiente),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: mensaje),
                const SizedBox(width: 12),
                atras,
                const SizedBox(width: 10),
                siguiente,
              ],
            ),
    );
  }
}

/// Los pasos arriba del formulario: dónde se está y cuántos faltan.
class _IndicadorPasos extends StatelessWidget {
  const _IndicadorPasos({
    required this.pasos,
    required this.actual,
    required this.color,
    this.compacto = false,
  });

  final List<String> pasos;
  final int actual;
  final Color color;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: compacto
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(28, 12, 28, 12),
      decoration: compacto
          ? null
          : const BoxDecoration(
              border: Border(bottom: BorderSide(color: Tokens.borde)),
            ),
      child: Row(
        children: [
          for (var i = 0; i < pasos.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  color: i <= actual ? color : Tokens.borde,
                ),
              ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i <= actual ? color : Tokens.superficie,
                border: Border.all(color: i <= actual ? color : Tokens.borde),
              ),
              child: i < actual
                  ? const Icon(
                      Icons.check_rounded,
                      size: 15,
                      color: Colors.white,
                    )
                  : Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: i <= actual ? Colors.white : Tokens.texto2,
                      ),
                    ),
            ),
            if (!compacto || i == actual) ...[
              const SizedBox(width: 8),
              Text(
                pasos[i],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: i == actual ? FontWeight.w700 : FontWeight.w500,
                  color: i == actual ? Tokens.texto : Tokens.texto2,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Los comprobantes del movimiento, al pie de la columna derecha: el recibo
/// para firmar, el aviso del paso del efectivo y la boleta, que se genera
/// sola.
class _Comprobantes extends StatelessWidget {
  const _Comprobantes({
    required this.tipo,
    required this.conRecibo,
    required this.onRecibo,
    required this.enEfectivo,
    required this.emiteBoleta,
    required this.exigeCliente,
  });

  final Tipo tipo;
  final bool conRecibo;
  final ValueChanged<bool> onRecibo;
  final bool enEfectivo;
  final bool emiteBoleta;
  final bool exigeCliente;

  @override
  Widget build(BuildContext context) {
    final entro = tipo == Tipo.entro;

    Widget interruptor({
      required IconData icono,
      required String titulo,
      required String bajada,
      required bool valor,
      required ValueChanged<bool> onCambiar,
    }) => Material(
      color: valor ? Tokens.marcaSuave : Tokens.superficie,
      borderRadius: BorderRadius.circular(Tokens.radio),
      child: InkWell(
        borderRadius: BorderRadius.circular(Tokens.radio),
        onTap: () => onCambiar(!valor),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Tokens.radio),
            border: Border.all(
              color: valor
                  ? Tokens.marca.withValues(alpha: 0.45)
                  : Tokens.borde,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icono,
                size: 19,
                color: valor ? Tokens.marca : Tokens.texto2,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Tokens.texto,
                      ),
                    ),
                    Text(
                      bajada,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Tokens.texto2,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: valor,
                onChanged: onCambiar,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ),
      ),
    );

    Widget nota(IconData icono, String texto) => Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Tokens.fondo,
        borderRadius: BorderRadius.circular(Tokens.radio),
        border: Border.all(color: Tokens.borde),
      ),
      child: Row(
        children: [
          Icon(icono, size: 19, color: Tokens.texto2),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(fontSize: 12, color: Tokens.texto2),
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Etiqueta('Comprobantes'),
        interruptor(
          icono: Icons.receipt_long_rounded,
          titulo: 'Recibo interno',
          bajada: 'Se imprime para que lo firmen',
          valor: conRecibo,
          onCambiar: onRecibo,
        ),
        if (enEfectivo) ...[
          const SizedBox(height: 8),
          nota(
            Icons.payments_outlined,
            entro
                ? 'Efectivo: en el paso siguiente anotas con cuánto pagó y '
                      'el vuelto.'
                : 'Efectivo: en el paso siguiente anotas con qué billetes '
                      'pagaste y si te dieron vuelto.',
          ),
        ],
        if (emiteBoleta) ...[
          const SizedBox(height: 8),
          nota(
            Icons.shopping_bag_outlined,
            exigeCliente
                ? 'Boleta de venta: se genera sola. Desde S/ 700 lleva nombre '
                      'y DNI o RUC del cliente.'
                : 'Boleta de venta: se genera sola al guardar.',
          ),
        ],
      ],
    );
  }
}

/// La cabeza del formulario: de qué se trata, en el color de lo que se anota.
///
/// En el diálogo es una franja teñida que ocupa todo el ancho, con una frase
/// que dice qué cabe acá; en el celular, una fila simple bajo la manija.
class _Cabecera extends StatelessWidget {
  const _Cabecera({
    required this.entro,
    required this.color,
    required this.enDialogo,
    required this.onCerrar,
  });

  final bool entro;
  final Color color;
  final bool enDialogo;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    final icono = Container(
      width: enDialogo ? 46 : 38,
      height: enDialogo ? 46 : 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: enDialogo ? color : color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(enDialogo ? 14 : 11),
      ),
      child: Icon(
        entro ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
        color: enDialogo ? Colors.white : color,
        size: enDialogo ? 24 : 20,
      ),
    );

    final titulo = Text(
      entro ? 'Entró plata' : 'Salió plata',
      style: TextStyle(
        fontSize: enDialogo ? 21 : 19,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: Tokens.texto,
      ),
    );

    if (!enDialogo) {
      return Row(
        children: [
          icono,
          const SizedBox(width: 12),
          Expanded(child: titulo),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(28, 22, 18, 20),
      decoration: BoxDecoration(
        color: entro ? Tokens.entroSuave : Tokens.salioSuave,
        border: Border(
          bottom: BorderSide(color: color.withValues(alpha: 0.18)),
        ),
      ),
      child: Row(
        children: [
          icono,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                titulo,
                const SizedBox(height: 2),
                Text(
                  entro
                      ? 'Una venta, un cobro o cualquier plata que llegó'
                      : 'Una compra, un pago o cualquier plata que se fue',
                  style: const TextStyle(fontSize: 13, color: Tokens.texto2),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cerrar',
            icon: const Icon(Icons.close_rounded, size: 22),
            onPressed: onCerrar,
          ),
        ],
      ),
    );
  }
}

/// Las categorías como fichas.
///
/// En una entrada son cuatro y nada más: Ventas, Cobros de fiado, Adelanto de
/// cliente y Otros —que abre el plan contable—. En una salida van las de todos
/// los días, las que agregó el usuario, el menú "Otra" con el resto agrupado,
/// y el "+" para agregar una nueva.
class _Categorias extends StatelessWidget {
  const _Categorias({
    required this.tipo,
    required this.elegida,
    required this.onElegir,
    this.onAgregar,
  });

  final Tipo tipo;
  final String? elegida;
  final ValueChanged<Categoria> onElegir;

  /// El "+". Null donde no se ofrece.
  final VoidCallback? onAgregar;

  @override
  Widget build(BuildContext context) {
    // Se lee del estado para redibujar cuando se agrega una categoría.
    context.watch<EstadoCaja>();

    final visibles = [
      ...Categoria.comunesDe(tipo),
      ...Categoria.propiasDe(tipo),
    ];
    final resto = Categoria.restoDe(tipo);

    // Si la elegida no está a la vista, se agrega a las fichas para que se
    // vea seleccionada en vez de quedar escondida dentro del menú.
    final extra = elegida != null && !visibles.any((c) => c.id == elegida)
        ? Categoria.porId(elegida!)
        : null;

    final grupos = <GrupoCategoria, List<Categoria>>{};
    for (final c in resto) {
      grupos.putIfAbsent(c.grupo, () => []).add(c);
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in [...visibles, ?extra])
          ChoiceChip(
            label: Text(c.etiqueta),
            selected: elegida == c.id,
            onSelected: (_) => onElegir(c),
          ),
        if (grupos.isNotEmpty)
          MenuAnchor(
            alignmentOffset: const Offset(0, 6),
            menuChildren: [
              for (final grupo in grupos.keys)
                SubmenuButton(
                  menuChildren: [
                    for (final c in grupos[grupo]!)
                      MenuItemButton(
                        onPressed: () => onElegir(c),
                        child: Text(c.etiqueta),
                      ),
                  ],
                  child: Text(grupo.etiqueta),
                ),
            ],
            builder: (context, menu, _) => ActionChip(
              avatar: const Icon(Icons.more_horiz_rounded, size: 18),
              label: const Text('Otra'),
              onPressed: () => menu.isOpen ? menu.close() : menu.open(),
            ),
          ),
        if (onAgregar != null)
          Tooltip(
            message: 'Agregar una categoría nueva',
            child: ActionChip(
              label: const Icon(
                Icons.add_rounded,
                size: 18,
                color: Tokens.marca,
              ),
              labelPadding: const EdgeInsets.symmetric(horizontal: 2),
              side: BorderSide(
                color: Tokens.marca.withValues(alpha: 0.55),
                style: BorderStyle.solid,
              ),
              backgroundColor: Tokens.marcaSuave,
              onPressed: onAgregar,
            ),
          ),
      ],
    );
  }
}

/// Los medios de pago, todos a la vista: son seis y cubren todo lo que usa
/// un negocio. Antes había un menú "Otro" con tarjeta de crédito, cheque y
/// "otro medio"; escondía justo uno que sí se usa.
class _Medios extends StatelessWidget {
  const _Medios({required this.elegido, required this.onElegir});

  final MedioPago elegido;
  final ValueChanged<MedioPago> onElegir;

  @override
  Widget build(BuildContext context) {
    // Un medio que ya no se ofrece (cheque, "otro") sólo aparece si es el que
    // viene recordado, para que no quede elegido algo invisible.
    final extra = MedioPago.disponibles.contains(elegido) ? null : elegido;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final m in [...MedioPago.disponibles, ?extra])
          ChoiceChip(
            label: Text(m.etiqueta),
            selected: elegido == m,
            onSelected: (_) => onElegir(m),
          ),
      ],
    );
  }
}

/// El desglose del IGV bajo el monto.
///
/// Muestra lo que ya está adentro del número escrito, no pide nada nuevo: el
/// total es lo que de verdad se movió y el impuesto se lee hacia adentro. El
/// interruptor existe porque no toda compra viene con factura.
class _Igv extends StatelessWidget {
  const _Igv({
    required this.activo,
    required this.centavos,
    required this.onCambiar,
  });

  final bool activo;
  final int? centavos;
  final ValueChanged<bool> onCambiar;

  @override
  Widget build(BuildContext context) {
    final total = centavos;
    final desglose = (activo && total != null) ? Igv.desagregar(total) : null;

    // El Material va afuera y el borde adentro: así la onda del toque se pinta
    // sobre el fondo en vez de quedar tapada por él.
    return Material(
      color: activo ? Tokens.entroSuave : Tokens.fondo,
      borderRadius: BorderRadius.circular(Tokens.radio),
      child: InkWell(
        onTap: () => onCambiar(!activo),
        borderRadius: BorderRadius.circular(Tokens.radio),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Tokens.radio),
            border: Border.all(
              color: activo
                  ? Tokens.entro.withValues(alpha: 0.25)
                  : Tokens.borde,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      activo ? 'El monto incluye IGV' : 'Sin IGV',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Tokens.texto,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      desglose == null
                          ? 'Se anota el total, sin separar impuesto'
                          : 'Valor de venta '
                                '${Formato.soles(desglose.base / 100)}'
                                '  ·  IGV ${Formato.soles(desglose.igv / 100)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Tokens.texto2,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: activo,
                onChanged: onCambiar,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La sección plegada con los datos que piden los formatos oficiales.
class _MasDatos extends StatelessWidget {
  const _MasDatos({
    required this.abierto,
    required this.onCambiar,
    required this.children,
  });

  final bool abierto;
  final ValueChanged<bool> onCambiar;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          onPressed: () => onCambiar(!abierto),
          style: TextButton.styleFrom(
            foregroundColor: Tokens.texto2,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 40),
            textStyle: const TextStyle(
              fontFamily: Tokens.tipografia,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          icon: AnimatedRotation(
            turns: abierto ? 0.5 : 0,
            duration: const Duration(milliseconds: 180),
            child: const Icon(Icons.expand_more_rounded, size: 18),
          ),
          label: const Text('Datos para el comprobante'),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: abierto
              ? Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: children,
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        texto,
        style: const TextStyle(fontSize: 13, color: Tokens.texto2),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso(this.texto, {this.bloquea = false});

  final String texto;

  /// En rojo: no es un consejo, es lo que impide guardar.
  final bool bloquea;

  @override
  Widget build(BuildContext context) {
    final fondo = bloquea ? Tokens.salioSuave : const Color(0xFFFFF6E5);
    final borde = bloquea
        ? Tokens.salio.withValues(alpha: 0.35)
        : const Color(0xFFF0DCB4);
    final color = bloquea ? Tokens.salio : const Color(0xFF6B520F);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(Tokens.radio),
        border: Border.all(color: borde),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            bloquea ? Icons.block_rounded : Icons.info_outline,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: bloquea ? FontWeight.w600 : FontWeight.w400,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

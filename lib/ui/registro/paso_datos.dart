import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../dominio/categoria.dart';
import '../../dominio/enums.dart';
import 'campo_cuenta.dart';
import 'registro_componentes.dart';

/// Primer paso del registro: monto, categoría, medio de pago y datos del
/// movimiento. No guarda estado propio; recibe los datos y notifica cambios
/// al coordinador del registro.
class PasoDatos extends StatelessWidget {
  const PasoDatos({
    super.key,
    required this.tipo,
    required this.enDialogo,
    required this.monto,
    required this.centavos,
    required this.errorMonto,
    required this.categoria,
    required this.categoriaId,
    required this.errorCategoria,
    required this.cuentaElegida,
    required this.errorCuenta,
    required this.medio,
    required this.fecha,
    required this.concepto,
    required this.contraparte,
    required this.documento,
    required this.transaccion,
    required this.exigeCliente,
    required this.errorNombre,
    required this.errorDocumento,
    required this.masDatos,
    required this.conRecibo,
    required this.enEfectivo,
    required this.emiteBoleta,
    required this.bloqueaBancarizacion,
    required this.bloqueaCajaCerrada,
    required this.onMontoChanged,
    required this.onMontoSubmitted,
    required this.onContraparteChanged,
    required this.onDocumentoChanged,
    required this.onElegirCategoria,
    required this.onAgregarCategoria,
    required this.onElegirCuenta,
    required this.onElegirMedio,
    required this.onElegirFecha,
    required this.onCambiarMasDatos,
    required this.onCambiarRecibo,
  });

  final Tipo tipo;
  final bool enDialogo;
  final TextEditingController monto;
  final int? centavos;
  final String? errorMonto;
  final Categoria? categoria;
  final String? categoriaId;
  final String? errorCategoria;
  final String? cuentaElegida;
  final String? errorCuenta;
  final MedioPago medio;
  final DateTime fecha;
  final TextEditingController concepto;
  final TextEditingController contraparte;
  final TextEditingController documento;
  final TextEditingController transaccion;
  final bool exigeCliente;
  final String? errorNombre;
  final String? errorDocumento;
  final bool masDatos;
  final bool conRecibo;
  final bool enEfectivo;
  final bool emiteBoleta;
  final bool bloqueaBancarizacion;
  final bool bloqueaCajaCerrada;
  final ValueChanged<String> onMontoChanged;
  final ValueChanged<String> onMontoSubmitted;
  final ValueChanged<String> onContraparteChanged;
  final ValueChanged<String> onDocumentoChanged;
  final ValueChanged<Categoria> onElegirCategoria;
  final VoidCallback? onAgregarCategoria;
  final ValueChanged<String?> onElegirCuenta;
  final ValueChanged<MedioPago> onElegirMedio;
  final VoidCallback onElegirFecha;
  final ValueChanged<bool> onCambiarMasDatos;
  final ValueChanged<bool> onCambiarRecibo;

  @override
  Widget build(BuildContext context) {
    final entro = tipo == Tipo.entro;
    final color = entro ? Tokens.entro : Tokens.salio;

    final montoWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const EtiquetaRegistro('¿Cuánto fue?'),
        TextField(
          controller: monto,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: onMontoSubmitted,
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
            errorText: errorMonto,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Tokens.radio),
              borderSide: BorderSide(color: color, width: 1.8),
            ),
          ),
          onChanged: onMontoChanged,
        ),
        if ((categoria?.afectoIgv ?? false) && centavos != null) ...[
          const SizedBox(height: 10),
          LineaIgv(centavos: centavos!),
        ],
        if (bloqueaBancarizacion) ...[
          const SizedBox(height: 10),
          const AvisoRegistro(
            'Desde S/ 2,000 no se puede en efectivo (Ley de Bancarización). '
            'Elige Yape / Plin, transferencia, depósito o tarjeta para poder '
            'guardar.',
            bloquea: true,
          ),
        ],
      ],
    );

    final categoriasWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const EtiquetaRegistro('¿En qué?'),
        CategoriasRegistro(
          tipo: tipo,
          elegida: categoriaId,
          onElegir: onElegirCategoria,
          onAgregar: onAgregarCategoria,
        ),
        if (errorCategoria != null) ...[
          const SizedBox(height: 6),
          Text(
            errorCategoria!,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: (categoria?.pideCuenta ?? false)
              ? Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const EtiquetaRegistro('¿En qué exactamente?'),
                      CampoCuentaPcge(
                        tipo: tipo,
                        elegida: cuentaElegida,
                        error: errorCuenta,
                        onElegir: onElegirCuenta,
                      ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );

    final mediosWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const EtiquetaRegistro('¿Cómo se pagó?'),
        MediosRegistro(elegido: medio, onElegir: onElegirMedio),
        if (bloqueaCajaCerrada) ...[
          const SizedBox(height: 10),
          const AvisoRegistro(
            'La caja está cerrada y el efectivo entra y sale de ella: '
            'primero ábrela, o elige otro medio de pago.',
            bloquea: true,
          ),
        ],
      ],
    );

    final cuandoWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const EtiquetaRegistro('¿Cuándo?'),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onElegirFecha,
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Text(Formato.fechaRelativa(fecha)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 50),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ),
      ],
    );

    final detalleWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const EtiquetaRegistro('Detalle (opcional)'),
        TextField(
          controller: concepto,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Ej. Venta del día, pago de luz…',
          ),
        ),
      ],
    );

    final contraparteWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        EtiquetaRegistro(
          exigeCliente
              ? 'Cliente (obligatorio desde S/ 700)'
              : entro
              ? 'Cliente (opcional)'
              : 'Proveedor (opcional)',
        ),
        TextField(
          controller: contraparte,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'Nombre',
            errorText: errorNombre,
          ),
          onChanged: onContraparteChanged,
        ),
      ],
    );

    final masDatosWidget = MasDatosRegistro(
      abierto: masDatos,
      onCambiar: onCambiarMasDatos,
      children: [
        EtiquetaRegistro(
          exigeCliente ? 'DNI o RUC (obligatorio)' : 'DNI o RUC',
        ),
        TextField(
          controller: documento,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
            LengthLimitingTextInputFormatter(11),
          ],
          decoration: InputDecoration(
            hintText: 'Va impreso en el recibo y la boleta',
            errorText: errorDocumento,
          ),
          onChanged: onDocumentoChanged,
        ),
        if (medio.cuenta == Cuenta.banco) ...[
          const SizedBox(height: 14),
          const EtiquetaRegistro('N° de transacción bancaria'),
          TextField(
            controller: transaccion,
            decoration: const InputDecoration(
              hintText: 'El código del voucher o la operación',
            ),
          ),
        ],
      ],
    );

    // Por banco, quién pagó y su documento van con el voucher, en el paso
    // siguiente: allí está todo lo que pide el Formato 1.2.
    final enBanco = medio.cuenta == Cuenta.banco;
    final alVoucherWidget = Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Tokens.fondo,
        borderRadius: BorderRadius.circular(Tokens.radio),
        border: Border.all(color: Tokens.borde),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            size: 18,
            color: Tokens.texto2,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              entro
                  ? 'Quién pagó, su DNI o RUC y el N° de operación van en el '
                        'paso siguiente, con el voucher.'
                  : 'A quién se le pagó, su DNI o RUC y el N° de operación '
                        'van en el paso siguiente, con el voucher.',
              style: const TextStyle(fontSize: 12.5, color: Tokens.texto2),
            ),
          ),
        ],
      ),
    );

    final comprobantesWidget = ComprobantesRegistro(
      tipo: tipo,
      conRecibo: conRecibo,
      onRecibo: onCambiarRecibo,
      enEfectivo: enEfectivo,
      emiteBoleta: emiteBoleta,
      exigeCliente: exigeCliente,
    );

    List<Widget> columnaCompleta() => [
      montoWidget,
      const SizedBox(height: 18),
      categoriasWidget,
      const SizedBox(height: 18),
      mediosWidget,
      const SizedBox(height: 18),
      cuandoWidget,
      const SizedBox(height: 18),
      detalleWidget,
      const SizedBox(height: 14),
      if (enBanco)
        alVoucherWidget
      else ...[
        contraparteWidget,
        const SizedBox(height: 6),
        masDatosWidget,
      ],
      const SizedBox(height: 14),
      comprobantesWidget,
    ];

    if (!enDialogo) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: columnaCompleta(),
      );
    }

    return LayoutBuilder(
      builder: (context, medidas) {
        if (medidas.maxWidth < 664) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: columnaCompleta(),
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 11,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  montoWidget,
                  const SizedBox(height: 22),
                  categoriasWidget,
                  const SizedBox(height: 22),
                  mediosWidget,
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
                  cuandoWidget,
                  const SizedBox(height: 18),
                  detalleWidget,
                  const SizedBox(height: 18),
                  if (enBanco)
                    alVoucherWidget
                  else ...[
                    contraparteWidget,
                    const SizedBox(height: 6),
                    masDatosWidget,
                  ],
                  const SizedBox(height: 14),
                  comprobantesWidget,
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

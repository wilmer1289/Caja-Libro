import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../datos/local/evidencias.dart';
import '../../datos/local/selector_voucher.dart';
import '../../datos/ocr/lector_voucher.dart';
import '../../dominio/banco.dart';
import '../../dominio/categoria.dart';
import '../../dominio/enums.dart';
import '../../dominio/lectura_voucher.dart';
import '../../dominio/movimiento.dart';
import '../../dominio/pcge.dart';
import '../widgets/voucher_adjunto.dart';
import 'registro_componentes.dart';

/// El paso "Voucher": lo que pide el Libro Bancos (Formato 1.2) de una
/// operación por banco, Yape o tarjeta.
///
/// Es lo que en el Excel va en las hojas COBROS y PAGOS: el voucher, su N° de
/// operación, quién pagó o a quién se le pagó, su vínculo con el negocio y el
/// documento que se canceló. Con el voucher adjunto, la app lo lee y llena lo
/// que puede.
///
/// Como los otros pasos, no guarda estado: lo recibe del registro.
class PasoVoucher extends StatelessWidget {
  const PasoVoucher({
    super.key,
    required this.tipo,
    required this.medio,
    required this.categoria,
    required this.centavos,
    required this.fecha,
    required this.enDialogo,
    required this.cuenta,
    required this.bancoNegocio,
    required this.transaccion,
    required this.contraparte,
    required this.documento,
    required this.bancoTercero,
    required this.vinculo,
    required this.documentoPago,
    required this.situacion,
    required this.archivo,
    required this.leyendo,
    required this.lectura,
    required this.errorLectura,
    required this.errorTransaccion,
    required this.errorVoucher,
    required this.errorNombre,
    required this.errorDocumento,
    required this.exigeCliente,
    required this.duplicado,
    required this.onTomarFoto,
    required this.onElegirArchivo,
    required this.onQuitarArchivo,
    required this.onBanco,
    required this.onVinculo,
    required this.onDocumentoPago,
    required this.onSituacion,
    required this.onUsarMonto,
    required this.onUsarFecha,
    required this.onCambio,
  });

  final Tipo tipo;
  final MedioPago medio;
  final Categoria? categoria;
  final int centavos;
  final DateTime fecha;
  final bool enDialogo;

  /// La cuenta que va al formato con lo elegido: cambia en vivo con el
  /// vínculo y el documento.
  final String cuenta;

  /// El banco del negocio, para saber si una transferencia es interbancaria.
  final String bancoNegocio;

  final TextEditingController transaccion;
  final TextEditingController contraparte;
  final TextEditingController documento;
  final String? bancoTercero;
  final Vinculo vinculo;
  final DocumentoPago documentoPago;
  final Situacion situacion;

  final ArchivoVoucher? archivo;
  final bool leyendo;
  final LecturaVoucher? lectura;
  final String? errorLectura;

  final String? errorTransaccion;
  final String? errorVoucher;
  final String? errorNombre;
  final String? errorDocumento;
  final bool exigeCliente;

  /// Otro movimiento con el mismo N° de operación, si lo hay.
  final Movimiento? duplicado;

  final VoidCallback onTomarFoto;
  final VoidCallback onElegirArchivo;
  final VoidCallback onQuitarArchivo;
  final ValueChanged<String?> onBanco;
  final ValueChanged<Vinculo> onVinculo;
  final ValueChanged<DocumentoPago> onDocumentoPago;
  final ValueChanged<Situacion> onSituacion;
  final VoidCallback onUsarMonto;
  final VoidCallback onUsarFecha;
  final ValueChanged<String> onCambio;

  @override
  Widget build(BuildContext context) {
    final entro = tipo == Tipo.entro;

    final cabecera = Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Tokens.marcaSuave,
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(
            Icons.receipt_long_outlined,
            size: 20,
            color: Tokens.marcaOscura,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Datos del voucher',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Tokens.texto,
                ),
              ),
              Text(
                'Lo que pide el Libro Bancos (Formato 1.2).',
                style: TextStyle(fontSize: 12.5, color: Tokens.texto2),
              ),
            ],
          ),
        ),
      ],
    );

    final voucher = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TarjetaVoucher(
          archivo: archivo,
          obligatorio: centavos >= Movimiento.umbralVoucherCentavos,
          leyendo: leyendo,
          puedeTomarFoto: SelectorVoucher.instancia.puedeTomarFoto,
          puedeLeer: LectorVoucher.disponible,
          onTomarFoto: onTomarFoto,
          onElegir: onElegirArchivo,
          onQuitar: onQuitarArchivo,
          error: errorVoucher,
        ),
        if (errorLectura != null) ...[
          const SizedBox(height: 10),
          AvisoRegistro(errorLectura!),
        ],
        if (lectura != null && !leyendo) ...[
          const SizedBox(height: 10),
          _Leido(
            lectura: lectura!,
            centavos: centavos,
            fecha: fecha,
            onUsarMonto: onUsarMonto,
            onUsarFecha: onUsarFecha,
          ),
        ],
      ],
    );

    final operacion = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const EtiquetaRegistro('N° de operación'),
        TextField(
          controller: transaccion,
          onChanged: onCambio,
          decoration: InputDecoration(
            hintText: 'El número del voucher, ej. 04512378',
            errorText: errorTransaccion,
          ),
        ),
        if (duplicado != null) ...[
          const SizedBox(height: 8),
          AvisoRegistro(
            'Ya anotaste una operación con este número: la N° '
            '${duplicado!.numero} del ${Formato.fecha(duplicado!.fecha)}, '
            'por ${Formato.soles(duplicado!.monto)}. Revisa que no sea el '
            'mismo voucher.',
          ),
        ],
      ],
    );

    final opciones = EntidadesBancarias.para(medio);
    final banco = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        EtiquetaRegistro(
          medio == MedioPago.yape
              ? '¿Por qué app?'
              : entro
              ? '¿De qué banco vino?'
              : '¿A qué banco fue?',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final b in opciones)
              ChoiceChip(
                label: Text(b),
                selected: bancoTercero == b,
                // Tocarla de nuevo la desmarca: no siempre se sabe.
                onSelected: (elegida) => onBanco(elegida ? b : null),
              ),
          ],
        ),
        const SizedBox(height: 10),
        _Dato(
          icono: Icons.swap_horiz_rounded,
          rotulo: 'Tipo de operación',
          valor: EntidadesBancarias.tipoOperacion(
            medio,
            bancoTercero: bancoTercero,
            bancoNegocio: bancoNegocio,
          ),
        ),
      ],
    );

    final quien = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        EtiquetaRegistro(
          exigeCliente
              ? 'Cliente (obligatorio desde S/ 700)'
              : entro
              ? 'Cliente: quién pagó'
              : 'Proveedor: a quién se le pagó',
        ),
        TextField(
          controller: contraparte,
          onChanged: onCambio,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'Nombre o razón social',
            errorText: errorNombre,
          ),
        ),
        const SizedBox(height: 12),
        EtiquetaRegistro(
          exigeCliente ? 'DNI o RUC (obligatorio)' : 'DNI o RUC',
        ),
        TextField(
          controller: documento,
          onChanged: onCambio,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
            LengthLimitingTextInputFormatter(11),
          ],
          decoration: InputDecoration(
            hintText: medio == MedioPago.yape
                ? 'Yape no lo muestra: pídeselo'
                : 'DNI de 8 dígitos o RUC de 11',
            errorText: errorDocumento,
          ),
        ),
      ],
    );

    final relacion = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const EtiquetaRegistro('¿Quién es para el negocio?'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final v in Vinculo.values)
              ChoiceChip(
                label: Text(v.etiqueta),
                selected: vinculo == v,
                onSelected: (_) => onVinculo(v),
              ),
          ],
        ),
        if (categoria?.cancelaDocumento ?? false) ...[
          const SizedBox(height: 14),
          EtiquetaRegistro(entro ? '¿Qué se cobró?' : '¿Qué se pagó?'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in DocumentoPago.values)
                ChoiceChip(
                  label: Text(d.etiqueta),
                  selected: documentoPago == d,
                  onSelected: (_) => onDocumentoPago(d),
                ),
            ],
          ),
          if (entro) ...[
            const SizedBox(height: 14),
            const EtiquetaRegistro('¿Dónde estaba?'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in Situacion.values)
                  ChoiceChip(
                    label: Text(s.etiqueta),
                    selected: situacion == s,
                    onSelected: (_) => onSituacion(s),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              situacion.ayuda,
              style: const TextStyle(fontSize: 12, color: Tokens.texto2),
            ),
          ],
        ],
      ],
    );

    final itf = Itf.de(centavos);
    final contable = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Tokens.fondo,
        borderRadius: BorderRadius.circular(Tokens.radio),
        border: Border.all(color: Tokens.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dato(
            icono: Icons.account_tree_outlined,
            rotulo: 'Cuenta del formato',
            valor: '$cuenta · ${Pcge.instancia.denominacion(cuenta)}',
          ),
          const SizedBox(height: 8),
          _Dato(
            icono: Icons.account_balance_outlined,
            rotulo: 'ITF estimado',
            valor: itf > 0
                ? '${Formato.soles(itf / 100)} · lo descuenta el banco'
                : 'S/ 0.00 · menos de S/ 1,000 no paga',
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.only(left: 26),
            child: Text(
              'El ITF no va al libro: queda anotado en el historial.',
              style: TextStyle(fontSize: 11.5, color: Tokens.texto2),
            ),
          ),
        ],
      ),
    );

    List<Widget> izquierda() => [
      voucher,
      const SizedBox(height: 18),
      operacion,
      const SizedBox(height: 18),
      banco,
    ];
    List<Widget> derecha() => [
      quien,
      const SizedBox(height: 18),
      relacion,
      const SizedBox(height: 18),
      contable,
    ];

    Widget enColumna() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        cabecera,
        const SizedBox(height: 18),
        ...izquierda(),
        const SizedBox(height: 18),
        ...derecha(),
      ],
    );

    if (!enDialogo) return enColumna();

    return LayoutBuilder(
      builder: (context, medidas) {
        if (medidas.maxWidth < 664) return enColumna();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            cabecera,
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 11,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: izquierda(),
                  ),
                ),
                const SizedBox(width: 28),
                Expanded(
                  flex: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: derecha(),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Un dato que la app deduce: se muestra, no se escribe.
class _Dato extends StatelessWidget {
  const _Dato({required this.icono, required this.rotulo, required this.valor});

  final IconData icono;
  final String rotulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 18, color: Tokens.texto2),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$rotulo  ',
                  style: const TextStyle(color: Tokens.texto2),
                ),
                TextSpan(
                  text: valor,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Tokens.texto,
                  ),
                ),
              ],
            ),
            style: const TextStyle(fontSize: 12.5),
          ),
        ),
      ],
    );
  }
}

/// Lo que la app leyó del voucher. Si el monto o la fecha no coinciden con
/// lo anotado, lo dice y ofrece usar lo del voucher: casi siempre el voucher
/// tiene razón, pero el que decide es el usuario.
class _Leido extends StatelessWidget {
  const _Leido({
    required this.lectura,
    required this.centavos,
    required this.fecha,
    required this.onUsarMonto,
    required this.onUsarFecha,
  });

  final LecturaVoucher lectura;
  final int centavos;
  final DateTime fecha;
  final VoidCallback onUsarMonto;
  final VoidCallback onUsarFecha;

  @override
  Widget build(BuildContext context) {
    if (lectura.vacia) {
      return const AvisoRegistro(
        'No se pudo leer ningún dato del voucher. Queda adjunto igual: '
        'escribe los datos a mano.',
      );
    }

    final monto = lectura.centavos;
    final otroMonto = monto != null && monto != centavos;
    final dia = lectura.fecha;
    final otroDia =
        dia != null &&
        (dia.year != fecha.year ||
            dia.month != fecha.month ||
            dia.day != fecha.day);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Tokens.entroSuave,
        borderRadius: BorderRadius.circular(Tokens.radio),
        border: Border.all(color: Tokens.entro.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 16, color: Tokens.entro),
              SizedBox(width: 6),
              Text(
                'Leído del voucher',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Tokens.entro,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (lectura.numeroOperacion != null)
            _Fila('N° de operación', lectura.numeroOperacion!),
          if (monto != null)
            _Fila(
              'Monto',
              Formato.soles(monto / 100),
              aviso: otroMonto
                  ? 'Anotaste ${Formato.soles(centavos / 100)}'
                  : null,
              accion: otroMonto ? 'Usar este monto' : null,
              onAccion: onUsarMonto,
            ),
          if (dia != null)
            _Fila(
              'Fecha',
              Formato.fecha(dia),
              aviso: otroDia ? 'Anotaste ${Formato.fecha(fecha)}' : null,
              accion: otroDia && !dia.isAfter(DateTime.now())
                  ? 'Usar esta fecha'
                  : null,
              onAccion: onUsarFecha,
            ),
          if (lectura.nombre != null) _Fila('Nombre', lectura.nombre!),
          if (lectura.banco != null) _Fila('De', lectura.banco!),
        ],
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila(
    this.rotulo,
    this.valor, {
    this.aviso,
    this.accion,
    this.onAccion,
  });

  final String rotulo;
  final String valor;
  final String? aviso;
  final String? accion;
  final VoidCallback? onAccion;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          Text(
            '$rotulo: ',
            style: const TextStyle(fontSize: 12.5, color: Tokens.texto2),
          ),
          Text(
            valor,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Tokens.texto,
            ),
          ),
          if (aviso != null)
            Text(
              aviso!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B520F),
              ),
            ),
          if (accion != null)
            TextButton(
              onPressed: onAccion,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(accion!),
            ),
        ],
      ),
    );
  }
}

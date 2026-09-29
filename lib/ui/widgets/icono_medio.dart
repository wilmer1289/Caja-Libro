import 'package:flutter/material.dart';

import '../../dominio/enums.dart';

/// El ícono de cada medio de pago. Uno por medio y siempre el mismo, para que
/// "Yape / Plin" se reconozca de un vistazo en la lista y en los filtros.
IconData iconoDeMedio(MedioPago medio) => switch (medio) {
  MedioPago.efectivo => Icons.payments_outlined,
  MedioPago.yape => Icons.smartphone_rounded,
  MedioPago.transferencia => Icons.swap_horiz_rounded,
  MedioPago.deposito => Icons.savings_outlined,
  MedioPago.tarjeta => Icons.credit_card_rounded,
  MedioPago.tarjetaCredito => Icons.credit_score_rounded,
  MedioPago.cheque => Icons.request_page_outlined,
  MedioPago.otro => Icons.more_horiz_rounded,
};

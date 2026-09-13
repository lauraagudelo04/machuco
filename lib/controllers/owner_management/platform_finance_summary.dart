import 'package:machuco/controllers/payment/payment_store.dart';
import 'package:machuco/models/payment/payment.dart';

/// Totales agregados de todos los moteles de la plataforma.
///
/// La vista de finanzas del administrador calcula estos mismos totales por su
/// cuenta. Mantiene el cálculo fuera de la interfaz de gestión de propietarios.
class PlatformFinanceTotals {
  const PlatformFinanceTotals({
    required this.income,
    required this.paymentsReceived,
    required this.pendingAmount,
    required this.commissions,
  });

  factory PlatformFinanceTotals.from(List<MotelFinance> finances) {
    var income = 0;
    var paymentsReceived = 0;
    var pendingAmount = 0;
    var commissions = 0;

    for (final finance in finances) {
      income += finance.income;
      paymentsReceived += finance.paymentsReceived;
      pendingAmount += finance.pendingAmount;
      commissions += finance.commissions;
    }

    return PlatformFinanceTotals(
      income: income,
      paymentsReceived: paymentsReceived,
      pendingAmount: pendingAmount,
      commissions: commissions,
    );
  }

  final int income;
  final int paymentsReceived;
  final int pendingAmount;
  final int commissions;
}

/// Expone los totales de la plataforma al listado de propietarios.
///
/// Envuelve al controlador financiero para que la vista no dependa directamente
/// del módulo de pagos ni recorra sus registros.
class PlatformFinanceSummary {
  PlatformFinanceSummary({PaymentStore? paymentStore})
    : _paymentStore = paymentStore ?? PaymentStore.shared;

  final PaymentStore _paymentStore;

  PlatformFinanceTotals get totals =>
      PlatformFinanceTotals.from(_paymentStore.motelFinances);
}

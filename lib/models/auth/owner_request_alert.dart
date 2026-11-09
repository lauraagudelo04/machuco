/// Kind of warning shown to the administrator on an owner request. They only
/// inform: approving or rejecting is always the administrator's decision.
enum OwnerRequestAlertType {
  /// The NIT check digit (DIAN modulo 11) does not match, or the NIT has no
  /// recognizable `base-DV` form.
  invalidNitCheckDigit,

  /// Another owner account already uses the same NIT.
  duplicateNit,

  /// The chosen plan is missing from the active plans catalog (or the request
  /// has no plan).
  planNotAvailable,

  /// A check could not be completed (no connection); [OwnerRequestAlert.message]
  /// says which one.
  verificationUnavailable,
}

class OwnerRequestAlert {
  const OwnerRequestAlert(this.type, this.message);

  final OwnerRequestAlertType type;

  /// Spanish text, safe to show.
  final String message;
}

/// Warnings of one owner request, in a fixed order (NIT, duplicate, plan).
class OwnerRequestAlerts {
  const OwnerRequestAlerts(this.alerts);

  static const none = OwnerRequestAlerts(<OwnerRequestAlert>[]);

  final List<OwnerRequestAlert> alerts;

  bool get isEmpty => alerts.isEmpty;

  bool get isNotEmpty => alerts.isNotEmpty;

  bool has(OwnerRequestAlertType type) =>
      alerts.any((alert) => alert.type == type);
}

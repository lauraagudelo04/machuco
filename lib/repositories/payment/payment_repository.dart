import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:machuco/database/app_database.dart';
import 'package:machuco/models/payment/payment.dart';
import 'package:machuco/models/payment/payment_catalog_entry.dart';
import 'package:machuco/repositories/payment/payment_dao.dart';

enum PaymentRepositoryError {
  configuration,
  connection,
  remote,
  invalidCatalog,
  storage,
  invalidPayment,
  notFound,
  alreadyProcessed,
}

class PaymentRepositoryException implements Exception {
  const PaymentRepositoryException(this.kind, this.message);

  final PaymentRepositoryError kind;
  final String message;

  @override
  String toString() => message;
}

/// Coordina SQLite y el maestro remoto, sin procesar cobros ni escribir en él.
class PaymentRepository {
  PaymentRepository({
    AppDatabase? database,
    http.Client? client,
    String? supabaseUrl,
    String? publishableKey,
    Duration requestTimeout = const Duration(seconds: 15),
    DateTime Function()? now,
  }) : _database = database == null ? null : Future.value(database),
       _get = client?.get ?? http.get,
       _supabaseUrl =
           supabaseUrl ?? const String.fromEnvironment('SUPABASE_URL'),
       _publishableKey =
           publishableKey ??
           const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
       _requestTimeout = requestTimeout,
       _now = now ?? DateTime.now {
    if (requestTimeout <= Duration.zero) {
      throw ArgumentError.value(requestTimeout, 'requestTimeout');
    }
  }

  final Future<AppDatabase>? _database;
  final Future<http.Response> Function(Uri, {Map<String, String>? headers})
  _get;
  final String _supabaseUrl;
  final String _publishableKey;
  final Duration _requestTimeout;
  final DateTime Function() _now;

  /// Prefiere Supabase; si no responde correctamente recupera la copia local.
  Future<List<PaymentCatalogEntry>> findPaymentMethods() async {
    late final List<PaymentCatalogEntry> entries;
    try {
      entries = await _fetchPaymentMethods();
    } on PaymentRepositoryException {
      final cached = await _withDao((dao) => dao.findCatalogEntries());
      if (cached.isNotEmpty) return List.unmodifiable(cached);
      rethrow;
    }
    await _withDao((dao) => dao.saveCatalogEntries(entries));
    return entries;
  }

  Future<List<PaymentCatalogEntry>> _fetchPaymentMethods() async {
    final base = Uri.tryParse(_supabaseUrl.trim());
    if (base == null ||
        base.scheme != 'https' ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment ||
        _publishableKey.trim().isEmpty) {
      throw const PaymentRepositoryException(
        PaymentRepositoryError.configuration,
        'Configura la URL de Supabase y la clave publicable para consultar '
        'los métodos de pago.',
      );
    }
    final uri = base.replace(
      path:
          '${base.path.replaceFirst(RegExp(r'/$'), '')}/rest/v1/payment_method',
      queryParameters: {'select': 'id,nombre', 'order': 'id.asc'},
    );
    late final http.Response response;
    try {
      response = await _get(
        uri,
        headers: {
          'apikey': _publishableKey.trim(),
          'Accept': 'application/json',
        },
      ).timeout(_requestTimeout);
    } on Exception {
      throw const PaymentRepositoryException(
        PaymentRepositoryError.connection,
        'No se pudo conectar con el maestro de métodos de pago. '
        'Comprueba la conexión e inténtalo nuevamente.',
      );
    }
    if (response.statusCode != 200) {
      throw PaymentRepositoryException(
        PaymentRepositoryError.remote,
        response.statusCode == 401 || response.statusCode == 403
            ? 'Supabase no permitió consultar los métodos de pago. '
                  'Revisa la configuración y los permisos del catálogo.'
            : 'No se pudieron consultar los métodos de pago en Supabase. '
                  'Inténtalo nuevamente.',
      );
    }

    try {
      final rows = jsonDecode(utf8.decode(response.bodyBytes));
      if (rows is! List || rows.isEmpty) {
        throw const FormatException('Maestro vacío o inválido');
      }
      final ids = <int>{};
      final entries = <PaymentCatalogEntry>[];
      for (final row in rows) {
        if (row is! Map<String, dynamic>) {
          throw const FormatException('Método de pago inválido');
        }
        final entry = PaymentCatalogEntry.fromJson(row);
        if (!ids.add(entry.id)) {
          throw const FormatException('ID de método repetido');
        }
        entries.add(entry);
      }
      entries.sort((first, second) => first.id.compareTo(second.id));
      return List.unmodifiable(entries);
    } on FormatException {
      throw const PaymentRepositoryException(
        PaymentRepositoryError.invalidCatalog,
        'El maestro de métodos de pago está vacío o contiene datos inválidos. '
        'Inténtalo nuevamente.',
      );
    }
  }

  Future<List<PaymentRecord>> findAllPayments() =>
      _withDao((dao) => dao.findAll());

  Future<List<PaymentCatalogEntry>> findCachedPaymentMethods() =>
      _withDao((dao) => dao.findCatalogEntries());

  /// Opt-in del modo de demostración; no importa registros de otros moteles.
  Future<void> seedDemoPayments({
    required String motelId,
    required List<PaymentRecord> payments,
  }) {
    final id = _requiredId(motelId);
    final examples = payments
        .where((payment) => payment.motelId == id)
        .toList();
    for (final payment in examples) {
      _validatePayment(payment);
    }
    return _withDao((dao) => dao.insertMissingDemoPayments(examples));
  }

  Future<PaymentRecord?> findPayment(String id) {
    final paymentId = _requiredId(id);
    return _withDao((dao) => dao.findById(paymentId));
  }

  Future<List<PaymentRecord>> findPaymentsByClient(String clientId) {
    final id = _requiredId(clientId);
    return _withDao((dao) => dao.findByClient(id));
  }

  Future<List<PaymentRecord>> findPaymentsByMotel(String motelId) {
    final id = _requiredId(motelId);
    return _withDao((dao) => dao.findByMotel(id));
  }

  /// Inserta solamente; no sobrescribe un pago ni confirma su recepción.
  Future<void> createPayment(PaymentRecord payment) {
    _validatePayment(payment);
    return _withDao((dao) => dao.insertPayment(payment));
  }

  void _validatePayment(PaymentRecord payment) {
    for (final id in [
      payment.id,
      payment.bookingId,
      payment.clientId,
      payment.motelId,
      payment.roomId,
    ]) {
      if (id.trim().isEmpty || id != id.trim()) {
        throw const PaymentRepositoryException(
          PaymentRepositoryError.invalidPayment,
          'Los identificadores del pago no pueden estar vacíos ni contener '
          'espacios al principio o al final.',
        );
      }
    }
    final methodId = payment.paymentMethodId;
    if (payment.amount <= 0 || (methodId != null && methodId <= 0)) {
      throw const PaymentRepositoryException(
        PaymentRepositoryError.invalidPayment,
        'El valor del pago y el identificador del método deben ser positivos.',
      );
    }
  }

  Future<PaymentRecord> registerLocalPayment({
    required String paymentId,
    required String motelId,
    required int paymentMethodId,
  }) {
    final id = _requiredId(paymentId);
    final motel = _requiredId(motelId);
    if (paymentMethodId <= 0) {
      throw const PaymentRepositoryException(
        PaymentRepositoryError.invalidPayment,
        'Selecciona un método de pago válido.',
      );
    }
    return _withDao((dao) async {
      final payment = await dao.findById(id);
      if (payment == null || payment.motelId != motel) {
        throw const PaymentRepositoryException(
          PaymentRepositoryError.notFound,
          'No se encontró el pago en este motel.',
        );
      }
      if (payment.status != PaymentStatus.pending) {
        throw const PaymentRepositoryException(
          PaymentRepositoryError.alreadyProcessed,
          'Este pago ya no está pendiente y no se puede confirmar nuevamente.',
        );
      }
      final catalog = await dao.findCatalogEntries();
      if (!catalog.any((entry) => entry.id == paymentMethodId)) {
        throw const PaymentRepositoryException(
          PaymentRepositoryError.invalidPayment,
          'El método seleccionado no está disponible en el maestro local. '
          'Actualiza los métodos de pago e inténtalo nuevamente.',
        );
      }
      final changed = await dao.registerLocalPayment(
        id,
        motel,
        paymentMethodId,
        _now(),
        'LOCAL-${payment.id}',
      );
      if (changed != 1) {
        throw const PaymentRepositoryException(
          PaymentRepositoryError.alreadyProcessed,
          'Este pago ya no está pendiente y no se puede confirmar nuevamente.',
        );
      }
      final saved = await dao.findById(id);
      if (saved == null) {
        throw const PaymentRepositoryException(
          PaymentRepositoryError.storage,
          'No se pudo recuperar el pago registrado en el dispositivo.',
        );
      }
      return saved;
    });
  }

  String _requiredId(String value) {
    if (value.trim().isEmpty) {
      throw const PaymentRepositoryException(
        PaymentRepositoryError.invalidPayment,
        'Se requiere un identificador válido para consultar o registrar el pago.',
      );
    }
    return value.trim();
  }

  Future<T> _withDao<T>(Future<T> Function(PaymentDao dao) operation) async {
    try {
      final database = await (_database ?? AppDatabaseProvider.database);
      return await operation(database.paymentDao);
    } on PaymentRepositoryException {
      rethrow;
    } on Exception {
      throw const PaymentRepositoryException(
        PaymentRepositoryError.storage,
        'No se pudo consultar o guardar la información de pagos en el '
        'dispositivo. Inténtalo nuevamente.',
      );
    }
  }
}

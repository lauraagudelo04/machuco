import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/payment/owner_view/owner_payment_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/payment/payment.dart';
import 'package:machuco/models/payment/payment_catalog_entry.dart';
import 'package:machuco/repositories/payment/payment_repository.dart';
import 'package:machuco/views/payment/owner_view/owner_payment_page.dart';
import 'package:machuco/views/payment/owner_view/register_local_payment_sheet.dart';

const _methods = [
  PaymentCatalogEntry(id: 1, name: 'Efectivo'),
  PaymentCatalogEntry(id: 2, name: 'Tarjeta de crédito'),
  PaymentCatalogEntry(id: 3, name: 'Tarjeta de débito'),
  PaymentCatalogEntry(id: 4, name: 'Transferencia bancaria'),
];

PaymentRecord _pending() => PaymentRecord(
  id: 'pay-1',
  bookingId: 'booking-1',
  bookingReference: 'RES-1082',
  clientId: 'client-1',
  client: 'Carlos Ruiz',
  motelId: 'motel-1',
  motel: 'Motel de prueba',
  roomId: 'room-1',
  room: 'Habitación 112 · Junior',
  reservationDate: DateTime(2026, 10, 16),
  amount: 120000,
  status: PaymentStatus.pending,
);

PaymentRecord _paid(int methodId) => _pending().copyWith(
  status: PaymentStatus.paid,
  paymentMethodId: methodId,
  paidAt: DateTime(2026, 10, 16, 21),
  receiptNumber: 'LOCAL-pay-1',
);

void main() {
  Future<void> openSheet(
    WidgetTester tester, {
    Future<List<PaymentCatalogEntry>> Function()? load,
    Future<PaymentRecord> Function(int methodId)? save,
    double textScale = 1,
  }) async {
    await tester.binding.setSurfaceSize(const Size(440, 956));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              child: const Text('Abrir registro'),
              onPressed: () => showModalBottomSheet<PaymentRecord>(
                context: context,
                isScrollControlled: true,
                isDismissible: false,
                enableDrag: false,
                builder: (_) => RegisterLocalPaymentSheet(
                  payment: _pending(),
                  loadPaymentMethods: load ?? () async => _methods,
                  onSave: save ?? (id) async => _paid(id),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir registro'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> selectMethod(WidgetTester tester, String name) async {
    final dropdown = find.byType(DropdownButtonFormField<int>);
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
  }

  FilledButton confirmButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byType(FilledButton));

  testWidgets(
    'exige elegir un método y ofrece las cuatro opciones del maestro',
    (tester) async {
      int? selected;
      await openSheet(
        tester,
        save: (id) async {
          selected = id;
          return _paid(id);
        },
      );
      await tester.pumpAndSettle();
      expect(find.text('Carlos Ruiz'), findsOneWidget);
      expect(find.text(r'$ 120.000'), findsOneWidget);
      expect(confirmButton(tester).onPressed, isNull);

      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      for (final method in _methods) {
        expect(find.text(method.name), findsOneWidget);
      }
      await tester.tap(find.text('Transferencia bancaria'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Confirmar pago'));
      await tester.tap(find.text('Confirmar pago'));
      await tester.pumpAndSettle();
      expect(selected, 4);
      expect(find.byType(RegisterLocalPaymentSheet), findsNothing);
    },
  );

  testWidgets(
    'conserva el método al fallar y espera a que termine el guardado',
    (tester) async {
      var attempts = 0;
      final saved = Completer<PaymentRecord>();
      await openSheet(
        tester,
        save: (id) async {
          attempts++;
          expect(id, 2);
          if (attempts == 1) {
            throw const PaymentRepositoryException(
              PaymentRepositoryError.storage,
              'No se pudo guardar el pago.',
            );
          }
          return saved.future;
        },
      );
      await tester.pumpAndSettle();
      await selectMethod(tester, 'Tarjeta de crédito');
      await tester.ensureVisible(find.text('Confirmar pago'));
      await tester.tap(find.text('Confirmar pago'));
      await tester.pumpAndSettle();
      expect(find.text('No se pudo guardar el pago.'), findsOneWidget);
      expect(find.text('Tarjeta de crédito'), findsOneWidget);
      expect(find.byType(RegisterLocalPaymentSheet), findsOneWidget);

      await tester.tap(find.text('Confirmar pago'));
      await tester.pump();
      expect(attempts, 2);
      expect(confirmButton(tester).onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester
            .widget<AppButton>(find.widgetWithText(AppButton, 'Cancelar'))
            .onPressed,
        isNull,
      );
      expect(find.byType(RegisterLocalPaymentSheet), findsOneWidget);
      saved.complete(_paid(2));
      await tester.pumpAndSettle();
      expect(find.byType(RegisterLocalPaymentSheet), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cancelar no registra un pago', (tester) async {
    var saves = 0;
    await openSheet(
      tester,
      save: (id) async {
        saves++;
        return _paid(id);
      },
    );
    await tester.pumpAndSettle();
    await selectMethod(tester, 'Efectivo');
    await tester.ensureVisible(find.text('Cancelar'));
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(saves, 0);
    expect(find.byType(RegisterLocalPaymentSheet), findsNothing);
  });

  testWidgets('muestra errores del maestro y permite reintentar sin cerrar', (
    tester,
  ) async {
    var loads = 0;
    await openSheet(
      tester,
      load: () async {
        loads++;
        if (loads == 1) {
          throw const PaymentRepositoryException(
            PaymentRepositoryError.connection,
            'No se pudo conectar al maestro.',
          );
        }
        return _methods;
      },
    );
    await tester.pumpAndSettle();
    expect(find.text('No se pudo conectar al maestro.'), findsOneWidget);
    expect(confirmButton(tester).onPressed, isNull);
    await tester.ensureVisible(find.text('Reintentar'));
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(loads, 2);
    expect(find.byType(DropdownButtonFormField<int>), findsOneWidget);
    expect(find.text('No se pudo conectar al maestro.'), findsNothing);
  });

  testWidgets('un maestro vacío no habilita la confirmación', (tester) async {
    await openSheet(tester, load: () async => []);
    await tester.pumpAndSettle();
    expect(find.text('No hay métodos de pago disponibles.'), findsOneWidget);
    expect(confirmButton(tester).onPressed, isNull);
  });

  testWidgets(
    'muestra carga y no habilita confirmar hasta recibir el maestro',
    (tester) async {
      final methods = Completer<List<PaymentCatalogEntry>>();
      await openSheet(tester, load: () => methods.future);
      expect(find.text('Cargando métodos de pago...'), findsOneWidget);
      expect(confirmButton(tester).onPressed, isNull);
      methods.complete(_methods);
      await tester.pumpAndSettle();
      expect(find.byType(DropdownButtonFormField<int>), findsOneWidget);
      expect(confirmButton(tester).onPressed, isNull);
    },
  );

  testWidgets(
    'el formulario se desplaza con texto ampliado al 200 por ciento',
    (tester) async {
      await openSheet(tester, textScale: 2);
      await tester.pumpAndSettle();
      await selectMethod(tester, 'Efectivo');
      await tester.ensureVisible(find.text('Confirmar pago'));
      expect(confirmButton(tester).onPressed, isNotNull);
      // El framework falla ante errores de layout y conserva sus diagnósticos.
    },
  );

  testWidgets(
    'la vista mueve el pago a realizados y muestra método y comprobante',
    (tester) async {
      final repository = _PageRepository([_pending()]);
      final controller = OwnerPaymentController(
        motelId: 'motel-1',
        repository: repository,
        useDemoData: false,
      );
      addTearDown(controller.dispose);
      await controller.ready;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: OwnerPaymentsPage(
            motelId: 'motel-1',
            motelName: 'Motel de prueba',
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Registrar pago en efectivo'), findsNothing);
      await tester.ensureVisible(find.text('Registrar pago'));
      await tester.tap(find.text('Registrar pago'));
      await tester.pumpAndSettle();
      await selectMethod(tester, 'Tarjeta de débito');
      await tester.ensureVisible(find.text('Confirmar pago'));
      await tester.tap(find.text('Confirmar pago'));
      await tester.pumpAndSettle();

      expect(find.byType(RegisterLocalPaymentSheet), findsNothing);
      expect(controller.pendingPayments, isEmpty);
      expect(controller.completedPayments.single.paymentMethodId, 3);
      await tester.ensureVisible(find.byKey(const ValueKey('payment-pay-1')));
      expect(find.text('Método: Tarjeta de débito'), findsOneWidget);
      expect(find.text('Comprobante: LOCAL-pay-1'), findsOneWidget);
      expect(find.text('Pagado'), findsOneWidget);
      expect(find.text('Registrar pago'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('la vista muestra una carga fallida y permite reintentar', (
    tester,
  ) async {
    final repository = _PageRepository([])..failLoad = true;
    final controller = OwnerPaymentController(
      motelId: 'motel-1',
      repository: repository,
      useDemoData: false,
    );
    addTearDown(controller.dispose);
    await controller.ready;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: OwnerPaymentsPage(
          motelId: 'motel-1',
          motelName: 'Motel de prueba',
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Error de lectura de prueba.'), findsOneWidget);
    repository.failLoad = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Sin pagos guardados'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _PageRepository extends PaymentRepository {
  _PageRepository(this.records);
  final List<PaymentRecord> records;
  bool failLoad = false;

  @override
  Future<List<PaymentRecord>> findPaymentsByMotel(String motelId) async {
    if (failLoad) {
      throw const PaymentRepositoryException(
        PaymentRepositoryError.storage,
        'Error de lectura de prueba.',
      );
    }
    return records.where((payment) => payment.motelId == motelId).toList();
  }

  @override
  Future<List<PaymentCatalogEntry>> findCachedPaymentMethods() async =>
      _methods;

  @override
  Future<List<PaymentCatalogEntry>> findPaymentMethods() async => _methods;

  @override
  Future<PaymentRecord> registerLocalPayment({
    required String paymentId,
    required String motelId,
    required int paymentMethodId,
  }) async {
    final index = records.indexWhere(
      (payment) => payment.id == paymentId && payment.motelId == motelId,
    );
    final saved = _paid(paymentMethodId);
    records[index] = saved;
    return saved;
  }
}

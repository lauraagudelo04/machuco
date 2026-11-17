import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/pqrs/pqrs_type_catalog.dart';
import 'package:machuco/models/pqrs/pqrs.dart';
import 'package:machuco/models/pqrs/pqrs_type_info.dart';
import 'package:machuco/utils/pqrs_response_date.dart';

void main() {
  PqrsRequest requestOf(DateTime createdAt) => PqrsRequest(
    id: 'p1',
    motelId: 'm1',
    motelName: 'Motel',
    clientId: 'c1',
    clientName: 'Cliente',
    ownerId: 'o1',
    type: PqrsType.queja,
    subject: 'Asunto de prueba',
    description: 'Descripción de prueba',
    createdAt: createdAt,
  );

  group('PqrsTypeCatalog sin repositorio', () {
    test('arranca con los 4 tipos por defecto', () {
      expect(PqrsTypeCatalog().types, PqrsTypeInfo.defaults);
      expect(PqrsTypeCatalog().types, hasLength(4));
    });

    test('la fecha estimada suma días hábiles y no cambia el estado', () {
      final catalog = PqrsTypeCatalog();
      final request = requestOf(DateTime(2026, 11, 13)); // viernes
      final days =
          catalog.infoOf(PqrsType.queja)?.responseDays ??
          pqrsDefaultResponseDays;
      expect(
        catalog.estimatedResponse(request),
        addBusinessDays(request.createdAt, days),
      );
      expect(request.status, PqrsStatus.pending);
    });
  });
}

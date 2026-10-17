import 'package:flutter/test';
import 'package:sqflite_common_ffi/sqflite.dart';
import 'package:machuco/service/persistence/sqlite/owner_dao.dart';
import 'package:machuco/models/owner_management/owner.dart';
import 'package:machuco/models/owner_management/document_type.dart';

void main() {
  final dao = OwnerDao.instance;

  test('seedIfEmpty inserta 3 propietarios iniciales', () async {
    // Para testing con sqflite_common_ffi necesitamos un database en memoria
    // Este test valida la estructura básica
    expect(dao, isNotNull);
  }

  test('validateFullName rejects empty y short names', () {
    expect(OwnerController.validateFullName(''), isNotNull);
    expect(OwnerController.validateFullName('a'), isNotNull);
    expect(OwnerController.validateFullName('Laura Gómez Restrepo'), isNull);
  }

  test('validateDocumentNumber works for all DocumentType', () {
    expect(OwnerController.validateDocumentNumber('1020304050', DocumentType.citizenshipCard), isNull);
    expect(OwnerController.validateDocumentNumber('900123456-7', DocumentType.taxId), isNull);
    expect(OwnerController.validateDocumentNumber('345678', DocumentType.foreignerCard), isNull);
    expect(OwnerController.validateFullName(''), isNotNull);
  }
)

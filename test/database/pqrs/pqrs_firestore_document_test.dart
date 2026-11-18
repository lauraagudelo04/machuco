import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/database/model/pqrs/pqrs_firestore_document.dart';
import 'package:machuco/database/repository/pqrs/pqrs_repository.dart';
import 'package:machuco/models/pqrs/pqrs.dart';

PqrsAttachment _photo({String mime = 'image/jpeg'}) => PqrsAttachment(
  id: 'att',
  label: 'Foto',
  author: PqrsActor.client,
  capturedAt: DateTime(2026, 11, 16),
  seed: 0,
  bytes: Uint8List.fromList([1, 2, 3]),
  mimeType: mime,
);

PqrsTraceEntry _entry({
  PqrsStatus? change,
  List<PqrsAttachment> attachments = const [],
  PqrsActor author = PqrsActor.owner,
}) => PqrsTraceEntry(
  id: 'trace-1',
  author: author,
  authorId: 'uid-owner',
  authorName: 'Propietario Uno',
  message: 'Avance',
  createdAt: DateTime(2026, 11, 16),
  attachments: attachments,
  statusChange: change,
);

Map<String, dynamic> _requestData({
  String status = 'pending',
  Object? resolvedAt,
  Object? closedBy,
}) => {
  'clientId': 'uid-client',
  'clientName': 'Cliente',
  'motelId': 'motel-1',
  'motelName': 'Motel Uno',
  'ownerId': 'uid-owner',
  'type': 'queja',
  'subject': 'Ruido',
  'description': 'Ruido excesivo en la habitación',
  'status': status,
  'photoCount': 0,
  'createdAt': Timestamp.fromDate(DateTime.utc(2026, 11, 10)),
  'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 11, 10)),
  'resolvedAt': ?resolvedAt,
  'closedBy': ?closedBy,
};

void main() {
  group('status keys', () {
    test('in_progress maps to inProgress and back', () {
      expect(
        PqrsFirestoreDocument.statusToKey(PqrsStatus.inProgress),
        'in_progress',
      );
      expect(
        PqrsFirestoreDocument.statusFromKey('in_progress'),
        PqrsStatus.inProgress,
      );
    });

    test('every status round-trips', () {
      for (final status in PqrsStatus.values) {
        final key = PqrsFirestoreDocument.statusToKey(status);
        expect(PqrsFirestoreDocument.statusFromKey(key), status);
      }
    });

    test('unknown status throws FormatException', () {
      expect(
        () => PqrsFirestoreDocument.statusFromKey('inProgress'),
        throwsFormatException,
      );
    });
  });

  group('requestFromFirestore', () {
    test('reads an in_progress request with absent closedBy as null', () {
      final request = PqrsFirestoreDocument.requestFromFirestore(
        'p1',
        _requestData(status: 'in_progress'),
      );
      expect(request.status, PqrsStatus.inProgress);
      expect(request.closedBy, isNull);
      expect(request.resolvedAt, isNull);
      expect(request.type, PqrsType.queja);
      expect(request.ownerId, 'uid-owner');
      expect(request.createdAt.toUtc(), DateTime.utc(2026, 11, 10));
    });

    test('reads resolvedAt and closedBy of a closed request', () {
      final request = PqrsFirestoreDocument.requestFromFirestore(
        'p1',
        _requestData(
          status: 'closed',
          resolvedAt: Timestamp.fromDate(DateTime.utc(2026, 11, 12)),
          closedBy: 'owner_timeout',
        ),
      );
      expect(request.closedBy, PqrsClosedBy.ownerTimeout);
      expect(request.resolvedAt?.toUtc(), DateTime.utc(2026, 11, 12));
    });

    test('malformed documents throw FormatException', () {
      expect(
        () => PqrsFirestoreDocument.requestFromFirestore('p1', {}),
        throwsFormatException,
      );
      expect(
        () => PqrsFirestoreDocument.requestFromFirestore(
          'p1',
          _requestData(status: 'otro'),
        ),
        throwsFormatException,
      );
      final noDate = _requestData()..remove('createdAt');
      expect(
        () => PqrsFirestoreDocument.requestFromFirestore('p1', noDate),
        throwsFormatException,
      );
    });
  });

  group('writers', () {
    test('new request stores pending, type code and server timestamps', () {
      final data = PqrsFirestoreDocument.newRequestToFirestore(
        PqrsNewRequest(
          id: 'p1',
          motelId: 'motel-1',
          motelName: 'Motel Uno',
          clientId: 'uid-client',
          clientName: 'Cliente',
          ownerId: 'ignored',
          type: PqrsType.reclamo,
          subject: 'Asunto',
          description: 'Descripción larga',
          createdAt: DateTime(2026, 11, 16),
          photos: [_photo(), _photo()],
        ),
        ownerId: 'uid-owner',
      );
      expect(data['status'], 'pending');
      expect(data['type'], 'reclamo');
      expect(data['ownerId'], 'uid-owner');
      expect(data['photoCount'], 2);
      expect(data['createdAt'], isA<FieldValue>());
      expect(data['updatedAt'], isA<FieldValue>());
      expect(data.containsKey('resolvedAt'), isFalse);
      expect(data.containsKey('closedBy'), isFalse);
    });

    test('a comment without status change writes no request update', () {
      expect(
        PqrsFirestoreDocument.updateToFirestore(
          PqrsTraceAppend(requestId: 'p1', entry: _entry()),
        ),
        isNull,
      );
    });

    test('in progress is stored as in_progress without resolvedAt', () {
      final update = PqrsFirestoreDocument.updateToFirestore(
        PqrsTraceAppend(
          requestId: 'p1',
          entry: _entry(change: PqrsStatus.inProgress),
        ),
      )!;
      expect(update['status'], 'in_progress');
      expect(update.keys, containsAll(['status', 'updatedAt']));
      expect(update.containsKey('resolvedAt'), isFalse);
      expect(update.containsKey('closedBy'), isFalse);
    });

    test('resolving sets a server resolvedAt', () {
      final update = PqrsFirestoreDocument.updateToFirestore(
        PqrsTraceAppend(
          requestId: 'p1',
          entry: _entry(change: PqrsStatus.resolved),
          resolvedAt: DateTime(2026, 11, 16),
        ),
      )!;
      expect(update['status'], 'resolved');
      expect(update['resolvedAt'], isA<FieldValue>());
    });

    test('reopening deletes resolvedAt', () {
      final update = PqrsFirestoreDocument.updateToFirestore(
        PqrsTraceAppend(
          requestId: 'p1',
          entry: _entry(
            change: PqrsStatus.inProgress,
            author: PqrsActor.client,
          ),
          clearResolvedAt: true,
        ),
      )!;
      expect(update['status'], 'in_progress');
      expect(update.containsKey('resolvedAt'), isTrue);
      expect(update['resolvedAt'], isA<FieldValue>());
    });

    test('closing stores the closedBy key', () {
      final update = PqrsFirestoreDocument.updateToFirestore(
        PqrsTraceAppend(
          requestId: 'p1',
          entry: _entry(change: PqrsStatus.closed),
          closedBy: PqrsClosedBy.ownerTimeout,
        ),
      )!;
      expect(update['status'], 'closed');
      expect(update['closedBy'], 'owner_timeout');
      expect(update.containsKey('resolvedAt'), isFalse);
    });

    test('trace stores role, status key and counts only real photos', () {
      final simulated = PqrsAttachment(
        id: 'sim-owner',
        label: 'x',
        author: PqrsActor.owner,
        capturedAt: DateTime(2026),
        seed: 1,
      );
      final data = PqrsFirestoreDocument.traceToFirestore(
        _entry(
          change: PqrsStatus.inProgress,
          attachments: [_photo(), simulated],
        ),
      );
      expect(data['authorRole'], 'owner');
      expect(data['authorId'], 'uid-owner');
      expect(data['statusChange'], 'in_progress');
      expect(data['photoCount'], 1);
      expect(data['createdAt'], isA<FieldValue>());
    });

    test('trace without status change omits the key', () {
      final data = PqrsFirestoreDocument.traceToFirestore(_entry());
      expect(data.containsKey('statusChange'), isFalse);
    });

    test('photo stores a Blob and the fixed metadata', () {
      final data = PqrsFirestoreDocument.photoToFirestore(
        _photo(mime: 'image/png'),
        traceId: 'trace-1',
        authorId: 'uid-owner',
        authorRole: PqrsActor.owner,
      );
      expect(data['bytes'], isA<Blob>());
      expect((data['bytes'] as Blob).bytes, Uint8List.fromList([1, 2, 3]));
      expect(data['mimeType'], 'image/png');
      expect(data['traceId'], 'trace-1');
      expect(data['authorRole'], 'owner');
    });

    test('a photo without image cannot be written', () {
      final simulated = PqrsAttachment(
        id: 'sim-client',
        label: 'x',
        author: PqrsActor.client,
        capturedAt: DateTime(2026),
        seed: 1,
      );
      expect(
        () => PqrsFirestoreDocument.photoToFirestore(
          simulated,
          traceId: 't',
          authorId: 'u',
          authorRole: PqrsActor.client,
        ),
        throwsFormatException,
      );
    });

    test('photo ids use the _1 to _3 suffix of the trace', () {
      expect(pqrsPhotoId('trace-1', 1), 'trace-1_1');
      expect(pqrsPhotoId('trace-1', 3), 'trace-1_3');
      expect(pqrsOpeningTraceId('p1'), 'p1-open');
    });
  });

  group('trace and photo readers', () {
    test('trace maps in_progress and absent statusChange', () {
      final withChange = PqrsFirestoreDocument.traceFromFirestore('t1', {
        'authorId': 'uid-owner',
        'authorRole': 'owner',
        'authorName': 'Propietario',
        'message': 'Hola',
        'statusChange': 'in_progress',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 11, 11)),
      });
      expect(withChange.statusChange, PqrsStatus.inProgress);
      expect(withChange.author, PqrsActor.owner);
      expect(withChange.authorName, 'Propietario');

      final without = PqrsFirestoreDocument.traceFromFirestore('t2', {
        'authorId': 'uid-client',
        'authorRole': 'client',
        'message': 'Hola',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 11, 11)),
      });
      expect(without.statusChange, isNull);
      expect(without.authorName, isEmpty);
    });

    test('photo reads bytes back from the Blob', () {
      final photo = PqrsFirestoreDocument.photoFromFirestore('t1_1', {
        'bytes': Blob(Uint8List.fromList([9, 8])),
        'mimeType': 'image/webp',
        'authorRole': 'client',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 11, 11)),
      }, 1);
      expect(photo.bytes, Uint8List.fromList([9, 8]));
      expect(photo.mimeType, 'image/webp');
      expect(photo.hasImage, isTrue);
    });

    test('photo without Blob throws FormatException', () {
      expect(
        () => PqrsFirestoreDocument.photoFromFirestore('t1_1', {
          'mimeType': 'image/png',
          'authorRole': 'client',
          'createdAt': Timestamp.fromDate(DateTime.utc(2026, 11, 11)),
        }, 1),
        throwsFormatException,
      );
    });
  });
}

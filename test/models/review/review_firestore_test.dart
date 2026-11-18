import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/models/review/review.dart';

Review _review() => Review(
  id: 'review-1',
  authorId: 'user-1',
  authorName: 'Diana R.',
  title: 'Excelente atención',
  body: 'Muy amables.',
  rating: 5,
  date: DateTime.utc(2026, 7, 10, 15, 30),
  motelId: '1',
  roomId: 'room-2',
  type: ReviewType.room,
  status: ReviewModerationStatus.reported,
  reportReason: 'Lenguaje inapropiado',
  adminReply: 'Revisado',
  ownerReply: 'Gracias',
);

void main() {
  group('Review ↔ Firestore', () {
    test('toFirestore escribe todos los campos del dominio', () {
      final data = _review().toFirestore();

      expect(data['authorId'], 'user-1');
      expect(data['authorName'], 'Diana R.');
      expect(data['title'], 'Excelente atención');
      expect(data['body'], 'Muy amables.');
      expect(data['rating'], 5);
      expect(data['date'], isA<Timestamp>());
      expect(data['motelId'], '1');
      expect(data['roomId'], 'room-2');
      expect(data['type'], 'room');
      expect(data['status'], 'reported');
      expect(data['reportReason'], 'Lenguaje inapropiado');
      expect(data['adminReply'], 'Revisado');
      expect(data['ownerReply'], 'Gracias');
      expect(data.containsKey('id'), isFalse, reason: 'el id es del documento');
    });

    test('fromFirestore reconstruye el modelo', () {
      final original = _review();
      final restored = Review.fromFirestore('review-1', original.toFirestore());

      expect(restored.id, 'review-1');
      expect(restored.authorId, original.authorId);
      expect(restored.authorName, original.authorName);
      expect(restored.title, original.title);
      expect(restored.body, original.body);
      expect(restored.rating, original.rating);
      expect(restored.date, original.date);
      expect(restored.motelId, original.motelId);
      expect(restored.roomId, original.roomId);
      expect(restored.type, original.type);
      expect(restored.status, original.status);
      expect(restored.reportReason, original.reportReason);
      expect(restored.adminReply, original.adminReply);
      expect(restored.ownerReply, original.ownerReply);
    });

    test('fromFirestore tolera campos faltantes o desconocidos', () {
      final restored = Review.fromFirestore('review-2', {
        'authorId': 'user-2',
        'title': 'Bien',
        'body': 'Todo bien',
      });

      expect(restored.id, 'review-2');
      expect(restored.authorName, '');
      expect(restored.rating, 0);
      expect(restored.motelId, '');
      expect(restored.roomId, isNull);
      expect(restored.type, ReviewType.motel);
      expect(restored.status, ReviewModerationStatus.visible);
      expect(restored.reportReason, isNull);
      expect(restored.adminReply, isNull);
      expect(restored.ownerReply, isNull);
    });

    test('fromFirestore acepta DateTime además de Timestamp', () {
      final restored = Review.fromFirestore('review-3', {
        'authorId': 'user-3',
        'date': DateTime.utc(2026, 1, 2),
      });

      expect(restored.date, DateTime.utc(2026, 1, 2));
    });
  });
}

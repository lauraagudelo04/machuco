import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:machuco/models/motel/motel_model.dart';
import 'package:machuco/service/firebase/firestore_collections.dart';

/// Copia del motel en Firestore (`motels/{motelId}`).
///
/// Los moteles viven en Firebase SQL Connect, pero las reglas de Firestore no
/// pueden consultarlo. Esta copia (mismo UUID) permite que otros módulos,
/// como habitaciones, verifiquen el motel y su dueño desde Firestore. Se
/// escribe cada vez que se crea o edita un motel.
abstract interface class MotelFirestoreRegistry {
  Future<void> save(Motel motel);
}

class FirestoreMotelRegistry implements MotelFirestoreRegistry {
  FirestoreMotelRegistry({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<void> save(Motel motel) {
    return _firestore.collection(FirestoreCollections.motels).doc(motel.id).set({
      'ownerId': motel.ownerId,
      'name': motel.name,
      'email': motel.email,
      'roomCount': motel.roomCount,
      'nit': motel.nit,
      'address': motel.address,
      'phone': motel.phone,
      'description': motel.description,
      'generalLocation': motel.generalLocation,
      'paymentMethods': motel.paymentMethods,
      'imageUrls': motel.imageUrls,
      'isAvailable': motel.isAvailable,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

/// Subcolecciones de `users/{uid}` que el propio usuario puede borrar al
/// eliminar su cuenta (DA-15). Firestore no borra en cascada.
///
/// No incluye los pagos de suscripción (`subscriptions/{id}/payments` y
/// `subscriptions/{id}/subscriptionPayments`): se conservan por obligación
/// contable y `firestore.rules` no permite borrarlos. No guardan nombre,
/// correo, celular ni documento.
const userOwnedSubcollections = [
  'notificationReads',
  'devices',
  'subscriptions',
];

/// Tamaño de cada lote de borrado (Firestore admite hasta 500 escrituras).
const userTreeDeleteBatchSize = 200;

/// Borra la cuenta de Firestore de un Cliente o Propietario en orden:
/// primero cada subcolección de [subcollections], por lotes de [batchSize],
/// y al final el documento `users/{uid}` ([deleteProfileDocument]).
///
/// Es idempotente: un reintento tras un fallo vuelve a listar lo que quede y
/// continúa. Si algún lote falla, el documento del perfil no se borra, así
/// que la cuenta sigue completa para reintentar.
///
/// [fetchPage] devuelve hasta `limit` referencias de la subcolección;
/// [deleteBatch] las borra en una sola escritura atómica.
Future<void> removeUserDocumentTree<T>({
  required Future<List<T>> Function(String subcollection, int limit) fetchPage,
  required Future<void> Function(List<T> references) deleteBatch,
  required Future<void> Function() deleteProfileDocument,
  List<String> subcollections = userOwnedSubcollections,
  int batchSize = userTreeDeleteBatchSize,
}) async {
  for (final name in subcollections) {
    while (true) {
      final page = await fetchPage(name, batchSize);
      if (page.isEmpty) break;
      await deleteBatch(page);
      if (page.length < batchSize) break;
    }
  }
  await deleteProfileDocument();
}

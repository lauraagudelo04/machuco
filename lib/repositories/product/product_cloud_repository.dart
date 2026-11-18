import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:machuco/models/product/product.dart';
import 'package:machuco/service/firebase/firestore_collections.dart';

enum ProductCloudFailureType {
  permissionDenied,
  network,
  invalidData,
  unknown,
}

class ProductCloudException implements Exception {
  const ProductCloudException(this.type, this.message);

  final ProductCloudFailureType type;
  final String message;

  @override
  String toString() => message;
}

/// Contrato remoto de productos de un motel (`products/{productId}`).
///
/// El controller depende de esta interfaz para poder probarse sin Firebase.
abstract interface class ProductCloudRepository {
  Future<List<Product>> listByMotel(String motelId);

  /// Crea el producto y fija a [ownerId] (dueño del motel) como su creador.
  Future<void> create({required String ownerId, required Product product});

  /// Edita un producto sin cambiar su motel ni su propietario.
  Future<void> update(Product product);

  Future<void> delete(String productId);
}

class FirestoreProductCloudRepository implements ProductCloudRepository {
  FirestoreProductCloudRepository({
    FirebaseFirestore? firestore,
    this.requestTimeout = const Duration(seconds: 10),
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final Duration requestTimeout;

  CollectionReference<Map<String, dynamic>> get _products =>
      _firestore.collection(FirestoreCollections.products);

  @override
  Future<List<Product>> listByMotel(String motelId) async {
    _validateId(motelId);
    try {
      final snapshot = await _products
          .where('motelId', isEqualTo: motelId)
          .get()
          .timeout(requestTimeout);
      return List.unmodifiable(
        snapshot.docs.map((doc) => _fromDocument(doc.id, doc.data())),
      );
    } on FirebaseException catch (error) {
      throw _map(error);
    } on TimeoutException {
      throw const ProductCloudException(
        ProductCloudFailureType.network,
        'Sin conexión: se muestran los productos guardados en este dispositivo.',
      );
    } on FormatException {
      throw const ProductCloudException(
        ProductCloudFailureType.invalidData,
        'Firebase devolvió productos con datos inválidos.',
      );
    }
  }

  @override
  Future<void> create({
    required String ownerId,
    required Product product,
  }) async {
    _validateId(ownerId);
    _validateId(product.id);
    _validateId(product.motelId);
    await _write(
      () => _products.doc(product.id).set({
        'ownerId': ownerId,
        'motelId': product.motelId,
        'name': product.name,
        'description': product.description,
        'price': product.price,
        'stock': product.stock,
        'isAvailable': product.isAvailable,
        if (product.imageUrl != null) 'imageUrl': product.imageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }),
      'guardar',
    );
  }

  @override
  Future<void> update(Product product) async {
    _validateId(product.id);
    await _write(
      () => _products.doc(product.id).update({
        'name': product.name,
        'description': product.description,
        'price': product.price,
        'stock': product.stock,
        'isAvailable': product.isAvailable,
        'imageUrl': product.imageUrl ?? FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }),
      'guardar',
    );
  }

  @override
  Future<void> delete(String productId) async {
    _validateId(productId);
    await _write(() => _products.doc(productId).delete(), 'eliminar');
  }

  Future<void> _write(Future<void> Function() action, String verb) async {
    try {
      await action().timeout(requestTimeout);
    } on FirebaseException catch (error) {
      throw _map(error);
    } on TimeoutException {
      throw ProductCloudException(
        ProductCloudFailureType.network,
        'Sin conexión: no se pudo $verb el producto. Inténtalo de nuevo.',
      );
    }
  }

  Product _fromDocument(String id, Map<String, dynamic> data) {
    final price = data['price'];
    final stock = data['stock'];
    final motelId = data['motelId'];
    final name = data['name'];
    if (price is! num ||
        stock is! num ||
        motelId is! String ||
        name is! String) {
      throw const FormatException('Producto inválido');
    }
    return Product(
      id: id,
      motelId: motelId,
      name: name,
      description: (data['description'] as String?) ?? '',
      price: price.toDouble(),
      stock: stock.toInt(),
      isAvailable: (data['isAvailable'] as bool?) ?? false,
      imageUrl: data['imageUrl'] as String?,
    );
  }

  void _validateId(String value) {
    if (value.trim().isEmpty || value != value.trim()) {
      throw const ProductCloudException(
        ProductCloudFailureType.invalidData,
        'Se requiere un identificador válido para sincronizar el producto.',
      );
    }
  }

  ProductCloudException _map(FirebaseException error) {
    debugPrint('Firestore products error: ${error.code}');
    return switch (error.code) {
      'permission-denied' || 'unauthenticated' => const ProductCloudException(
        ProductCloudFailureType.permissionDenied,
        'No tienes permisos para gestionar los productos de este motel.',
      ),
      'unavailable' || 'deadline-exceeded' => const ProductCloudException(
        ProductCloudFailureType.network,
        'Sin conexión con Firebase. Inténtalo de nuevo.',
      ),
      _ => const ProductCloudException(
        ProductCloudFailureType.unknown,
        'No se pudo sincronizar el producto con Firebase.',
      ),
    };
  }
}

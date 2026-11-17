import 'dart:convert';

import '../../models/product/product.dart';
import '../../repositories/product/product_cloud_repository.dart';
import '../../service/firebase/current_user.dart';
import '../../service/storage/local_preferences_service.dart';
import '../../service/storage/shared_preferences_local_service.dart';

class ProductController {
  ProductController({
    LocalPreferencesService? preferences,
    ProductCloudRepository? cloud,
    String? Function()? currentUserId,
  }) : _preferences =
           preferences ?? SharedPreferencesLocalService(namespace: 'products'),
       _cloud = cloud ?? _defaultCloud(),
       _currentUserId = currentUserId ?? (() => CurrentUser.uidOrNull),
       _products = List<Product>.of(_sharedProducts ?? _seedProducts);

  final LocalPreferencesService _preferences;
  final ProductCloudRepository? _cloud;
  final String? Function() _currentUserId;

  /// Firestore es la fuente de verdad. Sin Firebase inicializado (pruebas,
  /// modo demo) el controller trabaja solo con el almacenamiento local.
  static ProductCloudRepository? _defaultCloud() {
    try {
      return FirestoreProductCloudRepository();
    } catch (_) {
      return null;
    }
  }
  final List<Product> _products;

  static const String _productsKey = 'catalog';

  static List<Product>? _sharedProducts;

  static const List<Product> _seedProducts = [
    Product(
      id: 'product-001',
      motelId: '1',
      name: 'Preservativos (Caja x 3)',
      description:
          'Preservativos de látex lubricados para la protección y tranquilidad en la pareja.',
      price: 15000,
      stock: 12,
      isAvailable: true,
    ),
    Product(
      id: 'product-002',
      motelId: '1',
      name: 'Lubricante Íntimo (50 ml)',
      description:
          'Gel a base de agua diseñado para reducir la fricción y aumentar el confort.',
      price: 25000,
      stock: 8,
      isAvailable: true,
    ),
    Product(
      id: 'product-007',
      motelId: '1',
      name: 'Anillo Vibrador',
      description:
          'Accesorio elástico con motor vibrador para estimulación de la pareja durante la relación.',
      price: 35000,
      stock: 8,
      isAvailable: true,
    ),
    Product(
      id: 'product-003',
      motelId: '1',
      name: 'Bebida Energizante (473 ml)',
      description:
          'Bebida fría para recuperar energía y mantener la vitalidad.',
      price: 12000,
      stock: 20,
      isAvailable: true,
    ),
    Product(
      id: 'product-004',
      motelId: '2',
      name: 'Cerveza Corona (330 ml)',
      description:
          'Cerveza rubia bien fría, ideal para refrescarse y acompañar el momento.',
      price: 8000,
      stock: 0,
      isAvailable: false,
    ),
    Product(
      id: 'product-005',
      motelId: '2',
      name: 'balas vibradoras',
      description:
          'Discreto y potente estimulador de tamaño compacto, perfecto para intensificar el encuentro en pareja.',
      price: 45000,
      stock: 15,
      isAvailable: true,
    ),
    Product(
      id: 'product-006',
      motelId: '2',
      name: 'Dados Eróticos (Juego)',
      description:
          'Divertido juego de pareja que brilla en la oscuridad para explorar nuevas dinámicas.',
      price: 3500,
      stock: 10,
      isAvailable: true,
    ),
    Product(
      id: 'product-009',
      motelId: '3',
      name: 'Cerveza Pilsen (330 ml)',
      description:
          'Cerveza rubia bien fría, ideal para refrescarse y acompañar el momento.',
      price: 8000,
      stock: 0,
      isAvailable: false,
    ),
    Product(
      id: 'product-008',
      motelId: '3',
      name: 'Mini Vibrador Clásico',
      description:
          'Juguete estimulador de silicona suave, discreto y con múltiples velocidades. Ideal para explorar nuevas dinámicas en pareja.',
      price: 55000,
      stock: 10,
      isAvailable: true,
    ),
    Product(
      id: 'product-010',
      motelId: '3',
      name: 'Preservativos (Caja x 3)',
      description:
          'Preservativos de látex lubricados para la protección y tranquilidad en la pareja.',
      price: 15000,
      stock: 12,
      isAvailable: true,
    ),
  ];

  /// Carga el catálogo local y, si se indica [motelId], lo sincroniza con
  /// Firestore. Si la nube no responde se conserva la copia local y el motivo
  /// queda en [lastSyncError]; no se lanza para que la pantalla siga usable.
  Future<void> loadProducts({String? motelId}) async {
    await _loadLocal();
    if (motelId != null) {
      await _syncMotelFromCloud(motelId);
    }
  }

  /// Último error de sincronización con Firestore, o `null` si fue exitosa.
  String? lastSyncError;

  Future<void> _syncMotelFromCloud(String motelId) async {
    final cloud = _cloud;
    if (cloud == null || _currentUserId() == null) return;
    try {
      final remote = await cloud.listByMotel(motelId);
      lastSyncError = null;
      _products
        ..removeWhere((product) => product.motelId == motelId)
        ..addAll(remote);
      await _persist();
    } on ProductCloudException catch (error) {
      lastSyncError = error.message;
    }
  }

  Future<void> _loadLocal() async {
    if (_sharedProducts != null) {
      _products
        ..clear()
        ..addAll(_sharedProducts!);
      return;
    }

    final raw = await _preferences.getString(_productsKey);
    if (raw == null || raw.isEmpty) {
      _sharedProducts = List<Product>.of(_seedProducts);
      await _persist();
    } else {
      final decoded = (jsonDecode(raw) as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(Product.fromJson)
          .toList();
      _sharedProducts = decoded;
    }

    _products
      ..clear()
      ..addAll(_sharedProducts!);
  }

  List<Product> get products => List.unmodifiable(_products);

  List<Product> getProductsByMotel(String motelId) {
    return _products.where((product) => product.motelId == motelId).toList();
  }

  Product? getProductById(String productId) {
    try {
      return _products.firstWhere((product) => product.id == productId);
    } catch (_) {
      return null;
    }
  }

  /// Escribe en Firestore antes que en local: si falla (permisos, red) la
  /// excepción llega a la pantalla y la copia local no queda desalineada.
  bool get _writesToCloud => _cloud != null && _currentUserId() != null;

  Future<void> createProduct(Product product) async {
    if (_writesToCloud) {
      await _cloud!.create(ownerId: _currentUserId()!, product: product);
    }
    _products.add(product);
    await _persist();
  }

  Future<void> updateProduct(Product product) async {
    final index = _products.indexWhere((item) => item.id == product.id);
    if (index == -1) {
      throw StateError('No existe un producto con id: ${product.id}');
    }
    if (_writesToCloud) {
      await _cloud!.update(product);
    }
    _products[index] = product;
    await _persist();
  }

  Future<void> deleteProduct(String productId) async {
    if (!_products.any((product) => product.id == productId)) {
      throw StateError('No existe un producto con id: $productId');
    }
    if (_writesToCloud) {
      await _cloud!.delete(productId);
    }
    final before = _products.length;
    _products.removeWhere((product) => product.id == productId);
    if (_products.length == before) {
      throw StateError('No existe un producto con id: $productId');
    }
    await _persist();
  }

  // GET /products?motelId={motelId}&isAvailable={isAvailable}
  Future<List<Product>> restGetProducts({
    String? motelId,
    bool? isAvailable,
  }) async {
    await loadProducts();
    return _products.where((product) {
      final byMotel = motelId == null || product.motelId == motelId;
      final byState = isAvailable == null || product.isAvailable == isAvailable;
      return byMotel && byState;
    }).toList();
  }

  // GET /products/{id}
  Future<Product?> restGetProductById(String id) async {
    await loadProducts();
    return getProductById(id);
  }

  // POST /products
  Future<Product> restCreateProduct(Product product) async {
    await loadProducts();
    await createProduct(product);
    return product;
  }

  // PUT /products/{id}
  Future<Product> restUpdateProduct(String id, Product product) async {
    await loadProducts();
    if (id != product.id) {
      throw ArgumentError('El id de la ruta no coincide con el body');
    }
    await updateProduct(product);
    return product;
  }

  // DELETE /products/{id}
  Future<void> restDeleteProduct(String id) async {
    await loadProducts();
    await deleteProduct(id);
  }

  // PATCH /products/{id}/availability
  Future<Product> restPatchAvailability({
    required String id,
    required bool isAvailable,
  }) async {
    await loadProducts();
    final product = getProductById(id);
    if (product == null) {
      throw StateError('No existe un producto con id: $id');
    }
    final updated = product.copyWith(isAvailable: isAvailable);
    await updateProduct(updated);
    return updated;
  }

  Future<void> _persist() async {
    final payload = jsonEncode(
      _products.map((product) => product.toJson()).toList(),
    );
    await _preferences.setString(_productsKey, payload);
    _sharedProducts = List<Product>.of(_products);
  }
}

import '../../models/product/product.dart';

class ProductController {
  final List<Product> _products = [
    // =========================
    // MOTEL 1
    // =========================
    const Product(
      id: 'product-001',
      motelId: '1',
      name: 'Preservativos (Caja x 3)',
      description: 'Preservativos de látex lubricados para la protección y tranquilidad en la pareja.',
      price: 15000,
      stock: 12,
      isAvailable: true,
    ),
    const Product(
      id: 'product-002',
      motelId: '1',
      name: 'Lubricante Íntimo (50 ml)',
      description: 'Gel a base de agua diseñado para reducir la fricción y aumentar el confort.',
      price: 25000,
      stock: 8,
      isAvailable: true,
    ),
    const Product(
      id: 'product-002',
      motelId: '1',
      name: 'Anillo Vibrador',
      description: 'Accesorio elástico con motor vibrador para estimulación de la pareja durante la relación.',
      price: 35000,
      stock: 8,
      isAvailable: true,
    ),
    const Product(
      id: 'product-003',
      motelId: '1',
      name: 'Bebida Energizante (473 ml)',
      description: 'Bebida fría para recuperar energía y mantener la vitalidad.',
      price: 12000,
      stock: 20,
      isAvailable: true,
    ),

    // =========================
    // MOTEL 2
    // =========================
    const Product(
      id: 'product-004',
      motelId: '2',
      name: 'Cerveza Corona (330 ml)',
      description: 'Cerveza rubia bien fría, ideal para refrescarse y acompañar el momento.',
      price: 8000,
      stock: 0,
      isAvailable: false,
    ),
    const Product(
      id: 'product-005',
      motelId: '2',
      name: 'balas vibradoras',
      description: 'Discreto y potente estimulador de tamaño compacto, perfecto para intensificar el encuentro en pareja.',
      price: 45000,
      stock: 15,
      isAvailable: true,
    ),
    const Product(
      id: 'product-006',
      motelId: '2',
      name: 'Dados Eróticos (Juego)',
      description: 'Divertido juego de pareja que brilla en la oscuridad para explorar nuevas dinámicas.',
      price: 3500,
      stock: 10,
      isAvailable: true,
    ),

    // =========================
    // MOTEL 3
    // =========================
    const Product(
      id: 'product-004',
      motelId: '3',
      name: 'Cerveza Pilsen (330 ml)',
      description: 'Cerveza rubia bien fría, ideal para refrescarse y acompañar el momento.',
      price: 8000,
      stock: 0,
      isAvailable: false,
    ),
    const Product(
      id: 'product-008',
      motelId: '3',
      name: 'Mini Vibrador Clásico',
      description: 'Juguete estimulador de silicona suave, discreto y con múltiples velocidades. Ideal para explorar nuevas dinámicas en pareja.',
      price: 55000,
      stock: 10,
      isAvailable: true,
    ),
    const Product(
      id: 'product-001',
      motelId: '3',
      name: 'Preservativos (Caja x 3)',
      description: 'Preservativos de látex lubricados para la protección y tranquilidad en la pareja.',
      price: 15000,
      stock: 12,
      isAvailable: true,
    ),
  ];

  // =========================================================
  // GETTERS
  // =========================================================

  /// Obtiene todos los productos.
  List<Product> get products => List.unmodifiable(_products);

  /// Obtiene los productos pertenecientes a un motel.
  List<Product> getProductsByMotel(String motelId) {
    return _products
        .where((product) => product.motelId == motelId)
        .toList();
  }

  /// Obtiene un producto por su ID.
  Product? getProductById(String productId) {
    try {
      return _products.firstWhere(
        (product) => product.id == productId,
      );
    } catch (_) {
      return null;
    }
  }

  // =========================================================
  // CREATE
  // =========================================================

  /// Crea un nuevo producto.
  void createProduct(Product product) {
    _products.add(product);
  }

  // =========================================================
  // UPDATE
  // =========================================================

  /// Actualiza un producto existente.
  void updateProduct(Product product) {
    final index = _products.indexWhere(
      (item) => item.id == product.id,
    );

    if (index == -1) {
      return;
    }

    _products[index] = product;
  }

  // =========================================================
  // DELETE
  // =========================================================

  /// Elimina un producto por su ID.
  void deleteProduct(String productId) {
    _products.removeWhere(
      (product) => product.id == productId,
    );
  }
}

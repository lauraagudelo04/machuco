import '../../models/product/product.dart';

class ProductService {
  ProductService();

  final List<Product> _products = [
    const Product(
      id: 'product-001',
      motelId: 'motel-001',
      name: 'Gaseosa',
      description: 'Bebida fría de 400 ml',
      price: 6000,
      stock: 12,
      isAvailable: true,
    ),
    const Product(
      id: 'product-002',
      motelId: 'motel-001',
      name: 'Papas',
      description: 'Snack personal',
      price: 4500,
      stock: 8,
      isAvailable: true,
    ),
    const Product(
      id: 'product-003',
      motelId: 'motel-001',
      name: 'Kit de aseo',
      description: 'Kit básico para huéspedes',
      price: 12000,
      stock: 0,
      isAvailable: false,
    ),
    const Product(
      id: 'product-004',
      motelId: 'motel-001',
      name: 'Agua',
      description: 'Botella de agua de 600 ml',
      price: 3000,
      stock: 20,
      isAvailable: true,
    ),
    const Product(
      id: 'product-005',
      motelId: 'motel-001',
      name: 'Chocolate',
      description: 'Barra de chocolate',
      price: 5000,
      stock: 15,
      isAvailable: true,
    ),
  ];

  Future<List<Product>> getProducts({
    String? motelId,
  }) async {
    await Future<void>.delayed(
      const Duration(milliseconds: 300),
    );

    if (motelId == null) {
      return List<Product>.from(_products);
    }

    return _products
        .where((product) => product.motelId == motelId)
        .toList();
  }

  Future<Product> createProduct(Product product) async {
    await Future<void>.delayed(
      const Duration(milliseconds: 300),
    );

    _products.add(product);

    return product;
  }

  Future<Product> updateProduct(Product product) async {
    await Future<void>.delayed(
      const Duration(milliseconds: 300),
    );

    final index = _products.indexWhere(
          (item) => item.id == product.id,
    );

    if (index == -1) {
      throw Exception('Producto no encontrado');
    }

    _products[index] = product;

    return product;
  }

  Future<void> deleteProduct(String productId) async {
    await Future<void>.delayed(
      const Duration(milliseconds: 300),
    );

    final index = _products.indexWhere(
          (product) => product.id == productId,
    );

    if (index == -1) {
      throw Exception('Producto no encontrado');
    }

    _products.removeAt(index);
  }
}
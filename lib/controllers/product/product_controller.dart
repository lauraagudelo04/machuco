import 'package:flutter/foundation.dart';

import '../../models/product/product.dart';

class ProductController extends ChangeNotifier {
  final Map<String, Product> _products = {
    'product-001': const Product(
      id: 'product-001',
      motelId: 'motel-001',
      name: 'Gaseosa',
      description: 'Bebida fría de 400 ml',
      price: 6000,
      stock: 12,
      isAvailable: true,
    ),
    'product-002': const Product(
      id: 'product-002',
      motelId: 'motel-001',
      name: 'Papas',
      description: 'Snack personal',
      price: 4500,
      stock: 8,
      isAvailable: true,
    ),
    'product-003': const Product(
      id: 'product-003',
      motelId: 'motel-001',
      name: 'Kit de aseo',
      description: 'Kit básico para huéspedes',
      price: 12000,
      stock: 0,
      isAvailable: false,
    ),
    'product-004': const Product(
      id: 'product-004',
      motelId: 'motel-001',
      name: 'Agua',
      description: 'Botella de agua de 600 ml',
      price: 3000,
      stock: 20,
      isAvailable: true,
    ),
    'product-005': const Product(
      id: 'product-005',
      motelId: 'motel-001',
      name: 'Chocolate',
      description: 'Barra de chocolate',
      price: 5000,
      stock: 15,
      isAvailable: true,
    ),
  };

  List<Product> get products => _products.values.toList();

  List<Product> getProductsByMotel(String motelId) {
    return _products.values
        .where((product) => product.motelId == motelId)
        .toList();
  }

  void createProduct(Product product) {
    _products[product.id] = product;
    notifyListeners();
  }

  void updateProduct(Product product) {
    if (!_products.containsKey(product.id)) return;

    _products[product.id] = product;
    notifyListeners();
  }

  void deleteProduct(String productId) {
    _products.remove(productId);
    notifyListeners();
  }

  Product? getProductById(String productId) {
    return _products[productId];
  }
}
import 'package:flutter/foundation.dart';

import '../../models/product/product.dart';
import '../../service/product/product_service.dart';

class ProductController extends ChangeNotifier {
  ProductController({
    ProductService? productService,
  }) : _productService = productService ?? ProductService();

  final ProductService _productService;

  List<Product> _products = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Product> get products => List.unmodifiable(_products);

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  bool get hasProducts => _products.isNotEmpty;

  Future<void> loadProducts({
    String? motelId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _products = await _productService.getProducts(
        motelId: motelId,
      );
    } catch (_) {
      _errorMessage = 'No fue posible cargar los productos.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createProduct(Product product) async {
    _errorMessage = null;

    try {
      final createdProduct = await _productService.createProduct(
        product,
      );

      _products = [
        ..._products,
        createdProduct,
      ];

      notifyListeners();
      return true;
    } catch (_) {
      _errorMessage = 'No fue posible crear el producto.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProduct(Product product) async {
    _errorMessage = null;

    try {
      final updatedProduct = await _productService.updateProduct(
        product,
      );

      _products = _products.map((item) {
        if (item.id == updatedProduct.id) {
          return updatedProduct;
        }

        return item;
      }).toList();

      notifyListeners();
      return true;
    } catch (_) {
      _errorMessage = 'No fue posible actualizar el producto.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteProduct(String productId) async {
    _errorMessage = null;

    try {
      await _productService.deleteProduct(productId);

      _products = _products
          .where((product) => product.id != productId)
          .toList();

      notifyListeners();
      return true;
    } catch (_) {
      _errorMessage = 'No fue posible eliminar el producto.';
      notifyListeners();
      return false;
    }
  }
}
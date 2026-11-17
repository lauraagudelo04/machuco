import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/product/product_controller.dart';
import 'package:machuco/models/product/product.dart';
import 'package:machuco/repositories/product/product_cloud_repository.dart';
import 'package:machuco/service/storage/local_preferences_service.dart';

class _MemoryPrefs implements LocalPreferencesService {
  final Map<String, Object> _data = {};
  @override
  String get namespace => 'test';
  @override
  Future<String?> getString(String key) async => _data[key] as String?;
  @override
  Future<void> setString(String key, String value) async => _data[key] = value;
  @override
  noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeCloud implements ProductCloudRepository {
  final Map<String, Product> remote = {};
  final List<String> calls = [];
  bool failReads = false;
  String? lastOwner;

  @override
  Future<List<Product>> listByMotel(String motelId) async {
    if (failReads) {
      throw const ProductCloudException(
        ProductCloudFailureType.network,
        'sin red',
      );
    }
    return remote.values.where((p) => p.motelId == motelId).toList();
  }

  @override
  Future<void> create({required String ownerId, required Product product}) async {
    calls.add('create');
    lastOwner = ownerId;
    remote[product.id] = product;
  }

  @override
  Future<void> update(Product product) async {
    calls.add('update');
    remote[product.id] = product;
  }

  @override
  Future<void> delete(String productId) async {
    calls.add('delete');
    remote.remove(productId);
  }
}

Product _p(String id, String motel) => Product(
  id: id,
  name: 'n$id',
  description: '',
  price: 10,
  stock: 2,
  isAvailable: true,
  motelId: motel,
);

void main() {
  late _FakeCloud cloud;
  late ProductController controller;

  setUp(() {
    cloud = _FakeCloud();
    controller = ProductController(
      preferences: _MemoryPrefs(),
      cloud: cloud,
      currentUserId: () => 'owner-1',
    );
  });

  test('syncs a motel catalog from the cloud, replacing local copies', () async {
    cloud.remote['a'] = _p('a', 'motel-x');
    await controller.loadProducts(motelId: 'motel-x');
    expect(controller.getProductsByMotel('motel-x').map((p) => p.id), ['a']);
    expect(controller.lastSyncError, isNull);
  });

  test('keeps the local copy when the cloud fails', () async {
    cloud.failReads = true;
    await controller.loadProducts(motelId: '1');
    expect(controller.getProductsByMotel('1'), isNotEmpty);
    expect(controller.lastSyncError, 'sin red');
  });

  test('writes go to the cloud with the signed-in owner', () async {
    await controller.loadProducts();
    await controller.restCreateProduct(_p('n1', 'motel-x'));
    expect(cloud.lastOwner, 'owner-1');
    await controller.restPatchAvailability(id: 'n1', isAvailable: false);
    await controller.restDeleteProduct('n1');
    expect(cloud.calls, ['create', 'update', 'delete']);
    expect(controller.getProductById('n1'), isNull);
  });

  test('without a session it only writes locally', () async {
    final local = ProductController(
      preferences: _MemoryPrefs(),
      cloud: cloud,
      currentUserId: () => null,
    );
    await local.restCreateProduct(_p('n2', 'motel-x'));
    expect(cloud.calls, isEmpty);
    expect(local.getProductById('n2'), isNotNull);
  });
}

import 'package:flutter/material.dart';

import '../../controllers/product/product_controller.dart';
import '../../core/design_system/design_system.dart';
import '../../models/product/product.dart';
import 'product_detail_page.dart';
import 'product_form_page.dart';

class ProductListView extends StatefulWidget {
  const ProductListView({super.key});

  @override
  State<ProductListView> createState() => _ProductListViewState();
}

class _ProductListViewState extends State<ProductListView> {
  late final ProductController _controller;

  @override
  void initState() {
    super.initState();

    _controller = ProductController();

    _controller.loadProducts(
      motelId: 'motel-001',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openCreateView() async {
    final product = await Navigator.of(context).push<Product>(
      MaterialPageRoute(
        builder: (_) => const ProductFormView(
          motelId: 'motel-001',
        ),
      ),
    );

    if (!mounted || product == null) return;

    final success = await _controller.createProduct(product);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Producto creado correctamente.'
              : 'No fue posible crear el producto.',
        ),
      ),
    );
  }

  Future<void> _openEditView(Product product) async {
    final updatedProduct =
    await Navigator.of(context).push<Product>(
      MaterialPageRoute(
        builder: (_) => ProductFormView(
          motelId: product.motelId,
          product: product,
        ),
      ),
    );

    if (!mounted || updatedProduct == null) return;

    final success = await _controller.updateProduct(
      updatedProduct,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Producto actualizado correctamente.'
              : 'No fue posible actualizar el producto.',
        ),
      ),
    );
  }

  Future<void> _openDetailView(Product product) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailView(
          product: product,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Product product) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text(
          '¿Deseas eliminar “${product.name}” del catálogo?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(false);
            },
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(true);
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (!mounted || shouldDelete != true) return;

    final success = await _controller.deleteProduct(
      product.id,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '${product.name} fue eliminado.'
              : 'No fue posible eliminar el producto.',
        ),
      ),
    );
  }

  String _formatPrice(double value) {
    final text = value.toStringAsFixed(0);
    final buffer = StringBuffer();

    for (var i = 0; i < text.length; i++) {
      if (i > 0 && (text.length - i) % 3 == 0) {
        buffer.write('.');
      }

      buffer.write(text[i]);
    }

    return '\$${buffer.toString()}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Productos'),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Agregar producto',
        onPressed: _openCreateView,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, child) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final horizontalPadding = constraints.maxWidth < 360
                    ? AppSpacing.screenCompact
                    : AppSpacing.screen;

                if (_controller.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (_controller.errorMessage != null) {
                  return AppEmptyState(
                    icon: Icons.error_outline,
                    title: 'No se pudieron cargar los productos',
                    message: _controller.errorMessage!,
                    actionLabel: 'Reintentar',
                    onAction: () {
                      _controller.loadProducts(
                        motelId: 'motel-001',
                      );
                    },
                  );
                }

                if (_controller.products.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'No hay productos',
                    message:
                    'Agrega el primer producto al catálogo del motel.',
                    actionLabel: 'Agregar producto',
                    onAction: _openCreateView,
                  );
                }

                return ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    AppSpacing.s5,
                    horizontalPadding,
                    AppSpacing.s12,
                  ),
                  itemCount: _controller.products.length,
                  separatorBuilder: (_, __) => const SizedBox(
                    height: AppSpacing.s3,
                  ),
                  itemBuilder: (context, index) {
                    final product = _controller.products[index];

                    return _ProductCard(
                      product: product,
                      priceText: _formatPrice(product.price),
                      onTap: () => _openDetailView(product),
                      onEdit: () => _openEditView(product),
                      onDelete: () => _confirmDelete(product),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.priceText,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Product product;
  final String priceText;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: AppCard(
        semanticLabel: 'Producto ${product.name}',
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: context.appColors.mediaFallback,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.inventory_2_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style:
                          Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      StatusBadge(
                        status: product.isAvailable &&
                            product.stock > 0
                            ? AppStatus.available
                            : AppStatus.outOfService,
                        size: StatusBadgeSize.extraSmall,
                      ),
                    ],
                  ),
                  if (product.description.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.s1),
                    Text(
                      product.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                      Theme.of(context).textTheme.bodySmall?.copyWith(
                        color:
                        context.appColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.s2),
                  Wrap(
                    spacing: AppSpacing.s3,
                    runSpacing: AppSpacing.s1,
                    children: [
                      Text(
                        priceText,
                        style:
                        Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Stock: ${product.stock}',
                        style:
                        Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.appColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AppIconButton(
                        icon: Icons.edit_outlined,
                        tooltip: 'Editar ${product.name}',
                        onPressed: onEdit,
                      ),
                      const SizedBox(width: AppSpacing.s2),
                      AppIconButton(
                        icon: Icons.delete_outline,
                        tooltip: 'Eliminar ${product.name}',
                        variant: AppIconButtonVariant.destructive,
                        onPressed: onDelete,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
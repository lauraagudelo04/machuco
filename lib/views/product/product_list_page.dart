import 'package:flutter/material.dart';
import 'package:machuco/views/product/product_form_page.dart';

import '../../controllers/product/product_controller.dart';
import '../../core/design_system/design_system.dart';
import '../../models/product/product.dart';
import 'product_detail_page.dart';

class ProductListView extends StatelessWidget {
  const ProductListView({super.key, required this.motelId});

  final String motelId;

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
    return _ProductListViewBody(motelId: motelId, formatPrice: _formatPrice);
  }
}

class _ProductListViewBody extends StatefulWidget {
  const _ProductListViewBody({
    required this.motelId,
    required this.formatPrice,
  });

  final String motelId;
  final String Function(double value) formatPrice;

  @override
  State<_ProductListViewBody> createState() => _ProductListViewBodyState();
}

class _ProductListViewBodyState extends State<_ProductListViewBody> {
  late final ProductController _controller;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = ProductController();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _controller.loadProducts();
    } catch (error) {
      _error = 'No fue posible cargar los productos.';
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openDetailView(Product product) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProductDetailView(product: product)),
    );
  }

  Future<void> _openCreateView() async {
    final created = await Navigator.of(context).push<Product>(
      MaterialPageRoute(
        builder: (_) => ProductFormView(motelId: widget.motelId),
      ),
    );
    if (created == null) return;
    try {
      await _controller.restCreateProduct(created);
      if (!mounted) return;
      setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _openEditView(Product product) async {
    final edited = await Navigator.of(context).push<Product>(
      MaterialPageRoute(
        builder: (_) =>
            ProductFormView(motelId: product.motelId, product: product),
      ),
    );
    if (edited == null) return;
    try {
      await _controller.restUpdateProduct(product.id, edited);
      if (!mounted) return;
      setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _confirmDelete(Product product) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('¿Deseas eliminar “${product.name}” del catálogo?'),
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

    if (shouldDelete != true) return;

    try {
      await _controller.restDeleteProduct(product.id);
      if (!mounted) return;
      setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _toggleAvailability(Product product) async {
    try {
      await _controller.restPatchAvailability(
        id: product.id,
        isAvailable: !product.isAvailable,
      );
      if (!mounted) return;
      setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = _controller.getProductsByMotel(widget.motelId);

    return Scaffold(
      appBar: AppBar(title: const Text('Productos')),

      // ---------------------------------------------------------
      // BOTÓN CREAR PRODUCTO
      // ---------------------------------------------------------
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateView,
        icon: const Icon(Icons.add),
        label: const Text('Crear producto'),
      ),

      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth < 360
                ? AppSpacing.screenCompact
                : AppSpacing.screen;

            if (_isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (_error != null) {
              return AppEmptyState(
                icon: Icons.error_outline,
                title: 'Error al cargar productos',
                message: _error!,
              );
            }

            if (products.isEmpty) {
              return AppEmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'No hay productos',
                message: 'Este motel no tiene productos registrados.',
              );
            }

            return ListView.separated(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                AppSpacing.s5,
                horizontalPadding,
                AppSpacing.s12,
              ),
              itemCount: products.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s3),
              itemBuilder: (context, index) {
                final product = products[index];

                return _ProductCard(
                  product: product,
                  priceText: widget.formatPrice(product.price),

                  // Ver detalle
                  onTap: () => _openDetailView(product),

                  // Editar
                  onEdit: () => _openEditView(product),

                  // Eliminar
                  onDelete: () => _confirmDelete(product),
                  onToggleAvailability: () => _toggleAvailability(product),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ============================================================
// PRODUCT CARD
// ============================================================

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.priceText,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleAvailability,
  });

  final Product product;
  final String priceText;

  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleAvailability;

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
            // ------------------------------------------------
            // ICONO DEL PRODUCTO
            // ------------------------------------------------
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

            // ------------------------------------------------
            // INFORMACIÓN
            // ------------------------------------------------
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nombre + estado
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),

                      StatusBadge(
                        status: product.isAvailable
                            ? AppStatus.available
                            : AppStatus.outOfService,
                        size: StatusBadgeSize.extraSmall,
                      ),
                    ],
                  ),

                  // Descripción
                  if (product.description.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.s1),

                    Text(
                      product.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.appColors.textSecondary,
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.s2),

                  // Precio + stock
                  Wrap(
                    spacing: AppSpacing.s3,
                    runSpacing: AppSpacing.s1,
                    children: [
                      Text(
                        priceText,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      Text(
                        'Stock: ${product.stock}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.appColors.textMuted,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.s3),

                  // ------------------------------------------------
                  // BOTONES
                  // ------------------------------------------------
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AppIconButton(
                        icon: product.isAvailable
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        tooltip: product.isAvailable
                            ? 'Desactivar ${product.name}'
                            : 'Activar ${product.name}',
                        onPressed: onToggleAvailability,
                      ),

                      const SizedBox(width: AppSpacing.s2),

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

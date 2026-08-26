import 'package:flutter/material.dart';

import '../../core/design_system/design_system.dart';
import 'product_form_page.dart';

class ProductListView extends StatefulWidget {
  const ProductListView({super.key});

  @override
  State<ProductListView> createState() => _ProductListViewState();
}

class _ProductListViewState extends State<ProductListView> {
  final List<ProductViewData> _products = [
    const ProductViewData(
      name: 'Gaseosa',
      description: 'Bebida fría de 400 ml',
      price: 6000,
      stock: 12,
      isAvailable: true,
    ),
    const ProductViewData(
      name: 'Papas',
      description: 'Snack personal',
      price: 4500,
      stock: 8,
      isAvailable: true,
    ),
    const ProductViewData(
      name: 'Kit de aseo',
      description: 'Kit básico para huéspedes',
      price: 12000,
      stock: 0,
      isAvailable: false,
    ),
  ];

  Future<void> _openCreateView() async {
    final product = await Navigator.of(context).push<ProductViewData>(
      MaterialPageRoute(
        builder: (_) => const ProductFormView(),
      ),
    );

    if (!mounted || product == null) return;
    setState(() => _products.add(product));
  }

  Future<void> _openEditView(int index) async {
    final product = await Navigator.of(context).push<ProductViewData>(
      MaterialPageRoute(
        builder: (_) => ProductFormView(product: _products[index]),
      ),
    );

    if (!mounted || product == null) return;
    setState(() => _products[index] = product);
  }

  Future<void> _confirmDelete(int index) async {
    final product = _products[index];

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text(
          '¿Deseas eliminar “${product.name}” del catálogo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (!mounted || shouldDelete != true) return;

    setState(() => _products.removeAt(index));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${product.name} fue eliminado.')),
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth < 360
                ? AppSpacing.screenCompact
                : AppSpacing.screen;

            if (_products.isEmpty) {
              return AppEmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'No hay productos',
                message: 'Agrega el primer producto al catálogo del motel.',
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
              itemCount: _products.length,
              separatorBuilder: (_, __) => const SizedBox(
                height: AppSpacing.s3,
              ),
              itemBuilder: (context, index) {
                final product = _products[index];
                return _ProductCard(
                  product: product,
                  priceText: _formatPrice(product.price),
                  onEdit: () => _openEditView(index),
                  onDelete: () => _confirmDelete(index),
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
    required this.onEdit,
    required this.onDelete,
  });

  final ProductViewData product;
  final String priceText;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AppCard(
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
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    StatusBadge(
                      status: product.isAvailable && product.stock > 0
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
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.appColors.textSecondary,
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
    );
  }
}

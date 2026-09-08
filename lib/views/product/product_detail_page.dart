import 'package:flutter/material.dart';

import '../../core/design_system/design_system.dart';
import '../../models/product/product.dart';

class ProductDetailView extends StatelessWidget {
  const ProductDetailView({
    super.key,
    required this.product,
  });

  final Product product;

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
    final isAvailable = product.isAvailable && product.stock > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del producto'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 560,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 180,
                          decoration: BoxDecoration(
                            color: context.appColors.mediaFallback,
                            borderRadius: BorderRadius.circular(
                              AppRadius.md,
                            ),
                          ),
                          child: Icon(
                            Icons.inventory_2_outlined,
                            size: 64,
                            color: Theme.of(context)
                                .colorScheme
                                .primary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s5),
                        Text(
                          product.name,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall,
                        ),
                        const SizedBox(height: AppSpacing.s2),
                        StatusBadge(
                          status: isAvailable
                              ? AppStatus.available
                              : AppStatus.outOfService,
                        ),
                        const SizedBox(height: AppSpacing.s5),
                        Text(
                          'Descripción',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.s1),
                        Text(
                          product.description.isEmpty
                              ? 'Sin descripción.'
                              : product.description,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                            color: context.appColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s5),
                        const Divider(),
                        const SizedBox(height: AppSpacing.s4),
                        _DetailRow(
                          label: 'Precio',
                          value: _formatPrice(product.price),
                        ),
                        const SizedBox(height: AppSpacing.s3),
                        _DetailRow(
                          label: 'Stock',
                          value: product.stock.toString(),
                        ),
                        const SizedBox(height: AppSpacing.s3),
                        _DetailRow(
                          label: 'Estado',
                          value: isAvailable
                              ? 'Disponible'
                              : 'No disponible',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
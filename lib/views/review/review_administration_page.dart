import 'dart:async';

import 'package:flutter/material.dart';
import 'package:machuco/controllers/review/review_administration_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/widgets/review/admin_review_card.dart';
import 'package:machuco/widgets/review/review_stat_card.dart';
import 'package:machuco/widgets/review/review_reply_sheet.dart';

/// Panel de administración de reseñas. No contiene datos quemados ni
/// lógica de negocio: todo vive en [ReviewAdministrationController].
class ReviewAdministrationPage extends StatefulWidget {
  const ReviewAdministrationPage({super.key, this.controller});

  final ReviewAdministrationController? controller;

  @override
  State<ReviewAdministrationPage> createState() =>
      _ReviewAdministrationPageState();
}

class _ReviewAdministrationPageState extends State<ReviewAdministrationPage> {
  final TextEditingController _searchController = TextEditingController();

  late final ReviewAdministrationController _controller;
  bool _controllerInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controllerInitialized) return;
    _controller = widget.controller ?? ReviewAdministrationController.instance;
    _controllerInitialized = true;
    _controller.addListener(_refresh);
    unawaited(_controller.loadReviews());
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _confirmDelete(AdminReviewEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar reseña'),
        content: Text(
          'Esta acción eliminará de forma permanente la reseña de ${entry.review.author}. ¿Deseas continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Eliminar',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) _controller.delete(entry);
  }

  void _openReplySheet(AdminReviewEntry entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => ReviewReplySheet(
        entry: entry,
        onSubmit: (message) => _controller.reply(entry, message),
      ),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reseñas')),
      body: SafeArea(
        child: _controller.isLoading
            ? const Center(child: CircularProgressIndicator())
            : _controller.errorMessage != null
            ? _buildErrorState(context)
            : _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final entries = _controller.entries;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screen),
      children: [
        _buildHeader(context),
        const SizedBox(height: AppSpacing.s5),
        _buildStatistics(context),
        const SizedBox(height: AppSpacing.s5),
        AppTextField(
          label: 'Buscar reseña',
          controller: _searchController,
          hint: 'Autor, título o contenido...',
          prefixIcon: const Icon(Icons.search),
          onChanged: _controller.setQuery,
        ),
        const SizedBox(height: AppSpacing.s4),
        _buildFilterChips(context),
        const SizedBox(height: AppSpacing.s5),
        Row(
          children: [
            Expanded(
              child: Text(
                'Reseñas',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            Text(
              '${entries.length} registros',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: context.appColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s3),
        if (entries.isEmpty)
          _buildEmptyState(context)
        else
          ...entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s3),
              child: AdminReviewCard(
                entry: entry,
                onToggleVisibility: () => _controller.toggleVisibility(entry),
                onDismissReport: () => _controller.dismissReport(entry),
                onReply: () => _openReplySheet(entry),
                onDelete: () => _confirmDelete(entry),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Administración',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.s1),
        Text('Reseñas', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.s2),
      
      ],
    );
  }

  Widget _buildStatistics(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        final cards = [
          ReviewStatCard(
            icon: Icons.reviews_outlined,
            title: 'Total',
            value: '${_controller.totalCount}',
          ),
          ReviewStatCard(
            icon: Icons.star_rounded,
            title: 'Promedio',
            value: _controller.averageRating.toStringAsFixed(1),
          ),
          ReviewStatCard(
            icon: Icons.flag_outlined,
            title: 'Reportadas',
            value: '${_controller.reportedCount}',
          ),
        ];
        if (compact) {
          return Column(
            children: [
              for (final card in cards) ...[
                card,
                const SizedBox(height: AppSpacing.s2),
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              Expanded(child: cards[i]),
              if (i != cards.length - 1) const SizedBox(width: AppSpacing.s3),
            ],
          ],
        );
      },
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: ReviewFilter.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.s2),
        itemBuilder: (context, index) {
          final filterValue = ReviewFilter.values[index];
          final selected = _controller.filter == filterValue;
          return ChoiceChip(
            label: Text(filterValue.label),
            selected: selected,
            onSelected: (_) => _controller.setFilter(filterValue),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s6),
        child: Column(
          children: [
            Icon(
              Icons.reviews_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: AppSpacing.s3),
            Text('No hay reseñas', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.s2),
            Text(
              'No encontramos reseñas que coincidan con la búsqueda o el filtro.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: context.appColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: AppSpacing.s3),
            Text(_controller.errorMessage!),
            const SizedBox(height: AppSpacing.s3),
            AppButton(label: 'Reintentar', onPressed: _controller.loadReviews),
          ],
        ),
      ),
    );
  }
}
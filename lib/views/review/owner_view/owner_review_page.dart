import 'dart:async';

import 'package:flutter/material.dart';
import 'package:machuco/controllers/review/owner_review_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/widgets/review/owner_review_card.dart';
import 'package:machuco/widgets/review/owner_review_reply_sheet.dart';
import 'package:machuco/widgets/review/review_stat_card.dart';

class OwnerReviewPage extends StatefulWidget {
  const OwnerReviewPage({super.key, this.controller});

  final OwnerReviewController? controller;

  @override
  State<OwnerReviewPage> createState() => _OwnerReviewPageState();
}

class _OwnerReviewPageState extends State<OwnerReviewPage> {
  final TextEditingController _searchController = TextEditingController();

  late final OwnerReviewController _controller;
  bool _controllerInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controllerInitialized) return;
    _controller = widget.controller ?? OwnerReviewController.instance;
    _controllerInitialized = true;
    _controller.addListener(_refresh);
    unawaited(_controller.loadReviews());
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _openReplySheet(OwnerReviewEntry entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => OwnerReviewReplySheet(
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
      appBar: AppBar(title: const Text('Reseñas de mis moteles')),
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
        _buildMotelFilterChips(context),
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
        if (_controller.myMotels.isEmpty)
          _buildNoMotelsState(context)
        else if (entries.isEmpty)
          _buildEmptyState(context)
        else
          ...entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s3),
              child: OwnerReviewCard(
                entry: entry,
                onReply: () => _openReplySheet(entry),
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
        Text('Mis moteles', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.s1),
        Text('Reseñas', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.s2),
      ],
    );
  }

  Widget _buildStatistics(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ReviewStatCard(
            icon: Icons.reviews_outlined,
            title: 'Total',
            value: '${_controller.totalCount}',
          ),
        ),
        const SizedBox(width: AppSpacing.s3),
        Expanded(
          child: ReviewStatCard(
            icon: Icons.star_rounded,
            title: 'Promedio',
            value: _controller.averageRating.toStringAsFixed(1),
          ),
        ),
      ],
    );
  }

  Widget _buildMotelFilterChips(BuildContext context) {
    final motels = _controller.myMotels;
    if (motels.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: motels.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.s2),
        itemBuilder: (context, index) {
          if (index == 0) {
            final selected = _controller.selectedMotelId == null;
            return ChoiceChip(
              label: const Text('Todos'),
              selected: selected,
              onSelected: (_) => _controller.selectMotel(null),
            );
          }
          final motel = motels[index - 1];
          final selected = _controller.selectedMotelId == motel.id;
          return ChoiceChip(
            label: Text(motel.name),
            selected: selected,
            onSelected: (_) => _controller.selectMotel(motel.id),
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

  Widget _buildNoMotelsState(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s6),
        child: Column(
          children: [
            Icon(
              Icons.storefront_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: AppSpacing.s3),
            Text(
              'Aún no tienes moteles registrados',
              style: Theme.of(context).textTheme.titleLarge,
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
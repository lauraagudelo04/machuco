import 'package:flutter/material.dart';
import '../../core/design_system/design_system.dart';

enum ReviewModerationStatus { visible, hidden, reported }

extension ReviewModerationStatusData on ReviewModerationStatus {
  String get label => switch (this) {
        ReviewModerationStatus.visible => 'Visible',
        ReviewModerationStatus.hidden => 'Oculta',
        ReviewModerationStatus.reported => 'Reportada',
      };

  
  Color get color => switch (this) {
        ReviewModerationStatus.visible => AppColors.available,
        ReviewModerationStatus.hidden => AppColors.blocked,
        ReviewModerationStatus.reported => AppColors.maintenance,
      };

  IconData get icon => switch (this) {
        ReviewModerationStatus.visible => Icons.visibility_outlined,
        ReviewModerationStatus.hidden => Icons.visibility_off_outlined,
        ReviewModerationStatus.reported => Icons.flag_outlined,
      };
}


class AdminReview {
  AdminReview({
    required this.id,
    required this.author,
    required this.motelName,
    required this.rating,
    required this.comment,
    required this.date,
    this.status = ReviewModerationStatus.visible,
    this.reportReason,
    this.adminReply,
  });

  final String id;
  final String author;
  final String motelName;
  final int rating;
  final String comment;
  final DateTime date;
  ReviewModerationStatus status;
  String? reportReason;
  String? adminReply;
}

enum _ReviewFilter { all, visible, hidden, reported }

extension on _ReviewFilter {
  String get label => switch (this) {
        _ReviewFilter.all => 'Todas',
        _ReviewFilter.visible => 'Visibles',
        _ReviewFilter.hidden => 'Ocultas',
        _ReviewFilter.reported => 'Reportadas',
      };
}

class ReviewAdministrationPage extends StatefulWidget {
  const ReviewAdministrationPage({super.key});

  @override
  State<ReviewAdministrationPage> createState() =>
      _ReviewAdministrationPageState();
}

class _ReviewAdministrationPageState extends State<ReviewAdministrationPage> {
  final TextEditingController _searchController = TextEditingController();
  _ReviewFilter _filter = _ReviewFilter.all;

  final List<AdminReview> _reviews = [
    AdminReview(
      id: 'r1',
      author: 'Carlos M.',
      motelName: 'Motel Aurora',
      rating: 5,
      comment:
          'Las habitaciones estaban limpias y el personal fue muy amable. La cama súper cómoda.',
      date: DateTime(2026, 7, 20),
      status: ReviewModerationStatus.visible,
    ),
    AdminReview(
      id: 'r2',
      author: 'Luisa P.',
      motelName: 'Motel Aurora',
      rating: 4,
      comment: 'Está bien ubicado, cerca de todo. El precio es justo para lo que ofrece.',
      date: DateTime(2026, 6, 15),
      status: ReviewModerationStatus.visible,
    ),
    AdminReview(
      id: 'r3',
      author: 'Roberto V.',
      motelName: 'Villa Nocturna',
      rating: 1,
      comment: 'Contiene lenguaje ofensivo hacia el personal y datos de contacto personales.',
      date: DateTime(2026, 8, 2),
      status: ReviewModerationStatus.reported,
      reportReason: 'Lenguaje inapropiado y datos personales expuestos',
    ),
    AdminReview(
      id: 'r4',
      author: 'Andrea T.',
      motelName: 'Suites del Parque',
      rating: 2,
      comment: 'El wifi no funcionó en toda la estadía, aunque el resto estuvo bien.',
      date: DateTime(2026, 5, 3),
      status: ReviewModerationStatus.hidden,
      adminReply: 'Gracias por tu comentario, ya lo trasladamos al motel para su revisión.',
    ),
  ];

  List<AdminReview> get _filteredReviews {
    final query = _searchController.text.trim().toLowerCase();
    return _reviews.where((review) {
      final matchesFilter = switch (_filter) {
        _ReviewFilter.all => true,
        _ReviewFilter.visible => review.status == ReviewModerationStatus.visible,
        _ReviewFilter.hidden => review.status == ReviewModerationStatus.hidden,
        _ReviewFilter.reported => review.status == ReviewModerationStatus.reported,
      };
      if (!matchesFilter) return false;
      if (query.isEmpty) return true;
      return review.author.toLowerCase().contains(query) ||
          review.motelName.toLowerCase().contains(query) ||
          review.comment.toLowerCase().contains(query);
    }).toList();
  }

  int get _reportedCount =>
      _reviews.where((r) => r.status == ReviewModerationStatus.reported).length;

  double get _averageRating => _reviews.isEmpty
      ? 0
      : _reviews.map((r) => r.rating).reduce((a, b) => a + b) / _reviews.length;

  void _toggleVisibility(AdminReview review) {
    setState(() {
      review.status = review.status == ReviewModerationStatus.hidden
          ? ReviewModerationStatus.visible
          : ReviewModerationStatus.hidden;
    });
  }

  void _dismissReport(AdminReview review) {
    setState(() {
      review.status = ReviewModerationStatus.visible;
      review.reportReason = null;
    });
  }

  Future<void> _confirmDelete(AdminReview review) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar reseña'),
        content: Text(
          'Esta acción eliminará de forma permanente la reseña de ${review.author}. ¿Deseas continuar?',
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
    if (confirmed == true) {
      setState(() => _reviews.removeWhere((r) => r.id == review.id));
    }
  }

  void _openReplySheet(AdminReview review) {
    final replyController = TextEditingController(text: review.adminReply ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s5,
            AppSpacing.s1,
            AppSpacing.s5,
            AppSpacing.s6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Responder reseña',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.s2),
              Text(
                'Tu respuesta será visible públicamente para ${review.author}.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.appColors.textSecondary,
                    ),
              ),
              const SizedBox(height: AppSpacing.s4),
              AppTextField(
                label: 'Respuesta',
                controller: replyController,
                hint: 'Escribe una respuesta profesional...',
                maxLines: 4,
              ),
              const SizedBox(height: AppSpacing.s5),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Cancelar',
                      variant: AppButtonVariant.secondary,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s3),
                  Expanded(
                    child: AppButton(
                      label: 'Publicar',
                      onPressed: () {
                        final reply = replyController.text.trim();
                        if (reply.isEmpty) return;
                        setState(() => review.adminReply = reply);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reseñas')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            _buildHeader(context),
            const SizedBox(height: AppSpacing.s5),
            _buildStatistics(context),
            const SizedBox(height: AppSpacing.s5),
            AppTextField(
              label: 'Buscar reseña',
              controller: _searchController,
              hint: 'Autor, motel o contenido...',
              prefixIcon: const Icon(Icons.search),
              onChanged: (_) => setState(() {}),
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
                  '${_filteredReviews.length} registros',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: context.appColors.textSecondary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s3),
            if (_filteredReviews.isEmpty)
              _buildEmptyState(context)
            else
              ..._filteredReviews.map(
                (review) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s3),
                  child: _AdminReviewCard(
                    review: review,
                    onToggleVisibility: () => _toggleVisibility(review),
                    onDismissReport: () => _dismissReport(review),
                    onReply: () => _openReplySheet(review),
                    onDelete: () => _confirmDelete(review),
                  ),
                ),
              ),
          ],
        ),
      ),
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
        Text(
          'Reseñas',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.s2),
        Text(
          'Modera los comentarios de los clientes: oculta, responde o elimina reseñas.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.appColors.textSecondary,
              ),
        ),
      ],
    );
  }

  Widget _buildStatistics(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        final cards = [
          _StatisticCard(
            icon: Icons.reviews_outlined,
            title: 'Total',
            value: '${_reviews.length}',
          ),
          _StatisticCard(
            icon: Icons.star_rounded,
            title: 'Promedio',
            value: _averageRating.toStringAsFixed(1),
          ),
          _StatisticCard(
            icon: Icons.flag_outlined,
            title: 'Reportadas',
            value: '$_reportedCount',
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
        itemCount: _ReviewFilter.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.s2),
        itemBuilder: (context, index) {
          final filter = _ReviewFilter.values[index];
          final selected = _filter == filter;
          return ChoiceChip(
            label: Text(filter.label),
            selected: selected,
            onSelected: (_) => setState(() => _filter = filter),
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
            Text(
              'No hay reseñas',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.s2),
            Text(
              'No encontramos reseñas que coincidan con la búsqueda o el filtro.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.appColors.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatisticCard extends StatelessWidget {
  const _StatisticCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.appColors.textSecondary,
                      ),
                ),
                const SizedBox(height: AppSpacing.s1),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminReviewCard extends StatelessWidget {
  const _AdminReviewCard({
    required this.review,
    required this.onToggleVisibility,
    required this.onDismissReport,
    required this.onReply,
    required this.onDelete,
  });

  final AdminReview review;
  final VoidCallback onToggleVisibility;
  final VoidCallback onDismissReport;
  final VoidCallback onReply;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isReported = review.status == ReviewModerationStatus.reported;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AuthorAvatar(initial: review.author.isNotEmpty ? review.author[0] : '?'),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.author,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${review.motelName} · ${_formatDate(review.date)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.appColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              _StarRow(rating: review.rating),
              PopupMenuButton<String>(
                tooltip: 'Acciones',
                onSelected: (value) {
                  switch (value) {
                    case 'toggle':
                      onToggleVisibility();
                      break;
                    case 'dismiss':
                      onDismissReport();
                      break;
                    case 'reply':
                      onReply();
                      break;
                    case 'delete':
                      onDelete();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'toggle',
                    child: ListTile(
                      leading: Icon(
                        review.status == ReviewModerationStatus.hidden
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      title: Text(
                        review.status == ReviewModerationStatus.hidden
                            ? 'Mostrar'
                            : 'Ocultar',
                      ),
                    ),
                  ),
                  if (isReported)
                    const PopupMenuItem(
                      value: 'dismiss',
                      child: ListTile(
                        leading: Icon(Icons.task_alt_outlined),
                        title: Text('Descartar reporte'),
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'reply',
                    child: ListTile(
                      leading: Icon(Icons.reply_outlined),
                      title: Text('Responder'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('Eliminar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          Text(
            review.comment,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.appColors.textSecondary,
                ),
          ),
          if (isReported && review.reportReason != null) ...[
            const SizedBox(height: AppSpacing.s3),
            _InlineNote(
              icon: Icons.flag_outlined,
              color: AppColors.maintenance,
              label: 'Motivo del reporte',
              text: review.reportReason!,
            ),
          ],
          if (review.adminReply != null) ...[
            const SizedBox(height: AppSpacing.s3),
            _InlineNote(
              icon: Icons.support_agent_outlined,
              color: AppColors.violet,
              label: 'Respuesta del administrador',
              text: review.adminReply!,
            ),
          ],
          const SizedBox(height: AppSpacing.s3),
          StatusBadgeGeneric(status: review.status),
        ],
      ),
    );
  }
}

/// Insignia de estado adaptada al enum propio de moderación de reseñas,
/// manteniendo la misma apariencia visual que [StatusBadge].
class StatusBadgeGeneric extends StatelessWidget {
  const StatusBadgeGeneric({super.key, required this.status});

  final ReviewModerationStatus status;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Estado: ${status.label}',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: status.color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s3,
              vertical: AppSpacing.s1,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(status.icon, size: 16, color: status.color),
                const SizedBox(width: AppSpacing.s1),
                Text(
                  status.label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: status.color,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineNote extends StatelessWidget {
  const _InlineNote({
    required this.icon,
    required this.color,
    required this.label,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: .24)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: AppSpacing.s2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    text,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.appColors.textSecondary,
                        ),
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

class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating, this.size = 16});

  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
          size: size,
          color: i < rating ? const Color(0xFFFFB300) : context.appColors.textMuted,
        ),
      ),
    );
  }
}

class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: AppGradients.primary,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      alignment: Alignment.center,
      child: Text(
        initial.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
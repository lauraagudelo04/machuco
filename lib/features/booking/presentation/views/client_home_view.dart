import 'package:flutter/material.dart';
import 'package:machuco/controllers/booking/client_view/client_booking_ui_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/booking/booking_checkout_data.dart';
import 'package:machuco/routes/routes.dart';
import 'package:machuco/views/booking/booking_view_support.dart';
import 'package:machuco/widgets/booking/booking_widgets.dart';
import 'package:machuco/widgets/layout/responsive_content.dart';

class ClientHomeView extends StatefulWidget {
  const ClientHomeView({super.key});

  @override
  State<ClientHomeView> createState() => _ClientHomeViewState();
}

class _ClientHomeViewState extends State<ClientHomeView> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Encuentra tu estadía'),
        actions: [
          IconButton(
            onPressed: () => _showPlaceholder('Notificaciones'),
            tooltip: 'Notificaciones',
            icon: const Icon(Icons.notifications_none_outlined),
          ),
          IconButton(
            onPressed: () => _showPlaceholder('Perfil'),
            tooltip: 'Perfil',
            icon: const Icon(Icons.account_circle_outlined),
          ),
          const SizedBox(width: AppSpacing.s2),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: ResponsiveContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Busca por motel, zona o servicio',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s5),
                    Text(
                      'Moteles disponibles',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.s2),
                    Text(
                      'Opciones seleccionadas cerca de ti',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.appColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 900
                            ? 3
                            : constraints.maxWidth >= 600
                            ? 2
                            : 1;
                        const spacing = AppSpacing.s4;
                        final width =
                            (constraints.maxWidth - (columns - 1) * spacing) /
                            columns;
                        return Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          children: [
                            for (final motel
                                in ClientBookingUiController.motels)
                              SizedBox(
                                width: width,
                                child: _MotelCard(
                                  motel: motel,
                                  onBook: () => Navigator.pushNamed(
                                    context,
                                    AppRoutes.createBooking,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BookingNavigationBar(
        selectedIndex: 0,
        onSelected: (index) {
          if (index == 1) {
            Navigator.pushReplacementNamed(context, AppRoutes.clientBookings);
          }
          if (index == 2) {
            Navigator.pushReplacementNamed(context, AppRoutes.clientPqrs);
          }
        },
      ),
    );
  }

  void _showPlaceholder(String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$name estará disponible próximamente.')),
    );
  }
}

class _MotelCard extends StatelessWidget {
  const _MotelCard({required this.motel, required this.onBook});
  final ClientMotelPreview motel;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 132,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _colorsFor(motel.id),
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: const Icon(
            Icons.hotel_outlined,
            size: 54,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: AppSpacing.s3),
        Row(
          children: [
            Expanded(
              child: Text(
                motel.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(width: AppSpacing.s2),
            StatusBadge(
              status: motel.isAvailable
                  ? AppStatus.available
                  : AppStatus.occupied,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s1),
        Text(
          motel.location,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: context.appColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.s3),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.s3,
          runSpacing: AppSpacing.s2,
          children: [
            Text(
              'Desde ${formatBookingMoney(motel.startingPrice)} / ${motel.rateLabel}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            AppButton(
              label: 'Reservar',
              expanded: false,
              size: AppButtonSize.medium,
              onPressed: onBook,
            ),
          ],
        ),
      ],
    ),
  );

  List<Color> _colorsFor(String motelId) => switch (motelId) {
    'luna-roja' => const [Color(0xFFBE123C), AppColors.rose],
    'paraiso-elite' => const [Color(0xFF0369A1), Color(0xFF38BDF8)],
    _ => const [AppColors.violet, AppColors.fuchsia],
  };
}

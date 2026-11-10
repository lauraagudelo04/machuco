import 'package:flutter/material.dart';
import 'package:machuco/controllers/auth/login_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/views/login/auth_controller_factory.dart';
import 'package:machuco/views/login/logout_navigation.dart';
import 'package:machuco/widgets/auth/delete_account_sheet.dart';
import 'package:machuco/widgets/layout/responsive_content.dart';

/// Argumentos de ruta de [AccountReviewPage]: solo datos simples.
class AccountReviewArgs {
  const AccountReviewArgs({
    required this.email,
    this.rejected = false,
    this.rejectionReason,
  });

  final String email;
  final bool rejected;
  final String? rejectionReason;
}

/// Estado de la cuenta de un propietario: "En revisión" o "Solicitud
/// rechazada" (con el motivo escrito por el administrador).
class AccountReviewPage extends StatefulWidget {
  const AccountReviewPage({super.key, required this.args, this.controller});

  final AccountReviewArgs args;
  final LoginController? controller;

  @override
  State<AccountReviewPage> createState() => _AccountReviewPageState();
}

class _AccountReviewPageState extends State<AccountReviewPage> {
  late final LoginController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? buildLoginController();
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await _controller.logout();
    if (!mounted) return;
    goToLogin(context);
  }

  Future<void> _deleteAccount() async {
    final deleted = await showDeleteAccountSheet(
      context,
      controller: _controller,
    );
    if (!deleted || !mounted) return;
    goToLogin(context, notice: 'Tu cuenta fue eliminada');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rejected = widget.args.rejected;
    final reason = widget.args.rejectionReason;
    final color = rejected
        ? theme.colorScheme.error
        : theme.colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(rejected ? 'Solicitud rechazada' : 'Cuenta en revisión'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveContent(
            maxWidth: 560,
            padding: const EdgeInsets.all(AppSpacing.s6),
            child: Semantics(
              liveRegion: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    rejected
                        ? Icons.cancel_outlined
                        : Icons.hourglass_top_outlined,
                    size: AppSpacing.s12 + AppSpacing.s8,
                    color: color,
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    rejected
                        ? 'Tu solicitud fue rechazada'
                        : 'Tu cuenta está en revisión',
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  Text(
                    rejected
                        ? 'Un administrador revisó tu solicitud de propietario '
                              'y no pudo aprobarla.'
                        : 'Un administrador está revisando tu solicitud de '
                              'propietario. Podrás ingresar en cuanto sea '
                              'aprobada.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: context.appColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (rejected && reason != null && reason.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.s4),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Motivo', style: theme.textTheme.labelLarge),
                          const SizedBox(height: AppSpacing.s1),
                          Text(reason, style: theme.textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  ],
                  if (widget.args.email.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      'Correo registrado',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: context.appColors.textMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      widget.args.email,
                      style: theme.textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.s6),
                  AppButton(
                    label: 'Cerrar sesión',
                    variant: AppButtonVariant.secondary,
                    onPressed: _logout,
                  ),
                  if (!rejected) ...[
                    const SizedBox(height: AppSpacing.s2),
                    AppButton(
                      label: 'Eliminar cuenta',
                      icon: Icons.delete_outline,
                      variant: AppButtonVariant.destructive,
                      size: AppButtonSize.medium,
                      onPressed: _deleteAccount,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:machuco/controllers/auth/administrators_controller.dart';
import 'package:machuco/controllers/auth/login_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/database/repository/auth/administrators_repository.dart';
import 'package:machuco/models/auth/user_profile.dart';
import 'package:machuco/views/admin_access/administrator_format.dart';
import 'package:machuco/views/login/auth_controller_factory.dart';
import 'package:machuco/views/login/logout_navigation.dart';
import 'package:machuco/widgets/auth/administrator_contact_fields.dart';
import 'package:machuco/widgets/auth/auth_date_format.dart';
import 'package:machuco/widgets/auth/auth_notice.dart';
import 'package:machuco/widgets/auth/delete_account_sheet.dart';
import 'package:machuco/widgets/auth/delete_administrator_sheet.dart';
import 'package:machuco/widgets/layout/responsive_content.dart';

/// Argumentos de ruta del detalle: solo identificadores y el controlador
/// compartido con la lista (no se envía el modelo completo).
class AdministratorDetailArgs {
  const AdministratorDetailArgs({
    required this.uid,
    required this.controller,
    this.currentUid,
  });

  final String uid;
  final AdministratorsController controller;
  final String? currentUid;
}

/// Detalle de un administrador con "Editar" y "Eliminar cuenta".
class AdministratorDetailPage extends StatefulWidget {
  const AdministratorDetailPage({
    super.key,
    required this.uid,
    required this.controller,
    this.currentUid,
    this.catalog,
  });

  final String uid;
  final AdministratorsController controller;
  final String? currentUid;

  /// Aporta los indicativos y elimina la cuenta propia. Si es `null` se crea
  /// el de producción.
  final LoginController? catalog;

  @override
  State<AdministratorDetailPage> createState() =>
      _AdministratorDetailPageState();
}

class _AdministratorDetailPageState extends State<AdministratorDetailPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNames = TextEditingController();
  final _lastNames = TextEditingController();
  final _phone = TextEditingController();
  final _readOnlyEmail = TextEditingController();
  final _readOnlyRole = TextEditingController(text: 'Administrador');

  late final LoginController _catalog;
  late final bool _ownsCatalog;
  bool _editing = false;
  bool _preparingEdit = false;

  AdministratorsController get _controller => widget.controller;
  bool get _isMe => widget.uid == widget.currentUid;

  @override
  void initState() {
    super.initState();
    _ownsCatalog = widget.catalog == null;
    _catalog = widget.catalog ?? buildLoginController();
  }

  @override
  void dispose() {
    for (final c in [
      _firstNames,
      _lastNames,
      _phone,
      _readOnlyEmail,
      _readOnlyRole,
    ]) {
      c.dispose();
    }
    if (_ownsCatalog) _catalog.dispose();
    super.dispose();
  }

  Future<void> _startEdit(UserProfile profile) async {
    setState(() => _preparingEdit = true);
    if (_catalog.countryPhoneCodes.isEmpty) {
      await _catalog.loadCountryPhoneCodes();
    }
    for (final code in _catalog.countryPhoneCodes) {
      if (code.id == profile.phoneCountryCodeId) {
        await _catalog.selectCountryPhoneCode(code);
      }
    }
    if (!mounted) return;
    final dial = _catalog.selectedCountryPhoneCode?.dialCode;
    _firstNames.text = profile.firstNames ?? profile.fullName;
    _lastNames.text = profile.lastNames ?? '';
    _phone.text = dial != null && profile.phoneNumber.startsWith(dial)
        ? profile.phoneNumber.substring(dial.length)
        : profile.phoneNumber;
    _readOnlyEmail.text = profile.email;
    _controller.clearError();
    setState(() {
      _preparingEdit = false;
      _editing = true;
    });
  }

  Future<void> _save() async {
    if (_controller.isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final code = _catalog.selectedCountryPhoneCode;
    if (code == null) return;
    final ok = await _controller.update(
      widget.uid,
      firstNames: _firstNames.text,
      lastNames: _lastNames.text,
      phoneCode: code,
      phoneNumber: _phone.text,
    );
    if (!mounted) return;
    if (ok) {
      setState(() => _editing = false);
      _snack('Datos actualizados.');
    } else if (_controller.errorType == AdministratorsFailureType.notFound) {
      _snack(_controller.error ?? 'Esa cuenta ya no existe.');
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete(UserProfile profile) async {
    if (_isMe) {
      final deleted = await showDeleteAccountSheet(
        context,
        controller: _catalog,
        isAdministrator: true,
      );
      if (!deleted || !mounted) return;
      goToLogin(context, notice: 'Tu cuenta fue eliminada');
      return;
    }
    final result = await showDeleteAdministratorSheet(
      context,
      controller: _controller,
      uid: widget.uid,
      name: profile.fullName,
    );
    if (result == null || !mounted) return;
    _snack(
      result == DeleteAdministratorResult.deleted
          ? 'Administrador eliminado.'
          : 'Esa cuenta ya no existe. Actualizamos la lista.',
    );
    Navigator.of(context).pop();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del administrador')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([_controller, _catalog]),
          builder: (context, _) {
            final profile = _controller.findAdministrator(widget.uid);
            if (profile == null) {
              return AppEmptyState(
                icon: Icons.person_off_outlined,
                title: 'Administrador no disponible',
                message: 'Esta cuenta ya no existe.',
                actionLabel: 'Volver a la lista',
                onAction: () => Navigator.of(context).pop(),
              );
            }
            return SingleChildScrollView(
              child: ResponsiveContent(
                maxWidth: 560,
                padding: const EdgeInsets.all(AppSpacing.s4),
                child: _editing
                    ? _buildEditForm(context, profile)
                    : _buildDetails(context, profile),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDetails(BuildContext context, UserProfile profile) {
    final busy = _controller.isSubmitting || _preparingEdit;
    final created = profile.createdAt;
    final rows = <(String, String)>[
      ('Nombre', _isMe ? '${profile.fullName} (Tú)' : profile.fullName),
      ('Correo', profile.email),
      ('Celular', profile.phoneNumber),
      ('Rol', 'Administrador'),
      ('Estado', administratorStatusLabel(profile)),
      (
        'Fecha de creación',
        created == null ? 'Fecha no disponible' : formatDate(created.toLocal()),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (label, value) in rows) _DetailRow(label, value),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s5),
        AppButton(
          label: 'Editar',
          icon: Icons.edit_outlined,
          loading: _preparingEdit,
          onPressed: busy ? null : () => _startEdit(profile),
        ),
        const SizedBox(height: AppSpacing.s3),
        AppButton(
          label: 'Eliminar cuenta',
          icon: Icons.delete_outline,
          variant: AppButtonVariant.destructive,
          onPressed: busy ? null : () => _delete(profile),
        ),
      ],
    );
  }

  Widget _buildEditForm(BuildContext context, UserProfile profile) {
    final busy = _controller.isSubmitting;
    final error = _controller.error;
    final isNetwork =
        _controller.errorType == AdministratorsFailureType.network;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error != null) ...[
            AuthNotice(
              message: error,
              icon: isNetwork ? Icons.wifi_off_outlined : null,
              actionLabel: isNetwork ? 'Reintentar' : null,
              onAction: isNetwork ? _save : null,
            ),
            const SizedBox(height: AppSpacing.s4),
          ],
          AdministratorContactFields(
            catalog: _catalog,
            firstNames: _firstNames,
            lastNames: _lastNames,
            phone: _phone,
            enabled: !busy,
          ),
          const SizedBox(height: AppSpacing.s4),
          AppTextField(
            key: const ValueKey('readonly-email'),
            label: 'Correo electrónico (no editable)',
            controller: _readOnlyEmail,
            enabled: false,
          ),
          const SizedBox(height: AppSpacing.s4),
          AppTextField(
            key: const ValueKey('readonly-role'),
            label: 'Rol (no editable)',
            controller: _readOnlyRole,
            enabled: false,
          ),
          const SizedBox(height: AppSpacing.s5),
          AppButton(label: 'Guardar', loading: busy, onPressed: _save),
          const SizedBox(height: AppSpacing.s3),
          AppButton(
            label: 'Cancelar',
            variant: AppButtonVariant.secondary,
            onPressed: busy
                ? null
                : () {
                    _controller.clearError();
                    setState(() => _editing = false);
                  },
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s3),
      child: Semantics(
        label: '$label: $value',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: context.appColors.textMuted,
              ),
            ),
            Text(value, style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}

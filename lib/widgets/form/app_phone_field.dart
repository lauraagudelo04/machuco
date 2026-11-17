import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/auth/country_phone_code.dart';
import 'package:machuco/widgets/form/app_country_flag.dart';

/// Campo de celular con selector de indicativo por país.
///
/// Es genérico: recibe los indicativos por parámetro y no conoce Supabase,
/// SQLite ni el login, así cualquier funcionalidad (perfil, registro, PQRS)
/// puede reutilizarlo.
class AppPhoneField extends StatelessWidget {
  const AppPhoneField({
    super.key,
    required this.countryCodes,
    required this.selectedCountryCode,
    required this.onCountryCodeSelected,
    required this.phoneController,
    this.loading = false,
    this.errorMessage,
    this.phoneErrorText,
    this.onRetry,
    this.validator,
    this.textInputAction = TextInputAction.next,
    this.label = 'Celular',
    this.hint = '300 123 4567',
    this.onChanged,
    this.onSubmitted,
  });

  final List<CountryPhoneCode> countryCodes;
  final CountryPhoneCode? selectedCountryCode;
  final ValueChanged<CountryPhoneCode> onCountryCodeSelected;
  final TextEditingController phoneController;
  final bool loading;
  final String? errorMessage;

  /// Error del número nacional; se muestra bajo el campo para conservar el
  /// comportamiento de los formularios que validan fuera de un `Form`.
  final String? phoneErrorText;

  final VoidCallback? onRetry;
  final FormFieldValidator<String>? validator;
  final TextInputAction textInputAction;

  /// Etiqueta del campo numérico; otros módulos ya no hablan de "celular".
  final String label;

  /// Texto de ayuda del número nacional.
  final String hint;

  /// Se invoca en cada cambio del número nacional.
  final ValueChanged<String>? onChanged;

  /// Se invoca al confirmar el número nacional desde el teclado.
  final ValueChanged<String>? onSubmitted;

  Future<void> _openPicker(BuildContext context) async {
    final selected = await showModalBottomSheet<CountryPhoneCode>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CountryCodePickerSheet(
        countryCodes: countryCodes,
        selectedCountryCode: selectedCountryCode,
      ),
    );
    if (selected != null) {
      onCountryCodeSelected(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasError = errorMessage != null;
    final canPick = !loading && !hasError && countryCodes.isNotEmpty;

    final Widget dialCodeContent;
    if (loading) {
      dialCodeContent = const AppSkeleton(
        width: AppSpacing.s12,
        height: AppSpacing.s4,
      );
    } else if (hasError) {
      dialCodeContent = Icon(
        Icons.error_outline,
        color: Theme.of(context).colorScheme.error,
      );
    } else {
      final code = selectedCountryCode;
      dialCodeContent = code == null
          ? Text('—', style: textTheme.bodyLarge)
          : Semantics(
              label: '${code.countryName} ${code.dialCode}',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppCountryFlag(isoCode: code.isoCode),
                  const SizedBox(width: AppSpacing.s2),
                  Text(code.dialCode, style: textTheme.bodyLarge),
                ],
              ),
            );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              button: true,
              label: 'Seleccionar indicativo del país',
              child: InkWell(
                key: const ValueKey('phone-country-code-button'),
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: canPick ? () => _openPicker(context) : null,
                // Dentro de un Row el InputDecorator recibe ancho ilimitado y
                // rompe el layout; IntrinsicWidth lo ajusta a su contenido.
                child: IntrinsicWidth(
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Indicativo',
                      enabled: canPick,
                      suffixIcon: canPick
                          ? const Icon(Icons.arrow_drop_down)
                          : null,
                    ),
                    child: dialCodeContent,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s2),
            Expanded(
              child: AppTextField(
                label: label,
                hint: hint,
                controller: phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: textInputAction,
                autofillHints: const [AutofillHints.telephoneNumber],
                errorText: phoneErrorText,
                validator: validator,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
              ),
            ),
          ],
        ),
        if (hasError) ...[
          const SizedBox(height: AppSpacing.s2),
          Row(
            children: [
              Expanded(
                child: Text(
                  errorMessage!,
                  style: textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
              if (onRetry != null)
                TextButton(onPressed: onRetry, child: const Text('Reintentar')),
            ],
          ),
        ],
        if (selectedCountryCode?.isDevelopmentSeed ?? false) ...[
          const SizedBox(height: AppSpacing.s1),
          Text(
            'Indicativos de desarrollo: Supabase no está configurado.',
            style: textTheme.bodySmall?.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class _CountryCodePickerSheet extends StatefulWidget {
  const _CountryCodePickerSheet({
    required this.countryCodes,
    required this.selectedCountryCode,
  });

  final List<CountryPhoneCode> countryCodes;
  final CountryPhoneCode? selectedCountryCode;

  @override
  State<_CountryCodePickerSheet> createState() =>
      _CountryCodePickerSheetState();
}

class _CountryCodePickerSheetState extends State<_CountryCodePickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final results = widget.countryCodes
        .where((code) => code.matches(_query))
        .toList(growable: false);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.screen,
        right: AppSpacing.screen,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.s4,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Selecciona tu país', style: textTheme.titleMedium),
            const SizedBox(height: AppSpacing.s3),
            AppSearchField(
              label: 'Buscar país o indicativo',
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              onClear: _query.isEmpty
                  ? null
                  : () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
            ),
            const SizedBox(height: AppSpacing.s3),
            Flexible(
              child: results.isEmpty
                  ? const AppEmptyState(
                      icon: Icons.search_off,
                      title: 'Sin resultados',
                      message: 'No encontramos países con esa búsqueda.',
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final code = results[index];
                        final selected =
                            code.id == widget.selectedCountryCode?.id;
                        return ListTile(
                          leading: AppCountryFlag(
                            isoCode: code.isoCode,
                            width: AppSpacing.s8,
                            height: AppSpacing.s6,
                          ),
                          title: Text(code.countryName),
                          trailing: Text(
                            code.dialCode,
                            style: textTheme.bodyLarge,
                          ),
                          selected: selected,
                          onTap: () => Navigator.of(context).pop(code),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

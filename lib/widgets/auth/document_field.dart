import 'package:flutter/material.dart';
import 'package:machuco/controllers/auth/validators/document_number_validator.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/auth/document_type.dart';
import 'package:machuco/widgets/form/app_bottom_sheet.dart';

/// Selector de tipo de documento (hoja inferior, como el de indicativos) y
/// número, en una sola fila.
///
/// Es genérico: recibe los tipos por parámetro y no conoce Supabase ni el
/// login. Cubre los estados cargando, error (con "Reintentar") y vacío.
class DocumentField extends StatelessWidget {
  const DocumentField({
    super.key,
    required this.types,
    required this.selected,
    required this.onSelected,
    required this.numberController,
    this.loading = false,
    this.errorMessage,
    this.onRetry,
    this.legalRepresentative = false,
  });

  final List<DocumentTypeOption> types;
  final DocumentTypeOption? selected;
  final ValueChanged<DocumentTypeOption> onSelected;
  final TextEditingController numberController;
  final bool loading;
  final String? errorMessage;
  final VoidCallback? onRetry;

  /// Propietario jurídico: el documento es del representante legal.
  final bool legalRepresentative;

  static const emptyMessage =
      'No hay tipos de documento disponibles por ahora.';

  Future<void> _openPicker(BuildContext context) async {
    final picked = await AppBottomSheet.show<DocumentTypeOption>(
      context,
      title: 'Tipo de documento',
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final type in types)
            ListTile(
              key: ValueKey('document-type-option-${type.code}'),
              title: Text(type.name),
              trailing: Text(
                type.code,
                style: Theme.of(sheetContext).textTheme.bodyLarge,
              ),
              selected: type.id == selected?.id,
              onTap: () => Navigator.of(sheetContext).pop(type),
            ),
        ],
      ),
    );
    if (picked != null) onSelected(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = errorMessage != null;
    final isEmpty = !loading && !hasError && types.isEmpty;
    final canPick = !loading && !hasError && types.isNotEmpty;
    final current = selected;

    final Widget typeContent;
    if (loading) {
      typeContent = const AppSkeleton(
        width: AppSpacing.s12,
        height: AppSpacing.s4,
      );
    } else if (hasError || isEmpty) {
      typeContent = Icon(Icons.error_outline, color: theme.colorScheme.error);
    } else {
      typeContent = Text(
        current?.code ?? '—',
        style: theme.textTheme.bodyLarge,
      );
    }

    return Column(
      key: const ValueKey('document-field'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          legalRepresentative
              ? 'Documento de identidad (documento del representante legal)'
              : 'Documento de identidad',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: AppSpacing.s2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              button: true,
              label: 'Seleccionar tipo de documento',
              child: InkWell(
                key: const ValueKey('document-type-button'),
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: canPick ? () => _openPicker(context) : null,
                child: IntrinsicWidth(
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Tipo',
                      enabled: canPick,
                      suffixIcon: canPick
                          ? const Icon(Icons.arrow_drop_down)
                          : null,
                    ),
                    child: typeContent,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s2),
            Expanded(
              child: AppTextField(
                key: const ValueKey('document-number-field'),
                label: 'Número de documento',
                hint: current?.example,
                controller: numberController,
                enabled: canPick,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.next,
                // Se crea con el tipo actual: al cambiarlo se revalida.
                validator: DocumentNumberValidator.forType(current),
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
            ),
          ],
        ),
        if (hasError || isEmpty) ...[
          const SizedBox(height: AppSpacing.s2),
          Row(
            children: [
              Expanded(
                child: Text(
                  errorMessage ?? emptyMessage,
                  key: const ValueKey('document-types-message'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
              if (onRetry != null)
                TextButton(onPressed: onRetry, child: const Text('Reintentar')),
            ],
          ),
        ],
      ],
    );
  }
}

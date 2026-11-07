import 'package:flutter/material.dart';
import 'package:machuco/controllers/motel/phone_country_code_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/utils/motel_form_validators.dart';

/// Selector de indicativo telefónico + campo del número.
///
/// Carga el maestro de indicativos de país (Supabase + caché SQLite) y avisa
/// el código elegido con [onCallingCodeChanged] para que el formulario lo
/// concatene al guardar. Lo comparten los formularios de motel del propietario
/// y del administrador para que ambos muestren el mismo indicativo.
class PhoneNumberField extends StatefulWidget {
  const PhoneNumberField({
    super.key,
    required this.controller,
    required this.initialCallingCode,
    required this.onCallingCodeChanged,
    this.validator = MotelFormValidators.validatePhone,
  });

  /// Número de teléfono sin el indicativo.
  final TextEditingController controller;

  /// Indicativo con el que arranca el selector, por ejemplo `+57`.
  final String initialCallingCode;

  /// Se invoca cada vez que el usuario cambia el indicativo.
  final ValueChanged<String> onCallingCodeChanged;

  final FormFieldValidator<String>? validator;

  @override
  State<PhoneNumberField> createState() => _PhoneNumberFieldState();
}

class _PhoneNumberFieldState extends State<PhoneNumberField> {
  final PhoneCountryCodeController _countryCodeController =
      PhoneCountryCodeController.fromEnvironment();
  late String _selectedCallingCode = widget.initialCallingCode;

  @override
  void initState() {
    super.initState();
    _countryCodeController.load();
  }

  @override
  void dispose() {
    _countryCodeController.dispose();
    super.dispose();
  }

  void _selectCallingCode(String value) {
    if (value == _selectedCallingCode) return;
    setState(() => _selectedCallingCode = value);
    widget.onCallingCodeChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _countryCodeController,
      builder: (context, _) {
        final codes = _countryCodeController.countryCodes;
        final hasSelected = codes.any(
          (code) => code.callingCode == _selectedCallingCode,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: _countryCodeController.isLoading
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      : DropdownButtonFormField<String>(
                          initialValue: hasSelected
                              ? _selectedCallingCode
                              : null,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Indicativo',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          selectedItemBuilder: (context) => codes
                              .map((code) => Text(code.callingCode))
                              .toList(),
                          items: codes
                              .map(
                                (code) => DropdownMenuItem(
                                  value: code.callingCode,
                                  child: Text(
                                    '${code.countryName}  ${code.callingCode}',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) _selectCallingCode(value);
                          },
                        ),
                ),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: TextFormField(
                    controller: widget.controller,
                    keyboardType: TextInputType.phone,
                    validator: widget.validator,
                    decoration: InputDecoration(
                      labelText: 'Teléfono',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_countryCodeController.error != null && codes.isEmpty)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _countryCodeController.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _countryCodeController.refresh,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}

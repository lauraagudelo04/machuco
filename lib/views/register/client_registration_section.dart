import 'package:flutter/material.dart';
import 'package:machuco/controllers/auth/validators/auth_validators.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/widgets/auth/auth_date_format.dart';

/// Bloque propio del Cliente: fecha de nacimiento (texto + selector).
class ClientRegistrationSection extends StatelessWidget {
  const ClientRegistrationSection({
    super.key,
    required this.birthDateController,
  });

  final TextEditingController birthDateController;

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final current = AuthValidators.parseBirthDate(birthDateController.text);
    final picked = await showDatePicker(
      context: context,
      initialDate:
          current ?? DateTime(now.year - AuthValidators.minimumAge, 1, 1),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Fecha de nacimiento',
    );
    if (picked != null) {
      birthDateController.text = formatDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: 'Fecha de nacimiento',
      hint: 'dd/mm/aaaa',
      controller: birthDateController,
      keyboardType: TextInputType.datetime,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.birthday],
      validator: AuthValidators.birthDateText(),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      suffixIcon: IconButton(
        tooltip: 'Elegir fecha',
        onPressed: () => _pickDate(context),
        icon: const Icon(Icons.calendar_today_outlined),
      ),
    );
  }
}

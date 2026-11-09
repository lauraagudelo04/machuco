import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/design_system.dart';

/// Campo de contraseña con botón mostrar/ocultar.
class AuthPasswordField extends StatefulWidget {
  const AuthPasswordField({
    super.key,
    required this.controller,
    this.label = 'Contraseña',
    this.hint,
    this.validator,
    this.textInputAction = TextInputAction.next,
    this.autofillHints = const [AutofillHints.password],
    this.onSubmitted,
    this.onChanged,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final FormFieldValidator<String>? validator;
  final TextInputAction textInputAction;
  final Iterable<String> autofillHints;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  @override
  State<AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<AuthPasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: widget.label,
      hint: widget.hint,
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: !_visible,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      suffixIcon: IconButton(
        tooltip: _visible ? 'Ocultar contraseña' : 'Ver contraseña',
        onPressed: () => setState(() => _visible = !_visible),
        icon: Icon(
          _visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        ),
      ),
    );
  }
}

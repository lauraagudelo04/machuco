import 'package:flutter/material.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({super.key, required this.label, this.controller, this.hint, this.errorText, this.enabled = true, this.obscureText = false, this.keyboardType, this.textInputAction, this.autofillHints, this.prefixIcon, this.suffixIcon, this.onChanged, this.onSubmitted, this.maxLines = 1});
  final String label; final TextEditingController? controller; final String? hint; final String? errorText; final bool enabled; final bool obscureText; final TextInputType? keyboardType; final TextInputAction? textInputAction; final Iterable<String>? autofillHints; final Widget? prefixIcon; final Widget? suffixIcon; final ValueChanged<String>? onChanged; final ValueChanged<String>? onSubmitted; final int maxLines;
  @override Widget build(BuildContext context) => TextField(controller: controller, enabled: enabled, obscureText: obscureText, keyboardType: keyboardType, textInputAction: textInputAction, autofillHints: autofillHints, onChanged: onChanged, onSubmitted: onSubmitted, maxLines: maxLines, decoration: InputDecoration(labelText: label, hintText: hint, errorText: errorText, prefixIcon: prefixIcon, suffixIcon: suffixIcon));
}

class AppSearchField extends StatelessWidget {
  const AppSearchField({super.key, required this.label, this.controller, this.onChanged, this.onSubmitted, this.loading = false, this.onClear});
  final String label; final TextEditingController? controller; final ValueChanged<String>? onChanged; final ValueChanged<String>? onSubmitted; final bool loading; final VoidCallback? onClear;
  @override Widget build(BuildContext context) => AppTextField(label: label, controller: controller, textInputAction: TextInputAction.search, onChanged: onChanged, onSubmitted: onSubmitted, prefixIcon: const Icon(Icons.search), suffixIcon: loading ? const Padding(padding: EdgeInsets.all(14), child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))) : onClear == null ? null : IconButton(tooltip: 'Limpiar búsqueda', onPressed: onClear, icon: const Icon(Icons.close)));
}

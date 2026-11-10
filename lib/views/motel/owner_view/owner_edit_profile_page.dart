import 'package:flutter/material.dart';

import 'package:machuco/controllers/owner_management/owner_profile_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';

/// Edición del perfil del propietario.
///
/// Solo nombre y teléfono: `firestore.rules` no permite que el propio usuario
/// cambie el documento, el rol ni el estado de su cuenta.
class OwnerEditProfilePage extends StatefulWidget {
  const OwnerEditProfilePage({super.key, required this.controller});

  final OwnerProfileController controller;

  @override
  State<OwnerEditProfilePage> createState() => _OwnerEditProfilePageState();
}

class _OwnerEditProfilePageState extends State<OwnerEditProfilePage> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  String? _nameError;
  String? _phoneError;

  @override
  void initState() {
    super.initState();
    final profile = widget.controller.profile;
    _nameController = TextEditingController(text: profile?.fullName ?? '');
    _phoneController = TextEditingController(text: profile?.phoneNumber ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  bool _validate() {
    final name = _nameController.text.trim();
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    setState(() {
      _nameError = name.length < 3 ? 'Ingresa tu nombre completo.' : null;
      _phoneError = digits.length < 7 || digits.length > 15
          ? 'Ingresa un teléfono con indicativo, por ejemplo +573001234567.'
          : null;
    });
    return _nameError == null && _phoneError == null;
  }

  Future<void> _save() async {
    if (widget.controller.isSaving || !_validate()) return;

    final saved = await widget.controller.update(
      fullName: _nameController.text,
      phoneNumber: _phoneController.text,
    );
    if (!mounted) return;

    if (saved) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado correctamente.')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.controller.errorMessage ??
              'No se pudo guardar tu perfil. Intenta de nuevo.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final isSaving = widget.controller.isSaving;
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.screen),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppTextField(
                        label: 'Nombre completo',
                        controller: _nameController,
                        errorText: _nameError,
                        enabled: !isSaving,
                        keyboardType: TextInputType.name,
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      AppTextField(
                        label: 'Teléfono con indicativo',
                        controller: _phoneController,
                        hint: '+573001234567',
                        errorText: _phoneError,
                        enabled: !isSaving,
                        keyboardType: TextInputType.phone,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s6),
                AppButton(
                  label: 'Guardar cambios',
                  icon: Icons.check_outlined,
                  loading: isSaving,
                  onPressed: isSaving ? null : _save,
                ),
                const SizedBox(height: AppSpacing.s3),
                AppButton(
                  label: 'Cancelar',
                  variant: AppButtonVariant.secondary,
                  onPressed: isSaving
                      ? null
                      : () => Navigator.of(context).maybePop(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

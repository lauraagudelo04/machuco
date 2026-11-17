import 'package:flutter/material.dart';
import 'package:machuco/controllers/pqrs/pqrs_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/database/repository/pqrs/pqrs_repository.dart';
import 'package:machuco/models/pqrs/pqrs.dart';
import 'package:machuco/widgets/pqrs/pqrs_presentation.dart';
import 'package:machuco/widgets/pqrs/pqrs_state_views.dart';

/// Gives a PQRS screen its [PqrsController].
///
/// An injected [controller] is used as it is (tests, navigation from another
/// PQRS screen). Without one, the gate builds the controller of the signed-in
/// user with [loader] and disposes it with the screen. Without a session it
/// shows "Debes iniciar sesión"; with a session of another role than
/// [expectedRole] it shows an access notice. This is only courtesy: the real
/// authorization is in the Firestore rules.
class PqrsControllerGate extends StatefulWidget {
  const PqrsControllerGate({
    super.key,
    required this.title,
    required this.builder,
    this.expectedRole,
    this.controller,
    this.loader = PqrsController.forCurrentUser,
  });

  final String title;
  final PqrsActor? expectedRole;
  final PqrsController? controller;
  final Future<PqrsController> Function() loader;
  final Widget Function(BuildContext context, PqrsController controller)
  builder;

  @override
  State<PqrsControllerGate> createState() => _PqrsControllerGateState();
}

class _PqrsControllerGateState extends State<PqrsControllerGate> {
  PqrsController? _owned;
  PqrsFailure? _failure;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) _open();
  }

  Future<void> _open() async {
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      final controller = await widget.loader();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _owned = controller;
        _loading = false;
      });
    } on PqrsFailure catch (failure) {
      if (mounted) {
        setState(() {
          _failure = failure;
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _owned?.dispose();
    super.dispose();
  }

  Widget _scaffold(Widget body) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: SafeArea(child: body),
  );

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller ?? _owned;
    if (controller != null) {
      final expected = widget.expectedRole;
      if (expected != null && controller.role != expected) {
        return _scaffold(
          AppEmptyState(
            icon: Icons.lock_outline,
            title: 'Sin acceso a esta vista',
            message: controller.role == null
                ? 'Debes iniciar sesión'
                : 'Esta vista es para el perfil ${expected.label.toLowerCase()}.',
          ),
        );
      }
      return widget.builder(context, controller);
    }

    final failure = _failure;
    if (failure == null || _loading) {
      return _scaffold(
        const Padding(
          padding: EdgeInsets.all(AppSpacing.screen),
          child: PqrsLoadingSkeleton(),
        ),
      );
    }
    if (failure.kind == PqrsFailureKind.permission) {
      return _scaffold(
        AppEmptyState(
          icon: Icons.lock_outline,
          title: failure.message,
          message: 'Inicia sesión para consultar tus solicitudes.',
        ),
      );
    }
    return _scaffold(AppErrorState(message: failure.message, onRetry: _open));
  }
}

import 'package:flutter/material.dart';

/// Espera [action] (una acción sobre una reseña) y, si el servidor la
/// rechazó, muestra el motivo en un [SnackBar].
Future<void> showReviewActionError(
  BuildContext context,
  Future<String?> action,
) async {
  final error = await action;
  if (error == null || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
}

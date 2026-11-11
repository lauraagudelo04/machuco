import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:machuco/controllers/auth/validators/auth_validators.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/auth/phone_verification.dart';
import 'package:machuco/service/auth/auth_service.dart';
import 'package:machuco/service/auth/phone_verification_service.dart';
import 'package:machuco/widgets/auth/auth_notice.dart';
import 'package:machuco/widgets/form/app_bottom_sheet.dart';

/// Segundos de espera antes de poder pedir otro SMS.
const phoneCodeResendCooldown = 60;

/// Abre la hoja que envía el código SMS a [phoneNumber] (E.164) y lo recoge.
///
/// Con el código escrito llama a [onVerified]; esa función crea la cuenta (o el
/// perfil) y es donde Firebase comprueba el código. Si lanza [AuthFailure], la
/// hoja muestra el mensaje y deja reintentar sin cerrarse. Devuelve `true` si
/// [onVerified] terminó bien y `false` si el usuario cerró la hoja.
Future<bool> showPhoneVerificationSheet(
  BuildContext context, {
  required PhoneVerificationService service,
  required String phoneNumber,
  required Future<void> Function(PhoneVerificationProof proof) onVerified,
  String confirmLabel = 'Verificar y continuar',
}) async {
  final done = await AppBottomSheet.show<bool>(
    context,
    title: 'Verifica tu celular',
    // Cerrar a mitad de la creación de la cuenta dejaría el resultado sin
    // atender; solo "Cancelar" cierra la hoja, y no mientras se envía.
    isDismissible: false,
    enableDrag: false,
    builder: (_) => PhoneVerificationSheet(
      service: service,
      phoneNumber: phoneNumber,
      onVerified: onVerified,
      confirmLabel: confirmLabel,
    ),
  );
  return done ?? false;
}

/// Contenido de la hoja de verificación del celular.
class PhoneVerificationSheet extends StatefulWidget {
  const PhoneVerificationSheet({
    super.key,
    required this.service,
    required this.phoneNumber,
    required this.onVerified,
    this.confirmLabel = 'Verificar y continuar',
  });

  final PhoneVerificationService service;
  final String phoneNumber;
  final Future<void> Function(PhoneVerificationProof proof) onVerified;
  final String confirmLabel;

  @override
  State<PhoneVerificationSheet> createState() => _PhoneVerificationSheetState();
}

class _PhoneVerificationSheetState extends State<PhoneVerificationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();

  PhoneCodeRequest? _request;
  bool _sending = false;
  bool _confirming = false;
  AuthFailure? _failure;
  int _cooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_sendCode());
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _sendCode({bool resend = false}) async {
    if (_sending || _confirming) return;
    setState(() {
      _sending = true;
      _failure = null;
    });
    try {
      final request = await widget.service.sendCode(
        phoneNumber: widget.phoneNumber,
        resendFrom: resend ? _request : null,
      );
      if (!mounted) return;
      setState(() {
        _request = request;
        _sending = false;
      });
      _startCooldown();
      final proof = request.autoVerifiedProof;
      if (proof != null) await _verify(proof);
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _failure = failure;
      });
      if (failure.type == AuthFailureType.tooManyRequests) _startCooldown();
    }
  }

  Future<void> _submit() async {
    final request = _request;
    if (request == null || _confirming) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final PhoneVerificationProof proof;
    try {
      proof = widget.service.buildProof(request: request, smsCode: _code.text);
    } on AuthFailure catch (failure) {
      setState(() => _failure = failure);
      return;
    }
    await _verify(proof);
  }

  Future<void> _verify(PhoneVerificationProof proof) async {
    setState(() {
      _confirming = true;
      _failure = null;
    });
    try {
      await widget.onVerified(proof);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _confirming = false;
        _failure = failure;
      });
      if (failure.type == AuthFailureType.verificationExpired) {
        _stopCooldown();
      }
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = phoneCodeResendCooldown);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _cooldown = _cooldown > 0 ? _cooldown - 1 : 0);
      if (_cooldown == 0) timer.cancel();
    });
  }

  void _stopCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final request = _request;
    final failure = _failure;
    final canResend = _cooldown == 0 && !_sending && !_confirming;
    return PopScope(
      canPop: !_confirming,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enviamos un código de ${AuthValidators.smsCodeLength} dígitos '
              'por SMS al ${widget.phoneNumber}. Escríbelo para continuar.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.appColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            if (_sending && request == null)
              Semantics(
                liveRegion: true,
                child: Row(
                  children: [
                    const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: AppSpacing.s3),
                    Expanded(
                      child: Text(
                        'Enviando el código…',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              )
            else if (request != null)
              AppTextField(
                label: 'Código de verificación',
                hint: '000000',
                controller: _code,
                enabled: !_confirming,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(
                    AuthValidators.smsCodeLength,
                  ),
                ],
                validator: AuthValidators.smsCode,
                onSubmitted: (_) => _submit(),
              ),
            if (failure != null) ...[
              const SizedBox(height: AppSpacing.s3),
              AuthNotice(
                message: failure.message,
                icon: failure.type == AuthFailureType.network
                    ? Icons.wifi_off_outlined
                    : Icons.error_outline,
                actionLabel: request == null ? 'Reintentar' : null,
                onAction: request == null ? () => _sendCode() : null,
              ),
            ],
            const SizedBox(height: AppSpacing.s4),
            AppButton(
              label: widget.confirmLabel,
              loading: _confirming,
              onPressed: request == null || _sending ? null : _submit,
            ),
            const SizedBox(height: AppSpacing.s2),
            TextButton(
              onPressed: canResend && request != null
                  ? () => _sendCode(resend: true)
                  : null,
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              child: Text(
                _cooldown > 0
                    ? 'Reenviar código en ${_cooldown}s'
                    : 'Reenviar código',
              ),
            ),
            Text(
              'Si el número está mal, cancela y corrígelo en el formulario.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.appColors.textSecondary,
              ),
            ),
            TextButton(
              onPressed: _confirming
                  ? null
                  : () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}

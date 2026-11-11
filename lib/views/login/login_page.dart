import 'package:flutter/material.dart';
import 'package:machuco/controllers/auth/admin_access_controller.dart';
import 'package:machuco/controllers/auth/auth_routes.dart';
import 'package:machuco/controllers/auth/login_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/database/repository/auth/admin_access_repository.dart';
import 'package:machuco/models/auth/auth_provider_kind.dart';
import 'package:machuco/models/auth/registered_user.dart';
import 'package:machuco/models/auth/registration_data.dart';
import 'package:machuco/service/auth/auth_service.dart';
import 'package:machuco/service/auth/firebase_social_auth_service.dart';
import 'package:machuco/views/account_review/account_review_page.dart';
import 'package:machuco/views/login/account_session_guard.dart';
import 'package:machuco/views/login/auth_controller_factory.dart';
import 'package:machuco/views/login/logout_navigation.dart';
import 'package:machuco/views/login/social_auth_flow.dart';
import 'package:machuco/views/register/register_form.dart';
import 'package:machuco/widgets/auth/phone_verification_sheet.dart';
import 'package:machuco/widgets/auth/active_session_card.dart';
import 'package:machuco/widgets/auth/auth_header.dart';
import 'package:machuco/widgets/auth/auth_notice.dart';
import 'package:machuco/widgets/auth/auth_tab_switcher.dart';
import 'package:machuco/widgets/auth/delete_account_sheet.dart';
import 'package:machuco/widgets/auth/forgot_password_sheet.dart';
import 'package:machuco/widgets/auth/login_form.dart';
import 'package:machuco/widgets/auth/social_auth_buttons.dart';

export 'package:machuco/widgets/auth/auth_tab_switcher.dart' show AuthTab;

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    this.initialTab = AuthTab.login,
    this.authService,
    this.controller,
    this.adminAccessController,
    this.notice,
    this.socialAuthService,
  });

  final AuthTab initialTab;
  final AuthService? authService;
  final LoginController? controller;

  /// Para administradores: contador de solicitudes pendientes. Si es `null`
  /// se crea uno sobre Firestore cuando la sesión es de administrador.
  final AdminAccessController? adminAccessController;

  /// Aviso breve al abrir la pantalla (p. ej. "Tu cuenta fue eliminada").
  final String? notice;

  /// Google y GitHub. Si es `null` se usa el de producción, o ninguno si
  /// Firebase no está disponible (los botones se deshabilitan).
  final SocialAuthService? socialAuthService;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _loginFormKey = GlobalKey<FormState>();
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  late AuthTab _selectedTab;
  late final LoginController _controller;
  late final bool _ownsController;
  AdminAccessController? _adminController;
  bool _ownsAdminController = false;
  bool _adminLoaded = false;
  bool _rememberEmail = false;
  AuthFailure? _loginFailure;
  VoidCallback? _noticeRetry;
  SocialAuthService? _social;
  AuthProviderKind? _socialBusy;

  bool get _isSubmitting => _controller.isSubmitting;
  AuthSession? get _session => _controller.session;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ??
        buildLoginController(authService: widget.authService);
    _controller.addListener(_onControllerChanged);
    _adminController = widget.adminAccessController;
    _social = widget.socialAuthService ?? buildSocialAuthService();
    ensureAccountSessionWatcher(context);
    final notice = widget.notice;
    if (notice != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showSnack(message: notice);
      });
    }
    _bootstrap();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    if (_ownsController) _controller.dispose();
    if (_ownsAdminController) _adminController?.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    _ensureAdminController();
    setState(() {});
  }

  /// Contador de solicitudes: solo se crea si la sesión es de administrador.
  void _ensureAdminController() {
    if (_session?.role != RegisteredUserRole.admin) return;
    if (_adminController == null) {
      _adminController = AdminAccessController(
        repository: FirestoreAdminAccessRepository(),
      );
      _ownsAdminController = true;
    }
    if (!_adminLoaded) {
      _adminLoaded = true;
      _adminController!.loadPendingOwners();
    }
  }

  Future<void> _bootstrap() async {
    final remembered = await _controller.loadRememberedEmail();
    if (mounted && remembered.remember) {
      setState(() => _rememberEmail = true);
      final email = remembered.email;
      if (email != null && _loginEmailController.text.isEmpty) {
        _loginEmailController.text = email;
      }
    }
    final savedEmail = await _controller.loadCurrentUserEmail();
    if (mounted && savedEmail != null && _loginEmailController.text.isEmpty) {
      _loginEmailController.text = savedEmail;
    }
    if (!_controller.isAuthConfigured) return;
    try {
      final restored = await _controller.restoreSession();
      if (!mounted) return;
      if (restored == null) return _resumeSocialSession();
      _goToRoleHome(restored);
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      if (failure.type == AuthFailureType.network ||
          failure.type == AuthFailureType.accountDeleted) {
        setState(() => _loginFailure = failure);
      } else {
        _showSnack(message: 'No se pudo restaurar tu sesión.', isError: true);
      }
    }
  }

  void _selectTab(AuthTab tab) => setState(() => _selectedTab = tab);

  /// Retoma "Completar perfil" si la app se cerró antes de terminarlo, o
  /// vuelve a leer el perfil de un usuario ya autenticado (p. ej. tras un
  /// error de red) sin abrir otra vez el flujo del proveedor.
  Future<void> _resumeSocialSession({AuthProviderKind? busy}) async {
    final social = _social;
    if (social == null) return;
    if (busy != null) setState(() => _socialBusy = busy);
    final result = await social.resumeSession();
    if (!mounted) return;
    if (busy != null) setState(() => _socialBusy = null);
    if (result == null) return;
    _showSocialFailure(
      await routeSocialResult(
        context,
        result: result,
        controller: _controller,
        social: social,
      ),
      retry: _resumeSocialSession,
    );
  }

  Future<void> _signInWithProvider(AuthProviderKind kind) async {
    final social = _social;
    if (social == null || _socialBusy != null || _isSubmitting) return;
    // Ya hay un usuario de Firebase (el proveedor respondió pero, p. ej., no
    // se pudo leer el perfil): abrir otro flujo del proveedor con la sesión
    // iniciada deja el navegador sin su estado ("missing initial state").
    if (social.linkedProviders.isNotEmpty) {
      return _resumeSocialSession(busy: kind);
    }
    final pendingBefore = social.pendingLinkProvider;
    setState(() {
      _socialBusy = kind;
      _loginFailure = null;
    });
    final result = kind == AuthProviderKind.github
        ? await social.signInWithGitHub()
        : await social.signInWithGoogle();
    if (!mounted) return;
    if (pendingBefore != null && pendingBefore != kind) {
      await offerPendingProviderLink(
        context,
        social: social,
        pendingBeforeSignIn: pendingBefore,
      );
      if (!mounted) return;
    }
    final failure = await routeSocialResult(
      context,
      result: result,
      controller: _controller,
      social: social,
    );
    if (!mounted) return;
    setState(() => _socialBusy = null);
    _showSocialFailure(failure, retry: () => _signInWithProvider(kind));
  }

  void _showSocialFailure(AuthFailure? failure, {VoidCallback? retry}) {
    if (failure == null || !mounted) return;
    switch (failure.type) {
      case AuthFailureType.network ||
          AuthFailureType.accountDisabled ||
          AuthFailureType.accountDeleted:
        setState(() {
          _loginFailure = failure;
          _noticeRetry = retry;
        });
      default:
        _showSnack(message: failure.message, isError: true);
    }
  }

  Future<void> _submitLogin() async {
    if (_isSubmitting) return;
    if (!(_loginFormKey.currentState?.validate() ?? false)) return;
    if (!_controller.isAuthConfigured) {
      _showAuthNotConfigured();
      return;
    }
    setState(() {
      _loginFailure = null;
      _noticeRetry = null;
    });
    try {
      final session = await _controller.login(
        email: _loginEmailController.text,
        password: _loginPasswordController.text,
        rememberEmail: _rememberEmail,
      );
      if (!mounted) return;
      _showSnack(message: 'Bienvenido, ${session.name}.');
      if (_social case final social?) {
        await offerPendingProviderLink(context, social: social);
        if (!mounted) return;
      }
      _goToRoleHome(session);
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      _handleLoginFailure(failure);
    }
  }

  void _handleLoginFailure(AuthFailure failure) {
    switch (failure.type) {
      case AuthFailureType.accountRejected:
        Navigator.of(context).pushNamed(
          AuthRoutes.accountReview,
          arguments: AccountReviewArgs(
            email: _loginEmailController.text.trim(),
            rejected: true,
            rejectionReason: failure.rejectionReason,
          ),
        );
      case AuthFailureType.accountDisabled ||
          AuthFailureType.network ||
          AuthFailureType.accountDeleted:
        setState(() => _loginFailure = failure);
      default:
        _showSnack(message: failure.message, isError: true);
    }
  }

  Future<void> _submitRegister(RegistrationData data) async {
    if (!_controller.isAuthConfigured) {
      _showAuthNotConfigured();
      return;
    }
    try {
      final created = await _registerVerifyingPhone(data);
      if (!created || !mounted) return;
      final session = _session;
      if (data.role == RegisteredUserRole.owner && session != null) {
        _goToRoleHome(session);
        return;
      }
      _loginEmailController.text = data.email.trim();
      _loginPasswordController.clear();
      _showSnack(
        message: data.role == RegisteredUserRole.owner
            ? 'Solicitud enviada. Un administrador revisará tu cuenta; '
                  'inicia sesión para ver su estado.'
            : 'Cuenta creada correctamente. Ahora inicia sesión.',
      );
      setState(() => _selectedTab = AuthTab.login);
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      _showSnack(message: failure.message, isError: true);
    }
  }

  /// Verifica el celular por SMS y, con el código, crea la cuenta. `false` si
  /// el usuario cerró la hoja sin terminar. Sin servicio de verificación
  /// (solo pruebas) registra directo; el servicio real exige la prueba igual.
  Future<bool> _registerVerifyingPhone(RegistrationData data) async {
    final verification = _controller.phoneVerificationService;
    if (verification == null) {
      await _controller.registerAccount(data);
      return true;
    }
    return showPhoneVerificationSheet(
      context,
      service: verification,
      phoneNumber: _controller.phoneNumberToVerify(data),
      confirmLabel: 'Verificar y crear cuenta',
      onVerified: (proof) =>
          _controller.registerAccount(data.copyWith(phoneProof: proof)),
    );
  }

  Future<void> _openForgotPassword() async {
    if (!_controller.isAuthConfigured) {
      _showAuthNotConfigured();
      return;
    }
    await showForgotPasswordSheet(
      context,
      controller: _controller,
      initialEmail: _loginEmailController.text.trim(),
    );
  }

  Future<void> _deleteAccount() async {
    final deleted = await showDeleteAccountSheet(
      context,
      controller: _controller,
      socialAuthService: _social,
      isAdministrator: _session?.role == RegisteredUserRole.admin,
    );
    if (!deleted || !mounted) return;
    goToLogin(context, notice: 'Tu cuenta fue eliminada');
  }

  Future<void> _logout() async {
    await _controller.logout();
    if (!mounted) return;
    _showSnack(message: 'Sesión cerrada.');
  }

  void _showAuthNotConfigured() {
    _showSnack(
      isError: true,
      message: 'La autenticación no está disponible en este momento.',
    );
  }

  void _showSnack({required String message, bool isError = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? colorScheme.error : null,
        ),
      );
  }

  void _goToRoleHome(AuthSession session) =>
      goToSessionHome(context, controller: _controller, session: session);

  Widget? _buildLoginNotice() {
    final failure = _loginFailure;
    if (failure == null) return null;
    final isNetwork = failure.type == AuthFailureType.network;
    return AuthNotice(
      message: failure.message,
      icon: isNetwork
          ? Icons.wifi_off_outlined
          : failure.type == AuthFailureType.accountDeleted
          ? Icons.person_off_outlined
          : Icons.block_outlined,
      actionLabel: isNetwork ? 'Reintentar' : null,
      onAction: isNetwork ? (_noticeRetry ?? _submitLogin) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final socialButtons = SocialAuthButtons(
      onSelected: _social == null ? null : _signInWithProvider,
      busyProvider: _socialBusy,
      enabled: !_isSubmitting,
    );
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth < 360
                ? AppSpacing.s4
                : AppSpacing.s5;
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(
                  AppSpacing.s6,
                ).copyWith(left: horizontalPadding, right: horizontalPadding),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AuthHeader(
                        title: 'Machuco',
                        subtitle: 'Inicia sesión o crea tu cuenta',
                      ),
                      if (session != null) ...[
                        const SizedBox(height: AppSpacing.s4),
                        ActiveSessionCard(
                          session: session,
                          onLogout: _logout,
                          onDeleteAccount: _deleteAccount,
                          adminController:
                              session.role == RegisteredUserRole.admin
                              ? _adminController
                              : null,
                          onOpenOwnerApprovals: () =>
                              Navigator.of(context).pushNamed(
                                AuthRoutes.adminOwnerApprovals,
                                arguments: _adminController,
                              ),
                          onOpenAdministrators:
                              session.role == RegisteredUserRole.admin
                              ? () => Navigator.of(
                                  context,
                                ).pushNamed(AuthRoutes.adminAdministrators)
                              : null,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.s6),
                      AuthTabSwitcher(
                        selectedTab: _selectedTab,
                        onChanged: _selectTab,
                      ),
                      const SizedBox(height: AppSpacing.s6),
                      AnimatedSwitcher(
                        duration: AppMotion.fast,
                        child: _selectedTab == AuthTab.login
                            ? Form(
                                key: _loginFormKey,
                                child: LoginForm(
                                  emailController: _loginEmailController,
                                  passwordController: _loginPasswordController,
                                  submitting: _isSubmitting,
                                  rememberEmail: _rememberEmail,
                                  onRememberEmailChanged: (value) =>
                                      setState(() => _rememberEmail = value),
                                  notice: _buildLoginNotice(),
                                  onForgotPassword: _openForgotPassword,
                                  onSubmit: _submitLogin,
                                  onRegisterTap: () =>
                                      _selectTab(AuthTab.register),
                                  socialButtons: socialButtons,
                                ),
                              )
                            : RegisterForm(
                                controller: _controller,
                                onSubmit: _submitRegister,
                                onLoginTap: () => _selectTab(AuthTab.login),
                                socialButtons: socialButtons,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

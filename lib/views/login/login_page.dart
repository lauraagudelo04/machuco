import 'package:flutter/material.dart';
import 'package:machuco/controllers/auth/admin_access_controller.dart';
import 'package:machuco/controllers/auth/auth_routes.dart';
import 'package:machuco/controllers/auth/login_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/database/repository/auth/admin_access_repository.dart';
import 'package:machuco/models/auth/registered_user.dart';
import 'package:machuco/models/auth/registration_data.dart';
import 'package:machuco/service/auth/auth_service.dart';
import 'package:machuco/views/account_review/account_review_page.dart';
import 'package:machuco/views/login/auth_controller_factory.dart';
import 'package:machuco/views/login/logout_navigation.dart';
import 'package:machuco/views/register/register_form.dart';
import 'package:machuco/widgets/auth/active_session_card.dart';
import 'package:machuco/widgets/auth/auth_header.dart';
import 'package:machuco/widgets/auth/auth_notice.dart';
import 'package:machuco/widgets/auth/auth_tab_switcher.dart';
import 'package:machuco/widgets/auth/delete_account_sheet.dart';
import 'package:machuco/widgets/auth/forgot_password_sheet.dart';
import 'package:machuco/widgets/auth/login_form.dart';

export 'package:machuco/widgets/auth/auth_tab_switcher.dart' show AuthTab;

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    this.initialTab = AuthTab.login,
    this.authService,
    this.controller,
    this.adminAccessController,
    this.notice,
  });

  final AuthTab initialTab;
  final AuthService? authService;
  final LoginController? controller;

  /// Para administradores: contador de solicitudes pendientes. Si es `null`
  /// se crea uno sobre Firestore cuando la sesión es de administrador.
  final AdminAccessController? adminAccessController;

  /// Aviso breve al abrir la pantalla (p. ej. "Tu cuenta fue eliminada").
  final String? notice;

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
  AuthFailure? _loginFailure;

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
    final savedEmail = await _controller.loadCurrentUserEmail();
    if (mounted && savedEmail != null && _loginEmailController.text.isEmpty) {
      _loginEmailController.text = savedEmail;
    }
    if (!_controller.isAuthConfigured) return;
    try {
      final restored = await _controller.restoreSession();
      if (!mounted || restored == null) return;
      _goToRoleHome(restored);
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      if (failure.type == AuthFailureType.network) {
        setState(() => _loginFailure = failure);
      } else {
        _showSnack(message: 'No se pudo restaurar tu sesión.', isError: true);
      }
    }
  }

  void _selectTab(AuthTab tab) => setState(() => _selectedTab = tab);

  Future<void> _submitLogin() async {
    if (_isSubmitting) return;
    if (!(_loginFormKey.currentState?.validate() ?? false)) return;
    if (!_controller.isAuthConfigured) {
      _showAuthNotConfigured();
      return;
    }
    setState(() => _loginFailure = null);
    try {
      final session = await _controller.login(
        email: _loginEmailController.text,
        password: _loginPasswordController.text,
      );
      if (!mounted) return;
      _showSnack(message: 'Bienvenido, ${session.name}.');
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
      case AuthFailureType.accountDisabled || AuthFailureType.network:
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
      await _controller.registerAccount(data);
      if (!mounted) return;
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

  void _goToRoleHome(AuthSession session) {
    final route = _controller.resolvePostLoginRoute(session);
    Navigator.of(context).pushNamedAndRemoveUntil(
      route,
      (_) => false,
      arguments: route == AuthRoutes.accountReview
          ? AccountReviewArgs(email: session.email)
          : null,
    );
  }

  Widget? _buildLoginNotice() {
    final failure = _loginFailure;
    if (failure == null) return null;
    final isNetwork = failure.type == AuthFailureType.network;
    return AuthNotice(
      message: failure.message,
      icon: isNetwork ? Icons.wifi_off_outlined : Icons.block_outlined,
      actionLabel: isNetwork ? 'Reintentar' : null,
      onAction: isNetwork ? _submitLogin : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
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
                                  notice: _buildLoginNotice(),
                                  onForgotPassword: _openForgotPassword,
                                  onSubmit: _submitLogin,
                                  onRegisterTap: () =>
                                      _selectTab(AuthTab.register),
                                ),
                              )
                            : RegisterForm(
                                controller: _controller,
                                onSubmit: _submitRegister,
                                onLoginTap: () => _selectTab(AuthTab.login),
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

import 'package:flutter/material.dart';
import 'package:machuco/controllers/auth/login_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/service/auth/auth0_auth_service.dart';
import 'package:machuco/service/auth/auth0_config.dart';
import 'package:machuco/service/auth/backend_registered_user_directory.dart';
import 'package:machuco/service/auth/registered_user_directory.dart';
import 'package:machuco/views/booking/booking_home_page.dart';

enum AuthTab { login, register }

enum UserProfileType { administrator, finalUser, owner }

const _registerPasswordMinLength = 15;

extension on UserProfileType {
  String get metadataValue => switch (this) {
    UserProfileType.administrator => 'administrator',
    UserProfileType.finalUser => 'final_user',
    UserProfileType.owner => 'owner',
  };
}

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    this.initialTab = AuthTab.login,
    this.authService,
    this.controller,
  });

  final AuthTab initialTab;
  final Auth0AuthService? authService;
  final LoginController? controller;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late AuthTab _selectedTab;
  UserProfileType _selectedProfileType = UserProfileType.finalUser;
  bool _loginPasswordVisible = false;
  bool _registerPasswordVisible = false;
  bool _registerConfirmVisible = false;
  late final LoginController _controller;
  late final bool _ownsController;

  bool get _isSubmitting => _controller.isSubmitting;
  AuthSession? get _session => _controller.session;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
    final providedController = widget.controller;
    if (providedController != null) {
      _controller = providedController;
      _ownsController = false;
    } else {
      final authService =
          widget.authService ?? Auth0AuthService.fromEnvironment();
      final RegisteredUserDirectory userDirectory;
      if (Auth0Config.useBackendUsers && Auth0Config.hasUsersApiConfigured) {
        userDirectory = BackendRegisteredUserDirectory(
          baseUrl: Auth0Config.usersApiBaseUrl,
          usersPath: Auth0Config.usersApiPath,
        );
      } else {
        userDirectory = InMemoryRegisteredUserDirectory();
      }
      _controller = LoginController(
        authService: authService,
        userDirectory: userDirectory,
      );
      _ownsController = true;
    }
    _controller.addListener(_onControllerChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _bootstrap() async {
    await _refreshRegisteredUsers();
    if (!_controller.isAuthConfigured) {
      return;
    }
    try {
      await _controller.restoreSession();
      if (!mounted) {
        return;
      }
      await _refreshRegisteredUsers(showError: false);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnack(message: 'No se pudo restaurar tu sesión.', isError: true);
    }
  }

  Future<void> _submitLogin() async {
    if (_isSubmitting) {
      return;
    }
    final formState = _loginFormKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }
    if (!_controller.isAuthConfigured) {
      _showAuth0NotConfigured();
      return;
    }

    try {
      final session = await _controller.login(
        email: _loginEmailController.text,
        password: _loginPasswordController.text,
      );
      if (!mounted) {
        return;
      }
      await _refreshRegisteredUsers(showError: false);
      _showSnack(message: 'Bienvenido, ${session.name}.');
      _goToMainMenu();
    } on AuthFailure catch (failure) {
      if (!mounted) {
        return;
      }
      _showSnack(message: failure.message, isError: true);
    }
  }

  Future<void> _submitRegister() async {
    if (_isSubmitting) {
      return;
    }
    final formState = _registerFormKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }
    if (!_controller.isAuthConfigured) {
      _showAuth0NotConfigured();
      return;
    }

    try {
      await _controller.register(
        fullName: _fullNameController.text.trim(),
        email: _registerEmailController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        password: _registerPasswordController.text,
        profileType: _selectedProfileType.metadataValue,
      );
      if (!mounted) {
        return;
      }

      _loginEmailController.text = _registerEmailController.text.trim();
      _loginPasswordController.text = _registerPasswordController.text;
      _showSnack(
        message: 'Cuenta creada correctamente en Auth0. Ahora inicia sesión.',
      );
      setState(() => _selectedTab = AuthTab.login);
    } on AuthFailure catch (failure) {
      if (!mounted) {
        return;
      }
      _showSnack(message: failure.message, isError: true);
    }
  }

  Future<void> _submitGoogleAuth({required bool preferSignup}) async {
    if (_isSubmitting) {
      return;
    }
    if (!_controller.isAuthConfigured) {
      _showAuth0NotConfigured();
      return;
    }

    try {
      final session = await _controller.loginWithGoogle(
        preferSignup: preferSignup,
      );
      if (!mounted) {
        return;
      }
      await _refreshRegisteredUsers(showError: false);
      _showSnack(message: 'Bienvenido, ${session.name}.');
      setState(() => _selectedTab = AuthTab.login);
      _goToMainMenu();
    } on AuthFailure catch (failure) {
      if (!mounted) {
        return;
      }
      _showSnack(message: failure.message, isError: true);
    }
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

  Future<void> _refreshRegisteredUsers({bool showError = true}) async {
    try {
      await _controller.listRegisteredUsers();
    } on AuthFailure catch (failure) {
      if (!mounted || !showError) {
      return;
      }
      _showSnack(message: failure.message, isError: true);
    } on Exception {
      if (!mounted || !showError) {
      return;
      }
      _showSnack(
      message: 'No fue posible actualizar el listado de usuarios.',
      isError: true,
      );
    }
  }

  Future<void> _showForgotPasswordMessage() async {
    final email = _loginEmailController.text.trim();
    if (!_controller.isAuthConfigured) {
      _showAuth0NotConfigured();
      return;
    }
    if (_validateEmail(email) != null) {
      _showSnack(
        message: 'Ingresa un correo válido para recuperar la contraseña.',
        isError: true,
      );
      return;
    }
    try {
      await _controller.requestPasswordReset(email: email);
      if (!mounted) {
        return;
      }
      _showSnack(
        message: 'Te enviamos un correo para restablecer la contraseña.',
      );
    } on AuthFailure catch (failure) {
      if (!mounted) {
        return;
      }
      _showSnack(message: failure.message, isError: true);
    }
  }

  Future<void> _logout() async {
    await _controller.logout();
    if (!mounted) {
      return;
    }
    _showSnack(message: 'Sesión cerrada.');
  }

  void _showAuth0NotConfigured() {
    _showSnack(
      isError: true,
      message:
          'Auth0 no está configurado. Define AUTH0_DOMAIN y AUTH0_CLIENT_ID.',
    );
  }

  void _goToMainMenu() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const BookingHomePage()),
      (_) => false,
    );
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      return 'Ingresa tu correo.';
    }
    const pattern = r'^[^@\s]+@[^@\s]+\.[^@\s]+$';
    if (!RegExp(pattern).hasMatch(email)) {
      return 'Ingresa un correo válido.';
    }
    return null;
  }

  String? _validateLoginPassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return 'Ingresa tu contraseña.';
    }
    if (password.length < 6) {
      return 'Debe tener mínimo 6 caracteres.';
    }
    return null;
  }

  String? _validateRegisterPassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return 'Ingresa tu contraseña.';
    }
    if (password.length < _registerPasswordMinLength) {
      return 'Debe tener mínimo $_registerPasswordMinLength caracteres.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final semanticColors = context.appColors;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth < 360
                ? AppSpacing.s4
                : AppSpacing.s5;
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  AppSpacing.s6,
                  horizontalPadding,
                  AppSpacing.s6,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HeaderLogo(
                        title: 'Machuco',
                        subtitle: 'Inicia sesión o crea tu cuenta',
                      ),
                      if (!_controller.isAuthConfigured) ...[
                        const SizedBox(height: AppSpacing.s4),
                        _Auth0SetupAlert(
                          message:
                              'Falta configuración de Auth0. Ejecuta con --dart-define=AUTH0_DOMAIN=... --dart-define=AUTH0_CLIENT_ID=...',
                        ),
                      ],
                      if (_session != null) ...[
                        const SizedBox(height: AppSpacing.s4),
                        _ActiveSessionCard(
                          session: _session!,
                          onLogout: _logout,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.s6),
                      _AuthTabSwitcher(
                        selectedTab: _selectedTab,
                        onChanged: (tab) => setState(() => _selectedTab = tab),
                      ),
                      const SizedBox(height: AppSpacing.s6),
                      AnimatedSwitcher(
                        duration: AppMotion.fast,
                        child: _selectedTab == AuthTab.login
                            ? Form(
                                key: _loginFormKey,
                                child: _LoginForm(
                                  emailController: _loginEmailController,
                                  passwordController: _loginPasswordController,
                                  passwordVisible: _loginPasswordVisible,
                                  onTogglePassword: () => setState(
                                    () => _loginPasswordVisible =
                                        !_loginPasswordVisible,
                                  ),
                                  submitting: _isSubmitting,
                                  onForgotPassword: () {
                                    _showForgotPasswordMessage();
                                  },
                                  onSubmit: () {
                                    _submitLogin();
                                  },
                                  onGoogleTap: () {
                                    _submitGoogleAuth(preferSignup: false);
                                  },
                                  onRegisterTap: () => setState(
                                    () => _selectedTab = AuthTab.register,
                                  ),
                                  validateEmail: _validateEmail,
                                  validatePassword: _validateLoginPassword,
                                ),
                              )
                            : Form(
                                key: _registerFormKey,
                                child: _RegisterForm(
                                  fullNameController: _fullNameController,
                                  phoneController: _phoneController,
                                  emailController: _registerEmailController,
                                  passwordController:
                                      _registerPasswordController,
                                  confirmPasswordController:
                                      _confirmPasswordController,
                                  selectedProfileType: _selectedProfileType,
                                  passwordVisible: _registerPasswordVisible,
                                  confirmVisible: _registerConfirmVisible,
                                  submitting: _isSubmitting,
                                  onProfileSelected: (profile) => setState(
                                    () => _selectedProfileType = profile,
                                  ),
                                  onTogglePassword: () => setState(
                                    () => _registerPasswordVisible =
                                        !_registerPasswordVisible,
                                  ),
                                  onToggleConfirm: () => setState(
                                    () => _registerConfirmVisible =
                                        !_registerConfirmVisible,
                                  ),
                                  onSubmit: () {
                                    _submitRegister();
                                  },
                                  onGoogleTap: () {
                                    _submitGoogleAuth(preferSignup: true);
                                  },
                                  onLoginTap: () => setState(
                                    () => _selectedTab = AuthTab.login,
                                  ),
                                  validateEmail: _validateEmail,
                                  validatePassword: _validateRegisterPassword,
                                ),
                              ),
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        'Al continuar, aceptas nuestros Términos y Privacidad.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: semanticColors.textSecondary,
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

class _Auth0SetupAlert extends StatelessWidget {
  const _Auth0SetupAlert({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.s2),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.appColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveSessionCard extends StatelessWidget {
  const _ActiveSessionCard({required this.session, required this.onLogout});

  final AuthSession session;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sesión activa',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.s1),
          Text(session.name, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.s1),
          Text(
            session.email,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          AppButton(
            label: 'Cerrar sesión',
            variant: AppButtonVariant.secondary,
            onPressed: onLogout,
          ),
        ],
      ),
    );
  }
}

class _HeaderLogo extends StatelessWidget {
  const _HeaderLogo({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: const Icon(Icons.bed_rounded, color: Colors.white, size: 28),
        ),
        const SizedBox(height: AppSpacing.s2),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.s1),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: context.appColors.textMuted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _AuthTabSwitcher extends StatelessWidget {
  const _AuthTabSwitcher({required this.selectedTab, required this.onChanged});

  final AuthTab selectedTab;
  final ValueChanged<AuthTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final borderColor = context.appColors.border;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: _AuthTabButton(
              text: 'Iniciar sesión',
              selected: selectedTab == AuthTab.login,
              onTap: () => onChanged(AuthTab.login),
            ),
          ),
          Expanded(
            child: _AuthTabButton(
              text: 'Registrarse',
              selected: selectedTab == AuthTab.register,
              onTap: () => onChanged(AuthTab.register),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthTabButton extends StatelessWidget {
  const _AuthTabButton({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = selected ? Colors.white : context.appColors.textSecondary;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          gradient: selected ? AppGradients.primary : null,
          color: selected ? null : Colors.transparent,
        ),
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.s4,
          horizontal: AppSpacing.s3,
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.emailController,
    required this.passwordController,
    required this.passwordVisible,
    required this.onTogglePassword,
    required this.submitting,
    required this.onForgotPassword,
    required this.onSubmit,
    required this.onGoogleTap,
    required this.onRegisterTap,
    required this.validateEmail,
    required this.validatePassword,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool passwordVisible;
  final VoidCallback onTogglePassword;
  final bool submitting;
  final VoidCallback onForgotPassword;
  final VoidCallback onSubmit;
  final VoidCallback onGoogleTap;
  final VoidCallback onRegisterTap;
  final FormFieldValidator<String> validateEmail;
  final FormFieldValidator<String> validatePassword;

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      key: const ValueKey('login-form'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            label: 'Correo electrónico',
            hint: 'correo@ejemplo.com',
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            validator: validateEmail,
            autovalidateMode: AutovalidateMode.onUserInteraction,
          ),
          const SizedBox(height: AppSpacing.s4),
          AppTextField(
            label: 'Contraseña',
            hint: 'Tu contraseña',
            controller: passwordController,
            obscureText: !passwordVisible,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            validator: validatePassword,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            suffixIcon: IconButton(
              tooltip: passwordVisible
                  ? 'Ocultar contraseña'
                  : 'Ver contraseña',
              onPressed: onTogglePassword,
              icon: Icon(
                passwordVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
            onSubmitted: (_) => onSubmit(),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onForgotPassword,
              child: const Text('¿Olvidaste tu contraseña?'),
            ),
          ),
          AppButton(
            label: 'Ingresar',
            loading: submitting,
            onPressed: onSubmit,
          ),
          const SizedBox(height: AppSpacing.s3),
          AppButton(
            label: 'Continuar con Google',
            variant: AppButtonVariant.secondary,
            onPressed: submitting ? null : onGoogleTap,
          ),
          const SizedBox(height: AppSpacing.s5),
          Text.rich(
            TextSpan(
              text: '¿No tienes cuenta? ',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.appColors.textSecondary,
              ),
              children: [
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: InkWell(
                    onTap: onRegisterTap,
                    child: Text(
                      'Regístrate aquí',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _RegisterForm extends StatelessWidget {
  const _RegisterForm({
    required this.fullNameController,
    required this.phoneController,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.selectedProfileType,
    required this.passwordVisible,
    required this.confirmVisible,
    required this.submitting,
    required this.onProfileSelected,
    required this.onTogglePassword,
    required this.onToggleConfirm,
    required this.onSubmit,
    required this.onGoogleTap,
    required this.onLoginTap,
    required this.validateEmail,
    required this.validatePassword,
  });

  final TextEditingController fullNameController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final UserProfileType selectedProfileType;
  final bool passwordVisible;
  final bool confirmVisible;
  final bool submitting;
  final ValueChanged<UserProfileType> onProfileSelected;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirm;
  final VoidCallback onSubmit;
  final VoidCallback onGoogleTap;
  final VoidCallback onLoginTap;
  final FormFieldValidator<String> validateEmail;
  final FormFieldValidator<String> validatePassword;

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) {
      return 'Ingresa tu nombre completo.';
    }
    if (name.length < 3) {
      return 'El nombre es demasiado corto.';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final digits = value?.replaceAll(RegExp(r'\D'), '') ?? '';
    if (digits.isEmpty) {
      return 'Ingresa tu número de celular.';
    }
    if (digits.length < 10) {
      return 'Ingresa un número válido de 10 dígitos.';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Confirma tu contraseña.';
    }
    if (value != passwordController.text) {
      return 'Las contraseñas no coinciden.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 430;
    return AutofillGroup(
      key: const ValueKey('register-form'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            label: 'Nombre completo',
            hint: 'Ej. Carlos Rodríguez',
            controller: fullNameController,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            validator: _validateName,
            autovalidateMode: AutovalidateMode.onUserInteraction,
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            'Número de celular',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.s2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
                decoration: BoxDecoration(
                  color: context.appColors.elevated,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: context.appColors.border),
                ),
                alignment: Alignment.center,
                child: Text(
                  'CO +57',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
              Expanded(
                child: AppTextField(
                  label: 'Celular',
                  hint: '300 123 4567',
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  validator: _validatePhone,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          Text('Tipo de perfil', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: AppSpacing.s2),
          _ProfileTypeSelector(
            selectedType: selectedProfileType,
            onSelected: onProfileSelected,
            compact: compact,
          ),
          const SizedBox(height: AppSpacing.s4),
          AppTextField(
            label: 'Correo electrónico',
            hint: 'correo@ejemplo.com',
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            validator: validateEmail,
            autovalidateMode: AutovalidateMode.onUserInteraction,
          ),
          const SizedBox(height: AppSpacing.s4),
          AppTextField(
            label: 'Contraseña',
            hint: 'Mínimo 15 caracteres',
            controller: passwordController,
            obscureText: !passwordVisible,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            validator: validatePassword,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            suffixIcon: IconButton(
              tooltip: passwordVisible
                  ? 'Ocultar contraseña'
                  : 'Ver contraseña',
              onPressed: onTogglePassword,
              icon: Icon(
                passwordVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          AppTextField(
            label: 'Confirmar contraseña',
            hint: 'Repite tu contraseña',
            controller: confirmPasswordController,
            obscureText: !confirmVisible,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            validator: _validateConfirmPassword,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            suffixIcon: IconButton(
              tooltip: confirmVisible ? 'Ocultar contraseña' : 'Ver contraseña',
              onPressed: onToggleConfirm,
              icon: Icon(
                confirmVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
            onSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: AppSpacing.s5),
          AppButton(
            label: 'Crear cuenta',
            loading: submitting,
            onPressed: onSubmit,
          ),
          const SizedBox(height: AppSpacing.s3),
          AppButton(
            label: 'Continuar con Google',
            variant: AppButtonVariant.secondary,
            onPressed: submitting ? null : onGoogleTap,
          ),
          const SizedBox(height: AppSpacing.s5),
          Text.rich(
            TextSpan(
              text: '¿Ya tienes cuenta? ',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.appColors.textSecondary,
              ),
              children: [
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: InkWell(
                    onTap: onLoginTap,
                    child: Text(
                      'Inicia sesión',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ProfileTypeSelector extends StatelessWidget {
  const _ProfileTypeSelector({
    required this.selectedType,
    required this.onSelected,
    required this.compact,
  });

  final UserProfileType selectedType;
  final ValueChanged<UserProfileType> onSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final profiles =
        <
          ({UserProfileType type, IconData icon, String title, String subtitle})
        >[
          (
            type: UserProfileType.administrator,
            icon: Icons.security_rounded,
            title: 'Administrador',
            subtitle: 'Gestión total del sistema',
          ),
          (
            type: UserProfileType.finalUser,
            icon: Icons.person_rounded,
            title: 'Usuario final',
            subtitle: 'Realiza y consulta reservas',
          ),
          (
            type: UserProfileType.owner,
            icon: Icons.home_work_rounded,
            title: 'Propietario',
            subtitle: 'Gestiona sus propiedades',
          ),
        ];

    return Wrap(
      spacing: AppSpacing.s2,
      runSpacing: AppSpacing.s2,
      children: profiles
          .map((profile) {
            final selected = profile.type == selectedType;
            return SizedBox(
              width: compact ? double.infinity : 165,
              child: AppCard(
                selected: selected,
                onTap: () => onSelected(profile.type),
                semanticLabel: profile.title,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      profile.icon,
                      size: 22,
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : context.appColors.textSecondary,
                    ),
                    const SizedBox(height: AppSpacing.s2),
                    Text(
                      profile.title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s1),
                    Text(
                      profile.subtitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.appColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/api_service.dart';
import '../../core/services/repositories.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/common.dart';

/// Sign in / register against the Node API. Stores the bearer token so the
/// session survives app restarts.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _registerMode = false;
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = ref.read(authProvider.notifier);
      final err = _registerMode
          ? await auth.register(
              _nameController.text,
              _emailController.text,
              _passwordController.text,
            )
          : await auth.login(_emailController.text, _passwordController.text);

      if (err != null) {
        setState(() {
          _error = err;
          _loading = false;
        });
        return;
      }

      if (mounted) {
        showAppSnackBar(
          context,
          _registerMode ? 'Welcome to CodeYoung!' : 'Welcome back!',
        );
        context.go('/home');
      }
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _loading = false;
      });
    }
  }

  void _toggleMode() {
    setState(() {
      _registerMode = !_registerMode;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      appBar: AppHeader(
        showBack: true,
        subtitle: _registerMode ? 'Create account' : 'Sign in',
        // Login is reached with `context.go`, so there may be nothing to pop.
        onBack: () => context.go('/home'),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                const Center(child: AppLogo(height: 54)),
                const SizedBox(height: 16),
                Text(
                  _registerMode ? 'Create your account' : 'Welcome back',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  _registerMode
                      ? 'Track lessons, earn badges and learn 1:1 live.'
                      : 'Sign in to continue your 1:1 live learning.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: isDark
                        ? AppColors.textOnDark.withValues(alpha: 0.7)
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 26),

                if (_error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: AppColors.error, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              fontSize: 13.5,
                              height: 1.45,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 250.ms).slide(begin: const Offset(0, -0.1)),

                if (_registerMode) ...[
                  _textField(
                    controller: _nameController,
                    hint: 'Full name',
                    icon: Icons.person_rounded,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
                  ),
                  const SizedBox(height: 14),
                ],
                _textField(
                  controller: _emailController,
                  hint: 'Email address',
                  icon: Icons.mail_rounded,
                  keyboard: TextInputType.emailAddress,
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return 'Enter your email';
                    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(t)) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _textField(
                  controller: _passwordController,
                  hint: 'Password',
                  icon: Icons.lock_rounded,
                  obscure: _obscure,
                  suffix: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                      size: 20,
                    ),
                  ),
                  validator: (v) {
                    if ((v ?? '').isEmpty) return 'Enter your password';
                    if (_registerMode && v!.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                GradientButton(
                  label: _registerMode ? 'Create account' : 'Sign in',
                  icon: _registerMode ? Icons.person_add_rounded : Icons.login_rounded,
                  loading: _loading,
                  onPressed: _submit,
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _registerMode ? 'Already have an account?' : "Don't have an account?",
                      style: TextStyle(
                        fontSize: 13.5,
                        color: isDark
                            ? AppColors.textOnDark.withValues(alpha: 0.7)
                            : AppColors.textSecondary,
                      ),
                    ),
                    TextButton(
                      onPressed: _loading ? null : _toggleMode,
                      child: Text(
                        _registerMode ? 'Sign in' : 'Create one',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _DemoCard(
                  onUse: (email) {
                    _emailController.text = email;
                    _passwordController.text = 'password';
                    setState(() => _registerMode = false);
                    showAppSnackBar(context, 'Demo credentials filled in — tap Sign in.');
                  },
                ),
                const SizedBox(height: 18),
                TextButton(
                  onPressed: _loading ? null : () => context.go('/home'),
                  child: Text(
                    'Continue as guest',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textOnDark.withValues(alpha: 0.6)
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboard,
    bool obscure = false,
    Widget? suffix,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgDarkCard : AppColors.bgWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.07),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboard,
        obscureText: obscure,
        textInputAction: TextInputAction.done,
        onFieldSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: 14.5,
            color: isDark ? AppColors.textOnDark.withValues(alpha: 0.45) : AppColors.textSecondary,
          ),
          prefixIcon: Icon(icon, color: AppColors.primaryBlue, size: 21),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 17),
          errorStyle: const TextStyle(fontSize: 12, height: 1.3),
        ),
        style: TextStyle(
          fontSize: 15,
          color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _DemoCard extends StatelessWidget {
  const _DemoCard({required this.onUse});

  final void Function(String email) onUse;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: isDark ? 0.14 : 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, color: AppColors.primaryBlue, size: 18),
              const SizedBox(width: 7),
              Text(
                'Try it instantly',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Demo account — password "password":',
            style: TextStyle(
              fontSize: 12.5,
              color: isDark
                  ? AppColors.textOnDark.withValues(alpha: 0.7)
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.person_rounded, size: 16, color: AppColors.primaryBlue),
                label: const Text('learner@codeyoung.com'),
                onPressed: () => onUse('learner@codeyoung.com'),
                backgroundColor: isDark ? AppColors.bgDarkCard : AppColors.bgWhite,
                side: BorderSide(color: AppColors.primaryBlue.withValues(alpha: 0.35)),
              ),
              ActionChip(
                avatar: const Icon(Icons.person_rounded, size: 16, color: AppColors.accentPurple),
                label: const Text('student@codeyoung.com'),
                onPressed: () => onUse('student@codeyoung.com'),
                backgroundColor: isDark ? AppColors.bgDarkCard : AppColors.bgWhite,
                side: BorderSide(color: AppColors.accentPurple.withValues(alpha: 0.35)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

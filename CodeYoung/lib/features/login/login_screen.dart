import 'package:flutter/material.dart';
import 'package:codeyoung/core/theme/app_theme.dart';
import 'package:codeyoung/core/widgets/app_header.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final result = await _authenticateUser();
      
      if (result['success'] == true && mounted) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', result['userId'] as String);
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('email', _emailController.text.trim());
        await prefs.setString('name', result['name'] as String? ?? 'CodeYoung Learner');
        if (!mounted) return;
        context.go('/home');
      } else {
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] as String? ?? 'Login failed'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred: ${e.toString()}'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<Map<String, dynamic>> _authenticateUser() async {
    await Future.delayed(const Duration(seconds: 1));
    
    if (_emailController.text == 'learner@codeyoung.com' && _passwordController.text == 'password') {
      return {
        'success': true,
        'userId': '1',
        'name': 'CodeYoung Learner',
      };
    }
    
    return {'success': false, 'error': 'Invalid credentials. Try: learner@codeyoung.com / password'};
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: const AppHeader(showBack: true, subtitle: 'Sign in'),
      body: Stack(
        children: [
          _buildBackground(isDark),
          SafeArea(
            top: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildLogo(),
                        const SizedBox(height: 40),
                        _buildWelcomeHeader(isDark),
                        const SizedBox(height: 16),
                        _buildForm(isDark),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground(bool isDark) {
    return Container(
      height: MediaQuery.of(context).size.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [
                  const Color(0xFF0B0F19),
                  const Color(0xFF0A0E1A),
                ]
              : [
                  AppColors.primaryBlue.withValues(alpha: 0.05),
                  Colors.white,
                ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        gradient: AppGradients.primary,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.4),
            blurRadius: 25,
            spreadRadius: 4,
          ),
        ],
      ),
      child: const Icon(Icons.code, size: 60, color: Colors.white),
    ).animate().scale(duration: 600.ms, curve: Curves.elasticOut, delay: 200.ms).fadeIn(duration: 400.ms);
  }

  Widget _buildWelcomeHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome Back!',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Continue your learning journey',
          style: TextStyle(
            fontSize: 15,
            color: isDark ? AppColors.textOnDark.withValues(alpha: 0.6) : AppColors.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildForm(bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
            blurRadius: isDark ? 10 : 30,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildEmailField(),
              const SizedBox(height: 20),
              _buildPasswordField(),
              const SizedBox(height: 12),
              _buildRememberMeRow(),
              const SizedBox(height: 28),
              _buildSignInButton(),
              const SizedBox(height: 20),
              _buildDivider(),
              const SizedBox(height: 20),
              _buildSocialButtons(),
              const SizedBox(height: 8),
              _buildSignUpPrompt(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(
        labelText: 'Email Address',
        prefixIcon: Icon(Icons.mail_outline_rounded),
        border: OutlineInputBorder(),
        filled: true,
        hintText: 'your@email.com',
      ),
      validator: (v) => v != null && v.contains('@') ? null : 'Enter valid email',
      autofillHints: const [AutofillHints.email],
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: 'Password',
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
          ),
        ),
        border: const OutlineInputBorder(),
        filled: true,
        hintText: '••••••••',
      ),
      validator: (v) => v != null && v.length >= 6 ? null : 'Min 6 characters',
      onFieldSubmitted: (_) => _signIn(),
      autofillHints: const [AutofillHints.password],
    );
  }

  Widget _buildRememberMeRow() {
    return Row(
      children: [
        Checkbox(
          value: false,
          onChanged: (value) {},
          activeColor: AppColors.primaryBlue,
        ),
        Text(
          'Remember me',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: () {},
          child: const Text(
            'Forgot Password?',
            style: TextStyle(
              color: AppColors.primaryBlue,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.primaryBlue,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignInButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Container(
        decoration: BoxDecoration(
          gradient: AppGradients.primary,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryBlue.withValues(alpha: 0.3),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _signIn,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)
              : Text(
                  _isLoading ? 'Signing In...' : 'Sign In',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Text(
          'OR',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Container(
            height: 1.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButtons() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSocialButton('Google', Icons.g_mobiledata, () {}, isDark),
        const SizedBox(width: 16),
        _buildSocialButton('Apple', Icons.apple, () {}, isDark),
      ],
    );
  }

  Widget _buildSocialButton(String label, IconData icon, VoidCallback onPressed, bool isDark) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: isDark ? Colors.grey.shade700 : AppColors.textSecondary.withValues(alpha: 0.3),
            width: 1.5,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: isDark ? AppColors.textOnDark : AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textOnDark : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignUpPrompt() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account? ",
          style: TextStyle(
            color: isDark ? AppColors.textOnDark.withValues(alpha: 0.5) : AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        TextButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sign Up screen coming soon')),
            );
          },
          child: const Text(
            'Sign Up',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryBlue,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.primaryBlue,
            ),
          ),
        ),
      ],
    );
  }
}
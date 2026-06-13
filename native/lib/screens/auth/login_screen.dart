import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/auth.dart';
import '../../widgets/widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  // Pulsująca poświata logo
  late final AnimationController _glowCtrl;
  late final Animation<double> _glow;

  static const _gold = Color(0xFFF5C400);
  static const _bg   = Color(0xFF0A0A0A);

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _glow = Tween<double>(begin: 0.55, end: 1.0).animate(
        CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  void _handleLogin() {
    if (_formKey.currentState!.validate()) {
      context.read<AuthBloc>().add(
            AuthSignInRequested(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            ),
          );
    }
  }

  // Tłumaczenie błędów Supabase na krótkie PL
  String _translateError(String msg) {
    final m = msg.toLowerCase();
    if (m.contains('invalid login') || m.contains('invalid credentials') ||
        m.contains('wrong password') || m.contains('email not confirmed') == false &&
        m.contains('password')) return 'Hasło nieprawidłowe';
    if (m.contains('user not found') || m.contains('no user')) return 'Nie znaleziono konta';
    if (m.contains('email not confirmed')) return 'Potwierdź email przed logowaniem';
    if (m.contains('too many')) return 'Zbyt wiele prób — spróbuj później';
    if (m.contains('network') || m.contains('socket')) return 'Błąd połączenia z internetem';
    if (m.contains('email') && m.contains('invalid')) return 'Nieprawidłowy adres email';
    return 'Błąd logowania — spróbuj ponownie';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthAuthenticated) {
              Navigator.pushReplacementNamed(context, '/main');
            } else if (state is AuthError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_translateError(state.message)),
                  backgroundColor: AppTheme.errorColor,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 52),

                  // ── Logo z pulsującą poświatą ──────────────
                  Center(
                    child: AnimatedBuilder(
                      animation: _glow,
                      builder: (_, child) => Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _gold.withValues(alpha: 0.45 * _glow.value),
                              blurRadius: 48,
                              spreadRadius: 6,
                            ),
                            BoxShadow(
                              color: const Color(0xFF1E6FD9).withValues(alpha: 0.22 * _glow.value),
                              blurRadius: 80,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: child,
                      ),
                      child: Image.asset(
                        'assets/icons/ui/typerly-icon-app.png',
                        width: 110,
                        height: 110,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Wordmark TYPE RLY ─────────────────────
                  Center(
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontFamily: 'Archivo',
                          fontWeight: FontWeight.w900,
                          fontSize: 40,
                          letterSpacing: 4,
                          height: 1,
                        ),
                        children: [
                          TextSpan(text: 'TYPE',
                              style: TextStyle(color: Colors.white)),
                          TextSpan(text: 'RLY',
                              style: TextStyle(color: _gold)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Center(
                    child: Text(
                      'TYPUJ  ·  RYWALIZUJ  ·  WYGRYWAJ',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 52),

                  // ── Email ─────────────────────────────────
                  CustomTextField(
                    label: 'Email',
                    hint: 'Twój adres email',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: const Icon(Icons.email_outlined),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Podaj email';
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                          .hasMatch(value)) return 'Nieprawidłowy email';
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // ── Hasło ─────────────────────────────────
                  CustomTextField(
                    label: 'Hasło',
                    hint: 'Twoje hasło',
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    isPassword: true,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Podaj hasło';
                      if (value.length < 6) return 'Hasło za krótkie (min. 6 znaków)';
                      return null;
                    },
                  ),

                  const SizedBox(height: 8),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {},
                      child: Text('Zapomniałeś hasła?',
                          style: TextStyle(
                              color: _gold.withValues(alpha: 0.8),
                              fontSize: 13)),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Przycisk logowania ────────────────────
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      return PrimaryButton(
                        text: 'Zaloguj się',
                        onPressed: _handleLogin,
                        isLoading: state is AuthLoading,
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Nie masz konta? ',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 14),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pushReplacementNamed(
                            context, '/register'),
                        child: Text('Zarejestruj się',
                            style: TextStyle(
                                color: _gold,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

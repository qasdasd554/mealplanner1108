import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'forgot_password_screen.dart';
import '../../theme/app_theme.dart';
import '../../config/api_config.dart';
import '../../widgets/turnstile_widget.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Token z bramki CAPTCHA. `null` = jeszcze nie zweryfikowano (albo
  /// token wygasł). Gdy bramka jest wyłączona, widget od razu zgłasza
  /// pusty ciąg, więc przycisk nie jest blokowany.
  String? _captchaToken;

  /// Zmiana tej wartości odtwarza widget CAPTCHA, co wymusza pobranie
  /// ŚWIEŻEGO tokenu. Konieczne, bo token Turnstile jest JEDNORAZOWY —
  /// serwer zużywa go przy weryfikacji. Bez odświeżenia druga próba
  /// logowania (np. po literówce w haśle) wysyłałaby token już zużyty
  /// i kończyła się mylącym "Weryfikacja nie powiodła się" zamiast
  /// informacji o błędnym haśle.
  int _captchaAttempt = 0;

  void _resetCaptcha() {
    setState(() {
      _captchaToken = null;
      _captchaAttempt++;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_captchaToken == null) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text,
      captchaToken: _captchaToken,
    );

    if (mounted) {
      if (success) {
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage ?? 'Logowanie nie powiodło się'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _submitGoogle() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.loginWithGoogle(captchaToken: _captchaToken);

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else if (authProvider.errorMessage != null) {
      _resetCaptcha();
      // `success == false` bez komunikatu błędu oznacza, że użytkownik po
      // prostu anulował okno logowania Google — wtedy nic nie pokazujemy.
      ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage!),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _submitApple() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.loginWithApple(captchaToken: _captchaToken);

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      // Token został zużyty przy tej próbie — niezależnie od tego, czy
      // logowanie nie powiodło się, czy użytkownik anulował okno.
      _resetCaptcha();
      if (authProvider.errorMessage != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(authProvider.errorMessage!),
              backgroundColor: AppTheme.errorColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: Stack(
        children: [
          // Dekoracyjny rozmyty fioletowy okrąg w tle (Premium look)
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.secondaryColor.withOpacity(0.15),
              ),
            ).animate().fadeIn(duration: 1000.ms).scale(duration: 1000.ms),
          ),
          // UWAGA (nowe): dwa-trzy dodatkowe okręgi w innych odcieniach
          // palety marki, żeby tło było bardziej żywe wizualnie — te same
          // rozmyte, półprzezroczyste kółka co powyżej, tylko inne
          // kolory/rozmiary/pozycje, rozmieszczone POZA obszarem
          // formularza (który jest wyśrodkowany), więc nic nie zasłaniają.
          Positioned(
            bottom: -120,
            left: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryColor.withOpacity(0.12),
              ),
            ).animate(delay: 200.ms).fadeIn(duration: 1000.ms).scale(duration: 1000.ms),
          ),
          Positioned(
            top: 160,
            left: -60,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accentColor.withOpacity(0.12),
              ),
            ).animate(delay: 400.ms).fadeIn(duration: 1000.ms).scale(duration: 1000.ms),
          ),
          Positioned(
            bottom: 80,
            right: -50,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.secondaryColor.withOpacity(0.08),
              ),
            ).animate(delay: 600.ms).fadeIn(duration: 1000.ms).scale(duration: 1000.ms),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo / Icon
                      Center(
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.restaurant_menu,
                            size: 40,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
                      const SizedBox(height: 24),
                      // Tytuł powitalny
                      Text(
                        'Witaj ponownie!',
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        textAlign: TextAlign.center,
                      ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
                      const SizedBox(height: 8),
                      Text(
                        'Zaloguj się do swojego konta',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),
                      const SizedBox(height: 32),
                      
                      // Email Input
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'E-mail',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Wprowadź adres e-mail';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                            return 'Wprowadź poprawny adres e-mail';
                          }
                          return null;
                        },
                      ).animate().fadeIn(delay: 400.ms),
                      const SizedBox(height: 16),
                      
                      // Password Input
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Hasło',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Wprowadź hasło';
                          }
                          if (value.length < 6) {
                            return 'Hasło musi mieć co najmniej 6 znaków';
                          }
                          return null;
                        },
                      ).animate().fadeIn(delay: 500.ms),
                      const SizedBox(height: 24),
                      
                      // Login Button
                      // Bramka CAPTCHA — przycisk pozostaje nieaktywny, dopóki
                      // weryfikacja się nie powiedzie (patrz _captchaToken).
                      TurnstileWidget(
                        key: ValueKey(_captchaAttempt),
                        onToken: (t) => setState(() => _captchaToken = t),
                      ),
                      if (TurnstileWidget.isEnabled) const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: (authProvider.isLoading || _captchaToken == null) ? null : _submit,
                        child: authProvider.isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('Zaloguj się'),
                      ).animate().fadeIn(delay: 600.ms),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                            );
                          },
                          child: const Text('Zapomniałeś hasła?'),
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Rozdzielacz "lub"
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'lub',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ).animate().fadeIn(delay: 650.ms),
                      const SizedBox(height: 16),

                      // Sign in with Apple — TYLKO iOS (Guideline 4.8:
                      // musi być co najmniej tak samo widoczne jak
                      // logowanie Google, dlatego jest WYŻEJ, nie niżej).
                      if (Platform.isIOS) ...[
                        OutlinedButton.icon(
                          onPressed: (authProvider.isLoading || _captchaToken == null) ? null : _submitApple,
                          icon: const Icon(Icons.apple, size: 22),
                          label: const Text('Kontynuuj z Apple'),
                        ).animate().fadeIn(delay: 680.ms),
                        const SizedBox(height: 12),
                      ],

                      // Google Sign-In — WYŁĄCZNIE Android.
                      //
                      // Na iOS ten przycisk kończył się błędem, bo logowanie
                      // Google nie jest tam skonfigurowane: Info.plist nie ma
                      // klucza GIDClientID ani schematu URL z odwróconym
                      // client ID (bez niego system nie ma jak wrócić do
                      // aplikacji po zalogowaniu w przeglądarce), a
                      // initialize() dostaje tylko serverClientId — na iOS
                      // wtyczka wymaga dodatkowo clientId klienta iOS.
                      // Na Androidzie działa, bo tam tożsamość aplikacji
                      // bierze się z podpisu (SHA-1) zarejestrowanego
                      // w Google Cloud, więc nic nie trzeba podawać w kodzie.
                      //
                      // Użytkownicy iOS mają Sign in with Apple powyżej, więc
                      // nie tracą logowania jednym kliknięciem. Jak włączyć
                      // Google także na iOS — patrz komentarz przy
                      // googleIosClientId w lib/config/api_config.dart.
                      // Po uzupełnieniu przycisk pojawi się na iOS sam.
                      if (!Platform.isIOS || ApiConfig.googleIosClientId.isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: (authProvider.isLoading || _captchaToken == null) ? null : _submitGoogle,
                          icon: const Icon(Icons.g_mobiledata, size: 28),
                          label: const Text('Kontynuuj z Google'),
                        ).animate().fadeIn(delay: 700.ms),
                      const SizedBox(height: 16),
                      
                      // Register Button
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pushNamed('/register');
                        },
                        child: RichText(
                          text: TextSpan(
                            text: 'Nie masz konta?',
                            style: TextStyle(color: AppTheme.textSecondary),
                            children: [
                              TextSpan(
                                text: 'Zarejestruj się',
                                style: TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(delay: 700.ms),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

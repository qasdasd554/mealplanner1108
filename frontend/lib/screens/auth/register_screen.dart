import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/turnstile_widget.dart';
import '../../theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Patrz komentarz przy tym samym polu w login_screen.dart.
  String? _captchaToken;

  /// Akceptacja regulaminu. Wymagana przy zakładaniu konta — Apple
  /// (Guideline 1.2) wymaga jawnej zgody na zasady dotyczące treści
  /// publikowanych przez użytkowników, a nasz regulamin zawiera klauzulę
  /// zerowej tolerancji dla treści obraźliwych.
  bool _termsAccepted = false;

  /// Patrz komentarz przy _captchaAttempt w login_screen.dart — token
  /// Turnstile jest jednorazowy, więc po nieudanej próbie trzeba pobrać
  /// nowy.
  int _captchaAttempt = 0;

  /// Patrz komentarz przy _requireCaptcha w login_screen.dart — ta sama
  /// zasada: przycisk reaguje zamiast być wyszarzony.
  final GlobalKey _captchaKey = GlobalKey();
  final GlobalKey _termsKey = GlobalKey();
  bool _captchaHighlighted = false;
  bool _termsHighlighted = false;

  /// Przewija do wskazanego elementu i podświetla go na chwilę.
  void _pointAt(GlobalKey key, VoidCallback highlight, VoidCallback unhighlight,
      String message) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
          alignment: 0.3);
    }
    setState(highlight);
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(unhighlight);
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ));
  }

  /// Otwiera dokument prawny. Bez sprawdzania canLaunchUrl — ta metoda
  /// bywa zawodna i wcześniej blokowała otwieranie linków (patrz
  /// premium_screen.dart).
  Future<void> _openLegal(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            duration: const Duration(seconds: 3),content: Text('Nie udało się otworzyć: $url')));
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Kolejność sprawdzeń idzie ZGODNIE Z UKŁADEM EKRANU (najpierw
    // regulamin, potem weryfikacja) — inaczej użytkownik byłby odesłany
    // najpierw w dół, a potem z powrotem w górę.
    if (!_termsAccepted) {
      _pointAt(_termsKey, () => _termsHighlighted = true,
          () => _termsHighlighted = false,
          'Zaakceptuj regulamin, aby założyć konto.');
      return;
    }
    if (_captchaToken == null) {
      _pointAt(_captchaKey, () => _captchaHighlighted = true,
          () => _captchaHighlighted = false,
          'Najpierw potwierdź, że nie jesteś robotem.');
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.register(
      _emailController.text.trim(),
      _passwordController.text,
      _nameController.text.trim(),
      captchaToken: _captchaToken,
    );

    if (mounted) {
      if (success) {
        // UWAGA (nowe): konta email/hasło muszą najpierw potwierdzić
        // adres kodem z maila — dopiero POTEM onboarding. Logowanie
        // Google w ogóle tu nie trafia (osobna metoda, już zweryfikowana
        // automatycznie po stronie backendu).
        Navigator.of(context).pushReplacementNamed('/verify-email');
      } else {
        // Token CAPTCHA jest JEDNORAZOWY i został właśnie zużyty przez
        // nieudaną próbę. Bez odtworzenia widgetu kolejna próba (np. po
        // poprawieniu zajętego adresu e-mail) odbiłaby się od bramki
        // z mylącym "Weryfikacja nie powiodła się" zamiast właściwego
        // komunikatu — a użytkownik nie miałby jak tego naprawić.
        setState(() {
          _captchaToken = null;
          _captchaAttempt++;
        });

        ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(authProvider.errorMessage ?? 'Rejestracja nie powiodła się'),
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          // Dekoracyjny rozmyty fioletowy okrąg w tle (Premium look)
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.secondaryColor.withOpacity(0.15),
              ),
            ).animate().fadeIn(duration: 1000.ms).scale(duration: 1000.ms),
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
                      // Tytuł powitalny
                      Text(
                        'Utwórz konto',
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        textAlign: TextAlign.center,
                      ).animate().fadeIn().slideY(begin: 0.2, end: 0),
                      const SizedBox(height: 8),
                      Text(
                        'Dołącz do Meal Planner i planuj sprytnie',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2, end: 0),
                      const SizedBox(height: 32),
                      
                      // Name Input
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Imię / Nazwa użytkownika',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Wprowadź swoje imię';
                          }
                          return null;
                        },
                      ).animate().fadeIn(delay: 200.ms),
                      const SizedBox(height: 16),
                      
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
                      ).animate().fadeIn(delay: 300.ms),
                      const SizedBox(height: 16),
                      
                      // Password Input
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: const InputDecoration(
                          labelText: 'Hasło',
                          prefixIcon: Icon(Icons.lock_outline),
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
                      ).animate().fadeIn(delay: 400.ms),
                      const SizedBox(height: 16),
                      
                      // Confirm Password Input
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscurePassword,
                        decoration: const InputDecoration(
                          labelText: 'Powtórz hasło',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Potwierdź hasło';
                          }
                          if (value != _passwordController.text) {
                            return 'Hasła nie są identyczne';
                          }
                          return null;
                        },
                      ).animate().fadeIn(delay: 500.ms),
                      const SizedBox(height: 16),

                      // Akceptacja regulaminu i polityki prywatności.
                      // Odnośniki są KLIKALNE i otwierają dokumenty —
                      // zgoda na coś, czego nie da się przeczytać, byłaby
                      // pozorna (i kwestionowana przy weryfikacji w App Store).
                      AnimatedContainer(
                        key: _termsKey,
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _termsHighlighted
                                ? AppTheme.errorColor
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: _termsAccepted,
                              onChanged: (v) => setState(() => _termsAccepted = v ?? false),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text('Akceptuję ',
                                      style: TextStyle(
                                          fontSize: 12, color: AppTheme.textSecondary)),
                                  GestureDetector(
                                    onTap: () => _openLegal(
                                        'https://qasdasd554.github.io/mealplanner1108/terms-of-use.html'),
                                    child: Text('regulamin',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.primaryColor,
                                          fontWeight: FontWeight.w600,
                                          decoration: TextDecoration.underline,
                                        )),
                                  ),
                                  Text(' oraz ',
                                      style: TextStyle(
                                          fontSize: 12, color: AppTheme.textSecondary)),
                                  GestureDetector(
                                    onTap: () => _openLegal(
                                        'https://qasdasd554.github.io/mealplanner1108/privacy-policy.html'),
                                    child: Text('politykę prywatności',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.primaryColor,
                                          fontWeight: FontWeight.w600,
                                          decoration: TextDecoration.underline,
                                        )),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      ).animate().fadeIn(delay: 550.ms),
                      const SizedBox(height: 16),

                      // Bramka CAPTCHA — przycisk pozostaje nieaktywny,
                      // dopóki weryfikacja się nie powiedzie.
                      AnimatedContainer(
                        key: _captchaKey,
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _captchaHighlighted
                                ? AppTheme.errorColor
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: TurnstileWidget(
                          key: ValueKey(_captchaAttempt),
                          onToken: (t) => setState(() => _captchaToken = t),
                        ),
                      ),
                      if (TurnstileWidget.isEnabled) const SizedBox(height: 8),

                      // Register Button
                      ElevatedButton(
                        // Przycisk AKTYWNY — brakujące zgody sygnalizuje
                        // _submit, przewijając do nich i podświetlając.
                        onPressed: authProvider.isLoading ? null : _submit,
                        child: authProvider.isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('Zarejestruj się'),
                      ).animate().fadeIn(delay: 600.ms),
                      const SizedBox(height: 16),
                      
                      // Login Link
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: RichText(
                          text: TextSpan(
                            text: 'Masz już konto?',
                            style: TextStyle(color: AppTheme.textSecondary),
                            children: [
                              TextSpan(
                                text: 'Zaloguj się',
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

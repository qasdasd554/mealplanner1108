import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'recipes/ai_add_recipe_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // UWAGA (naprawa — błąd "wraca do ekranu głównego po udostępnieniu z
  // TikToka"): wcześniej ten ekran BEZWARUNKOWO wykonywał
  // pushReplacementNamed('/home') po swoim opóźnieniu, NIEZALEŻNIE od
  // tego, co ShareIntentHandler mógł w międzyczasie już otworzyć na
  // wierzchu stosu nawigacji. pushReplacement zawsze zastępuje TĘ
  // GÓRNĄ trasę (czyli już otwarty ekran AI) trasą '/home' — więc
  // nawet gdyby ShareIntentHandler był błyskawiczny, ten ekran i tak by
  // go nadpisał. Naprawione przez scalenie DECYZJI o trasie docelowej
  // w JEDNYM miejscu (tutaj) — sprawdzamy oczekujący udostępniony link
  // RAZEM z autoryzacją, PRZED podjęciem jedynej, ostatecznej decyzji
  // o nawigacji, zamiast mieć dwa niezależne, konkurujące ze sobą
  // mechanizmy startowe.
  static const MethodChannel _shareChannel = MethodChannel('com.meal_planner_polska_v1/share_intent');

  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Wait for auth initialization with timeout
    if (!authProvider.isInitialized) {
      await Future.any([
        // Wait for initialization
        () async {
          while (!authProvider.isInitialized) {
            await Future.delayed(const Duration(milliseconds: 100));
          }
        }(),
        // Timeout after 5 seconds
        Future.delayed(const Duration(seconds: 5)),
      ]);
    }

    // Sprawdzamy RÓWNOLEGLE z resztą inicjalizacji (nie dodatkowo po),
    // czy aplikacja została otwarta przez udostępnienie linku z innej
    // aplikacji (np. TikToka) — zimny start. To JEDYNE miejsce, które
    // o to pyta; ShareIntentHandler już tego nie robi (patrz jego
    // komentarz), więc nie ma ryzyka, że dwa miejsca "walczą" o tę samą,
    // jednorazowo zwracaną wartość.
    String? sharedUrl;
    try {
      final sharedText = await _shareChannel.invokeMethod<String>('getInitialSharedText');
      if (sharedText != null) {
        final match = RegExp(r'https?://\S+').firstMatch(sharedText);
        sharedUrl = match?.group(0);
      }
    } catch (_) {
      // Cicho ignorujemy — to nie jest krytyczna ścieżka startu aplikacji.
    }

    // Small delay for splash animation
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    if (authProvider.isAuthenticated) {
      if (sharedUrl != null) {
        // Zalogowany i przyszedł z udostępnienia linku — od razu na
        // ekran rozpoznawania przepisu przez AI, z wypełnionym linkiem.
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => AiAddRecipeScreen(initialUrl: sharedUrl)),
        );
      } else {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } else {
      // Niezalogowany — link przepada (rzadki przypadek brzegowy), ale
      // najpierw i tak trzeba się zalogować, więc nie ma go dokąd
      // sensownie przekazać na tym etapie.
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: AppTheme.backgroundColor,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Image.asset(
                'assets/branding/logo.png',
                width: 120,
                height: 120,
              ),
              const SizedBox(height: 24),
              // Tytuł
              Text(
                'Meal Planner',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
              ),
              const SizedBox(height: 8),
              // Podtytuł
              Text(
                'Planuj posiłki mądrze i oszczędzaj',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
              const SizedBox(height: 48),
              // Wskaźnik ładowania
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

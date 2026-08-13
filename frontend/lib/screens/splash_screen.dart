import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
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
    
    // Small delay for splash animation
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    if (authProvider.isAuthenticated) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

/// Ekran "Zapomniałem hasła" — dwa kroki w jednym widgecie (prościej niż
/// osobna nawigacja między dwoma ekranami dla tak krótkiego przepływu):
/// 1. Podaj e-mail -> wysyłamy kod
/// 2. Podaj kod + nowe hasło -> hasło zmienione, wracamy do logowania
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();

  bool _codeSent = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Podaj prawidłowy adres e-mail.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.forgotPassword(email);
    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      // UWAGA: przechodzimy do kroku 2 nawet, gdyby coś poszło nie tak
      // po stronie sieci — backend i tak ZAWSZE zwraca tę samą,
      // generyczną odpowiedź (patrz komentarz w endpoint /forgot-password
      // o ochronie przed enumeracją kont), więc nie ma tu żadnej
      // dodatkowej informacji do pokazania w przypadku niepowodzenia.
      _codeSent = true;
    });
    if (!success && authProvider.errorMessage != null) {
      // To by się zdarzyło tylko przy prawdziwym błędzie sieci/serwera,
      // nie przy "nie znaleziono takiego e-maila" (tego backend celowo
      // nigdy nie mówi wprost).
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authProvider.errorMessage!)),
      );
    }
  }

  Future<void> _submitNewPassword() async {
    final code = _codeController.text.trim();
    final newPassword = _newPasswordController.text;

    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kod musi mieć dokładnie 6 cyfr.')),
      );
      return;
    }
    if (newPassword.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nowe hasło musi mieć co najmniej 8 znaków.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.resetPassword(
      email: _emailController.text.trim(),
      code: code,
      newPassword: newPassword,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hasło zostało zmienione. Zaloguj się nowym hasłem.')),
      );
      Navigator.of(context).pop();
    } else if (authProvider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage!),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zapomniałem hasła')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _codeSent ? _buildStepTwo() : _buildStepOne(),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildStepOne() {
    return [
      Text(
        'Podaj adres e-mail, na który wyślemy kod do zresetowania hasła.',
        style: TextStyle(color: AppTheme.textSecondary),
      ),
      const SizedBox(height: 20),
      TextField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(labelText: 'Adres e-mail', border: OutlineInputBorder()),
      ),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _isSubmitting ? null : _requestCode,
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Wyślij kod'),
        ),
      ),
    ];
  }

  List<Widget> _buildStepTwo() {
    return [
      Text(
        'Jeśli konto z adresem ${_emailController.text.trim()} istnieje, wysłaliśmy '
        'na nie 6-cyfrowy kod. Wpisz go poniżej razem z nowym hasłem.',
        style: TextStyle(color: AppTheme.textSecondary),
      ),
      const SizedBox(height: 20),
      TextField(
        controller: _codeController,
        keyboardType: TextInputType.number,
        maxLength: 6,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
        decoration: const InputDecoration(
          labelText: 'Kod',
          counterText: '',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _newPasswordController,
        obscureText: true,
        decoration: const InputDecoration(labelText: 'Nowe hasło', border: OutlineInputBorder()),
      ),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _isSubmitting ? null : _submitNewPassword,
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Zmień hasło'),
        ),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: _isSubmitting ? null : () => setState(() => _codeSent = false),
        child: const Text('Podaj inny e-mail'),
      ),
    ];
  }
}

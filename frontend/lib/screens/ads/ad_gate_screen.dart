import 'package:flutter/material.dart';
import '../../services/ad_gate_service.dart';
import '../../theme/app_theme.dart';

/// Ekran "obejrzyj reklamę, żeby przejść dalej" — pokazywany PRZED
/// wejściem do Śledzenia dla kont bez Premium, maksymalnie 2 razy na
/// 8 godzin (limit i logika w AdGateService). Zgodnie z zasadami AdMob
/// dla reklam typu "rewarded interstitial", pokazujemy najpierw ten
/// ekran wprowadzający z jasną informacją i możliwością rezygnacji
/// PRZED odpaleniem samej reklamy — nie odpalamy reklamy automatycznie
/// bez zgody użytkownika.
///
/// Zwraca `true` przez Navigator.pop, jeśli reklama została obejrzana
/// do końca (można wpuścić do Śledzenia), `false`/`null` w każdym innym
/// przypadku (użytkownik zrezygnował albo reklama się nie załadowała).
class AdGateScreen extends StatefulWidget {
  const AdGateScreen({super.key});

  @override
  State<AdGateScreen> createState() => _AdGateScreenState();
}

class _AdGateScreenState extends State<AdGateScreen> {
  final AdGateService _adGateService = AdGateService();
  bool _isLoadingAd = false;
  String? _error;

  Future<void> _watchAd() async {
    setState(() {
      _isLoadingAd = true;
      _error = null;
    });

    final earned = await _adGateService.showAd();

    if (!mounted) return;

    if (earned) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _isLoadingAd = false;
        _error = 'Nie udało się załadować reklamy. Sprawdź połączenie z internetem i spróbuj ponownie.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_circle_outline, size: 48, color: AppTheme.primaryColor),
              ),
              const SizedBox(height: 24),
              Text(
                'Obejrzyj krótką reklamę',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Żeby przejść do Śledzenia, obejrzyj krótką reklamę wideo do końca. '
                'To ogranicznie nie dotyczy kont Premium — tam Śledzenie jest zawsze bez reklam.',
                style: TextStyle(color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (_error != null) ...[
                Text(_error!, style: TextStyle(color: AppTheme.errorColor), textAlign: TextAlign.center),
                const SizedBox(height: 16),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isLoadingAd ? null : _watchAd,
                  icon: _isLoadingAd
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.play_arrow),
                  label: Text(_isLoadingAd ? 'Ładowanie reklamy...' : 'Obejrzyj reklamę'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _isLoadingAd ? null : () => Navigator.of(context).pop(false),
                child: const Text('Nie teraz'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

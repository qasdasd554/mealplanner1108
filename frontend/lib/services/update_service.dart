import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../theme/app_theme.dart';

/// Wynik sprawdzenia dostępności aktualizacji.
class UpdateCheckResult {
  final bool updateAvailable;
  final bool forceUpdate;
  final String storeUrl;

  const UpdateCheckResult({
    required this.updateAvailable,
    required this.forceUpdate,
    required this.storeUrl,
  });

  static const none = UpdateCheckResult(
    updateAvailable: false,
    forceUpdate: false,
    storeUrl: '',
  );
}

/// Sprawdza, czy w sklepie jest nowsza wersja aplikacji.
///
/// Numer zainstalowanej wersji bierzemy z `package_info_plus`
/// (buildNumber = część po "+" z pubspec.yaml na Androidzie,
/// CFBundleVersion na iOS), a próg z backendu — osobny dla każdej
/// platformy, bo numeracja iOS i Androida jest niezależna
/// (patrz komentarz przy LATEST_IOS_BUILD_NUMBER w backend/app/core/config.py).
class UpdateService {
  Future<UpdateCheckResult> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(packageInfo.buildNumber);
      if (currentBuild == null) return UpdateCheckResult.none;

      final platform = Platform.isIOS ? 'ios' : 'android';
      // Endpoint jest PUBLICZNY i leży POZA prefiksem /api/v1, więc nie
      // przechodzi przez ApiClient (który dokleja prefiks i token).
      final uri = Uri.parse(
        '${ApiConfig.baseUrl}/app/version-info?platform=$platform',
      );
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return UpdateCheckResult.none;
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      final latestBuild = data['latest_build_number'] as int?;
      if (latestBuild == null) return UpdateCheckResult.none;

      return UpdateCheckResult(
        updateAvailable: currentBuild < latestBuild,
        forceUpdate: data['force_update'] as bool? ?? false,
        storeUrl: data['store_url'] as String? ?? '',
      );
    } catch (_) {
      // Każdy błąd (brak sieci, backend nieosiągalny, zły format) MUSI
      // kończyć się "brak aktualizacji" — sprawdzanie wersji nigdy nie
      // może zablokować uruchomienia aplikacji.
      return UpdateCheckResult.none;
    }
  }
}

/// Pełnoekranowy komunikat o dostępnej aktualizacji.
///
/// Przy `forceUpdate == true` nie da się go zamknąć: brak przycisku
/// "Później" i przechwycony gest cofnięcia (PopScope) — używane, gdy
/// stara wersja przestaje działać z powodu zmiany w API.
class UpdateAvailableScreen extends StatelessWidget {
  final String storeUrl;
  final bool forceUpdate;

  const UpdateAvailableScreen({
    super.key,
    required this.storeUrl,
    this.forceUpdate = false,
  });

  Future<void> _openStore(BuildContext context) async {
    final uri = Uri.parse(storeUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Nie udało się otworzyć sklepu.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !forceUpdate,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.system_update,
                      size: 56,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Dostępna nowa wersja',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    forceUpdate
                        ? 'Ta wersja aplikacji nie jest już obsługiwana. '
                            'Zaktualizuj ją, aby korzystać dalej.'
                        : 'Zaktualizuj aplikację, aby korzystać z najnowszych '
                            'funkcji i poprawek.',
                    style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _openStore(context),
                      icon: const Icon(Icons.download),
                      label: Text(
                        Platform.isIOS ? 'Otwórz App Store' : 'Otwórz Google Play',
                      ),
                    ),
                  ),
                  if (!forceUpdate) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Później'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

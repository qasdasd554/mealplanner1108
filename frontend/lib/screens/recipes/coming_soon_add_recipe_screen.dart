import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Zapowiedź nadchodzącej funkcji: dodawanie własnych przepisów przez
/// użytkowników (z filmu, zdjęcia lub wklejonego tekstu — aplikacja sama
/// rozpozna produkty i rozpisze sposób przygotowania).
///
/// Na razie to tylko zapowiedź — przycisk w liście przepisów jest celowo
/// wyszarzony i prowadzi tutaj, żeby jasno pokazać, że funkcja jest
/// planowana, ale jeszcze nieaktywna (bez udawania, że coś działa, skoro
/// nie działa).
class ComingSoonAddRecipeScreen extends StatelessWidget {
  const ComingSoonAddRecipeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dodaj własny przepis')),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppTheme.secondaryColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome_outlined, size: 40, color: AppTheme.secondaryColor),
            ),
            const SizedBox(height: 24),
            Text(
              'Już wkrótce',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Będziesz mógł dodać własny przepis na trzy sposoby — prześlij '
              'nagranie wideo, zdjęcie dania albo po prostu wklej tekst. '
              'Aplikacja sama rozpozna potrzebne produkty i rozpisze sposób '
              'przygotowania krok po kroku.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 28),
            _buildFeatureRow(Icons.videocam_outlined, 'Prześlij film z gotowania'),
            const SizedBox(height: 12),
            _buildFeatureRow(Icons.photo_camera_outlined, 'Zrób zdjęcie gotowego dania'),
            const SizedBox(height: 12),
            _buildFeatureRow(Icons.text_snippet_outlined, 'Wklej przepis z dowolnego źródła'),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.hourglass_empty),
              label: const Text('Dostępne wkrótce'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 22, color: AppTheme.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
        ),
      ],
    );
  }
}

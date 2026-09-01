import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

/// Ustalona lista powodów zgłoszenia — musi odpowiadać REPORT_REASONS
/// w backend/app/schemas/moderation.py.
const Map<String, String> kReportReasons = {
  'spam': 'Spam albo reklama',
  'inappropriate_content': 'Treść nieodpowiednia',
  'harassment': 'Nękanie albo mowa nienawiści',
  'misinformation': 'Fałszywe informacje',
  'other': 'Inny powód',
};

/// Okno dialogowe zgłoszenia treści (przepis lub komentarz) —
/// Apple Guideline 1.2 wymaga, żeby taki mechanizm istniał i był łatwo
/// dostępny przy każdej treści od użytkownika.
///
/// `onSubmit` dostaje wybrany powód i opcjonalny opis, i powinien
/// zwrócić `true` w razie sukcesu.
Future<void> showReportDialog(
  BuildContext context, {
  required Future<bool> Function(String reason, String? details) onSubmit,
}) async {
  String selectedReason = 'inappropriate_content';
  final detailsController = TextEditingController();

  final submitted = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setState) {
          return AlertDialog(
            title: const Text('Zgłoś treść'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Powód zgłoszenia:'),
                const SizedBox(height: 8),
                ...kReportReasons.entries.map(
                  (entry) => RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.value),
                    value: entry.key,
                    groupValue: selectedReason,
                    onChanged: (v) => setState(() => selectedReason = v!),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: detailsController,
                  maxLength: 1000,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Dodatkowe szczegóły (opcjonalnie)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Anuluj'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Zgłoś'),
              ),
            ],
          );
        },
      );
    },
  );

  if (submitted != true) return;

  final details = detailsController.text.trim();
  final success = await onSubmit(selectedReason, details.isEmpty ? null : details);

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Dziękujemy za zgłoszenie. Nasz zespół je sprawdzi.'
              : 'Nie udało się wysłać zgłoszenia. Spróbuj ponownie.',
        ),
      ),
    );
  }
}

/// Potwierdzenie blokady autora — blokada jest trwała (do momentu
/// ręcznego odblokowania w Profil → Zablokowani użytkownicy), więc
/// wymaga jawnego potwierdzenia, nie dzieje się jednym przypadkowym
/// dotknięciem.
Future<void> showBlockUserDialog(
  BuildContext context, {
  required String userId,
  required String authorName,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Zablokować tego użytkownika?'),
      content: Text(
        'Nie będziesz już widzieć przepisów ani komentarzy od "$authorName". '
        'Możesz cofnąć blokadę w dowolnym momencie w Profil → Zablokowani użytkownicy.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Anuluj'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Zablokuj'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  final success = await authProvider.blockUser(userId);

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Użytkownik "$authorName" został zablokowany.' : 'Nie udało się zablokować użytkownika.',
        ),
      ),
    );
  }
}

/// Menu "..." z opcjami Zgłoś / Zablokuj autora — do użycia w AppBar
/// szczegółów przepisu i przy każdym komentarzu. `authorId` może być
/// `null` (np. oficjalny przepis bez autora-użytkownika) — wtedy opcja
/// blokowania jest pominięta.
class ReportBlockMenu extends StatelessWidget {
  final String? authorId;
  final String authorName;
  final Future<bool> Function(String reason, String? details) onReport;

  const ReportBlockMenu({
    super.key,
    required this.authorId,
    required this.authorName,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        if (value == 'report') {
          showReportDialog(context, onSubmit: onReport);
        } else if (value == 'block' && authorId != null) {
          showBlockUserDialog(context, userId: authorId!, authorName: authorName);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'report',
          child: ListTile(
            leading: Icon(Icons.flag_outlined),
            title: Text('Zgłoś'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        if (authorId != null)
          PopupMenuItem(
            value: 'block',
            child: const ListTile(
              leading: Icon(Icons.block),
              title: Text('Zablokuj autora'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
      ],
    );
  }
}

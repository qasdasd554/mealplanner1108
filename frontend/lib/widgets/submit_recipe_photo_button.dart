import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import '../l10n/market_locale.dart';
import 'package:image_picker/image_picker.dart';

import '../services/recipe_service.dart';
import '../theme/app_theme.dart';
import '../utils/error_utils.dart';

/// Przycisk pozwalający użytkownikowi zaproponować zdjęcie do przepisu.
///
/// Zdjęcie NIE pojawia się od razu — trafia do kolejki moderacji
/// (`pending_photo_base64` w backendzie) i staje się widoczne dopiero po
/// akceptacji administratora. Bez tego każdy mógłby podmienić zdjęcie
/// w dowolnym przepisie, również w oficjalnych.
class SubmitRecipePhotoButton extends StatefulWidget {
  final String recipeId;
  final bool recipeHasPhoto;

  const SubmitRecipePhotoButton({
    super.key,
    required this.recipeId,
    this.recipeHasPhoto = false,
  });

  @override
  State<SubmitRecipePhotoButton> createState() =>
      _SubmitRecipePhotoButtonState();
}

class _SubmitRecipePhotoButtonState extends State<SubmitRecipePhotoButton> {
  final ImagePicker _picker = ImagePicker();
  final RecipeService _recipeService = RecipeService();
  bool _isSending = false;

  Future<void> _pickAndSend(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        // Te same limity co przy rozpoznawaniu przepisu przez AI —
        // backend odrzuca zdjęcia powyżej 3 MB, a bez zmniejszania
        // zdjęcie z nowoczesnego telefonu potrafi mieć znacznie więcej.
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;

      setState(() => _isSending = true);
      final bytes = await File(picked.path).readAsBytes();
      await _recipeService.submitPhoto(widget.recipeId, base64Encode(bytes));

      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(context.strings.detailPhotoSent),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(friendlyError(e, strings: context.strings)),
            backgroundColor: AppTheme.errorColor,
          ),
        );
    }
  }

  void _showSourceSheet() {
    showModalBottomSheet(
      context: context,
      builder:
          (sheetContext) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.recipeHasPhoto)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Text(
                      context.strings.detailPhotoReplaceHelp,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: Text(context.strings.takeRecipePhoto),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _pickAndSend(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: Text(context.strings.aiRecipeChooseGallery),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _pickAndSend(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _isSending ? null : _showSourceSheet,
      icon:
          _isSending
              ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
              : const Icon(Icons.add_a_photo_outlined, size: 18),
      label: Text(
        _isSending
            ? context.strings.detailPhotoSending
            : (widget.recipeHasPhoto
                ? context.strings.detailPhotoReplace
                : context.strings.detailPhotoAdd),
      ),
    );
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/recipe_comment.dart';
import '../providers/auth_provider.dart';
import '../services/recipe_comment_service.dart';
import '../theme/app_theme.dart';

/// Sekcja komentarzy i zdjęć pod przepisem — samodzielny widget z własnym
/// stanem (StatefulWidget), żeby nie trzeba było przerabiać całego ekranu
/// szczegółów przepisu (StatelessWidget) tylko dla tej jednej sekcji.
class RecipeCommentsSection extends StatefulWidget {
  final String recipeId;
  const RecipeCommentsSection({super.key, required this.recipeId});

  @override
  State<RecipeCommentsSection> createState() => _RecipeCommentsSectionState();
}

class _RecipeCommentsSectionState extends State<RecipeCommentsSection> {
  final RecipeCommentService _service = RecipeCommentService();
  final TextEditingController _textController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  List<RecipeComment> _comments = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;
  File? _pickedImage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final comments = await _service.getComments(widget.recipeId);
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _error = null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Nie udało się załadować komentarzy';
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80, // kompresja — zdjęcie trafi do bazy danych, patrz backend
      );
      if (picked != null) {
        setState(() => _pickedImage = File(picked.path));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nie udało się pobrać zdjęcia')),
      );
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Zrób zdjęcie'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Wybierz z galerii'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final text = _textController.text.trim();
    if (text.isEmpty && _pickedImage == null) return;

    setState(() => _isSubmitting = true);
    try {
      String? photoBase64;
      if (_pickedImage != null) {
        final bytes = await _pickedImage!.readAsBytes();
        photoBase64 = base64Encode(bytes);
      }
      await _service.addComment(
        widget.recipeId,
        text: text.isEmpty ? null : text,
        photoBase64: photoBase64,
      );
      _textController.clear();
      setState(() => _pickedImage = null);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _delete(RecipeComment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usunąć komentarz?'),
        content: const Text('Tej operacji nie da się cofnąć.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anuluj')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Usuń', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.deleteComment(widget.recipeId, comment.id);
      setState(() => _comments.removeWhere((c) => c.id == comment.id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nie udało się usunąć komentarza')),
      );
    }
  }

  /// Przełącza polubienie — UI reaguje natychmiast (optymistycznie), bez
  /// czekania na odpowiedź serwera. Jeśli żądanie się nie powiedzie,
  /// cofamy zmianę i informujemy o błędzie.
  Future<void> _toggleLike(RecipeComment comment) async {
    final index = _comments.indexWhere((c) => c.id == comment.id);
    if (index == -1) return;

    final wasLiked = comment.likedByMe;
    final optimistic = comment.copyWithLike(
      likedByMe: !wasLiked,
      likeCount: wasLiked ? comment.likeCount - 1 : comment.likeCount + 1,
    );
    setState(() => _comments[index] = optimistic);

    try {
      if (wasLiked) {
        await _service.unlikeComment(widget.recipeId, comment.id);
      } else {
        await _service.likeComment(widget.recipeId, comment.id);
      }
    } catch (e) {
      // Cofnij optymistyczną zmianę — serwer jej nie potwierdził.
      if (!mounted) return;
      setState(() {
        final currentIndex = _comments.indexWhere((c) => c.id == comment.id);
        if (currentIndex != -1) _comments[currentIndex] = comment;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nie udało się zapisać polubienia')),
      );
    }
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'przed chwilą';
    if (diff.inHours < 1) return '${diff.inMinutes} min temu';
    if (diff.inDays < 1) return '${diff.inHours} godz. temu';
    if (diff.inDays < 7) return '${diff.inDays} dni temu';
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Provider.of<AuthProvider>(context).currentUser?.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Komentarze i zdjęcia',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          _comments.isEmpty
              ? 'Bądź pierwszą osobą, która skomentuje ten przepis'
              : '${_comments.length} ${_comments.length == 1 ? "komentarz" : "komentarzy"}',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 16),

        // ── Formularz dodawania komentarza ─────────────────────────
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_pickedImage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_pickedImage!, height: 140, width: double.infinity, fit: BoxFit.cover),
                      ),
                      Positioned(
                        right: 4,
                        top: 4,
                        child: GestureDetector(
                          onTap: () => setState(() => _pickedImage = null),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              TextField(
                controller: _textController,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Podziel się swoją opinią lub wskazówką...',
                  border: InputBorder.none,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_photo_alternate_outlined, color: AppTheme.primaryColor),
                    onPressed: _isSubmitting ? null : _showImageSourceSheet,
                    tooltip: 'Dodaj zdjęcie',
                  ),
                  const Spacer(),
                  ElevatedButton(
                    // UWAGA (naprawa): globalny styl ElevatedButton w
                    // całej aplikacji wymusza `minimumSize: Size.fromHeight(52)`
                    // — czyli PEŁNA SZEROKOŚĆ. To dobre dla dużych
                    // przycisków logowania/rejestracji, ale wstawione bez
                    // zmian do wąskiego Row (obok ikony zdjęcia) próbowało
                    // być nieskończenie szerokie, co psuło układ i
                    // renderowało przycisk jako niewidoczny. Nadpisuję
                    // styl lokalnie na rozsądny, mały rozmiar.
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(88, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Dodaj'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Lista komentarzy ────────────────────────────────────────
        if (_isLoading)
          const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: AppTheme.primaryColor)))
        else if (_error != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, style: TextStyle(color: AppTheme.textSecondary)),
            ),
          )
        else
          ..._comments.map((comment) {
            final isMine = comment.userId == currentUserId;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: AppTheme.primaryColor.withOpacity(0.15),
                        child: Text(
                          comment.authorName.isNotEmpty ? comment.authorName[0].toUpperCase() : '?',
                          style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(comment.authorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text(
                              _relativeTime(comment.createdAt),
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      if (isMine)
                        IconButton(
                          icon: Icon(Icons.delete_outline, size: 18, color: AppTheme.textSecondary),
                          onPressed: () => _delete(comment),
                          tooltip: 'Usuń komentarz',
                        ),
                    ],
                  ),
                  if (comment.photoBase64 != null) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        base64Decode(comment.photoBase64!),
                        width: double.infinity,
                        height: 180,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                  if (comment.text != null && comment.text!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(comment.text!, style: const TextStyle(fontSize: 14)),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      InkWell(
                        onTap: () => _toggleLike(comment),
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                comment.likedByMe ? Icons.favorite : Icons.favorite_border,
                                size: 18,
                                color: comment.likedByMe ? AppTheme.errorColor : AppTheme.textSecondary,
                              ),
                              if (comment.likeCount > 0) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '${comment.likeCount}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: comment.likedByMe ? AppTheme.errorColor : AppTheme.textSecondary,
                                    fontWeight: comment.likedByMe ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

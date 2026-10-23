import 'package:flutter/material.dart';

/// Keeps the existing action row on regular screens. On a narrow/text-enlarged
/// sheet, secondary badges move below the description instead of taking all
/// the space from the actionable title. No font shrinking or clipped labels.
class AdaptiveActionTile extends StatelessWidget {
  const AdaptiveActionTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.titleMaxLines,
    this.subtitleMaxLines,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final int? titleMaxLines;
  final int? subtitleMaxLines;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
      final stackBadge =
          trailing != null && constraints.maxWidth / textScale < 340;
      return ListTile(
        leading: Icon(icon),
        title: Text(
          title,
          maxLines: stackBadge ? null : titleMaxLines,
          overflow:
              stackBadge || titleMaxLines == null
                  ? null
                  : TextOverflow.ellipsis,
        ),
        subtitle:
            stackBadge
                ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (subtitle != null) Text(subtitle!),
                    const SizedBox(height: 4),
                    trailing!,
                  ],
                )
                : subtitle == null
                ? null
                : Text(
                  subtitle!,
                  maxLines: subtitleMaxLines,
                  overflow:
                      subtitleMaxLines == null ? null : TextOverflow.ellipsis,
                ),
        trailing: stackBadge ? null : trailing,
        onTap: onTap,
      );
    },
  );
}

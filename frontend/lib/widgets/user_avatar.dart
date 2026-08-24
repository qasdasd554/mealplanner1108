import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Reużywalny awatar użytkownika — pokazuje jeden z dwóch gotowych,
/// stylizowanych placeholderów ("male"/"female") jako kolorowe koło z
/// ikoną, albo neutralną domyślną ikonę, gdy użytkownik nie wybrał
/// jeszcze żadnego awatara. Używany zarówno w profilu (duży, do wyboru),
/// jak i w rankingu autorów przepisów (mały, tylko do wyświetlenia).
class UserAvatar extends StatelessWidget {
  final String? avatar;
  final double size;
  final bool selected;

  const UserAvatar({
    super.key,
    required this.avatar,
    this.size = 40,
    this.selected = false,
  });

  static const _femaleGradient = [Color(0xFFF472B6), Color(0xFFEC4899)];
  static const _maleGradient = [Color(0xFF60A5FA), Color(0xFF3B82F6)];
  static const _neutralGradient = [Color(0xFFBBBBBB), Color(0xFF9CA3AF)];

  @override
  Widget build(BuildContext context) {
    final List<Color> gradient;
    final IconData icon;
    switch (avatar) {
      case 'female':
        gradient = _femaleGradient;
        icon = Icons.woman;
        break;
      case 'male':
        gradient = _maleGradient;
        icon = Icons.man;
        break;
      default:
        gradient = _neutralGradient;
        icon = Icons.person;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: selected ? Border.all(color: AppTheme.primaryColor, width: 3) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.6),
    );
  }
}

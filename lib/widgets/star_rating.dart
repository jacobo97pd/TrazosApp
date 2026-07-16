import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Muestra las estrellas de corredor (1..5) rellenas según el rango.
class StarRating extends StatelessWidget {
  const StarRating({super.key, required this.stars, this.size = 16, this.color});
  final int stars;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.gold;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            i <= stars ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: i <= stars ? c : AppColors.border,
          ),
      ],
    );
  }
}

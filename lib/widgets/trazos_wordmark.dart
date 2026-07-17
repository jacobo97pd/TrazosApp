import 'package:flutter/material.dart';

class TrazosWordmark extends StatelessWidget {
  const TrazosWordmark({
    super.key,
    required this.width,
  });

  final double width;

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/images/trazos-wordmark.png',
        width: width,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        semanticLabel: 'Trazos',
      );
}

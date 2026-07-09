import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'location_simulator.dart';

/// Joystick flotante (solo pruebas) que mueve la posición simulada. Arrástralo
/// para "correr" en esa dirección; suéltalo para pararte.
class SimJoystick extends StatefulWidget {
  const SimJoystick({super.key, this.size = 132});
  final double size;

  @override
  State<SimJoystick> createState() => _SimJoystickState();
}

class _SimJoystickState extends State<SimJoystick> {
  Offset _knob = Offset.zero; // desplazamiento del centro, en px

  double get _radius => widget.size / 2;
  double get _knobRadius => widget.size * 0.22;
  double get _maxTravel => _radius - _knobRadius;

  void _update(Offset localPos) {
    // localPos relativo al centro del joystick.
    var v = localPos - Offset(_radius, _radius);
    if (v.distance > _maxTravel) {
      v = Offset.fromDirection(v.direction, _maxTravel);
    }
    setState(() => _knob = v);
    LocationSimulator.instance.setVector(v.dx / _maxTravel, v.dy / _maxTravel);
  }

  void _reset() {
    setState(() => _knob = Offset.zero);
    LocationSimulator.instance.setVector(0, 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (d) => _update(d.localPosition),
      onPanUpdate: (d) => _update(d.localPosition),
      onPanEnd: (_) => _reset(),
      onPanCancel: _reset,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surface.withValues(alpha: 0.85),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Stack(
          children: [
            const Center(
              child: Icon(Icons.open_with_rounded,
                  color: AppColors.textDisabled, size: 26),
            ),
            Align(
              alignment: Alignment.center,
              child: Transform.translate(
                offset: _knob,
                child: Container(
                  width: _knobRadius * 2,
                  height: _knobRadius * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.gradientAccent,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.4),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.directions_run_rounded,
                      color: Colors.white, size: 24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

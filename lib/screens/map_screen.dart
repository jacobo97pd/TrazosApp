import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../core/router.dart';
import '../providers/zones_provider.dart';

// Cámara por defecto (Madrid) hasta tener la ubicación del usuario
const _defaultCameraPosition = CameraPosition(
  target: LatLng(40.4168, -3.7038),
  zoom:   14.5,
);

/// Mapa limpio y NO interactivo: muestra las zonas y tu ubicación, sin gestos
/// ni controles ni overlays. Los tiles se cachean automáticamente.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  GoogleMapController? _mapController;
  String? _darkMapStyle;

  @override
  void initState() {
    super.initState();
    rootBundle.loadString('assets/map_style_dark.json').then((style) {
      if (mounted) setState(() => _darkMapStyle = style);
    });
    _centerOnUser();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  // Centra la cámara en la ubicación del usuario (una sola vez, sin seguirlo).
  Future<void> _centerOnUser() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition();
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 15),
      );
    } catch (_) {
      // Sin permiso/ubicación: nos quedamos en la cámara por defecto.
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _centerOnUser();
  }

  @override
  Widget build(BuildContext context) {
    final polygons = ref.watch(mapPolygonsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Mapa limpio, sin interacción ────────────────────────────────────
          GoogleMap(
            initialCameraPosition: _defaultCameraPosition,
            onMapCreated: _onMapCreated,
            style: _darkMapStyle,
            polygons: polygons,
            myLocationEnabled: true,
            // Todo desactivado: mapa solo de visualización
            scrollGesturesEnabled:   false,
            zoomGesturesEnabled:     false,
            tiltGesturesEnabled:     false,
            rotateGesturesEnabled:   false,
            zoomControlsEnabled:     false,
            myLocationButtonEnabled: false,
            mapToolbarEnabled:       false,
            compassEnabled:          false,
            buildingsEnabled:        false,
          ),

          // ── Banner de marca (no interactivo) ───────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: IgnorePointer(
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 14,
                  left: 20, right: 20, bottom: 22,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end:   Alignment.bottomCenter,
                    colors: [
                      AppColors.background,
                      AppColors.background.withValues(alpha: 0),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'TRAZOS',
                      style: AppTextStyles.displayMedium.copyWith(
                        letterSpacing: 3,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Conquista las zonas, compite por ser el mejor',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Único control: empezar a correr ────────────────────────────────
          Positioned(
            left: 24, right: 24,
            bottom: MediaQuery.of(context).padding.bottom + 20,
            child: ElevatedButton.icon(
              onPressed: () => context.push(AppRoutes.run),
              icon:  const Icon(Icons.play_arrow_rounded),
              label: const Text('Correr'),
            ),
          ),
        ],
      ),
    );
  }
}

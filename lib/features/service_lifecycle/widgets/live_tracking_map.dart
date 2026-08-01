import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../../core/models/user_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../geo_broadcast/services/provider_presence_service.dart';

/// Live map showing the assigned provider's moving location alongside the
/// customer's exact location — OpenStreetMap tiles via `flutter_map`, no
/// Google Maps API key required (Module 7 live tracking).
class LiveTrackingMap extends StatelessWidget {
  final String providerId;
  final GeoPoint customerLocation;
  final double height;

  const LiveTrackingMap({
    super.key,
    required this.providerId,
    required this.customerLocation,
    this.height = 220,
  });

  @override
  Widget build(BuildContext context) {
    final customerLatLng = ll.LatLng(
      customerLocation.latitude,
      customerLocation.longitude,
    );

    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: StreamBuilder<GeoPoint>(
          stream: ProviderPresenceService.instance.watchProviderLocation(
            providerId,
          ),
          builder: (context, snapshot) {
            final providerLocation = snapshot.data;
            final providerLatLng = providerLocation == null
                ? null
                : ll.LatLng(
                    providerLocation.latitude,
                    providerLocation.longitude,
                  );

            return FlutterMap(
              options: MapOptions(
                initialCenter: providerLatLng ?? customerLatLng,
                initialZoom: 14,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.fixwaala.fixwaala',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: customerLatLng,
                      width: 36,
                      height: 36,
                      child: const Icon(
                        Icons.home_rounded,
                        color: AppColors.primary,
                        size: 32,
                      ),
                    ),
                    if (providerLatLng != null)
                      Marker(
                        point: providerLatLng,
                        width: 36,
                        height: 36,
                        child: const Icon(
                          Icons.handyman_rounded,
                          color: AppColors.accent,
                          size: 32,
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

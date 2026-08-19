import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../../core/models/user_model.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/custom_button.dart';
import '../../auth/services/auth_service.dart';

class ProviderLocationScreen extends StatefulWidget {
  const ProviderLocationScreen({super.key});

  @override
  State<ProviderLocationScreen> createState() =>
      _ProviderLocationScreenState();
}

class _ProviderLocationScreenState extends State<ProviderLocationScreen> {
  final _mapController = MapController();
  GeoPoint? _selected;
  String? _address;
  bool _resolvingAddress = false;
  bool _saving = false;
  bool _loadingInitial = true;

  static const _fallbackCenter = GeoPoint(12.9716, 77.5946); // Bengaluru

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    final user = await AuthService.instance.currentUser();
    final existing =
        user?.providerProfile?.baseLocation ??
        user?.providerProfile?.liveLocation;
    if (!mounted) return;
    setState(() {
      _selected = existing ?? _fallbackCenter;
      _address = user?.providerProfile?.baseAddress;
      _loadingInitial = false;
    });
  }

  Future<void> _onTap(GeoPoint point) async {
    setState(() {
      _selected = point;
      _resolvingAddress = true;
      _address = null;
    });
    final address = await LocationService.instance.reverseGeocode(point);
    if (!mounted) return;
    setState(() {
      _address = address;
      _resolvingAddress = false;
    });
  }

  Future<void> _save() async {
    final point = _selected;
    if (point == null || _saving) return;
    setState(() => _saving = true);
    final user = await AuthService.instance.currentUser();
    final existingProfile = user?.providerProfile ?? const ProviderProfile();
    await AuthService.instance.updateProviderProfile(
      existingProfile.copyWith(baseLocation: point, baseAddress: _address),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Location saved')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingInitial || _selected == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final selected = _selected!;
    return Scaffold(
      appBar: AppBar(title: const Text('Set your location')),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: ll.LatLng(
                  selected.latitude,
                  selected.longitude,
                ),
                initialZoom: 15,
                onTap: (_, point) =>
                    _onTap(GeoPoint(point.latitude, point.longitude)),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.fixwaala.app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: ll.LatLng(
                        selected.latitude,
                        selected.longitude,
                      ),
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_pin,
                        color: AppColors.primary,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Tap the map to drop a pin at your base location.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _resolvingAddress
                      ? 'Resolving address...'
                      : (_address ?? 'No address resolved yet'),
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'Save location',
                  loading: _saving,
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

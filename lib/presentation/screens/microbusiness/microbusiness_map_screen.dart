import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/utils/maps_url.dart';
import '../../../domain/entities/microbusiness.dart';
import '../../viewmodels/microbusiness_viewmodel.dart';

class MicrobusinessMapScreen extends ConsumerStatefulWidget {
  const MicrobusinessMapScreen({super.key, this.focusId});

  final String? focusId;

  @override
  ConsumerState<MicrobusinessMapScreen> createState() =>
      _MicrobusinessMapScreenState();
}

class _MicrobusinessMapScreenState
    extends ConsumerState<MicrobusinessMapScreen> {
  GoogleMapController? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(microbusinessViewModelProvider);
    final businesses = state.nearbyBusinesses.isEmpty
        ? state.businesses
        : state.nearbyBusinesses;
    final locatedBusinesses = businesses.where(_hasValidLocation).toList();
    final focused = widget.focusId == null
        ? null
        : _findBusiness(locatedBusinesses, widget.focusId!);
    final initial = focused ??
        (state.userPosition == null
            ? (locatedBusinesses.isEmpty ? null : locatedBusinesses.first)
            : null);
    final initialTarget = state.userPosition == null
        ? LatLng(initial?.latitud ?? 4.7110, initial?.longitud ?? -74.0721)
        : LatLng(
            state.userPosition!.latitude,
            state.userPosition!.longitude,
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de micronegocios'),
        leading: IconButton(
          tooltip: 'Volver',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/micronegocios');
            }
          },
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            tooltip: 'Inicio',
            onPressed: () => context.go('/entrepreneur'),
            icon: const Icon(Icons.home_outlined),
          ),
          IconButton(
            tooltip: 'Cercanos',
            onPressed: _loadNearbyAndCenter,
            icon: const Icon(Icons.my_location_outlined),
          ),
        ],
      ),
      body: _buildBody(
        context: context,
        state: state,
        businesses: locatedBusinesses,
        initialTarget: initialTarget,
      ),
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required MicrobusinessState state,
    required List<Microbusiness> businesses,
    required LatLng initialTarget,
  }) {
    if (state.isLoading && businesses.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (businesses.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No hay micronegocios con coordenadas válidas para mostrar.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: initialTarget,
            zoom: 13,
          ),
          markers: businesses.map(_markerFor).toSet(),
          myLocationEnabled: state.userPosition != null,
          myLocationButtonEnabled: false,
          mapToolbarEnabled: false,
          zoomControlsEnabled: false,
          onMapCreated: (controller) {
            _controller = controller;
            final focused = widget.focusId == null
                ? null
                : _findBusiness(businesses, widget.focusId!);
            if (focused != null) _animateToBusiness(focused);
          },
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: _MapSummaryPanel(
            total: businesses.length,
            nearbyMode: state.nearbyBusinesses.isNotEmpty,
            locationDenied: state.locationDenied,
            error: state.error,
            onShowAll: () =>
                ref.read(microbusinessViewModelProvider.notifier).loadInitial(),
          ),
        ),
      ],
    );
  }

  Marker _markerFor(Microbusiness business) {
    return Marker(
      markerId: MarkerId(business.id),
      position: LatLng(business.latitud, business.longitud),
      infoWindow: InfoWindow(
        title: business.nombre,
        snippet: business.categoria,
        onTap: () => _openDetail(business),
      ),
      onTap: () => _showBusinessSheet(business),
    );
  }

  Future<void> _loadNearbyAndCenter() async {
    await ref.read(microbusinessViewModelProvider.notifier).loadNearby();
    final position = ref.read(microbusinessViewModelProvider).userPosition;
    if (position == null || _controller == null) return;

    await _controller!.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(position.latitude, position.longitude),
        14,
      ),
    );
  }

  Future<void> _animateToBusiness(Microbusiness business) async {
    await _controller?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(business.latitud, business.longitud),
        15,
      ),
    );
  }

  void _showBusinessSheet(Microbusiness business) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              business.nombre,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(business.direccion),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _openDetail(business),
                    icon: const Icon(Icons.storefront_outlined),
                    label: const Text('Detalle'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => openMapsUri(mapsDirectionsUri(business)),
                    icon: const Icon(Icons.directions_outlined),
                    label: const Text('Cómo llegar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openDetail(Microbusiness business) {
    if (context.mounted) {
      context.push('/micronegocios/detail/${business.id}');
    }
  }

  bool _hasValidLocation(Microbusiness business) {
    return business.latitud >= -90 &&
        business.latitud <= 90 &&
        business.longitud >= -180 &&
        business.longitud <= 180 &&
        !(business.latitud == 0 && business.longitud == 0);
  }

  Microbusiness? _findBusiness(List<Microbusiness> businesses, String id) {
    for (final business in businesses) {
      if (business.id == id) return business;
    }
    return null;
  }
}

class _MapSummaryPanel extends StatelessWidget {
  const _MapSummaryPanel({
    required this.total,
    required this.nearbyMode,
    required this.locationDenied,
    required this.error,
    required this.onShowAll,
  });

  final int total;
  final bool nearbyMode;
  final bool locationDenied;
  final String? error;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final message = locationDenied
        ? 'Activa el permiso de ubicación para ver negocios cercanos.'
        : nearbyMode
            ? '$total micronegocios cercanos'
            : '$total micronegocios en el mapa';

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.place_outlined),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                error ?? message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (nearbyMode)
              TextButton(
                onPressed: onShowAll,
                child: const Text('Ver todos'),
              ),
          ],
        ),
      ),
    );
  }
}

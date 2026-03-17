import 'package:citycab/pages/map/map_state.dart';
import 'package:citycab/pages/map/widgets/bottom_slide.dart';
import 'package:citycab/services/map_services.dart';
import 'package:citycab/ui/info_window/custom_info_window.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

class MapView extends StatefulWidget {
  const MapView({Key? key}) : super(key: key);

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  late final MapState _mapState;

  @override
  void initState() {
    super.initState();
    _mapState = MapState();
  }

  @override
  void dispose() {
    _mapState.dispose();
    MapService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MapState>.value(
      value: _mapState,
      child: Consumer<MapState>(
        builder: (context, state, child) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;

            final message = state.uiMessage;
            if (message != null && message.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(message)),
              );
              state.clearMessage();
            }
          });

          final LatLng initialTarget = state.currentPosition.value?.latLng ??
              const LatLng(24.7136, 46.6753);

          return Scaffold(
            body: Stack(
              children: [
                ValueListenableBuilder<List<Marker>>(
                  valueListenable: MapService.instance.markers,
                  builder: (context, markers, _) {
                    return GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: initialTarget,
                        zoom: 14,
                      ),
                      myLocationEnabled: false,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                      polylines: state.polylines,
                      markers: markers.toSet(),
                      onMapCreated: state.onMapCreated,
                      onTap: state.onTapMap,
                      onCameraMove: state.onCameraMove,
                    );
                  },
                ),
                CustomInfoWindow(
                  controller: MapService.instance.controller,
                  height: 90,
                  width: 220,
                  offset: 50,
                ),
                const Align(
                  alignment: Alignment.bottomCenter,
                  child: BottomSlide(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

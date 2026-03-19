import 'package:citycab/constant/my_address.dart';
import 'package:citycab/models/ride.dart';
import 'package:citycab/ui/theme.dart';
import 'package:citycab/ui/widget/buttons/city_cab_button.dart';
import 'package:citycab/ui/widget/cards/address_card.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../map_state.dart';

class TakeARide extends StatelessWidget {
  const TakeARide({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MapState>();
    final bool isUserDriver = state.isDriverUser;

    if (isUserDriver) {
      final Ride? incomingRide = state.incomingRide;
      final double distanceKm = state.incomingRideDistanceKm;
      final int etaMinutes = state.incomingRideEtaMinutes;
      final int secondsRemaining = state.incomingRideSecondsRemaining;
      final double progress = secondsRemaining <= 0
          ? 0
          : (secondsRemaining / 15).clamp(0.0, 1.0).toDouble();

      return Padding(
        padding: const EdgeInsets.all(CityTheme.elementSpacing),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CityCabButton(
              title: state.isActive ? 'Go Offline' : 'Go Online',
              textColor: Colors.white,
              color: state.isActive ? Colors.green : Colors.red,
              onTap: () {
                state.changeActivePresence();
              },
            ),
            const SizedBox(height: 16),
            if (!state.isActive)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Go online to receive ride requests.',
                  textAlign: TextAlign.center,
                ),
              ),
            if (state.isActive && incomingRide == null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Waiting for ride requests...',
                  textAlign: TextAlign.center,
                ),
              ),
            if (state.isActive && incomingRide != null) ...[
              const SizedBox(height: 16),
              Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'New Ride Request',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 8,
                          value: progress,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            secondsRemaining <= 5 ? Colors.red : Colors.orange,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        secondsRemaining > 0
                            ? 'Accept within ${secondsRemaining}s before the request moves to the next driver.'
                            : 'Request window is closing...',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: secondsRemaining <= 5
                              ? Colors.red.shade700
                              : Colors.orange.shade800,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _MetricTile(
                              label: 'Distance',
                              value: distanceKm > 0
                                  ? '${distanceKm.toStringAsFixed(1)} km'
                                  : '--',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MetricTile(
                              label: 'ETA',
                              value: etaMinutes > 0 ? '$etaMinutes min' : '--',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MetricTile(
                              label: 'Fare',
                              value:
                                  '${incomingRide.rideOption.price.toStringAsFixed(2)} SAR',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Pickup: ${state.formatAddressLine(incomingRide.startAddress)}',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Drop-off: ${state.formatAddressLine(incomingRide.endAddress)}',
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            state.previewIncomingRideRoute();
                          },
                          icon: const Icon(Icons.alt_route),
                          label: const Text('Preview Route'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                              onPressed: () {
                                state.acceptRide(incomingRide);
                              },
                              child: const Text('ACCEPT'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              onPressed: () {
                                state.rejectRide(incomingRide);
                              },
                              child: const Text('DECLINE'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          InkWell(
            onTap: () {
              state.searchLocation();
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 54,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: const BorderRadius.all(
                  Radius.circular(10),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Enter Your Destination...',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.search, size: 30),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(
            myAddresses.length,
            (index) {
              final address = myAddresses[index];
              return AddressCard(
                address: address,
                onTap: () {
                  state.onTapMyAddresses(address);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;

  const _MetricTile({
    Key? key,
    required this.label,
    required this.value,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

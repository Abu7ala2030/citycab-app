import 'package:citycab/pages/map/map_state.dart';
import 'package:citycab/ui/theme.dart';
import 'package:citycab/ui/widget/buttons/city_cab_button.dart';
import 'package:citycab/ui/widget/titles/bottom_slider_title.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DriverOnTheWay extends StatelessWidget {
  const DriverOnTheWay({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MapState>();
    final bool isDriver = state.isDriverUser;

    final passenger = state.passengerUser;
    final driver = state.assignedDriver;
    final start = state.currentRide?.startAddress ?? state.startAddress;
    final end = state.currentRide?.endAddress ?? state.endAddress;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isDriver ? 'GO TO PASSENGER PICKUP' : 'YOUR DRIVER IS ON THE WAY',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isDriver
                ? 'Preview the pickup route, then navigate to the passenger and start the trip.'
                : 'Your driver has accepted the ride and is heading to your pickup point.',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          _InfoCard(
            title: isDriver ? 'Pickup overview' : 'Driver status',
            children: [
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      label: isDriver ? 'Distance to pickup' : 'Distance away',
                      value: state.distanceRemainingKm > 0
                          ? '${state.distanceRemainingKm.toStringAsFixed(1)} km'
                          : '--',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricTile(
                      label: 'ETA',
                      value: state.driverArrivalMinutes > 0
                          ? '${state.driverArrivalMinutes} min'
                          : '--',
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (isDriver)
            _InfoCard(
              title: 'Passenger information',
              children: [
                _InfoRow(
                  label: 'Passenger',
                  value: (passenger?.getFullName ?? '').trim().isNotEmpty
                      ? passenger!.getFullName
                      : 'Unknown passenger',
                ),
                _InfoRow(
                  label: 'Phone',
                  value: (passenger?.phone ?? '').trim().isNotEmpty
                      ? passenger!.phone
                      : 'Not available',
                ),
                _InfoRow(
                  label: 'Pickup',
                  value: state.formatAddressLine(start).isNotEmpty
                      ? state.formatAddressLine(start)
                      : 'Pickup location not available',
                ),
                _InfoRow(
                  label: 'Drop-off',
                  value: state.formatAddressLine(end).isNotEmpty
                      ? state.formatAddressLine(end)
                      : 'Drop-off location not available',
                ),
              ],
            )
          else
            _InfoCard(
              title: 'Driver information',
              children: [
                _InfoRow(
                  label: 'Driver',
                  value: (driver?.getFullName ?? '').trim().isNotEmpty
                      ? driver!.getFullName
                      : 'Driver assigned',
                ),
                _InfoRow(
                  label: 'Phone',
                  value: (driver?.phone ?? '').trim().isNotEmpty
                      ? driver!.phone
                      : 'Not available',
                ),
                _InfoRow(
                  label: 'Pickup',
                  value: state.formatAddressLine(start).isNotEmpty
                      ? state.formatAddressLine(start)
                      : 'Pickup location not available',
                ),
                _InfoRow(
                  label: 'Drop-off',
                  value: state.formatAddressLine(end).isNotEmpty
                      ? state.formatAddressLine(end)
                      : 'Drop-off location not available',
                ),
              ],
            ),
          const SizedBox(height: 18),
          if (isDriver) ...[
            Row(
              children: [
                Expanded(
                  child: CityCabButton(
                    title: state.isUpdatingDriverRoute
                        ? 'LOADING ROUTE...'
                        : 'ROUTE TO PICKUP',
                    color: CityTheme.cityblue,
                    textColor: Colors.white,
                    disableColor: CityTheme.cityLightGrey,
                    buttonState: state.isUpdatingDriverRoute
                        ? ButtonState.loading
                        : ButtonState.initial,
                    onTap: () {
                      state.driverShowRouteToPickup();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CityCabButton(
                    title: 'START TRIP',
                    color: Colors.green,
                    textColor: Colors.white,
                    disableColor: CityTheme.cityLightGrey,
                    buttonState: ButtonState.initial,
                    onTap: () {
                      state.driverStartTrip();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: state.callPassenger,
                icon: const Icon(Icons.call_outlined),
                label: const Text('Call Passenger'),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: CityCabButton(
                title: state.isCallingDriver ? 'CALLING...' : 'CALL DRIVER',
                color: CityTheme.cityblue,
                textColor: Colors.white,
                disableColor: CityTheme.cityLightGrey,
                buttonState: state.isCallingDriver
                    ? ButtonState.loading
                    : ButtonState.initial,
                onTap: () {
                  state.callDriver();
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoCard({
    Key? key,
    required this.title,
    required this.children,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
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
      padding: const EdgeInsets.all(12),
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
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    Key? key,
    required this.label,
    required this.value,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey.shade700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:citycab/pages/map/map_state.dart';
import 'package:citycab/ui/theme.dart';
import 'package:citycab/ui/widget/buttons/city_cab_button.dart';
import 'package:citycab/ui/widget/titles/bottom_slider_title.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class InMotion extends StatefulWidget {
  const InMotion({Key? key}) : super(key: key);

  @override
  State<InMotion> createState() => _InMotionState();
}

class _InMotionState extends State<InMotion> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MapState>();
    return state.isDriverUser
        ? const _DriverTripPanel()
        : const _PassengerTripPanel();
  }
}

class _PassengerTripPanel extends StatelessWidget {
  const _PassengerTripPanel();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MapState>();
    final ride = state.currentRide;
    final option = ride?.rideOption ?? state.selectedOption;
    final start = ride?.startAddress ?? state.startAddress;
    final end = ride?.endAddress ?? state.endAddress;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 16),
          child: BottomSliderTitle(title: 'YOU ARE ON YOUR WAY'),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Your driver is taking you to the destination.',
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
        ),
        const SizedBox(height: 16),
        _TripSummaryCard(
          title: option?.title ?? 'Ride',
          amount:
              '${(option?.price ?? state.ridePrice).toStringAsFixed(2)} SAR',
          primaryLabel: 'Remaining',
          primaryValue: state.distanceRemainingKm > 0
              ? '${state.distanceRemainingKm.toStringAsFixed(1)} km'
              : 'Almost there',
          secondaryLabel: 'ETA',
          secondaryValue: state.etaLabel,
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _AddressTimeline(
              start: state.formatAddressLine(start),
              end: state.formatAddressLine(end)),
        ),
      ],
    );
  }
}

class _DriverTripPanel extends StatelessWidget {
  const _DriverTripPanel();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MapState>();
    final ride = state.currentRide;
    final passenger = state.passengerUser;
    final end = ride?.endAddress ?? state.endAddress;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 16),
          child: BottomSliderTitle(title: 'DRIVE TO DESTINATION'),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Passenger is onboard. Follow the route to the drop-off point.',
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
        ),
        const SizedBox(height: 16),
        _TripSummaryCard(
          title: passenger?.getFullName.isNotEmpty == true
              ? passenger!.getFullName
              : 'Passenger',
          amount:
              '${(ride?.rideOption.price ?? state.ridePrice).toStringAsFixed(2)} SAR',
          primaryLabel: 'Remaining',
          primaryValue: state.distanceRemainingKm > 0
              ? '${state.distanceRemainingKm.toStringAsFixed(1)} km'
              : 'Almost there',
          secondaryLabel: 'Destination',
          secondaryValue: state.etaLabel,
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _AddressTimeline(
              start: 'Passenger onboard', end: state.formatAddressLine(end)),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: CityCabButton(
                  title:
                      state.isCallingDriver ? 'Calling...' : 'Call Passenger',
                  color: CityTheme.cityblue,
                  textColor: Colors.white,
                  disableColor: CityTheme.cityLightGrey,
                  buttonState: state.isCallingDriver
                      ? ButtonState.loading
                      : ButtonState.initial,
                  onTap: state.callPassenger,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CityCabButton(
                  title: 'Arrived',
                  color: Colors.green,
                  textColor: Colors.white,
                  disableColor: CityTheme.cityLightGrey,
                  buttonState: ButtonState.initial,
                  onTap: state.driverArriveAtDestination,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TripSummaryCard extends StatelessWidget {
  final String title;
  final String amount;
  final String primaryLabel;
  final String primaryValue;
  final String secondaryLabel;
  final String secondaryValue;

  const _TripSummaryCard({
    required this.title,
    required this.amount,
    required this.primaryLabel,
    required this.primaryValue,
    required this.secondaryLabel,
    required this.secondaryValue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CityTheme.cityblue.withOpacity(.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                amount,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: CityTheme.cityblue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                  child: _MetricTile(label: primaryLabel, value: primaryValue)),
              const SizedBox(width: 10),
              Expanded(
                  child: _MetricTile(
                      label: secondaryLabel, value: secondaryValue)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;

  const _MetricTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _AddressTimeline extends StatelessWidget {
  final String start;
  final String end;

  const _AddressTimeline({required this.start, required this.end});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 10,
          top: 22,
          bottom: 25,
          child: Container(width: 2.5, color: Colors.grey[400]),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(CupertinoIcons.circle_fill,
                    color: CityTheme.cityblue, size: 16),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(start,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, height: 1.4))),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(CupertinoIcons.placemark_fill,
                    color: CityTheme.cityblue, size: 18),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(end,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, height: 1.4))),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

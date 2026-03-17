import 'dart:async';

import 'package:citycab/pages/map/map_state.dart';
import 'package:citycab/ui/theme.dart';
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
    _startRefreshTimer();
  }

  void _startRefreshTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
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

    final ride = state.currentRide;
    final option = ride?.rideOption ?? state.selectedOption;
    final start = ride?.startAddress ?? state.startAddress;
    final end = ride?.endAddress ?? state.endAddress;

    final double price = option?.price ?? 0;
    final double remainingKm = state.distanceRemainingKm;
    final double progress = state.tripProgress.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 16),
          child: BottomSliderTitle(title: 'YOU ARE IN MOTION'),
        ),
        const SizedBox(height: 16),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: CityTheme.cityblue.withOpacity(.08),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  if (option != null)
                    Image.asset(
                      option.icon,
                      height: 50,
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          option?.title ?? 'Ride',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${price.toStringAsFixed(2)} SAR',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.bolt,
                    color: Colors.orange[300],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: Colors.grey[700],
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      state.etaLabel,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: CityTheme.cityblue,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress <= 0 ? 0.02 : progress,
                  minHeight: 6,
                  backgroundColor: Colors.grey[300],
                  color: CityTheme.cityblue,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Distance remaining',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(
                    '${remainingKm.toStringAsFixed(1)} km',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: CityTheme.cityblue,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: CityTheme.elementSpacing),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Stack(
            children: [
              Positioned(
                left: 10,
                top: 22,
                bottom: 25,
                child: Container(
                  width: 2.5,
                  color: Colors.grey[400],
                ),
              ),
              Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        CupertinoIcons.circle_fill,
                        color: CityTheme.cityblue,
                        size: 16,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _addressLine(start),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        CupertinoIcons.placemark_fill,
                        color: CityTheme.cityblue,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _addressLine(end),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _addressLine(dynamic address) {
    if (address == null) return '';

    final parts = <String>[
      (address.street ?? '').toString().trim(),
      (address.city ?? '').toString().trim(),
      (address.country ?? '').toString().trim(),
    ].where((e) => e.isNotEmpty).toList();

    return parts.join(', ');
  }
}

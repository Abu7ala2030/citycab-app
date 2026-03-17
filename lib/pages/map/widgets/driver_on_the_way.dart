import 'package:citycab/pages/map/map_state.dart';
import 'package:citycab/ui/theme.dart';
import 'package:citycab/ui/widget/buttons/city_cab_button.dart';
import 'package:citycab/ui/widget/cards/rating_card.dart';
import 'package:citycab/ui/widget/titles/bottom_slider_title.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DriverOnTheWay extends StatelessWidget {
  const DriverOnTheWay({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MapState>();

    final ride = state.currentRide;
    final option = ride?.rideOption ?? state.selectedOption;
    final driver = state.assignedDriver;

    final String driverName = driver?.getFullName.trim().isNotEmpty == true
        ? driver!.getFullName
        : 'Searching driver...';

    final String vehicleName = driver != null
        ? '${driver.vehicleManufacturer} ${driver.vehicleType}'.trim()
        : option?.title ?? 'Vehicle';

    final String plate = driver?.licensePlate.trim().isNotEmpty == true
        ? driver!.licensePlate
        : 'Searching plate...';

    final double pickupDistanceKm = state.distanceRemainingKm;
    final double progress = state.tripProgress.clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BottomSliderTitle(
            title: driver == null
                ? 'SEARCHING FOR NEARBY DRIVERS'
                : 'YOUR DRIVER IS ON THE WAY',
          ),
          const SizedBox(height: CityTheme.elementSpacing),
          Row(
            children: [
              Icon(
                Icons.schedule,
                color: Colors.grey[600],
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  state.etaLabel,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: CityTheme.cityblue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress <= 0 ? 0.02 : progress,
                  minHeight: 6,
                  backgroundColor: Colors.grey[300],
                  color: CityTheme.cityblue,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  pickupDistanceKm > 0
                      ? '${pickupDistanceKm.toStringAsFixed(1)} km away'
                      : 'Very close',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: const Color(0xFFE0E0E0),
                      child: driver == null
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.person,
                              color: CityTheme.cityBlack,
                            ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      driverName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: CityTheme.cityBlack,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const RatingCard(rating: 4),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (option != null)
                      Image.asset(
                        option.icon,
                        height: 64,
                        fit: BoxFit.contain,
                      )
                    else
                      const SizedBox(height: 64),
                    const SizedBox(height: 10),
                    Text(
                      vehicleName.isNotEmpty ? vehicleName : 'Vehicle',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: CityTheme.cityBlack,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plate,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: CityTheme.cityblue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: CityCabButton(
                  title: state.isCallingDriver ? 'Calling...' : 'Call',
                  color: CityTheme.cityblue,
                  textColor: CityTheme.cityWhite,
                  disableColor: CityTheme.cityLightGrey,
                  buttonState: driver == null
                      ? ButtonState.disabled
                      : state.isCallingDriver
                          ? ButtonState.loading
                          : ButtonState.initial,
                  onTap: () {
                    state.callDriver();
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: CityCabButton(
                  title: 'Cancel',
                  color: CityTheme.cityWhite,
                  textColor: CityTheme.cityBlack,
                  disableColor: CityTheme.cityLightGrey,
                  borderColor: Colors.grey[800],
                  buttonState: ButtonState.initial,
                  onTap: () {
                    state.cancelRide();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

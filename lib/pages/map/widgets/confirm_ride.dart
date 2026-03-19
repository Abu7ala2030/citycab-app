import 'package:citycab/pages/map/map_state.dart';
import 'package:citycab/ui/theme.dart';
import 'package:citycab/ui/widget/buttons/city_cab_button.dart';
import 'package:citycab/ui/widget/titles/bottom_slider_title.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ConfirmRide extends StatelessWidget {
  const ConfirmRide({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MapState>();
    final option = state.selectedOption;
    final endAddress = state.endAddress;

    final bool isSearchingDriver = state.rideState == RideState.requestRide &&
        state.assignedDriver == null;

    final int etaMinutes = option == null
        ? 0
        : option.timeOfArrival.difference(DateTime.now()).inMinutes;

    String statusLine;
    if (isSearchingDriver) {
      statusLine = 'Searching for nearby drivers...';
    } else if (state.isCalculatingRoute) {
      statusLine = 'Calculating route...';
    } else {
      statusLine = 'Pickup in ${etaMinutes < 0 ? 0 : etaMinutes} mins';
    }

    String searchingMessage = 'Searching for nearby drivers...';
    if (isSearchingDriver && state.currentRide != null) {
      final remaining = state.currentRide!.requestExpiresAt == null
          ? 0
          : state.currentRide!.requestExpiresAt!
              .difference(DateTime.now())
              .inSeconds;

      if (remaining > 0) {
        searchingMessage =
            'Searching for nearby drivers... ${remaining}s remaining in this request window.';
      } else {
        searchingMessage = 'Searching for nearby drivers...';
      }
    }

    return Wrap(
      runAlignment: WrapAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 16),
              child: BottomSliderTitle(title: 'CONFIRM RIDE'),
            ),
            const SizedBox(height: 16),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              constraints: const BoxConstraints(minHeight: 96),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: CityTheme.cityblue.withOpacity(.08),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          option?.title ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          state.isCalculatingRoute
                              ? 'Calculating...'
                              : '${option?.price.toStringAsFixed(2) ?? '0.00'} SAR',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.grey[900],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.timelapse_rounded,
                              color: Colors.grey[600],
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                statusLine,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: CityTheme.cityblue,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.bolt, color: Colors.orange[300]),
                  const SizedBox(width: 12),
                  if (option != null)
                    Image.asset(
                      option.icon,
                      height: 52,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    CupertinoIcons.placemark_fill,
                    color: CityTheme.cityblue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.formatAddressLine(endAddress),
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                  Icon(Icons.edit, color: Colors.grey[600], size: 18),
                ],
              ),
            ),
            if (isSearchingDriver) ...[
              const SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 10),
                    Text(
                      searchingMessage,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: CityCabButton(
            title: state.isCalculatingRoute
                ? 'CALCULATING ROUTE...'
                : isSearchingDriver
                    ? 'SEARCHING DRIVER...'
                    : 'CONFIRM REQUEST',
            color: CityTheme.cityblue,
            textColor: CityTheme.cityWhite,
            disableColor: CityTheme.cityLightGrey,
            buttonState: state.isCalculatingRoute ||
                    (state.selectedOption?.price ?? 0) <= 0 ||
                    isSearchingDriver
                ? ButtonState.disabled
                : ButtonState.initial,
            onTap: () {
              state.confirmRide();
            },
          ),
        ),
      ],
    );
  }
}

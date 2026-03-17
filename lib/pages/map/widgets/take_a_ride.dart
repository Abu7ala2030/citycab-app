import 'package:citycab/constant/my_address.dart';
import 'package:citycab/models/ride.dart';
import 'package:citycab/ui/theme.dart';
import 'package:citycab/ui/widget/buttons/city_cab_button.dart';
import 'package:citycab/ui/widget/cards/address_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../map_state.dart';

class TakeARide extends StatelessWidget {
  const TakeARide({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MapState>();
    final isUserDriver = state.userRepo.currentUser?.isDriverRole ?? false;

    if (isUserDriver) {
      final Ride? incomingRide = state.incomingRide;

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
                      Text(
                        'Pickup: ${incomingRide.startAddress.street}, ${incomingRide.startAddress.city}',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Dropoff: ${incomingRide.endAddress.street}, ${incomingRide.endAddress.city}',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Fare: ${incomingRide.rideOption.price.toStringAsFixed(2)} SAR',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: CityTheme.cityblue,
                        ),
                      ),
                      const SizedBox(height: 16),
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

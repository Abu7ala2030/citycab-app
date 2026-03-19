import 'package:citycab/pages/map/map_state.dart';
import 'package:citycab/ui/theme.dart';
import 'package:citycab/ui/widget/buttons/city_cab_button.dart';
import 'package:citycab/ui/widget/titles/bottom_slider_title.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ArrivedAtDestination extends StatelessWidget {
  const ArrivedAtDestination({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MapState>();
    return state.isDriverUser
        ? const _DriverArrivedPanel()
        : const _PassengerArrivedPanel();
  }
}

class _PassengerArrivedPanel extends StatelessWidget {
  const _PassengerArrivedPanel();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MapState>();
    final ride = state.currentRide;
    final start = ride?.startAddress ?? state.startAddress;
    final end = ride?.endAddress ?? state.endAddress;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 16),
          child: BottomSliderTitle(title: 'YOU HAVE ARRIVED'),
        ),
        const SizedBox(height: 16),
        const RideDetailCard(),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _AddressTimeline(
            start: state.formatAddressLine(start),
            end: state.formatAddressLine(end),
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: CityTheme.elementSpacing),
          child: state.isRidePaid
              ? const _RatingSection()
              : const _PaymentSection(),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _DriverArrivedPanel extends StatelessWidget {
  const _DriverArrivedPanel();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MapState>();
    final ride = state.currentRide;
    final passenger = state.passengerUser;
    final start = ride?.startAddress ?? state.startAddress;
    final end = ride?.endAddress ?? state.endAddress;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 16),
          child: BottomSliderTitle(title: 'DESTINATION REACHED'),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Confirm trip completion after the passenger leaves the vehicle.',
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
        ),
        const SizedBox(height: 16),
        const RideDetailCard(),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _DriverPassengerCard(
            passengerName: passenger?.getFullName.isNotEmpty == true
                ? passenger!.getFullName
                : 'Passenger',
            phone: passenger?.phone.trim().isNotEmpty == true
                ? passenger!.phone
                : 'Not available',
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _AddressTimeline(
            start: state.formatAddressLine(start),
            end: state.formatAddressLine(end),
          ),
        ),
        const SizedBox(height: 20),
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
                  title: 'Complete Ride',
                  color: Colors.green,
                  textColor: Colors.white,
                  disableColor: CityTheme.cityLightGrey,
                  buttonState: ButtonState.initial,
                  onTap: state.driverCompleteRide,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _PaymentSection extends StatelessWidget {
  const _PaymentSection();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MapState>();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: CityTheme.cityblue.withOpacity(.06),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: CityTheme.cityblue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Trip completed successfully. Proceed to payment.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        CityCabButton(
          title: state.isPayingForRide ? 'Processing...' : 'Pay For Ride',
          color: CityTheme.cityblue,
          textColor: CityTheme.cityWhite,
          disableColor: CityTheme.cityLightGrey,
          buttonState:
              state.isPayingForRide ? ButtonState.loading : ButtonState.initial,
          onTap: state.payForRide,
        ),
      ],
    );
  }
}

class _RatingSection extends StatelessWidget {
  const _RatingSection();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MapState>();
    final driverName = state.assignedDriver?.getFullName ?? 'your driver';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Payment successful',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.grey[900])),
        const SizedBox(height: 6),
        Text('Rate $driverName',
            style: TextStyle(fontSize: 14, color: Colors.grey[700])),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final star = index + 1;
            final isActive = star <= state.selectedRatingStars;
            return IconButton(
              onPressed: () => state.updateRatingStars(star),
              icon: Icon(
                isActive ? Icons.star_rounded : Icons.star_border_rounded,
                color: isActive ? Colors.amber[600] : Colors.grey[400],
                size: 34,
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: state.ratingSubjectController,
          decoration: InputDecoration(
            hintText: 'Title (optional)',
            filled: true,
            fillColor: Colors.grey[100],
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: state.ratingBodyController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Share your feedback (optional)',
            filled: true,
            fillColor: Colors.grey[100],
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 14),
        CityCabButton(
          title: state.isSubmittingRating ? 'Submitting...' : 'Submit Rating',
          color: CityTheme.cityblue,
          textColor: CityTheme.cityWhite,
          disableColor: CityTheme.cityLightGrey,
          buttonState: state.isSubmittingRating
              ? ButtonState.loading
              : ButtonState.initial,
          onTap: state.submitRideRating,
        ),
      ],
    );
  }
}

class RideDetailCard extends StatelessWidget {
  const RideDetailCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MapState>();
    final option = state.currentRide?.rideOption ?? state.selectedOption;
    final price = option?.price ?? state.ridePrice;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: CityTheme.cityblue.withOpacity(.08),
      ),
      child: Row(
        children: [
          if (option != null) Image.asset(option.icon, height: 54),
          if (option != null) const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(option?.title ?? 'Ride',
                    style: TextStyle(fontSize: 14, color: Colors.grey[800])),
                const SizedBox(height: 3),
                Text('${price.toStringAsFixed(2)} SAR',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey[900])),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.timelapse_rounded,
                        color: Colors.grey[600], size: 13),
                    const SizedBox(width: 5),
                    const Text('Trip completed',
                        style: TextStyle(
                            fontSize: 12,
                            color: CityTheme.cityblue,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle, color: Colors.green[500], size: 26),
        ],
      ),
    );
  }
}

class _DriverPassengerCard extends StatelessWidget {
  final String passengerName;
  final String phone;

  const _DriverPassengerCard(
      {required this.passengerName, required this.phone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 22,
            backgroundColor: Color(0xFFE9EEF9),
            child: Icon(Icons.person, color: CityTheme.cityblue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(passengerName,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(phone,
                    style: TextStyle(fontSize: 13, color: Colors.grey[700])),
              ],
            ),
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
          left: 7,
          top: 18,
          bottom: 18,
          child: Container(width: 2.5, color: Colors.grey[350]),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AddressTile(
                icon: CupertinoIcons.circle_fill, iconSize: 15, text: start),
            const SizedBox(height: CityTheme.elementSpacing),
            _AddressTile(
                icon: CupertinoIcons.placemark_fill, iconSize: 17, text: end),
          ],
        ),
      ],
    );
  }
}

class _AddressTile extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final String text;

  const _AddressTile(
      {required this.icon, required this.iconSize, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: CityTheme.cityblue, size: iconSize),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style:
                TextStyle(fontSize: 16, height: 1.4, color: Colors.grey[800]),
          ),
        ),
      ],
    );
  }
}

import 'package:citycab/pages/map/map_state.dart';
import 'package:citycab/pages/map/widgets/at_destination.dart';
import 'package:citycab/pages/map/widgets/confirm_ride.dart';
import 'package:citycab/pages/map/widgets/driver_on_the_way.dart';
import 'package:citycab/pages/map/widgets/in_motion.dart';
import 'package:citycab/pages/map/widgets/search_map_address.dart';
import 'package:citycab/pages/map/widgets/select_ride.dart';
import 'package:citycab/pages/map/widgets/take_a_ride.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BottomSlide extends StatelessWidget {
  const BottomSlide({Key? key}) : super(key: key);

  static const BorderRadius _radius =
      BorderRadius.vertical(top: Radius.circular(24));

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MapState>();
    final size = MediaQuery.of(context).size;
    final viewPadding = MediaQuery.of(context).viewPadding;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: double.infinity,
      height: _getSliderHeight(state, size),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: _radius,
        boxShadow: [
          BoxShadow(
              blurRadius: 18, color: Color(0x22000000), offset: Offset(0, -4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: _radius,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                16, 16, 16, viewPadding.bottom > 0 ? 12 : 20),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: KeyedSubtree(
                key: ValueKey<String>(
                    '${state.rideState.name}-${state.isDriverUser}'),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: _buildCurrentPanel(state),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _getSliderHeight(MapState state, Size size) {
    final bool isSmallPhone = size.height < 700;
    final bool isDriver = state.isDriverUser;

    switch (state.rideState) {
      case RideState.searchingAddress:
        return isSmallPhone ? size.height * 0.62 : size.height * 0.58;
      case RideState.confirmAddress:
      case RideState.selectRide:
        return isSmallPhone ? size.height * 0.48 : size.height * 0.42;
      case RideState.requestRide:
        return isSmallPhone ? size.height * 0.52 : size.height * 0.46;
      case RideState.driverIsComing:
        return isDriver
            ? (isSmallPhone ? size.height * 0.58 : size.height * 0.50)
            : (isSmallPhone ? size.height * 0.54 : size.height * 0.46);
      case RideState.inMotion:
        return isDriver
            ? (isSmallPhone ? size.height * 0.56 : size.height * 0.48)
            : (isSmallPhone ? size.height * 0.52 : size.height * 0.45);
      case RideState.arrived:
        return isDriver
            ? (isSmallPhone ? size.height * 0.60 : size.height * 0.52)
            : (isSmallPhone ? size.height * 0.62 : size.height * 0.56);
      case RideState.initial:
        return isSmallPhone ? size.height * 0.42 : size.height * 0.38;
    }
  }

  Widget _buildCurrentPanel(MapState state) {
    switch (state.rideState) {
      case RideState.initial:
        return const TakeARide();
      case RideState.searchingAddress:
        return const SearchMapBar();
      case RideState.selectRide:
        return const SelectRide();
      case RideState.confirmAddress:
        return const ConfirmRide();
      case RideState.requestRide:
        return const ConfirmRide();
      case RideState.driverIsComing:
        return const DriverOnTheWay();
      case RideState.inMotion:
        return const InMotion();
      case RideState.arrived:
        return const ArrivedAtDestination();
    }
  }
}

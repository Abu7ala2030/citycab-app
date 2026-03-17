import 'package:citycab/constant/ride_options.dart';
import 'package:citycab/pages/map/map_state.dart';
import 'package:citycab/ui/theme.dart';
import 'package:citycab/ui/widget/buttons/city_cab_button.dart';
import 'package:citycab/ui/widget/cards/ride_card.dart';
import 'package:citycab/ui/widget/titles/bottom_slider_title.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SelectRide extends StatelessWidget {
  const SelectRide({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<MapState>(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BottomSliderTitle(title: 'SELECT RIDE OPTION'),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: ListView.builder(
              itemCount: rideOptions.length,
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                final option = rideOptions[index];
                return Padding(
                  padding: EdgeInsets.only(
                    right: index == rideOptions.length - 1 ? 0 : 16,
                  ),
                  child: RideOptionCard(
                    isSelected: state.isSelectedOptions[index],
                    onTap: (option) {
                      state.onTapRideOption(option, index);
                    },
                    option: option,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          CityCabButton(
            title: state.selectedOption == null
                ? 'SELECT A RIDE OPTION'
                : 'PROCEED WITH ${state.selectedOption!.title.toUpperCase()}',
            color: CityTheme.cityblue,
            textColor: CityTheme.cityWhite,
            disableColor: CityTheme.cityLightGrey,
            buttonState: ButtonState.initial,
            onTap: state.selectedOption == null
                ? null
                : () {
                    state.proceedRide();
                  },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

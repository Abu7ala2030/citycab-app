import 'package:citycab/pages/map/map_state.dart';
import 'package:citycab/ui/theme.dart';
import 'package:citycab/ui/widget/textfields/cab_textfield.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SearchMapBar extends StatelessWidget {
  const SearchMapBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MapState>();

    return SafeArea(
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: CityTheme.cityWhite,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: CityTheme.cityBlack.withOpacity(.2),
                spreadRadius: 2,
                blurRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.circle,
                          size: 16,
                          color: CityTheme.cityblue,
                        ),
                        Container(
                          width: 4,
                          height: 40,
                          color: CityTheme.cityblue,
                        ),
                        const Icon(
                          Icons.place,
                          color: CityTheme.cityblue,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        right: 12,
                        top: 12,
                        bottom: 12,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Focus(
                            focusNode: state.focusNode,
                            child: CityTextField(
                              label: 'My Address',
                              controller: state.currentAddressController,
                              onChanged: (v) {
                                state.searchAddress(v);
                              },
                            ).paddingBottom(12),
                          ),
                          Focus(
                            focusNode: state.focusNode,
                            child: CityTextField(
                              label: 'Destination Address',
                              controller: state.destinationAddressController,
                              onChanged: (v) {
                                state.searchAddress(v);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              /// SEARCH RESULTS
              if (state.searchedAddress.isNotEmpty)
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.searchedAddress.length,
                  itemBuilder: (context, index) {
                    final address = state.searchedAddress[index];

                    return ListTile(
                      leading: const Icon(Icons.location_on),
                      title: Text(address.street),
                      subtitle: Text("${address.city}, ${address.country}"),
                      onTap: () {
                        state.onTapAddressList(address);
                      },
                    );
                  },
                ),
            ],
          ),
        ).paddingAll(8),
      ),
    );
  }
}

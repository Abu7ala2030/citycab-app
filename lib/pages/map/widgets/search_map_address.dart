import 'package:citycab/pages/map/map_state.dart';
import 'package:citycab/ui/theme.dart';
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
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: CityTheme.cityBlack.withOpacity(.12),
                spreadRadius: 1,
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8, right: 10),
                      child: Column(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: CityTheme.cityblue,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Container(
                            width: 2,
                            height: 42,
                            color: Colors.grey.shade300,
                          ),
                          Icon(
                            Icons.place_rounded,
                            color: Colors.red.shade400,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: state.currentAddressController,
                            readOnly: true,
                            decoration: InputDecoration(
                              hintText: 'Pickup location',
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              prefixIcon: const Icon(Icons.my_location_rounded),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            focusNode: state.focusNode,
                            controller: state.destinationAddressController,
                            autofocus: true,
                            textInputAction: TextInputAction.search,
                            onChanged: state.searchAddress,
                            decoration: InputDecoration(
                              hintText: 'Where to?',
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: state
                                      .destinationAddressController.text
                                      .trim()
                                      .isNotEmpty
                                  ? IconButton(
                                      onPressed: () {
                                        state.destinationAddressController
                                            .clear();
                                        state.searchAddress('');
                                      },
                                      icon: const Icon(Icons.close_rounded),
                                    )
                                  : null,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (state.isSearchingAddressResults)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: LinearProgressIndicator(minHeight: 2),
                )
              else if (state.hasSearchResults)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: 8),
                    shrinkWrap: true,
                    itemCount: state.searchedAddress.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      indent: 56,
                      endIndent: 16,
                      color: Colors.grey.shade200,
                    ),
                    itemBuilder: (context, index) {
                      final address = state.searchedAddress[index];
                      final subtitle = [
                        address.city,
                        address.country,
                      ].where((e) => e.trim().isNotEmpty).join(', ');

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 2,
                        ),
                        leading: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.location_on_outlined,
                            color: CityTheme.cityblue,
                          ),
                        ),
                        title: Text(
                          address.title?.trim().isNotEmpty == true
                              ? address.title!.trim()
                              : address.street,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: subtitle.isEmpty
                            ? null
                            : Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                        onTap: () => state.onTapAddressList(address),
                      );
                    },
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                  child: Row(
                    children: [
                      Icon(
                        Icons.tips_and_updates_outlined,
                        size: 18,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.destinationAddressController.text
                                      .trim()
                                      .length <
                                  3
                              ? 'Type at least 3 characters to search places.'
                              : 'No places found. Try a landmark, street, or building name.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ).paddingAll(8),
      ),
    );
  }
}

import 'package:citycab/utils/icons_assets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RideOption {
  final String id;
  final String title;
  final DateTime timeOfArrival;
  final double price;
  final String icon;

  const RideOption({
    required this.id,
    required this.title,
    required this.timeOfArrival,
    required this.price,
    required this.icon,
  });

  RideOption copyWith({
    String? id,
    String? title,
    DateTime? timeOfArrival,
    double? price,
    String? icon,
  }) {
    return RideOption(
      id: id ?? this.id,
      title: title ?? this.title,
      timeOfArrival: timeOfArrival ?? this.timeOfArrival,
      price: price ?? this.price,
      icon: icon ?? this.icon,
    );
  }

  factory RideOption.fromMap(Map<String, dynamic> data) {
    String getIcon(String id) {
      if (id == '02' || id == '3') {
        return car_list[3];
      } else if (id == '01' || id == '1') {
        return car_list[1];
      } else {
        return car_list[0];
      }
    }

    final rawPrice = data['price'];
    final rawTime = data['time_of_arrival'];

    DateTime parsedTime;
    if (rawTime is Timestamp) {
      parsedTime = rawTime.toDate();
    } else if (rawTime is DateTime) {
      parsedTime = rawTime;
    } else {
      parsedTime = DateTime.now();
    }

    return RideOption(
      id: data['id']?.toString() ?? '',
      title: data['ride_type']?.toString() ?? '',
      price: rawPrice is num ? rawPrice.toDouble() : 0.0,
      timeOfArrival: parsedTime,
      icon: data['icon']?.toString() ?? getIcon(data['id']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'price': price,
      'ride_type': title,
      'time_of_arrival': timeOfArrival,
      'icon': icon,
    };
  }
}

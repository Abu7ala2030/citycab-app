import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:citycab/constant/ride_options.dart';
import 'package:citycab/models/address.dart';
import 'package:citycab/models/rate.dart';
import 'package:citycab/models/ride.dart';
import 'package:citycab/models/ride_option.dart';
import 'package:citycab/models/user.dart';
import 'package:citycab/repositories/ride_repository.dart';
import 'package:citycab/repositories/user_repository.dart';
import 'package:citycab/services/code_generator.dart';
import 'package:citycab/services/map_services.dart';
import 'package:citycab/ui/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

enum RideState {
  initial,
  searchingAddress,
  confirmAddress,
  selectRide,
  requestRide,
  driverIsComing,
  inMotion,
  arrived,
}

class MapState extends ChangeNotifier {
  GoogleMapController? controller;

  final ValueNotifier<Address?> currentPosition =
      MapService.instance.currentPosition;
  final UserRepository userRepo = UserRepository.instance;
  final RideRepository? rideRepo = RideRepository.instance;

  final TextEditingController currentAddressController =
      TextEditingController();
  final TextEditingController destinationAddressController =
      TextEditingController();
  final TextEditingController ratingSubjectController = TextEditingController();
  final TextEditingController ratingBodyController = TextEditingController();

  static const double baseFare = 5.0;
  static const double perKm = 2.5;
  static const double perMinute = 0.5;

  static const double cameraTopPadding = 110;
  static const double cameraSidePadding = 60;
  static const double cameraBottomSheetPadding = 320;
  static const double cameraScrollOffset = 140;

  Address? startAddress;
  Address? endAddress;

  RideOption? selectedOption;
  Ride? currentRide;
  User? assignedDriver;
  Ride? incomingRide;

  StreamSubscription<Ride?>? rideSubscription;
  StreamSubscription<void>? liveLocationSubscription;
  StreamSubscription<User?>? assignedDriverSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _driverRequestsSubscription;
  Timer? _driverRouteRefreshTimer;
  Timer? _searchDebounce;

  List<Address> searchedAddress = <Address>[];
  List<bool> isSelectedOptions = <bool>[];

  FocusNode? focusNode;
  RideState _rideState = RideState.initial;

  bool isActive = false;
  bool isCalculatingRoute = false;
  bool isSubmittingRide = false;
  bool isCallingDriver = false;
  bool isPayingForRide = false;
  bool isSubmittingRating = false;
  bool isRidePaid = false;
  bool isUpdatingDriverRoute = false;
  bool _disposed = false;
  bool _isAdjustingCamera = false;

  int selectedRatingStars = 5;

  DateTime _lastCameraMove = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastDriverRouteFetch = DateTime.fromMillisecondsSinceEpoch(0);
  LatLng? _lastDriverCameraTarget;
  LatLng? _lastDriverRouteOrigin;
  LatLng? _lastDriverRouteDestination;

  Duration driverLegDuration = Duration.zero;
  double driverLegDistanceKm = 0;
  List<LatLng> driverLegPolylinePoints = <LatLng>[];

  final PageController pageController = PageController();
  int pageIndex = 0;

  RideState get rideState => _rideState;

  set changeRideState(RideState state) {
    if (_rideState == state) return;
    _rideState = state;
    _safeNotify();
    _refreshRideCamera();
    _refreshDriverLegRoute(force: true);
  }

  String? uiMessage;

  void showMessage(String message) {
    uiMessage = message;
    notifyListeners();
  }

  void clearMessage() {
    uiMessage = null;
    notifyListeners();
  }

  Future<void> _initUser() async {
    await userRepo.signInCurrentUser();
    _listenToDriverRequests();
  }

  MapState() {
    focusNode = FocusNode();

    isSelectedOptions =
        List<bool>.generate(rideOptions.length, (index) => index == 0);

    selectedOption = rideOptions.isNotEmpty ? rideOptions.first : null;

    destinationAddressController.addListener(_onDestinationTextChanged);

    _initUser();

    isActive = userRepo.currentUser?.isActive ?? false;

    getCurrentLocation();
  }

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  RideOption? get activeRideOption => currentRide?.rideOption ?? selectedOption;

  double get ridePrice => activeRideOption?.price ?? 0;

  bool get isSearchingForDriver =>
      currentRide?.status == RideStatus.requesting &&
      assignedDriver == null &&
      currentRide != null;

  int get tripRemainingMinutes {
    if ((_rideState == RideState.driverIsComing ||
            _rideState == RideState.inMotion ||
            _rideState == RideState.arrived) &&
        driverLegDuration > Duration.zero) {
      return driverLegDuration.inMinutes <= 0 ? 1 : driverLegDuration.inMinutes;
    }

    final option = activeRideOption;
    if (option == null) return 0;

    final minutes = option.timeOfArrival.difference(DateTime.now()).inMinutes;
    return minutes < 0 ? 0 : minutes;
  }

  int get driverArrivalMinutes {
    if (driverLegDuration > Duration.zero) {
      return driverLegDuration.inMinutes <= 0 ? 1 : driverLegDuration.inMinutes;
    }

    if (assignedDriver?.latlng == null || startAddress == null) {
      return 0;
    }

    final meters = Geolocator.distanceBetween(
      assignedDriver!.latlng!.latitude,
      assignedDriver!.latlng!.longitude,
      startAddress!.latLng.latitude,
      startAddress!.latLng.longitude,
    );

    final estimatedMinutes = (meters / 1000) / 0.5;
    final rounded = estimatedMinutes.ceil();
    return rounded <= 0 ? 1 : rounded;
  }

  double get tripDistanceKm {
    if (startAddress == null || endAddress == null) return 0;

    final meters = Geolocator.distanceBetween(
      startAddress!.latLng.latitude,
      startAddress!.latLng.longitude,
      endAddress!.latLng.latitude,
      endAddress!.latLng.longitude,
    );

    return meters / 1000;
  }

  double get distanceRemainingKm {
    if ((_rideState == RideState.driverIsComing ||
            _rideState == RideState.inMotion ||
            _rideState == RideState.arrived) &&
        driverLegDistanceKm > 0) {
      return driverLegDistanceKm;
    }

    if (_rideState == RideState.driverIsComing) {
      if (assignedDriver?.latlng == null || startAddress == null) return 0;

      final meters = Geolocator.distanceBetween(
        assignedDriver!.latlng!.latitude,
        assignedDriver!.latlng!.longitude,
        startAddress!.latLng.latitude,
        startAddress!.latLng.longitude,
      );

      return meters / 1000;
    }

    if (assignedDriver?.latlng == null || endAddress == null) {
      return tripDistanceKm;
    }

    final meters = Geolocator.distanceBetween(
      assignedDriver!.latlng!.latitude,
      assignedDriver!.latlng!.longitude,
      endAddress!.latLng.latitude,
      endAddress!.latLng.longitude,
    );

    return meters / 1000;
  }

  double get tripProgress {
    final double remaining = distanceRemainingKm;

    if (_rideState == RideState.driverIsComing) {
      final divisor = driverLegDistanceKm > 0
          ? driverLegDistanceKm
          : (remaining <= 0 ? 1 : remaining);
      return (1 - (remaining / divisor)).clamp(0.0, 1.0);
    }

    final total = tripDistanceKm;
    if (total <= 0) return 0;
    return (1 - (remaining / total)).clamp(0.0, 1.0);
  }

  String get etaLabel {
    if (isSearchingForDriver) {
      return 'Searching for nearby drivers...';
    }

    if (_rideState == RideState.driverIsComing) {
      final mins = driverArrivalMinutes;
      return mins <= 0 ? 'Driver arriving...' : 'Pickup in $mins mins';
    }

    final mins = tripRemainingMinutes;
    return mins <= 0 ? 'Arriving shortly' : 'Drop-off in $mins mins';
  }

  Set<Polyline> get polylines {
    final Set<Polyline> lines = <Polyline>{};

    final tripPoints = endAddress?.polylines ?? const [];
    if (tripPoints.isNotEmpty) {
      lines.add(
        Polyline(
          polylineId: const PolylineId('overview_polyline'),
          color: CityTheme.cityBlack,
          width: 5,
          points:
              tripPoints.map((e) => LatLng(e.latitude, e.longitude)).toList(),
        ),
      );
    }

    if (driverLegPolylinePoints.isNotEmpty) {
      lines.add(
        Polyline(
          polylineId: const PolylineId('driver_leg_polyline'),
          color: CityTheme.cityblue,
          width: 4,
          patterns: <PatternItem>[
            PatternItem.dash(20),
            PatternItem.gap(10),
          ],
          points: driverLegPolylinePoints,
        ),
      );
    }

    return lines;
  }

  void _listenToDriverRequests() {
    _driverRequestsSubscription?.cancel();

    final currentUID = userRepo.currentUser?.uid;
    if (currentUID == null || currentUID.isEmpty) return;
    if (userRepo.currentUserRole != Roles.driver) return;

    _driverRequestsSubscription = FirebaseFirestore.instance
        .collection('rides')
        .where('status', isEqualTo: RideStatus.requesting.index)
        .snapshots()
        .listen((snapshot) {
      Ride? pendingRide;

      for (final doc in snapshot.docs) {
        final ride = Ride.fromMap(doc.data());

        if (ride.candidateDriverUIDs.contains(currentUID) &&
            !ride.rejectedDriverUIDs.contains(currentUID) &&
            !ride.isRequestExpired) {
          pendingRide = ride;
          break;
        }
      }

      incomingRide = pendingRide;
      _safeNotify();
    });
  }

  Future<void> acceptRide(Ride ride) async {
    final currentUID = userRepo.currentUser?.uid;
    if (currentUID == null || currentUID.isEmpty) return;

    await rideRepo?.driverAcceptRide(ride.id, currentUID);

    incomingRide = null;
    currentRide = ride;

    _listenToRide(ride.id);

    await loadDriverProfile(currentUID);
    await _refreshDriverLegRoute(force: true);

    _safeNotify();
  }

  Future<void> rejectRide(Ride ride) async {
    final currentUID = userRepo.currentUser?.uid;
    if (currentUID == null || currentUID.isEmpty) return;

    await rideRepo?.driverRejectRide(ride.id, currentUID);
    incomingRide = null;
    _safeNotify();
  }

  void _onDestinationTextChanged() {
    if (destinationAddressController.text.trim().isEmpty) {
      searchedAddress.clear();
      endAddress = null;
      _clearRideState(resetRide: true);
      _resetRidePrices();
      _safeNotify();
      _refreshRideCamera();
    }
  }

  void _resetDriverLegData() {
    driverLegDuration = Duration.zero;
    driverLegDistanceKm = 0;
    driverLegPolylinePoints = <LatLng>[];
    _lastDriverRouteOrigin = null;
    _lastDriverRouteDestination = null;
  }

  void _clearRideState({bool resetRide = false}) {
    _cancelAssignedDriverListener();
    _driverRouteRefreshTimer?.cancel();
    _driverRouteRefreshTimer = null;

    assignedDriver = null;
    _lastDriverCameraTarget = null;
    isCallingDriver = false;
    isPayingForRide = false;
    isSubmittingRating = false;
    isRidePaid = false;
    isUpdatingDriverRoute = false;
    selectedRatingStars = 5;
    ratingSubjectController.clear();
    ratingBodyController.clear();

    _resetDriverLegData();
    MapService.instance.removeDriverMarker();

    if (resetRide) {
      currentRide = null;
    }
  }

  double calculateFare(double distanceKm, double minutes, double multiplier) {
    return (baseFare + (distanceKm * perKm) + (minutes * perMinute)) *
        multiplier;
  }

  double calculateDistanceKm() {
    if (startAddress == null || endAddress == null) return 0;

    final start = startAddress!.latLng;
    final end = endAddress!.latLng;

    final meters = Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );

    return meters / 1000;
  }

  void _resetRidePrices() {
    for (var i = 0; i < rideOptions.length; i++) {
      rideOptions[i] = rideOptions[i].copyWith(price: 0);
    }

    final selectedIndex = isSelectedOptions.indexWhere((e) => e);

    if (selectedIndex != -1 && selectedIndex < rideOptions.length) {
      selectedOption = rideOptions[selectedIndex];
    } else if (rideOptions.isNotEmpty) {
      selectedOption = rideOptions.first;
      isSelectedOptions =
          List<bool>.generate(rideOptions.length, (index) => index == 0);
    } else {
      selectedOption = null;
    }
  }

  void updateRidePrices() {
    if (startAddress == null || endAddress == null) {
      debugPrint(
          'updateRidePrices skipped: startAddress or endAddress is null');
      return;
    }

    final distanceKm = calculateDistanceKm();
    double durationMinutes = MapService.instance.duration.inMinutes.toDouble();

    if (durationMinutes <= 0 && distanceKm > 0) {
      durationMinutes = (distanceKm / 40.0) * 60.0;
    }

    for (var i = 0; i < rideOptions.length; i++) {
      final option = rideOptions[i];

      double multiplier = 1.0;
      if (option.id == '01') multiplier = 1.4;
      if (option.id == '02') multiplier = 2.0;

      final calculatedPrice =
          calculateFare(distanceKm, durationMinutes, multiplier);

      rideOptions[i] = option.copyWith(price: calculatedPrice);
    }

    final selectedIndex = isSelectedOptions.indexWhere((e) => e);

    if (selectedIndex != -1 && selectedIndex < rideOptions.length) {
      selectedOption = rideOptions[selectedIndex];
    } else if (rideOptions.isNotEmpty) {
      selectedOption = rideOptions.first;
      isSelectedOptions =
          List<bool>.generate(rideOptions.length, (index) => index == 0);
    } else {
      selectedOption = null;
    }

    _safeNotify();
  }

  Future<void> animateCamera(
    LatLng latLng, {
    double zoom = 16.5,
  }) async {
    try {
      await controller?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: latLng, zoom: zoom),
        ),
      );
    } catch (e) {
      debugPrint('animateCamera error: $e');
    }
  }

  Future<void> animateCameraToBoundsSmart({
    required LatLng first,
    required LatLng second,
    double extraPadding = 1,
  }) async {
    if (controller == null || _isAdjustingCamera) return;

    final now = DateTime.now();
    if (now.difference(_lastCameraMove).inMilliseconds < 1000) {
      return;
    }

    _lastCameraMove = now;
    _isAdjustingCamera = true;

    try {
      final southwest = LatLng(
        first.latitude < second.latitude ? first.latitude : second.latitude,
        first.longitude < second.longitude ? first.longitude : second.longitude,
      );

      final northeast = LatLng(
        first.latitude > second.latitude ? first.latitude : second.latitude,
        first.longitude > second.longitude ? first.longitude : second.longitude,
      );

      final samePoint = (first.latitude - second.latitude).abs() < 0.0001 &&
          (first.longitude - second.longitude).abs() < 0.0001;

      if (samePoint) {
        await animateCamera(first, zoom: 16.3);
      } else {
        await controller!.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              southwest: southwest,
              northeast: northeast,
            ),
            extraPadding,
          ),
        );

        await controller!.animateCamera(
          CameraUpdate.scrollBy(0, cameraScrollOffset),
        );
      }
    } catch (e) {
      debugPrint('animateCameraToBoundsSmart error: $e');
    } finally {
      _isAdjustingCamera = false;
    }
  }

  bool _shouldFollowDriverCamera(LatLng driverLatLng) {
    if (_lastDriverCameraTarget == null) {
      _lastDriverCameraTarget = driverLatLng;
      return true;
    }

    final meters = Geolocator.distanceBetween(
      _lastDriverCameraTarget!.latitude,
      _lastDriverCameraTarget!.longitude,
      driverLatLng.latitude,
      driverLatLng.longitude,
    );

    if (meters >= 25) {
      _lastDriverCameraTarget = driverLatLng;
      return true;
    }

    return false;
  }

  Future<void> _refreshRideCamera() async {
    if (controller == null) return;

    final passenger = startAddress?.latLng;
    final destination = endAddress?.latLng;
    final driver = assignedDriver?.latlng;

    try {
      switch (_rideState) {
        case RideState.driverIsComing:
          if (driver != null && passenger != null) {
            if (_shouldFollowDriverCamera(driver)) {
              await animateCameraToBoundsSmart(
                first: driver,
                second: passenger,
              );
            }
          }
          break;

        case RideState.inMotion:
        case RideState.arrived:
          if (driver != null && destination != null) {
            if (_shouldFollowDriverCamera(driver)) {
              await animateCameraToBoundsSmart(
                first: driver,
                second: destination,
              );
            }
          }
          break;

        case RideState.confirmAddress:
        case RideState.selectRide:
        case RideState.requestRide:
          if (passenger != null && destination != null) {
            await animateCameraToBoundsSmart(
              first: passenger,
              second: destination,
            );
          }
          break;

        case RideState.initial:
        case RideState.searchingAddress:
          if (passenger != null) {
            await animateCamera(passenger);
          }
          break;
      }
    } catch (e) {
      debugPrint('_refreshRideCamera error: $e');
    }
  }

  bool _shouldFetchDriverRoute({
    required LatLng origin,
    required LatLng destination,
    bool force = false,
  }) {
    if (force) return true;

    final now = DateTime.now();
    if (now.difference(_lastDriverRouteFetch).inSeconds < 8) {
      return false;
    }

    if (_lastDriverRouteOrigin != null) {
      final originMoved = Geolocator.distanceBetween(
        _lastDriverRouteOrigin!.latitude,
        _lastDriverRouteOrigin!.longitude,
        origin.latitude,
        origin.longitude,
      );

      if (originMoved < 20 && _lastDriverRouteDestination != null) {
        final destinationMoved = Geolocator.distanceBetween(
          _lastDriverRouteDestination!.latitude,
          _lastDriverRouteDestination!.longitude,
          destination.latitude,
          destination.longitude,
        );

        if (destinationMoved < 10) {
          return false;
        }
      }
    }

    return true;
  }

  Future<void> _refreshDriverLegRoute({bool force = false}) async {
    final LatLng? origin = assignedDriver?.latlng;

    LatLng? destination;
    if (_rideState == RideState.driverIsComing) {
      destination = startAddress?.latLng;
    } else if (_rideState == RideState.inMotion ||
        _rideState == RideState.arrived) {
      destination = endAddress?.latLng;
    }

    if (origin == null || destination == null) {
      _resetDriverLegData();
      _safeNotify();
      return;
    }

    if (!_shouldFetchDriverRoute(
      origin: origin,
      destination: destination,
      force: force,
    )) {
      return;
    }

    try {
      isUpdatingDriverRoute = true;
      _lastDriverRouteFetch = DateTime.now();

      final routeData = await MapService.instance.getRouteData(
        origin,
        destination,
      );

      driverLegDuration = routeData.duration;
      driverLegDistanceKm = routeData.distanceMeters / 1000;
      driverLegPolylinePoints = routeData.polylines
          .map((e) => LatLng(e.latitude, e.longitude))
          .toList();

      _lastDriverRouteOrigin = origin;
      _lastDriverRouteDestination = destination;
    } catch (e) {
      debugPrint('_refreshDriverLegRoute error: $e');
    } finally {
      isUpdatingDriverRoute = false;
      _safeNotify();
    }
  }

  void _startDriverRouteRefreshTimer() {
    _driverRouteRefreshTimer?.cancel();

    _driverRouteRefreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) {
        _refreshDriverLegRoute();
      },
    );
  }

  Future<void> loadDriverProfile(String driverUID) async {
    if (driverUID.trim().isEmpty) return;

    try {
      final driver = await userRepo.fetchUserById(driverUID);
      if (driver == null) return;

      assignedDriver = driver;

      if (driver.latlng != null) {
        await MapService.instance.addOrUpdateDriverMarker(driver);
      }

      _safeNotify();
      await _refreshRideCamera();
      await _refreshDriverLegRoute(force: true);
      _startDriverRouteRefreshTimer();
    } catch (e) {
      debugPrint('Driver load failed: $e');
    }
  }

  void _listenToAssignedDriver(String driverUID) {
    _cancelAssignedDriverListener();

    if (driverUID.trim().isEmpty) return;

    assignedDriverSubscription =
        userRepo.listenToUser(driverUID).listen((driver) async {
      if (driver == null) return;

      final oldLatLng = assignedDriver?.latlng;
      assignedDriver = driver;

      if (driver.latlng != null) {
        final shouldUpdateMarker = oldLatLng == null ||
            Geolocator.distanceBetween(
                  oldLatLng.latitude,
                  oldLatLng.longitude,
                  driver.latlng!.latitude,
                  driver.latlng!.longitude,
                ) >=
                1.0;

        if (shouldUpdateMarker) {
          await MapService.instance.addOrUpdateDriverMarker(driver);
          await _refreshDriverLegRoute();
          await _refreshRideCamera();
        }
      }

      _safeNotify();
    });
  }

  void _cancelAssignedDriverListener() {
    assignedDriverSubscription?.cancel();
    assignedDriverSubscription = null;
  }

  Future<Address?> loadMyPosition(LatLng? position) async {
    try {
      if (position == null) {
        final current = await MapService.instance.getCurrentPosition();
        startAddress = current;

        await liveLocationSubscription?.cancel();

        liveLocationSubscription = MapService.instance.listenToPositionChanges(
          eventFiring: (Address? address) async {
            if (address == null) return;

            if (userRepo.currentUserRole == Roles.driver) {
              await userRepo.updateDriverLocation(
                userRepo.currentUser?.uid,
                address.latLng,
              );
            }

            startAddress = address;
            currentAddressController.text =
                _addressText(address.street, address.city);

            _safeNotify();
            await _refreshRideCamera();

            if (_rideState == RideState.driverIsComing) {
              await _refreshDriverLegRoute(force: true);
            }
          },
        ).listen((_) {});

        final startLatLng = startAddress?.latLng;
        if (startLatLng != null) {
          await animateCamera(startLatLng);
        }

        _safeNotify();
      } else {
        final myPosition = await MapService.instance.getPosition(position);
        startAddress = myPosition;

        final startLatLng = startAddress?.latLng;
        if (startLatLng != null) {
          await animateCamera(startLatLng);
        }

        _safeNotify();
      }

      MapService.instance.markers.notifyListeners();
      _safeNotify();
      return startAddress;
    } catch (e) {
      debugPrint('loadMyPosition error: $e');
      return null;
    }
  }

  Future<void> getCurrentLocation() async {
    final address = await loadMyPosition(null);

    if (address != null) {
      startAddress = address;
      currentAddressController.text =
          _addressText(address.street, address.city);
    } else {
      currentAddressController.text = '';
    }

    _safeNotify();
    await _refreshRideCamera();
  }

  Future<void> loadRouteCoordinates(LatLng start, LatLng end) async {
    isCalculatingRoute = true;
    _safeNotify();

    try {
      final endPosition = await MapService.instance.getRouteCoordinates(
        start,
        end,
      );

      startAddress = MapService.instance.currentPosition.value;
      endAddress = endPosition;

      if (assignedDriver != null && assignedDriver!.latlng != null) {
        await MapService.instance.addOrUpdateDriverMarker(assignedDriver!);
      }

      updateRidePrices();
      await _refreshRideCamera();
      await _refreshDriverLegRoute(force: true);
    } catch (e) {
      debugPrint('loadRouteCoordinates error: $e');

      if (endAddress != null) {
        updateRidePrices();
      }
    } finally {
      isCalculatingRoute = false;
      _safeNotify();
    }
  }

  Future<void> searchAddress(String query) async {
    _searchDebounce?.cancel();

    _searchDebounce = Timer(const Duration(milliseconds: 500), () async {
      final trimmed = query.trim();

      if (trimmed.length < 3) {
        searchedAddress = <Address>[];
        _safeNotify();
        return;
      }

      try {
        final results = await MapService.instance.getAddressFromQuery(trimmed);

        final filtered = results.where((q) {
          final input = trimmed.toLowerCase();

          final street = q.street.toLowerCase();
          final city = q.city.toLowerCase();
          final state = q.state.toLowerCase();
          final country = q.country.toLowerCase();
          final postcode = q.postcode.toLowerCase();

          return street.contains(input) ||
              city.contains(input) ||
              state.contains(input) ||
              country.contains(input) ||
              postcode.contains(input) ||
              input.contains(street) ||
              input.contains(city);
        }).toList();

        searchedAddress = filtered.isNotEmpty ? filtered : results;
      } catch (e) {
        debugPrint('searchAddress error: $e');
        searchedAddress = <Address>[];
      }

      _safeNotify();
    });
  }

  void onMapCreated(GoogleMapController controller) {
    this.controller = controller;
    MapService.instance.controller.googleMapController = controller;

    final currentLatLng = currentPosition.value?.latLng;
    if (currentLatLng != null) {
      animateCamera(currentLatLng);
    }
  }

  void onTapMap(LatLng argument) {
    MapService.instance.controller.hideInfoWindow?.call();
  }

  void onCameraMove(CameraPosition position) {
    MapService.instance.controller.onCameraMove?.call();
  }

  Future<void> onTapAddressList(Address address) async {
    focusNode?.unfocus();

    destinationAddressController.text =
        _addressText(address.street, address.city);
    endAddress = address;
    searchedAddress = <Address>[];
    assignedDriver = null;
    _cancelAssignedDriverListener();
    _driverRouteRefreshTimer?.cancel();
    MapService.instance.removeDriverMarker();
    _lastDriverCameraTarget = null;
    _resetDriverLegData();
    _safeNotify();

    final currentLatLng = MapService.instance.currentPosition.value?.latLng;
    if (currentLatLng != null) {
      await loadRouteCoordinates(currentLatLng, address.latLng);
    } else {
      updateRidePrices();
    }

    await animateCamera(address.latLng);
    await _refreshRideCamera();

    changeRideState = RideState.selectRide;
  }

  Future<void> onTapMyAddresses(Address address) async {
    destinationAddressController.text =
        _addressText(address.street, address.city);
    endAddress = address;
    searchedAddress = <Address>[];
    assignedDriver = null;
    _cancelAssignedDriverListener();
    _driverRouteRefreshTimer?.cancel();
    MapService.instance.removeDriverMarker();
    _lastDriverCameraTarget = null;
    _resetDriverLegData();
    _safeNotify();

    final currentLatLng = MapService.instance.currentPosition.value?.latLng;
    if (currentLatLng != null) {
      await loadRouteCoordinates(currentLatLng, address.latLng);
    } else {
      updateRidePrices();
    }

    await animateCamera(address.latLng);
    await _refreshRideCamera();

    changeRideState = RideState.selectRide;
  }

  void onTapRideOption(RideOption option, int index) {
    if (index < 0 || index >= isSelectedOptions.length) return;

    for (var i = 0; i < isSelectedOptions.length; i++) {
      isSelectedOptions[i] = false;
    }

    isSelectedOptions[index] = true;
    selectedOption = rideOptions[index];
    _safeNotify();
  }

  void onPageChanged(int value) {
    pageIndex = value;
    _safeNotify();
  }

  void animateToPage({
    required int pageIndex,
    required RideState state,
  }) {
    this.pageIndex = pageIndex;

    if (pageController.hasClients) {
      pageController.jumpToPage(pageIndex);
    }

    changeRideState = state;
  }

  void searchLocation() {
    animateToPage(pageIndex: 1, state: RideState.searchingAddress);
  }

  void closeSearching() {
    animateToPage(pageIndex: 0, state: RideState.initial);
  }

  void requestRide() {
    if (endAddress == null) {
      debugPrint('Destination not selected yet.');
      return;
    }

    animateToPage(pageIndex: 2, state: RideState.requestRide);
  }

  void proceedRide() {
    if (isCalculatingRoute) {
      debugPrint('Route still calculating');
      return;
    }

    if (selectedOption == null) {
      debugPrint('No selected option');
      return;
    }

    if ((selectedOption?.price ?? 0) <= 0) {
      debugPrint('Fare still zero');
      return;
    }

    animateToPage(pageIndex: 3, state: RideState.confirmAddress);
  }

  void _listenToRide(String rideId) {
    rideSubscription?.cancel();

    rideSubscription =
        rideRepo?.listenToRide(rideId).listen((rideUpdate) async {
      if (rideUpdate == null) return;

      currentRide = rideUpdate;

      if (rideUpdate.driverUID.isNotEmpty) {
        if (assignedDriver == null ||
            assignedDriver!.uid != rideUpdate.driverUID) {
          await loadDriverProfile(rideUpdate.driverUID);
          _listenToAssignedDriver(rideUpdate.driverUID);
        }
      }

      switch (rideUpdate.status) {
        case RideStatus.initial:
        case RideStatus.requesting:
          changeRideState = RideState.requestRide;
          break;
        case RideStatus.accepted:
          changeRideState = RideState.driverIsComing;
          _startDriverRouteRefreshTimer();
          break;
        case RideStatus.moving:
          changeRideState = RideState.inMotion;
          _startDriverRouteRefreshTimer();
          break;
        case RideStatus.arrived:
          changeRideState = RideState.arrived;
          _startDriverRouteRefreshTimer();
          break;
        case RideStatus.completed:
          changeRideState = RideState.arrived;
          break;
        case RideStatus.cancel:
          _handleRideCancellation();
          break;
        case RideStatus.expired:
          showMessage(
            'No nearby drivers accepted your request. Please try again.',
          );
          rideSubscription?.cancel();
          _clearRideState(resetRide: true);
          animateToPage(pageIndex: 0, state: RideState.initial);
          break;
      }

      _safeNotify();
      await _refreshRideCamera();
      await _refreshDriverLegRoute(force: true);
    });
  }

  Future<void> confirmRide() async {
    if (isSubmittingRide) return;

    if (currentRide != null) {
      showMessage('A ride is already in progress.');
      return;
    }

    if (startAddress == null || endAddress == null || selectedOption == null) {
      debugPrint(
          'Ride cannot be confirmed. Missing start, end or ride option.');
      return;
    }

    if ((selectedOption?.price ?? 0) <= 0) {
      debugPrint('Ride cannot be confirmed. Fare not calculated yet.');
      return;
    }

    assignedDriver = null;
    _cancelAssignedDriverListener();
    _driverRouteRefreshTimer?.cancel();
    MapService.instance.removeDriverMarker();
    _lastDriverCameraTarget = null;
    _resetDriverLegData();
    isSubmittingRide = true;
    _safeNotify();

    animateToPage(pageIndex: 4, state: RideState.requestRide);
    showMessage('Searching for nearby drivers...');

    try {
      final ownerUID = userRepo.currentUser?.uid;
      if (ownerUID == null || ownerUID.isEmpty) {
        debugPrint('Ride cannot be confirmed. Missing owner UID.');
        return;
      }

      final ride = _initializeRide(ownerUID);
      final addedRide = await rideRepo?.boardRide(ride);

      if (addedRide != null) {
        currentRide = addedRide;
        _listenToRide(addedRide.id);

        if (addedRide.driverUID.isNotEmpty) {
          await loadDriverProfile(addedRide.driverUID);
          _listenToAssignedDriver(addedRide.driverUID);
        }
      }
    } catch (e) {
      debugPrint('confirmRide error: $e');
    } finally {
      isSubmittingRide = false;
      _safeNotify();
      await _refreshRideCamera();
    }
  }

  Ride _initializeRide(String uid) {
    final id = CodeGenerator.instance!.generateCode('city-id');

    return Ride(
      createdAt: DateTime.now(),
      driverUID: '',
      endAddress: endAddress!,
      id: id,
      ownerUID: uid,
      passengers: <String>[uid],
      candidateDriverUIDs: const <String>[],
      rejectedDriverUIDs: const <String>[],
      requestExpiresAt: null,
      searchWave: -1,
      rate: Rate(uid: uid, subject: '', body: '', stars: 0),
      rideOption: selectedOption!,
      startAddress: startAddress!,
      status: RideStatus.requesting,
    );
  }

  void _handleRideCancellation() {
    rideSubscription?.cancel();
    _clearRideState(resetRide: true);
    animateToPage(pageIndex: 0, state: RideState.initial);
  }

  Future<void> payForRide() async {
    if (isPayingForRide) return;

    final String? rideId = currentRide?.id;
    if (rideId == null || rideId.isEmpty) {
      showMessage('No ride available to complete.');
      return;
    }

    try {
      isPayingForRide = true;
      _safeNotify();

      await rideRepo?.completeRide(rideId);

      isRidePaid = true;
      showMessage('Payment completed successfully.');
    } catch (_) {
      showMessage('Payment could not be completed.');
    } finally {
      isPayingForRide = false;
      _safeNotify();
    }
  }

  void updateRatingStars(int stars) {
    selectedRatingStars = stars.clamp(1, 5);
    _safeNotify();
  }

  Future<void> submitRideRating() async {
    if (isSubmittingRating) return;

    final ride = currentRide;
    final currentUserId = userRepo.currentUser?.uid;

    if (ride == null || currentUserId == null || currentUserId.isEmpty) {
      showMessage('Could not submit rating.');
      return;
    }

    try {
      isSubmittingRating = true;
      _safeNotify();

      final rate = Rate(
        uid: currentUserId,
        subject: ratingSubjectController.text.trim(),
        body: ratingBodyController.text.trim(),
        stars: selectedRatingStars.toDouble(),
      );

      await rideRepo?.submitRideRating(ride.id, rate);

      showMessage('Thanks for your feedback.');
      rideSubscription?.cancel();
      _clearRideState(resetRide: true);
      animateToPage(pageIndex: 0, state: RideState.initial);
    } catch (_) {
      showMessage('Rating submission failed.');
    } finally {
      isSubmittingRating = false;
      _safeNotify();
    }
  }

  Future<void> callDriver() async {
    if (assignedDriver == null) {
      showMessage('No assigned driver to call.');
      return;
    }

    final String phone = assignedDriver!.phone.trim();

    if (phone.isEmpty) {
      showMessage('Driver phone number is missing.');
      return;
    }

    final Uri telUri = Uri(
      scheme: 'tel',
      path: phone,
    );

    try {
      isCallingDriver = true;
      _safeNotify();

      final bool supported = await canLaunchUrl(telUri);

      if (!supported) {
        showMessage('Dialer not available on this device.');
        return;
      }

      final bool launched = await launchUrl(
        telUri,
        mode: LaunchMode.platformDefault,
      );

      if (!launched) {
        showMessage('Could not open the dialer.');
      }
    } catch (_) {
      showMessage('Failed to start phone call.');
    } finally {
      isCallingDriver = false;
      _safeNotify();
    }
  }

  Future<void> cancelRide() async {
    try {
      final rideId = currentRide?.id;
      if (rideId != null && rideId.isNotEmpty) {
        await rideRepo?.cancelRide(rideId);
        showMessage('Ride cancelled successfully.');
      }
    } catch (_) {
      showMessage('Could not cancel the ride.');
    } finally {
      rideSubscription?.cancel();
      _clearRideState(resetRide: true);
      animateToPage(pageIndex: 0, state: RideState.initial);
      await _refreshRideCamera();
    }
  }

  Future<void> changeActivePresence() async {
    isActive = !isActive;
    _safeNotify();

    try {
      await userRepo.updateOnlinePresense(userRepo.currentUser?.uid, isActive);
    } catch (e) {
      isActive = !isActive;
      debugPrint('changeActivePresence error: $e');
      _safeNotify();
    }
  }

  String _addressText(String street, String city) {
    final parts = <String>[
      street.trim(),
      city.trim(),
    ].where((e) => e.isNotEmpty).toList();

    return parts.join(', ');
  }

  @override
  void dispose() {
    _disposed = true;
    _searchDebounce?.cancel();

    rideSubscription?.cancel();
    liveLocationSubscription?.cancel();
    assignedDriverSubscription?.cancel();
    _driverRequestsSubscription?.cancel();
    _driverRouteRefreshTimer?.cancel();

    currentAddressController.dispose();
    destinationAddressController.removeListener(_onDestinationTextChanged);
    destinationAddressController.dispose();
    ratingSubjectController.dispose();
    ratingBodyController.dispose();

    focusNode?.dispose();
    controller?.dispose();
    pageController.dispose();

    super.dispose();
  }
}

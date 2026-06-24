import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'ble_mesh_service.dart';

enum ConnectivityMode { internet, ble }

class ConnectivityService with ChangeNotifier {
  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity() {
    _init();
  }

  final Connectivity _connectivity;
  final BleMeshService bleMeshService = BleMeshService();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  ConnectivityMode _currentMode = ConnectivityMode.internet;
  bool _isInternetAvailable = true;

  ConnectivityMode get mode => _currentMode;
  bool get isInternetAvailable => _isInternetAvailable;

  Future<void> _init() async {
    final initialState = await _connectivity.checkConnectivity();
    await _updateFromResults(initialState);

    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _updateFromResults,
    );
  }

  Future<void> _updateFromResults(List<ConnectivityResult> results) async {
    final hadInternet = _isInternetAvailable;
    _isInternetAvailable =
        results.any((result) => result != ConnectivityResult.none);
    _currentMode =
        _isInternetAvailable ? ConnectivityMode.internet : ConnectivityMode.ble;

    if (hadInternet == _isInternetAvailable) {
      notifyListeners();
      return;
    }

    if (_isInternetAvailable) {
      await bleMeshService.stopMeshDiscovery();
    }

    notifyListeners();
  }

  Future<void> toggleInternet(bool available, {String? deviceName}) async {
    _isInternetAvailable = available;
    _currentMode = available ? ConnectivityMode.internet : ConnectivityMode.ble;

    if (available) {
      await bleMeshService.stopMeshDiscovery();
    } else {
      await bleMeshService.startMeshDiscovery(deviceName: deviceName);
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    bleMeshService.dispose();
    super.dispose();
  }
}

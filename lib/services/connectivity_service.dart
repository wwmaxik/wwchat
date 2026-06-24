import 'dart:async';
import 'package:flutter/foundation.dart';
import 'ble_mesh_service.dart';

enum ConnectivityMode { internet, ble }

class ConnectivityService with ChangeNotifier {
  ConnectivityMode _currentMode = ConnectivityMode.internet;
  bool _isInternetAvailable = true;
  final BleMeshService bleMeshService = BleMeshService();
  
  ConnectivityMode get mode => _currentMode;
  bool get isInternetAvailable => _isInternetAvailable;

  ConnectivityService() {
    _startHeartbeat();
  }

  void _startHeartbeat() {
    Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkInternetStatus();
    });
  }

  Future<void> _checkInternetStatus() async {
    // In a real app, you'd ping your server or use connectivity_plus
  }

  Future<void> sendMessage(String text, String recipientId) async {
    if (_isInternetAvailable) {
      debugPrint("Routing message via INTERNET to $recipientId");
    } else {
      debugPrint("Routing message via BLE MESH to $recipientId");
      await bleMeshService.sendMeshMessage(text);
    }
  }

  Future<void> toggleInternet(bool available, {String? deviceName}) async {
    _isInternetAvailable = available;
    _currentMode = _isInternetAvailable ? ConnectivityMode.internet : ConnectivityMode.ble;
    
    if (!_isInternetAvailable) {
      await bleMeshService.startMeshDiscovery(deviceName: deviceName);
    } else {
      await bleMeshService.stopMeshDiscovery();
    }
    notifyListeners();
  }
}

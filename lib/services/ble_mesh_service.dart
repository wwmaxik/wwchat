import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';

class BleMeshService extends ChangeNotifier {
  NearbyService? _nearbyService;
  StreamSubscription? _stateSubscription;
  StreamSubscription? _dataSubscription;
  bool _isInitialized = false;
  bool _isStarting = false;

  final Map<String, Device> _discoveredDevices = {};

  List<Device> get discoveredDevices => _discoveredDevices.values.toList();

  // Callback for when a message is received
  void Function(String encryptedText, String senderId)? onMessageReceived;

  Future<void> initService(String deviceName) async {
    if (_isInitialized) return;

    debugPrint("Initializing NearbyService with name: $deviceName");
    try {
      _nearbyService = NearbyService();
      await _nearbyService!.init(
        serviceType: 'wwchat',
        strategy: Strategy.P2P_CLUSTER,
        deviceName: deviceName,
        callback: (isRunning) {
          debugPrint("NearbyService running state: $isRunning");
        },
      );
      _isInitialized = true;
      debugPrint("NearbyService initialized successfully");
    } catch (e, stack) {
      debugPrint("Error initializing NearbyService: $e");
      debugPrint("Stack: $stack");
      _nearbyService = null;
      _isInitialized = false;
    }
  }

  Future<bool> _requestPermissions() async {
    try {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.location,
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.nearbyWifiDevices,
      ].request();

      bool locationGranted = statuses[Permission.location]?.isGranted ?? false;
      debugPrint("Permissions granted status: location=$locationGranted");
      return locationGranted;
    } catch (e) {
      debugPrint("Error requesting permissions: $e");
      return false;
    }
  }

  Future<void> startMeshDiscovery({String? deviceName}) async {
    if (_isStarting) {
      debugPrint("Mesh discovery is already starting, skipping...");
      return;
    }
    _isStarting = true;
    
    debugPrint("Starting P2P Mesh Discovery...");
    
    try {
      // Request permissions first
      final permGranted = await _requestPermissions();
      if (!permGranted) {
        debugPrint("Location permission not granted, cannot start P2P discovery");
        _isStarting = false;
        return;
      }

      if (!_isInitialized) {
        await initService(deviceName ?? "User_${DateTime.now().millisecondsSinceEpoch % 1000}");
      }

      if (!_isInitialized || _nearbyService == null) {
        debugPrint("NearbyService failed to initialize, aborting discovery");
        _isStarting = false;
        return;
      }

      _discoveredDevices.clear();
      notifyListeners();

      // Cancel existing subscriptions if any
      await _stateSubscription?.cancel();
      await _dataSubscription?.cancel();

      // Subscribe to state changes
      _stateSubscription = _nearbyService!.stateChangedSubscription(
        callback: (devicesList) {
          for (var device in devicesList) {
            debugPrint("Device: ${device.deviceName} | State: ${device.state}");
            _discoveredDevices[device.deviceId] = device;

            // Automatically connect/invite if not connected
            if (device.state == SessionState.notConnected) {
              debugPrint("Auto-inviting device: ${device.deviceName}");
              try {
                _nearbyService!.invitePeer(
                  deviceID: device.deviceId,
                  deviceName: device.deviceName,
                );
              } catch (e) {
                debugPrint("Error inviting peer: $e");
              }
            }
          }
          notifyListeners();
        },
      );

      // Subscribe to data received
      _dataSubscription = _nearbyService!.dataReceivedSubscription(
        callback: (data) {
          debugPrint("Data received raw: $data");
          try {
            String? messageText;
            String? senderId;

            if (data is Map) {
              messageText = data['message'];
              senderId = data['deviceId'] ?? data['senderDeviceId'];
            } else {
              // Fallback: if it's some other format or a json encoded string
              messageText = data.toString();
            }

            if (messageText != null && senderId != null) {
              onMessageReceived?.call(messageText, senderId);
            }
          } catch (e) {
            debugPrint("Error parsing received P2P data: $e");
          }
        },
      );

      await _nearbyService!.startAdvertisingPeer();
      debugPrint("Started advertising peer");
      await _nearbyService!.startBrowsingForPeers();
      debugPrint("Started browsing for peers");
    } catch (e, stack) {
      debugPrint("Error during mesh discovery startup: $e");
      debugPrint("Stack: $stack");
    } finally {
      _isStarting = false;
    }
  }

  Future<void> stopMeshDiscovery() async {
    debugPrint("Stopping P2P Mesh Discovery...");
    try {
      await _stateSubscription?.cancel();
      _stateSubscription = null;
      await _dataSubscription?.cancel();
      _dataSubscription = null;
      
      if (_nearbyService != null && _isInitialized) {
        await _nearbyService!.stopAdvertisingPeer();
        await _nearbyService!.stopBrowsingForPeers();
      }
    } catch (e) {
      debugPrint("Error stopping advertising/browsing: $e");
    }

    _discoveredDevices.clear();
    notifyListeners();
  }

  Future<void> sendMeshMessage(String text) async {
    if (_nearbyService == null) {
      debugPrint("NearbyService is null, cannot send message");
      return;
    }
    
    debugPrint("Broadcasting P2P Message to all connected nodes: $text");
    for (var device in _discoveredDevices.values) {
      if (device.state == SessionState.connected) {
        debugPrint("Sending to connected peer: ${device.deviceName} (${device.deviceId})");
        try {
          await _nearbyService!.sendMessage(device.deviceId, text);
        } catch (e) {
          debugPrint("Failed to send message to ${device.deviceId}: $e");
        }
      }
    }
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _dataSubscription?.cancel();
    super.dispose();
  }
}

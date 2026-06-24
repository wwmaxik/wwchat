import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/message.dart';

class BleMeshService extends ChangeNotifier {
  NearbyService? _nearbyService;
  StreamSubscription? _stateSubscription;
  StreamSubscription? _dataSubscription;
  bool _isInitialized = false;
  bool _isStarting = false;
  String? _localDeviceId;
  final Set<String> _seenPacketIds = <String>{};

  final Map<String, Device> _discoveredDevices = {};

  static const int maxHopCount = 2;

  List<Device> get discoveredDevices => _discoveredDevices.values.toList();
  String? get localDeviceId => _localDeviceId;

  void Function(MeshMessagePacket packet)? onMessageReceived;

  Future<void> initService(String deviceName) async {
    if (_isInitialized) return;

    debugPrint('Initializing NearbyService with name: $deviceName');
    try {
      _nearbyService = NearbyService();
      await _nearbyService!.init(
        serviceType: 'wwchat',
        strategy: Strategy.P2P_CLUSTER,
        deviceName: deviceName,
        callback: (isRunning) {
          debugPrint('NearbyService running state: $isRunning');
        },
      );
      _isInitialized = true;
      debugPrint('NearbyService initialized successfully');
    } catch (e, stack) {
      debugPrint('Error initializing NearbyService: $e');
      debugPrint('Stack: $stack');
      _nearbyService = null;
      _isInitialized = false;
    }
  }

  Future<bool> _requestPermissions() async {
    try {
      final statuses = await [
        Permission.location,
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.nearbyWifiDevices,
      ].request();

      return (statuses[Permission.location]?.isGranted ?? false) &&
          (statuses[Permission.bluetooth]?.isGranted ?? true) &&
          (statuses[Permission.bluetoothScan]?.isGranted ?? true) &&
          (statuses[Permission.bluetoothAdvertise]?.isGranted ?? true) &&
          (statuses[Permission.bluetoothConnect]?.isGranted ?? true);
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
      return false;
    }
  }

  Future<void> startMeshDiscovery({String? deviceName}) async {
    if (_isStarting) {
      debugPrint('Mesh discovery is already starting, skipping...');
      return;
    }
    _isStarting = true;

    try {
      final permGranted = await _requestPermissions();
      if (!permGranted) {
        debugPrint('Required permissions are not granted, cannot start P2P discovery');
        return;
      }

      if (!_isInitialized) {
        await initService(deviceName ?? 'User_${DateTime.now().millisecondsSinceEpoch % 1000}');
      }

      if (!_isInitialized || _nearbyService == null) {
        debugPrint('NearbyService failed to initialize, aborting discovery');
        return;
      }

      _discoveredDevices.clear();
      notifyListeners();

      await _stateSubscription?.cancel();
      await _dataSubscription?.cancel();

      _stateSubscription = _nearbyService!.stateChangedSubscription(
        callback: (devicesList) {
          for (final device in devicesList) {
            _discoveredDevices[device.deviceId] = device;
            _localDeviceId ??= device.deviceId;

            if (device.state == SessionState.notConnected) {
              try {
                _nearbyService!.invitePeer(
                  deviceID: device.deviceId,
                  deviceName: device.deviceName,
                );
              } catch (e) {
                debugPrint('Error inviting peer: $e');
              }
            }
          }
          notifyListeners();
        },
      );

      _dataSubscription = _nearbyService!.dataReceivedSubscription(
        callback: (data) {
          try {
            String? encodedPacket;

            if (data is Map) {
              encodedPacket = data['message'] as String? ?? data['data'] as String?;
            } else {
              encodedPacket = data.toString();
            }

            if (encodedPacket == null || encodedPacket.isEmpty) {
              return;
            }

            final packet = MeshMessagePacket.decode(encodedPacket);
            if (_seenPacketIds.contains(packet.id)) {
              return;
            }
            _seenPacketIds.add(packet.id);
            onMessageReceived?.call(packet);
          } catch (e) {
            debugPrint('Error parsing received P2P data: $e');
          }
        },
      );

      await _nearbyService!.startAdvertisingPeer();
      await _nearbyService!.startBrowsingForPeers();
    } catch (e, stack) {
      debugPrint('Error during mesh discovery startup: $e');
      debugPrint('Stack: $stack');
    } finally {
      _isStarting = false;
    }
  }

  Future<void> stopMeshDiscovery() async {
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
      debugPrint('Error stopping advertising/browsing: $e');
    }

    _discoveredDevices.clear();
    notifyListeners();
  }

  Future<void> sendMeshMessage(MeshMessagePacket packet) async {
    await _broadcastPacket(packet);
  }

  Future<void> relayMeshMessage(MeshMessagePacket packet) async {
    if (packet.hopCount >= maxHopCount) {
      return;
    }

    await _broadcastPacket(
      MeshMessagePacket(
        id: packet.id,
        senderUserId: packet.senderUserId,
        senderMeshId: packet.senderMeshId,
        recipientUserId: packet.recipientUserId,
        conversationId: packet.conversationId,
        encryptedText: packet.encryptedText,
        hopCount: packet.hopCount + 1,
        sentAt: packet.sentAt,
      ),
    );
  }

  Future<void> _broadcastPacket(MeshMessagePacket packet) async {
    if (_nearbyService == null) {
      debugPrint('NearbyService is null, cannot send packet');
      return;
    }

    final encodedPacket = packet.encode();
    _seenPacketIds.add(packet.id);

    for (final device in _discoveredDevices.values) {
      if (device.state == SessionState.connected) {
        try {
          await _nearbyService!.sendMessage(device.deviceId, encodedPacket);
        } catch (e) {
          debugPrint('Failed to send packet to ${device.deviceId}: $e');
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

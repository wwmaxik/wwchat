import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/message.dart';

class BleMeshDevice {
  final String deviceId;
  final String deviceName;
  final BluetoothDevice bluetoothDevice;
  BleMeshConnectionState state;
  BluetoothCharacteristic? writeCharacteristic;

  BleMeshDevice({
    required this.deviceId,
    required this.deviceName,
    required this.bluetoothDevice,
    this.state = BleMeshConnectionState.disconnected,
    this.writeCharacteristic,
  });
}

enum BleMeshConnectionState { disconnected, connecting, connected }

class BleMeshService extends ChangeNotifier {
  final Map<String, BleMeshDevice> _discoveredDevices = {};
  final Set<String> _seenPacketIds = <String>{};
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  final Map<String, StreamSubscription<List<int>>> _notifySubscriptions = {};
  bool _isInitialized = false;
  bool _isScanning = false;
  String? _localDeviceId;

  static const String serviceUuid = '0000ff01-0000-1000-8000-00805f9b34fb';
  static const String characteristicUuid =
      '0000ff02-0000-1000-8000-00805f9b34fb';
  static const int maxHopCount = 2;

  List<BleMeshDevice> get discoveredDevices =>
      _discoveredDevices.values.toList();
  String? get localDeviceId => _localDeviceId;

  void Function(MeshMessagePacket packet)? onMessageReceived;

  Future<void> initService(String deviceName) async {
    if (_isInitialized) return;

    debugPrint('Initializing BLE Mesh Service');
    try {
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        debugPrint('Bluetooth adapter is not on');
        return;
      }

      _isInitialized = true;
      debugPrint('BLE Mesh Service initialized successfully');
    } catch (e, stack) {
      debugPrint('Error initializing BLE Mesh Service: $e');
      debugPrint('Stack: $stack');
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
    if (_isScanning) {
      debugPrint('BLE scanning is already running, skipping...');
      return;
    }
    _isScanning = true;

    try {
      final permGranted = await _requestPermissions();
      if (!permGranted) {
        debugPrint('Required permissions are not granted, cannot start BLE');
        return;
      }

      if (!_isInitialized) {
        await initService(deviceName ??
            'User_${DateTime.now().millisecondsSinceEpoch % 1000}');
      }

      if (!_isInitialized) {
        debugPrint('BLE Mesh Service failed to initialize, aborting');
        return;
      }

      _discoveredDevices.clear();
      notifyListeners();

      await _scanSubscription?.cancel();

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 0),
        androidUsesFineLocation: true,
      );

      _scanSubscription = FlutterBluePlus.scanResults.listen(
        (results) {
          for (final result in results) {
            final deviceId = result.device.remoteId.str;
            final advertisementName = result.advertisementData.advName;
            final deviceDisplayName =
                advertisementName.isNotEmpty ? advertisementName : deviceId;

            if (!_discoveredDevices.containsKey(deviceId)) {
              _discoveredDevices[deviceId] = BleMeshDevice(
                deviceId: deviceId,
                deviceName: deviceDisplayName,
                bluetoothDevice: result.device,
              );
              _localDeviceId ??= deviceId;
              notifyListeners();

              _connectToDevice(_discoveredDevices[deviceId]!);
            }
          }
        },
        onError: (e) {
          debugPrint('BLE scan error: $e');
        },
      );
    } catch (e, stack) {
      debugPrint('Error during BLE discovery startup: $e');
      debugPrint('Stack: $stack');
    } finally {
      _isScanning = false;
    }
  }

  Future<void> _connectToDevice(BleMeshDevice meshDevice) async {
    try {
      meshDevice.state = BleMeshConnectionState.connecting;
      notifyListeners();

      await meshDevice.bluetoothDevice.connect(
        timeout: const Duration(seconds: 10),
      );

      final services = await meshDevice.bluetoothDevice.discoverServices();
      for (final service in services) {
        if (service.uuid.toString() == serviceUuid) {
          for (final characteristic in service.characteristics) {
            if (characteristic.uuid.toString() == characteristicUuid) {
              meshDevice.writeCharacteristic = characteristic;

              if (characteristic.properties.notify) {
                await characteristic.setNotifyValue(true);
                final sub = characteristic.lastValueStream.listen(
                  (data) {
                    _handleReceivedData(data);
                  },
                  onError: (e) {
                    debugPrint('Notify error: $e');
                  },
                );
                _notifySubscriptions[meshDevice.deviceId]?.cancel();
                _notifySubscriptions[meshDevice.deviceId] = sub;
              }
            }
          }
        }
      }

      meshDevice.state = BleMeshConnectionState.connected;
      notifyListeners();
    } catch (e) {
      debugPrint('Error connecting to ${meshDevice.deviceId}: $e');
      meshDevice.state = BleMeshConnectionState.disconnected;
      notifyListeners();
    }
  }

  void _handleReceivedData(List<int> data) {
    try {
      final encodedPacket = utf8.decode(data);

      if (encodedPacket.isEmpty) return;

      final packet = MeshMessagePacket.decode(encodedPacket);
      if (_seenPacketIds.contains(packet.id)) return;

      _seenPacketIds.add(packet.id);
      onMessageReceived?.call(packet);
    } catch (e) {
      debugPrint('Error parsing received BLE data: $e');
    }
  }

  Future<void> stopMeshDiscovery() async {
    try {
      await _scanSubscription?.cancel();
      _scanSubscription = null;

      for (final sub in _notifySubscriptions.values) {
        await sub.cancel();
      }
      _notifySubscriptions.clear();

      await FlutterBluePlus.stopScan();

      for (final device in _discoveredDevices.values) {
        if (device.state == BleMeshConnectionState.connected) {
          await device.bluetoothDevice.disconnect();
        }
      }
    } catch (e) {
      debugPrint('Error stopping BLE discovery: $e');
    }

    _discoveredDevices.clear();
    notifyListeners();
  }

  Future<void> sendMeshMessage(MeshMessagePacket packet) async {
    await _broadcastPacket(packet);
  }

  Future<void> relayMeshMessage(MeshMessagePacket packet) async {
    if (packet.hopCount >= maxHopCount) return;

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
    final encodedPacket = packet.encode();
    final data = utf8.encode(encodedPacket);
    _seenPacketIds.add(packet.id);

    for (final device in _discoveredDevices.values) {
      if (device.state == BleMeshConnectionState.connected &&
          device.writeCharacteristic != null) {
        try {
          await device.writeCharacteristic!.write(data);
        } catch (e) {
          debugPrint('Failed to send packet to ${device.deviceId}: $e');
        }
      }
    }
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    for (final sub in _notifySubscriptions.values) {
      sub.cancel();
    }
    _notifySubscriptions.clear();
    FlutterBluePlus.stopScan();
    super.dispose();
  }
}

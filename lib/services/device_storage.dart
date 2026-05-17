import 'dart:convert';
import 'dart:io';

import 'package:adb_connector/models/saved_device.dart';

class DeviceStorage {
  static String get _dirPath {
    final home = Platform.environment['HOME'] ?? '';
    return '$home/Library/Application Support/adb_connector';
  }

  static String get _filePath => '$_dirPath/saved_devices.json';

  Future<List<SavedDevice>> loadDevices() async {
    final file = File(_filePath);
    if (!await file.exists()) return [];

    try {
      final content = await file.readAsString();
      final list = jsonDecode(content) as List<dynamic>;
      return list
          .map((e) => SavedDevice.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveDevices(List<SavedDevice> devices) async {
    final dir = Directory(_dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final file = File(_filePath);
    final json = jsonEncode(devices.map((d) => d.toJson()).toList());
    await file.writeAsString(json);
  }

  Future<void> addDevice(SavedDevice device) async {
    final devices = await loadDevices();
    final duplicate = devices.any((d) {
      if (device.isIos) return d.serialName == device.serialName;
      return d.ip == device.ip;
    });
    if (duplicate) return;
    devices.add(device);
    await saveDevices(devices);
  }

  Future<void> updateDevice(SavedDevice device) async {
    final devices = await loadDevices();
    final index = devices.indexWhere((d) => d.id == device.id);
    if (index >= 0) {
      devices[index] = device;
      await saveDevices(devices);
    }
  }

  Future<void> deleteDevice(String id) async {
    final devices = await loadDevices();
    devices.removeWhere((d) => d.id == id);
    await saveDevices(devices);
  }
}

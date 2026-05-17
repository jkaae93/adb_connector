import 'dart:async';
import 'dart:io';

class IosConnectedDevice {
  IosConnectedDevice({
    required this.udid,
    this.name,
    this.modelName,
    this.isWifi = false,
  });

  final String udid;
  final String? name;
  final String? modelName;
  final bool isWifi;
}

class IosService {
  IosService._();

  static final IosService instance = IosService._();

  static const _timeout = Duration(seconds: 5);

  static const List<String> _toolPaths = [
    '/opt/homebrew/bin',
    '/usr/local/bin',
    '/usr/bin',
  ];

  String? _resolveToolPath(String tool) {
    for (final dir in _toolPaths) {
      final file = File('$dir/$tool');
      if (file.existsSync()) return file.path;
    }
    return null;
  }

  String? get _ideviceIdPath => _resolveToolPath('idevice_id');
  String? get _ideviceSyslogPath => _resolveToolPath('idevicesyslog');

  bool isAvailable() => _ideviceIdPath != null;

  Future<ProcessResult> _run(String tool, List<String> args) async {
    final path = _resolveToolPath(tool);
    if (path == null) return ProcessResult(0, 1, '', '$tool not found');
    try {
      return await Process.run(path, args).timeout(_timeout);
    } on TimeoutException {
      return ProcessResult(0, 1, '', 'timed out');
    }
  }

  Future<List<IosConnectedDevice>> getConnectedDevices() async {
    final usbResult = await _run('idevice_id', ['-l']);
    final wifiResult = await _run('idevice_id', ['-n']);

    final usbUdids = _parseUdidList(usbResult.stdout as String);
    final wifiUdids = _parseUdidList(wifiResult.stdout as String);

    // 합집합, WiFi 여부 표시
    final allUdids = <String>{...usbUdids, ...wifiUdids};
    final devices = <IosConnectedDevice>[];

    for (final udid in allUdids) {
      final isWifi = wifiUdids.contains(udid) && !usbUdids.contains(udid);
      final name = await getDeviceName(udid);
      final model = await getDeviceModel(udid);
      devices.add(
        IosConnectedDevice(
          udid: udid,
          name: name.isEmpty ? null : name,
          modelName: model.isEmpty ? null : model,
          isWifi: isWifi,
        ),
      );
    }

    return devices;
  }

  List<String> _parseUdidList(String output) {
    return output
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.length == 40)
        .toList();
  }

  Future<String> getDeviceName(String udid) async {
    final r = await _run('ideviceinfo', ['-u', udid, '-k', 'DeviceName']);
    return (r.stdout as String).trim();
  }

  Future<String> getDeviceModel(String udid) async {
    final r = await _run('ideviceinfo', ['-u', udid, '-k', 'ProductType']);
    return (r.stdout as String).trim();
  }

  Future<Process> startSyslog(String udid) async {
    final path = _ideviceSyslogPath ?? 'idevicesyslog';
    return Process.start(path, ['-u', udid]);
  }

  String buildSyslogCommand(String udid) {
    final path = _ideviceSyslogPath ?? 'idevicesyslog';
    return '$path -u $udid';
  }
}

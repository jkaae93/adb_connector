import 'dart:async';

import 'package:adb_connector/models/logcat_options.dart';
import 'package:adb_connector/models/saved_device.dart';
import 'package:adb_connector/pages/file_browser_page.dart';
import 'package:adb_connector/pages/logcat_page.dart';
import 'package:adb_connector/services/adb_service.dart';
import 'package:adb_connector/services/device_storage.dart';
import 'package:adb_connector/services/ios_service.dart';
import 'package:adb_connector/services/terminal_service.dart';
import 'package:adb_connector/widgets/add_device_dialog.dart';
import 'package:adb_connector/widgets/device_list_tile.dart';
import 'package:adb_connector/widgets/logcat_options_dialog.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AdbService _adbService = AdbService();
  final IosService _iosService = IosService.instance;
  final DeviceStorage _storage = DeviceStorage();
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController =
      TextEditingController(text: '5555');

  List<SavedDevice> _savedDevices = [];
  List<ConnectedDevice> _connectedDevices = [];
  Set<String> _iosUsbUdids = {};
  Set<String> _iosWifiUdids = {};

  final Set<String> _connectingDeviceIds = {};
  bool _isRefreshing = false;
  Timer? _refreshTimer;

  bool _adbAvailable = false;
  bool _iosAvailable = false;
  bool _isInstallingAdb = false;
  String _installMessage = '';
  double? _installProgress;

  @override
  void initState() {
    super.initState();
    _adbAvailable = _adbService.isAdbAvailable();
    _iosAvailable = _iosService.isAvailable();
    _loadSavedDevices().then((_) => _refreshConnectedDevices());
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refreshConnectedDevices(),
    );
  }

  Future<void> _installAdb() async {
    setState(() {
      _isInstallingAdb = true;
      _installMessage = '설치 준비 중...';
      _installProgress = null;
    });

    final success = await _adbService.installAdb(
      onProgress: (message, progress) {
        if (mounted) {
          setState(() {
            _installMessage = message;
            _installProgress = progress;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _isInstallingAdb = false;
        _adbAvailable = success;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ADB 설치 완료'),
            backgroundColor: Colors.green,
          ),
        );
        await _refreshConnectedDevices();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ADB 설치 실패: $_installMessage'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedDevices() async {
    final devices = await _storage.loadDevices();
    setState(() => _savedDevices = devices);
  }

  Future<void> _refreshConnectedDevices() async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    try {
      // Android
      if (_adbAvailable) {
        final devices = await _adbService.getConnectedDevices();
        if (mounted) {
          setState(() => _connectedDevices = devices);
          await _autoSaveConnectedDevices(devices);
        }
      }

      // iOS
      if (_iosAvailable) {
        final iosDevices = await _iosService.getConnectedDevices();
        if (mounted) {
          setState(() {
            _iosUsbUdids =
                iosDevices.where((d) => !d.isWifi).map((d) => d.udid).toSet();
            _iosWifiUdids =
                iosDevices.where((d) => d.isWifi).map((d) => d.udid).toSet();
          });
          await _autoSaveIosDevices(iosDevices);
        }
      }
    } catch (_) {
      // 실행 실패 무시
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _autoSaveConnectedDevices(
    List<ConnectedDevice> connected,
  ) async {
    var changed = false;

    for (final device in connected) {
      if (device.state != 'device') continue;

      if (device.isIpConnection) {
        final ip = device.ip!;
        final port = device.port ?? 5555;
        final alreadySaved = _savedDevices.any(
          (d) => d.platform == DevicePlatform.android && d.ip == ip,
        );
        if (alreadySaved) continue;

        final model = device.modelName ?? '';
        final newDevice = SavedDevice(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          nickname: model.isNotEmpty ? model : ip,
          ip: ip,
          port: port,
          serialName: null,
          modelName: model.isNotEmpty ? model : null,
        );
        await _storage.addDevice(newDevice);
        changed = true;
      } else {
        final serial = device.identifier;
        final alreadySaved = _savedDevices.any(
          (d) => d.platform == DevicePlatform.android && d.serialName == serial,
        );
        if (alreadySaved) continue;

        final ip = await _adbService.getDeviceIp(serial);
        if (ip == null) continue;

        final ipAlreadySaved = _savedDevices.any(
          (d) => d.platform == DevicePlatform.android && d.ip == ip,
        );
        if (ipAlreadySaved) continue;

        final model =
            device.modelName ?? await _adbService.getDeviceModel(serial);
        final serialNo = await _adbService.getDeviceSerial(serial);

        final newDevice = SavedDevice(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          nickname: model.isNotEmpty ? model : serial,
          ip: ip,
          serialName: serialNo.isNotEmpty ? serialNo : serial,
          modelName: model.isNotEmpty ? model : null,
        );
        await _storage.addDevice(newDevice);
        changed = true;
      }
    }

    if (changed) await _loadSavedDevices();
  }

  Future<void> _autoSaveIosDevices(List<IosConnectedDevice> devices) async {
    var changed = false;

    for (final device in devices) {
      final alreadySaved = _savedDevices.any(
        (d) => d.platform == DevicePlatform.ios && d.serialName == device.udid,
      );
      if (alreadySaved) continue;

      final name = device.name ?? device.udid.substring(0, 8);
      final newDevice = SavedDevice(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        nickname: name,
        ip: '',
        port: 0,
        serialName: device.udid,
        modelName: device.modelName,
        platform: DevicePlatform.ios,
      );
      await _storage.addDevice(newDevice);
      changed = true;
    }

    if (changed) await _loadSavedDevices();
  }

  bool _isDeviceConnected(SavedDevice device) {
    return _isDeviceConnectedViaUsb(device) || _isDeviceConnectedViaWifi(device);
  }

  bool _isDeviceConnectedViaUsb(SavedDevice device) {
    if (device.isIos) {
      return device.serialName != null &&
          _iosUsbUdids.contains(device.serialName);
    }
    if (device.serialName == null) return false;
    return _connectedDevices.any(
      (c) => !c.isIpConnection && c.identifier == device.serialName,
    );
  }

  bool _isDeviceConnectedViaWifi(SavedDevice device) {
    if (device.isIos) {
      return device.serialName != null &&
          _iosWifiUdids.contains(device.serialName);
    }
    return _connectedDevices.any(
      (c) => c.isIpConnection && c.ip == device.ip,
    );
  }

  Future<void> _connectDevice(SavedDevice device) async {
    setState(() => _connectingDeviceIds.add(device.id));

    try {
      final result = await _adbService.connectWithRetry(
        ip: device.ip,
        port: device.port,
        serialName: device.serialName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? Colors.green : Colors.red,
          ),
        );
        await _refreshConnectedDevices();
      }
    } finally {
      if (mounted) setState(() => _connectingDeviceIds.remove(device.id));
    }
  }

  Future<void> _switchToWireless(SavedDevice device) async {
    if (device.serialName == null || device.serialName!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('시리얼 정보가 없어 전환할 수 없습니다')),
      );
      return;
    }

    setState(() => _connectingDeviceIds.add(device.id));

    try {
      final result = await _adbService.switchToWireless(
        serial: device.serialName!,
        ip: device.ip,
        port: device.port,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? Colors.green : Colors.red,
          ),
        );
        await _refreshConnectedDevices();
      }
    } finally {
      if (mounted) setState(() => _connectingDeviceIds.remove(device.id));
    }
  }

  Future<void> _disconnectDevice(SavedDevice device) async {
    final result = await _adbService.disconnect(device.ip, device.port);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
      await _refreshConnectedDevices();
    }
  }

  Future<void> _quickConnect() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) return;
    final port = int.tryParse(_portController.text.trim()) ?? 5555;

    final result = await _adbService.connectWithRetry(ip: ip, port: port);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? Colors.green : Colors.red,
        ),
      );
      if (result.success) {
        _ipController.clear();
        await _refreshConnectedDevices();
      }
    }
  }

  Future<void> _addOrEditDevice({SavedDevice? device}) async {
    final result = await showDialog<SavedDevice>(
      context: context,
      builder: (context) => AddDeviceDialog(device: device),
    );

    if (result == null) return;

    if (device != null) {
      await _storage.updateDevice(result);
    } else {
      await _storage.addDevice(result);
    }
    await _loadSavedDevices();
  }

  // Android logcat 또는 iOS syslog 앱 내 뷰어 열기
  void _openLogcat(SavedDevice device) {
    if (device.isIos) {
      final udid = device.serialName;
      if (udid == null) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LogcatPage(
            deviceName: device.nickname,
            processFactory: () => _iosService.startSyslog(udid),
          ),
        ),
      );
      return;
    }

    // Android
    final connected = _connectedDevices.firstWhere(
      (c) {
        if (c.isIpConnection) return c.ip == device.ip;
        return c.identifier == device.serialName;
      },
      orElse: () => ConnectedDevice(identifier: '', state: ''),
    );

    if (connected.identifier.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('연결된 기기가 아닙니다')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LogcatPage(
          deviceName: device.nickname,
          processFactory: () => _adbService.startLogcat(connected.identifier),
          onClearBuffer: () => _adbService.clearLogcat(connected.identifier),
        ),
      ),
    );
  }

  // 터미널에서 logcat / syslog 열기
  Future<void> _openTerminalLogcat(
    SavedDevice device,
    LogcatPreset preset,
  ) async {
    final ts = TerminalService.instance;
    final installed = ts.installedApps();

    if (installed.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('지원하는 터미널 앱을 찾을 수 없습니다')),
      );
      return;
    }

    // iOS syslog
    if (device.isIos) {
      final udid = device.serialName;
      if (udid == null) return;

      final savedId = await ts.loadSelectedId();
      TerminalApp? selected = savedId != null ? ts.appById(savedId) : null;
      final isInstalled =
          selected != null && installed.any((a) => a.id == selected!.id);
      if (!isInstalled) {
        if (!mounted) return;
        selected = await _showTerminalPickerDialog(installed);
        if (selected == null) return;
        await ts.saveSelectedId(selected.id);
      }

      final command = _iosService.buildSyslogCommand(udid);
      await ts.runCommand(selected, command);

      if (!mounted) return;
      if (ts.consumeClipboardCopied()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${selected.name}은 직접 명령 실행을 지원하지 않아 클립보드에 복사했습니다.',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    // Android logcat
    final connected = _connectedDevices.firstWhere(
      (c) {
        if (c.isIpConnection) return c.ip == device.ip;
        return c.identifier == device.serialName;
      },
      orElse: () => ConnectedDevice(identifier: '', state: ''),
    );

    if (connected.identifier.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('연결된 기기가 아닙니다')),
      );
      return;
    }

    LogcatOptions options;
    TerminalApp? selected;

    if (preset == LogcatPreset.custom) {
      final savedId = await ts.loadSelectedId();
      final initialId =
          savedId != null && installed.any((a) => a.id == savedId)
              ? savedId
              : null;

      if (!mounted) return;
      final result = await showDialog<LogcatRunConfig>(
        context: context,
        builder: (_) => LogcatOptionsDialog(initialTerminalId: initialId),
      );
      if (result == null) return;
      options = result.options;
      selected = ts.appById(result.terminalId);
      if (selected != null) await ts.saveSelectedId(selected.id);
    } else {
      options = preset == LogcatPreset.flutter
          ? const LogcatOptions(tags: ['flutter'])
          : const LogcatOptions();

      final savedId = await ts.loadSelectedId();
      selected = savedId != null ? ts.appById(savedId) : null;

      final isInstalled =
          selected != null && installed.any((a) => a.id == selected!.id);
      if (!isInstalled) {
        if (!mounted) return;
        selected = await _showTerminalPickerDialog(installed);
        if (selected == null) return;
        await ts.saveSelectedId(selected.id);
      }
    }

    if (selected == null) return;

    final logcatArgs = [
      '-s', connected.identifier, 'logcat', ...options.toArgs(),
    ];
    final command = '${_adbService.adbPath} ${logcatArgs.join(' ')}';
    await ts.runCommand(selected, command);

    if (!mounted) return;
    if (ts.consumeClipboardCopied()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${selected.name}은 직접 명령 실행을 지원하지 않아 클립보드에 복사했습니다.',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<TerminalApp?> _showTerminalPickerDialog(List<TerminalApp> apps) {
    return showDialog<TerminalApp>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('터미널 앱 선택'),
        children: [
          for (final app in apps)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(app),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.terminal, size: 20),
                    const SizedBox(width: 12),
                    Text(app.name, style: const TextStyle(fontSize: 15)),
                  ],
                ),
              ),
            ),
          const Divider(),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  void _openFileBrowser(SavedDevice device) {
    final connected = _connectedDevices.firstWhere(
      (c) {
        if (c.isIpConnection) return c.ip == device.ip;
        return c.identifier == device.serialName;
      },
      orElse: () => ConnectedDevice(identifier: '', state: ''),
    );

    if (connected.identifier.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('연결된 기기가 아닙니다')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FileBrowserPage(
          identifier: connected.identifier,
          deviceName: device.nickname,
        ),
      ),
    );
  }

  Future<void> _deleteDevice(SavedDevice device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('기기 삭제'),
        content: Text("'${device.nickname}'을(를) 삭제하시겠습니까?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _storage.deleteDevice(device.id);
      await _loadSavedDevices();
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectedCount =
        _savedDevices.where((d) => _isDeviceConnected(d)).length;
    final disconnectedCount = _savedDevices.length - connectedCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ADB Connector'),
        actions: [
          if (disconnectedCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                avatar: Icon(Icons.link_off, size: 16, color: Colors.red.shade700),
                label: Text(
                  '미연결 $disconnectedCount',
                  style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                ),
                backgroundColor: Colors.red.shade50,
                side: BorderSide.none,
              ),
            ),
          if (connectedCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                avatar: Icon(Icons.link, size: 16, color: Colors.green.shade700),
                label: Text(
                  '연결 $connectedCount',
                  style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                ),
                backgroundColor: Colors.green.shade50,
                side: BorderSide.none,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
            onPressed: _refreshConnectedDevices,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '기기 추가',
            onPressed: () => _addOrEditDevice(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          if (!_adbAvailable) _buildAdbInstallBanner(),
          if (!_iosAvailable) _buildIosBanner(),
          Expanded(
            child: _savedDevices.isEmpty
                ? const Center(
                    child: Text(
                      '기기가 없습니다.\n기기를 연결하면 자동으로 저장됩니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 15),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _savedDevices.length,
                    itemBuilder: (context, index) {
                      final device = _savedDevices[index];
                      return DeviceListTile(
                        device: device,
                        isConnected: _isDeviceConnected(device),
                        isConnectedViaUsb: _isDeviceConnectedViaUsb(device),
                        isConnectedViaWifi: _isDeviceConnectedViaWifi(device),
                        isConnecting: _connectingDeviceIds.contains(device.id),
                        onConnect: () => _connectDevice(device),
                        onEdit: () => _addOrEditDevice(device: device),
                        onDelete: () => _deleteDevice(device),
                        onDisconnect: () => _disconnectDevice(device),
                        onLogcat: () => _openLogcat(device),
                        onFileBrowser: () => _openFileBrowser(device),
                        onTerminalLogcat: (preset) =>
                            _openTerminalLogcat(device, preset),
                        onSwitchToWireless: () => _switchToWireless(device),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          _buildQuickConnectSection(),
        ],
      ),
    );
  }

  Widget _buildIosBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.blue.shade50,
      child: Row(
        children: [
          Icon(Icons.phone_iphone, color: Colors.blue.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'iPhone/iPad 지원을 위해 libimobiledevice를 설치하세요: brew install libimobiledevice',
              style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdbInstallBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: _isInstallingAdb ? Colors.blue.shade50 : Colors.orange.shade50,
      child: Row(
        children: [
          Icon(
            _isInstallingAdb ? Icons.downloading : Icons.warning_amber,
            color: _isInstallingAdb
                ? Colors.blue.shade700
                : Colors.orange.shade700,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isInstallingAdb ? 'ADB 설치 중' : 'ADB가 설치되지 않았습니다',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  _isInstallingAdb
                      ? _installMessage
                      : '자동으로 설치하려면 "설치" 버튼을 눌러주세요',
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                if (_isInstallingAdb) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: _installProgress),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (!_isInstallingAdb)
            FilledButton.icon(
              onPressed: _installAdb,
              icon: const Icon(Icons.download, size: 18),
              label: const Text('설치'),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickConnectSection() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Text(
            '빠른 연결',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _ipController,
              decoration: const InputDecoration(
                hintText: 'IP 주소 (예: 192.168.0.100)',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onSubmitted: (_) => _quickConnect(),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: TextField(
              controller: _portController,
              decoration: const InputDecoration(
                labelText: '포트',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onSubmitted: (_) => _quickConnect(),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _quickConnect,
            child: const Text('연결'),
          ),
        ],
      ),
    );
  }
}

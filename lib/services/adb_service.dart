import 'dart:async';
import 'dart:io';

import 'package:adb_connector/models/saved_device.dart';

class ConnectResult {
  ConnectResult({required this.success, required this.message});

  factory ConnectResult.ok(String message) =>
      ConnectResult(success: true, message: message);

  factory ConnectResult.failure(String message) =>
      ConnectResult(success: false, message: message);

  final bool success;
  final String message;
}

class AdbService {
  AdbService._(this._adbPath);

  factory AdbService() {
    _instance ??= AdbService._(_resolveAdbPath());
    return _instance!;
  }

  static AdbService? _instance;
  String _adbPath;
  static const Duration timeout = Duration(seconds: 10);
  static const String downloadUrl =
      'https://dl.google.com/android/repository/platform-tools-latest-darwin.zip';

  String get adbPath => _adbPath;

  static String get _installDir {
    final home = Platform.environment['HOME'] ?? '';
    return '$home/Library/Application Support/adb_connector/platform-tools';
  }

  static String get _installedAdbPath => '$_installDir/adb';

  static List<String> get _candidatePaths {
    final home = Platform.environment['HOME'] ?? '';
    return [
      _installedAdbPath,
      '$home/Library/Android/sdk/platform-tools/adb',
      '/opt/homebrew/bin/adb',
      '/usr/local/bin/adb',
      '/usr/bin/adb',
    ];
  }

  static String _resolveAdbPath() {
    for (final path in _candidatePaths) {
      if (File(path).existsSync()) return path;
    }
    return _installedAdbPath;
  }

  bool isAdbAvailable() => File(_adbPath).existsSync();

  Future<bool> refreshAdbPath() async {
    _adbPath = _resolveAdbPath();
    return isAdbAvailable();
  }

  /// ADB 다운로드 및 설치. 진행 상황을 [onProgress]로 보고.
  /// [onProgress]는 (단계 메시지, 0.0~1.0 진행률) 전달.
  Future<bool> installAdb({
    void Function(String message, double? progress)? onProgress,
  }) async {
    try {
      onProgress?.call('설치 디렉토리 준비 중...', null);
      final parentDir = Directory(
        '${Platform.environment['HOME']}/Library/Application Support/adb_connector',
      );
      if (!await parentDir.exists()) {
        await parentDir.create(recursive: true);
      }

      final zipPath = '${parentDir.path}/platform-tools.zip';
      final zipFile = File(zipPath);

      onProgress?.call('ADB 다운로드 중...', 0);
      final client = HttpClient();
      try {
        final request = await client.getUrl(Uri.parse(downloadUrl));
        final response = await request.close();
        final totalBytes = response.contentLength;
        var downloadedBytes = 0;

        final sink = zipFile.openWrite();
        await response.forEach((chunk) {
          downloadedBytes += chunk.length;
          sink.add(chunk);
          if (totalBytes > 0) {
            onProgress?.call(
              'ADB 다운로드 중... (${(downloadedBytes / 1024 / 1024).toStringAsFixed(1)}MB)',
              downloadedBytes / totalBytes,
            );
          }
        });
        await sink.close();
      } finally {
        client.close();
      }

      onProgress?.call('압축 해제 중...', null);

      // 기존 설치 폴더 제거
      final installDir = Directory(_installDir);
      if (await installDir.exists()) {
        await installDir.delete(recursive: true);
      }

      // unzip으로 압축 해제
      final unzipResult = await Process.run(
        'unzip',
        ['-q', zipPath, '-d', parentDir.path],
      );
      if (unzipResult.exitCode != 0) {
        onProgress?.call(
          '압축 해제 실패: ${unzipResult.stderr}',
          null,
        );
        return false;
      }

      // 권한 설정
      await Process.run('chmod', ['+x', _installedAdbPath]);

      // zip 파일 삭제
      if (await zipFile.exists()) {
        await zipFile.delete();
      }

      onProgress?.call('설치 완료', 1.0);

      // 경로 갱신
      _adbPath = _installedAdbPath;
      return isAdbAvailable();
    } catch (e) {
      onProgress?.call('설치 실패: $e', null);
      return false;
    }
  }

  Future<ProcessResult> _run(List<String> args) async {
    if (!isAdbAvailable()) {
      return ProcessResult(0, 1, '', 'ADB not installed');
    }
    try {
      return await Process.run(_adbPath, args).timeout(timeout);
    } on TimeoutException {
      return ProcessResult(0, 1, '', 'Command timed out');
    }
  }

  Future<List<ConnectedDevice>> getConnectedDevices() async {
    final result = await _run(['devices']);
    final output = result.stdout as String;
    final lines = output.split('\n');
    final devices = <ConnectedDevice>[];

    for (final line in lines) {
      if (line.startsWith('List of devices') || line.trim().isEmpty) continue;
      final parts = line.split('\t');
      if (parts.length >= 2) {
        devices.add(
          ConnectedDevice(identifier: parts[0].trim(), state: parts[1].trim()),
        );
      }
    }

    // 모델명 조회
    for (final device in devices) {
      try {
        final model = await getDeviceModel(device.identifier);
        if (model.isNotEmpty) {
          device.modelName = model;
        }
      } catch (_) {
        // 모델명 조회 실패 무시
      }
    }

    return devices;
  }

  Future<ConnectResult> connect(String ip, int port) async {
    final target = '$ip:$port';
    final result = await _run(['connect', target]);
    final output = (result.stdout as String).trim();

    if (output.contains('connected to') ||
        output.contains('already connected')) {
      return ConnectResult.ok('연결 성공: $target');
    }

    return ConnectResult.failure(output);
  }

  Future<bool> enableTcpip(String serial, int port) async {
    final result = await _run(['-s', serial, 'tcpip', port.toString()]);
    final output = (result.stdout as String).trim();
    return output.contains('restarting in TCP mode');
  }

  Future<String> getDeviceModel(String serial) async {
    final result = await _run([
      '-s',
      serial,
      'shell',
      'getprop',
      'ro.product.model',
    ]);
    return (result.stdout as String).trim();
  }

  Future<String> getDeviceSerial(String serial) async {
    final result = await _run([
      '-s',
      serial,
      'shell',
      'getprop',
      'ro.serialno',
    ]);
    return (result.stdout as String).trim();
  }

  Future<String?> getDeviceIp(String serial) async {
    final result = await _run([
      '-s',
      serial,
      'shell',
      'ip',
      'addr',
      'show',
      'wlan0',
    ]);
    final output = result.stdout as String;
    final regex = RegExp(r'inet (\d+\.\d+\.\d+\.\d+)/');
    final match = regex.firstMatch(output);
    return match?.group(1);
  }

  Future<ConnectResult> disconnect(String ip, int port) async {
    final target = '$ip:$port';
    final result = await _run(['disconnect', target]);
    final output = (result.stdout as String).trim();

    if (output.contains('disconnected')) {
      return ConnectResult.ok('연결 해제: $target');
    }
    return ConnectResult.failure(output);
  }

  /// USB 연결된 기기를 WiFi 연결로 전환.
  /// 1. IP 조회 (명시적 IP가 없으면)
  /// 2. tcpip 모드로 전환
  /// 3. WiFi로 연결
  Future<ConnectResult> switchToWireless({
    required String serial,
    String? ip,
    int port = 5555,
  }) async {
    // IP 조회
    final targetIp = ip ?? await getDeviceIp(serial);
    if (targetIp == null || targetIp.isEmpty) {
      return ConnectResult.failure(
        'IP 주소를 찾을 수 없습니다. 기기가 WiFi에 연결되어 있는지 확인해주세요',
      );
    }

    // tcpip 모드로 전환
    final tcpipOk = await enableTcpip(serial, port);
    if (!tcpipOk) {
      return ConnectResult.failure('tcpip 모드 전환 실패');
    }

    // 기기가 TCP 모드로 재시작할 시간 대기
    await Future<void>.delayed(const Duration(seconds: 2));

    // 연결 시도
    final result = await connect(targetIp, port);
    if (result.success) {
      return ConnectResult.ok('WiFi 연결 성공: $targetIp:$port');
    }
    return ConnectResult.failure(
      'WiFi 연결 실패 - 기기가 같은 WiFi에 있는지 확인해주세요',
    );
  }

  /// logcat을 실시간으로 스트리밍. [identifier]는 시리얼 또는 "ip:port".
  /// 반환된 Process를 kill()하면 스트리밍이 중단됩니다.
  Future<Process> startLogcat(String identifier) async {
    return Process.start(_adbPath, [
      '-s',
      identifier,
      'logcat',
      '-v',
      'threadtime',
      '-T',
      '1',
    ]);
  }

  /// 기기의 logcat 버퍼를 비움.
  Future<void> clearLogcat(String identifier) async {
    await _run(['-s', identifier, 'logcat', '-c']);
  }

  Future<ConnectResult> connectWithRetry({
    required String ip,
    int port = 5555,
    String? serialName,
  }) async {
    // 1단계: 바로 연결 시도
    final result1 = await connect(ip, port);
    if (result1.success) return result1;

    // 2단계: serial이 있으면 tcpip 초기화 후 재시도
    if (serialName != null && serialName.isNotEmpty) {
      await enableTcpip(serialName, port);
      await Future<void>.delayed(const Duration(seconds: 2));
      final result2 = await connect(ip, port);
      if (result2.success) return result2;
    }

    // 3단계: 실패
    return ConnectResult.failure('연결 실패 - 기기가 같은 WiFi에 있는지 확인해주세요');
  }
}

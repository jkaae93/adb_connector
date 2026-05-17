import 'package:adb_connector/models/saved_device.dart';
import 'package:flutter/material.dart';

class DeviceListTile extends StatelessWidget {
  const DeviceListTile({
    super.key,
    required this.device,
    required this.isConnected,
    required this.isConnectedViaUsb,
    required this.isConnectedViaWifi,
    required this.isConnecting,
    required this.onConnect,
    required this.onEdit,
    required this.onDelete,
    required this.onDisconnect,
    required this.onLogcat,
    required this.onSwitchToWireless,
  });

  final SavedDevice device;
  final bool isConnected;
  final bool isConnectedViaUsb;
  final bool isConnectedViaWifi;
  final bool isConnecting;
  final VoidCallback onConnect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDisconnect;
  final VoidCallback onLogcat;
  final VoidCallback onSwitchToWireless;

  String get _statusLabel {
    if (isConnectedViaUsb && isConnectedViaWifi) return 'USB+WiFi';
    if (isConnectedViaUsb) return 'USB';
    if (isConnectedViaWifi) return 'WiFi';
    return '미연결';
  }

  Color _statusBgColor() {
    if (isConnectedViaUsb && !isConnectedViaWifi) return Colors.orange.shade100;
    if (isConnectedViaWifi) return Colors.green.shade100;
    return Colors.red.shade50;
  }

  Color _statusFgColor() {
    if (isConnectedViaUsb && !isConnectedViaWifi) return Colors.orange.shade900;
    if (isConnectedViaWifi) return Colors.green.shade800;
    return Colors.red.shade700;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          Icons.phone_android,
          color: isConnected ? Colors.green : Colors.grey,
          size: 32,
        ),
        title: Row(
          children: [
            Text(
              device.nickname,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: _statusBgColor(),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _statusLabel,
                style: TextStyle(
                  fontSize: 11,
                  color: _statusFgColor(),
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          [
            '${device.ip}:${device.port}',
            if (device.modelName != null) device.modelName!,
            if (device.serialName != null) device.serialName!,
          ].join(' | '),
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isConnecting)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (isConnectedViaUsb && !isConnectedViaWifi)
              FilledButton.icon(
                onPressed: onSwitchToWireless,
                icon: const Icon(Icons.wifi, size: 16),
                label: const Text('WiFi로 전환'),
              )
            else if (isConnectedViaWifi)
              TextButton(
                onPressed: onDisconnect,
                child: const Text('연결 해제'),
              )
            else
              FilledButton(
                onPressed: onConnect,
                child: const Text('연결'),
              ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.description_outlined, size: 20),
              onPressed: isConnected ? onLogcat : null,
              tooltip: isConnected ? 'Logcat 보기' : '연결 후 사용 가능',
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: onEdit,
              tooltip: '수정',
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20),
              onPressed: onDelete,
              tooltip: '삭제',
            ),
          ],
        ),
      ),
    );
  }
}

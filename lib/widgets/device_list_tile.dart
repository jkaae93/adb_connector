import 'package:adb_connector/models/saved_device.dart';
import 'package:flutter/material.dart';

class DeviceListTile extends StatelessWidget {
  const DeviceListTile({
    super.key,
    required this.device,
    required this.isConnected,
    required this.isConnecting,
    required this.onConnect,
    required this.onEdit,
    required this.onDelete,
    required this.onDisconnect,
  });

  final SavedDevice device;
  final bool isConnected;
  final bool isConnecting;
  final VoidCallback onConnect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDisconnect;

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
                color: isConnected
                    ? Colors.green.shade100
                    : Colors.red.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isConnected ? '연결됨' : '미연결',
                style: TextStyle(
                  fontSize: 11,
                  color: isConnected
                      ? Colors.green.shade800
                      : Colors.red.shade700,
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
            else if (isConnected)
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

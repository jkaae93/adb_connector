import 'package:adb_connector/models/saved_device.dart';
import 'package:flutter/material.dart';

class AddDeviceDialog extends StatefulWidget {
  const AddDeviceDialog({super.key, this.device});

  final SavedDevice? device;

  @override
  State<AddDeviceDialog> createState() => _AddDeviceDialogState();
}

class _AddDeviceDialogState extends State<AddDeviceDialog> {
  late final TextEditingController _nicknameController;
  late final TextEditingController _ipController;
  late final TextEditingController _portController;
  late final TextEditingController _serialController;
  late final TextEditingController _modelController;

  bool get isEditing => widget.device != null;

  @override
  void initState() {
    super.initState();
    _nicknameController =
        TextEditingController(text: widget.device?.nickname ?? '');
    _ipController = TextEditingController(text: widget.device?.ip ?? '');
    _portController = TextEditingController(
      text: (widget.device?.port ?? 5555).toString(),
    );
    _serialController =
        TextEditingController(text: widget.device?.serialName ?? '');
    _modelController =
        TextEditingController(text: widget.device?.modelName ?? '');
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _ipController.dispose();
    _portController.dispose();
    _serialController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(isEditing ? '기기 수정' : '기기 추가'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nicknameController,
              decoration: const InputDecoration(
                labelText: '별명',
                hintText: '예: 테스트폰',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(
                labelText: 'IP 주소',
                hintText: '예: 192.168.0.100',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _portController,
              decoration: const InputDecoration(
                labelText: '포트',
                hintText: '5555',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _serialController,
              decoration: const InputDecoration(
                labelText: '시리얼 (선택)',
                hintText: '예: R5CX12M8YWZ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _modelController,
              decoration: const InputDecoration(
                labelText: '모델명 (선택)',
                hintText: '예: SM-A256N',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _onSave,
          child: const Text('저장'),
        ),
      ],
    );
  }

  void _onSave() {
    final nickname = _nicknameController.text.trim();
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 5555;
    final serial = _serialController.text.trim();
    final model = _modelController.text.trim();

    if (nickname.isEmpty || ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('별명과 IP 주소는 필수입니다')),
      );
      return;
    }

    final device = SavedDevice(
      id: widget.device?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      nickname: nickname,
      ip: ip,
      port: port,
      serialName: serial.isNotEmpty ? serial : null,
      modelName: model.isNotEmpty ? model : null,
    );

    Navigator.of(context).pop(device);
  }
}

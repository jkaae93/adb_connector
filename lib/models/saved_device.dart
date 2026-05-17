class SavedDevice {
  SavedDevice({
    required this.id,
    required this.nickname,
    required this.ip,
    this.port = 5555,
    this.serialName,
    this.modelName,
  });

  factory SavedDevice.fromJson(Map<String, dynamic> json) {
    return SavedDevice(
      id: json['id'] as String,
      nickname: json['nickname'] as String,
      ip: json['ip'] as String,
      port: json['port'] as int? ?? 5555,
      serialName: json['serialName'] as String?,
      modelName: json['modelName'] as String?,
    );
  }

  final String id;
  String nickname;
  String ip;
  int port;
  String? serialName;
  String? modelName;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nickname': nickname,
      'ip': ip,
      'port': port,
      'serialName': serialName,
      'modelName': modelName,
    };
  }

  SavedDevice copyWith({
    String? nickname,
    String? ip,
    int? port,
    String? serialName,
    String? modelName,
  }) {
    return SavedDevice(
      id: id,
      nickname: nickname ?? this.nickname,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      serialName: serialName ?? this.serialName,
      modelName: modelName ?? this.modelName,
    );
  }
}

class ConnectedDevice {
  ConnectedDevice({
    required this.identifier,
    required this.state,
    this.modelName,
  });

  final String identifier;
  final String state;
  String? modelName;

  bool get isIpConnection => identifier.contains(':');

  String? get ip {
    if (!isIpConnection) return null;
    return identifier.split(':').first;
  }

  int? get port {
    if (!isIpConnection) return null;
    final parts = identifier.split(':');
    if (parts.length < 2) return null;
    return int.tryParse(parts[1]);
  }
}

class RemoteFileEntry {
  RemoteFileEntry({
    required this.name,
    required this.isDirectory,
    required this.size,
    required this.permissions,
    required this.date,
    this.isSymlink = false,
    this.symlinkTarget,
  });

  final String name;
  final bool isDirectory;
  final bool isSymlink;
  final String? symlinkTarget;
  final int size;
  final String permissions;
  final String date;

  static RemoteFileEntry? parse(String line) {
    if (line.startsWith('total ') || line.trim().isEmpty) return null;

    final trimmed = line.trim();
    if (trimmed.isEmpty) return null;

    // Android ls -la 형식:
    // drwxr-xr-x 2 root root 4096 2024-01-01 00:00 dirname
    // -rw-r--r-- 1 root root 1234 2024-01-01 00:00 filename
    // lrwxrwxrwx 1 root root   11 2024-01-01 00:00 link -> target
    final regex = RegExp(
      r'^([dlcrpsbD-][rwxsStT-]{9})\s+\d+\s+\S+\s+\S+\s+(\d+)\s+(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2})\s+(.+)$',
    );

    final match = regex.firstMatch(trimmed);
    if (match == null) return null;

    final perms = match.group(1)!;
    final size = int.tryParse(match.group(2)!) ?? 0;
    final date = match.group(3)!;
    var namePart = match.group(4)!;

    final isDir = perms.startsWith('d');
    final isLink = perms.startsWith('l');
    String? symlinkTarget;

    if (isLink && namePart.contains(' -> ')) {
      final parts = namePart.split(' -> ');
      namePart = parts[0];
      symlinkTarget = parts.sublist(1).join(' -> ');
    }

    if (namePart == '.' || namePart == '..') return null;

    return RemoteFileEntry(
      name: namePart,
      isDirectory: isDir || isLink,
      isSymlink: isLink,
      symlinkTarget: symlinkTarget,
      size: size,
      permissions: perms,
      date: date,
    );
  }

  String get sizeLabel {
    if (isDirectory) return '';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(size / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }
}

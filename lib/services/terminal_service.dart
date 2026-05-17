import 'dart:convert';
import 'dart:io';

class TerminalApp {
  const TerminalApp({
    required this.id,
    required this.name,
    required this.appDirNames,
  });

  final String id;
  final String name;
  // /Applications, ~/Applications, /System/Applications 에서 탐색할 .app 이름 목록
  final List<String> appDirNames;
}

class TerminalService {
  TerminalService._();

  static final TerminalService instance = TerminalService._();

  static const List<TerminalApp> supported = [
    TerminalApp(id: 'terminal', name: 'Terminal', appDirNames: ['Terminal']),
    TerminalApp(id: 'iterm2', name: 'iTerm2', appDirNames: ['iTerm', 'iTerm2']),
    TerminalApp(id: 'warp', name: 'Warp', appDirNames: ['Warp']),
    TerminalApp(id: 'alacritty', name: 'Alacritty', appDirNames: ['Alacritty']),
    TerminalApp(id: 'kitty', name: 'kitty', appDirNames: ['kitty']),
    TerminalApp(id: 'ghostty', name: 'Ghostty', appDirNames: ['Ghostty']),
    TerminalApp(id: 'hyper', name: 'Hyper', appDirNames: ['Hyper']),
  ];

  static List<String> get _searchRoots {
    final home = Platform.environment['HOME'] ?? '';
    return [
      '/Applications',
      '$home/Applications',
      '/System/Applications',
      '/System/Applications/Utilities',
    ];
  }

  String? _findAppPath(TerminalApp app) {
    for (final root in _searchRoots) {
      for (final dirName in app.appDirNames) {
        final path = '$root/$dirName.app';
        if (Directory(path).existsSync()) return path;
      }
    }
    return null;
  }

  List<TerminalApp> installedApps() =>
      supported.where((a) => _findAppPath(a) != null).toList();

  static File get _prefsFile {
    final home = Platform.environment['HOME'] ?? '';
    return File(
      '$home/Library/Application Support/adb_connector/terminal_prefs.json',
    );
  }

  String? _cachedSelectedId;

  Future<String?> loadSelectedId() async {
    if (_cachedSelectedId != null) return _cachedSelectedId;
    try {
      final f = _prefsFile;
      if (!await f.exists()) return null;
      final map = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      _cachedSelectedId = map['terminal_id'] as String?;
      return _cachedSelectedId;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSelectedId(String id) async {
    _cachedSelectedId = id;
    final f = _prefsFile;
    await f.parent.create(recursive: true);
    await f.writeAsString(jsonEncode({'terminal_id': id}));
  }

  TerminalApp? appById(String id) {
    try {
      return supported.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> runCommand(TerminalApp app, String command) async {
    switch (app.id) {
      case 'terminal':
        await Process.run('osascript', [
          '-e',
          'tell application "Terminal" to do script "$command"',
          '-e',
          'tell application "Terminal" to activate',
        ]);
      case 'iterm2':
        await Process.run('osascript', [
          '-e',
          'tell application "iTerm" to create window with default profile command "$command"',
          '-e',
          'tell application "iTerm" to activate',
        ]);
      case 'warp':
        // Warp은 AppleScript로 명령 직접 실행 불가 → 클립보드에 복사 후 앱 오픈
        await _copyToClipboard(command);
        await Process.run('open', ['-a', 'Warp']);
        _warpCopied = true;
      case 'alacritty':
        final appPath = _findAppPath(app)!;
        await Process.run(
          '$appPath/Contents/MacOS/alacritty',
          ['-e', 'bash', '-c', '$command; exec bash'],
        );
      case 'kitty':
        final appPath = _findAppPath(app)!;
        await Process.run(
          '$appPath/Contents/MacOS/kitty',
          ['bash', '-c', '$command; exec bash'],
        );
      case 'ghostty':
        await Process.run('open', ['-a', 'Ghostty', '--args', command]);
      default:
        // 나머지는 클립보드 복사 후 앱 열기
        await _copyToClipboard(command);
        final appPath = _findAppPath(app);
        if (appPath != null) await Process.run('open', [appPath]);
        _warpCopied = true;
    }
  }

  Future<void> _copyToClipboard(String text) async {
    final process = await Process.start('pbcopy', []);
    process.stdin.write(text);
    await process.stdin.close();
    await process.exitCode;
  }

  bool _warpCopied = false;

  bool consumeClipboardCopied() {
    final v = _warpCopied;
    _warpCopied = false;
    return v;
  }
}

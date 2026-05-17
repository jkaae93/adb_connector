import 'package:adb_connector/models/remote_file_entry.dart';
import 'package:adb_connector/services/adb_service.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class FileBrowserPage extends StatefulWidget {
  const FileBrowserPage({
    super.key,
    required this.identifier,
    required this.deviceName,
  });

  final String identifier;
  final String deviceName;

  @override
  State<FileBrowserPage> createState() => _FileBrowserPageState();
}

class _FileBrowserPageState extends State<FileBrowserPage> {
  final AdbService _adbService = AdbService();
  final List<String> _pathStack = ['/'];
  List<RemoteFileEntry> _entries = [];
  bool _isLoading = false;
  String? _errorMessage;
  final Set<String> _transferring = {};
  bool _isDragOver = false;

  String get _currentPath => _pathStack.join('/').replaceAll('//', '/');

  @override
  void initState() {
    super.initState();
    _loadDirectory(_currentPath);
  }

  Future<void> _loadDirectory(String path) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final entries = await _adbService.listFiles(widget.identifier, path);
      entries.sort((a, b) {
        if (a.isDirectory && !b.isDirectory) return -1;
        if (!a.isDirectory && b.isDirectory) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      if (mounted) {
        setState(() {
          _entries = entries;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '목록을 불러올 수 없습니다: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _navigateTo(String dirName) {
    if (dirName == '..') {
      if (_pathStack.length > 1) _pathStack.removeLast();
    } else {
      _pathStack.add(dirName);
    }
    _loadDirectory(_currentPath);
  }

  Future<void> _uploadLocalPaths(List<String> localPaths) async {
    var anySuccess = false;
    for (final localPath in localPaths) {
      final fileName = localPath.split('/').last;
      final remotePath = '$_currentPath/$fileName'.replaceAll('//', '/');

      setState(() => _transferring.add(remotePath));
      try {
        final ok = await _adbService.pushFile(
          widget.identifier,
          localPath,
          remotePath,
        );
        if (ok) anySuccess = true;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(ok ? '업로드 완료: $fileName' : '업로드 실패: $fileName'),
              backgroundColor: ok ? Colors.green : Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _transferring.remove(remotePath));
      }
    }
    if (anySuccess && mounted) await _loadDirectory(_currentPath);
  }

  Future<void> _downloadEntry(RemoteFileEntry entry) async {
    final remotePath = '$_currentPath/${entry.name}'.replaceAll('//', '/');
    final key = remotePath;

    final saveDir = await FilePicker.getDirectoryPath(
      dialogTitle: '저장할 폴더 선택',
    );
    if (saveDir == null) return;

    final localPath = '$saveDir/${entry.name}';

    setState(() => _transferring.add(key));
    try {
      final ok = await _adbService.pullFile(
        widget.identifier,
        remotePath,
        localPath,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? '다운로드 완료: $localPath' : '다운로드 실패'),
            backgroundColor: ok ? Colors.green : Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _transferring.remove(key));
    }
  }

  Future<void> _uploadWithPicker() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      dialogTitle: '업로드할 파일 선택',
    );
    if (result == null || result.files.isEmpty) return;

    final paths = result.files
        .map((f) => f.path)
        .whereType<String>()
        .toList();
    if (paths.isEmpty) return;

    await _uploadLocalPaths(paths);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.deviceName),
            Text(
              _currentPath,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: '파일 업로드',
            onPressed: _uploadWithPicker,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
            onPressed: () => _loadDirectory(_currentPath),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildBreadcrumb(),
          const Divider(height: 1),
          Expanded(
            child: DropTarget(
              onDragEntered: (_) => setState(() => _isDragOver = true),
              onDragExited: (_) => setState(() => _isDragOver = false),
              onDragDone: (details) {
                setState(() => _isDragOver = false);
                final paths =
                    details.files.map((f) => f.path).toList();
                if (paths.isNotEmpty) _uploadLocalPaths(paths);
              },
              child: Stack(
                children: [
                  _buildBody(),
                  if (_isDragOver) _buildDropOverlay(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropOverlay() {
    return Container(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.upload_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              '$_currentPath 에 업로드',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreadcrumb() {
    return Container(
      height: 36,
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _pathStack.length,
        separatorBuilder: (_, __) =>
            const Icon(Icons.chevron_right, size: 16),
        itemBuilder: (context, index) {
          final label = index == 0 ? '/' : _pathStack[index];
          final isLast = index == _pathStack.length - 1;
          return Center(
            child: InkWell(
              onTap: isLast
                  ? null
                  : () {
                      _pathStack.removeRange(
                        index + 1,
                        _pathStack.length,
                      );
                      _loadDirectory(_currentPath);
                    },
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        isLast ? FontWeight.bold : FontWeight.normal,
                    color: isLast
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _loadDirectory(_currentPath),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (_entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open,
                size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            const Text(
              '폴더가 비어 있습니다\n파일을 드래그해서 업로드할 수 있습니다',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _entries.length + (_pathStack.length > 1 ? 1 : 0),
      itemBuilder: (context, index) {
        if (_pathStack.length > 1 && index == 0) {
          return ListTile(
            leading: const Icon(Icons.arrow_upward, size: 20),
            title: const Text('..'),
            dense: true,
            onTap: () => _navigateTo('..'),
          );
        }
        final entry =
            _entries[index - (_pathStack.length > 1 ? 1 : 0)];
        return _buildEntryTile(entry);
      },
    );
  }

  Widget _buildEntryTile(RemoteFileEntry entry) {
    final remotePath =
        '$_currentPath/${entry.name}'.replaceAll('//', '/');
    final isTransferring = _transferring.contains(remotePath);

    return ListTile(
      leading: Icon(
        entry.isDirectory
            ? (entry.isSymlink ? Icons.folder_special : Icons.folder)
            : _fileIcon(entry.name),
        color:
            entry.isDirectory ? Colors.amber.shade700 : Colors.blueGrey,
        size: 24,
      ),
      title: Text(
        entry.name,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: entry.isSymlink ? Colors.teal : null,
        ),
      ),
      subtitle: entry.isDirectory
          ? (entry.isSymlink
              ? Text(
                  '-> ${entry.symlinkTarget}',
                  style: const TextStyle(fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                )
              : null)
          : Text(
              '${entry.sizeLabel}  ${entry.date}',
              style: const TextStyle(fontSize: 11),
            ),
      trailing: isTransferring
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : IconButton(
              icon: Icon(
                entry.isDirectory
                    ? Icons.download
                    : Icons.download_outlined,
                size: 20,
              ),
              tooltip: '다운로드',
              onPressed: () => _downloadEntry(entry),
            ),
      onTap: entry.isDirectory ? () => _navigateTo(entry.name) : null,
      dense: true,
    );
  }

  IconData _fileIcon(String name) {
    final ext =
        name.contains('.') ? name.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'apk':
        return Icons.android;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return Icons.image;
      case 'mp4':
      case 'mkv':
      case 'avi':
      case 'mov':
        return Icons.video_file;
      case 'mp3':
      case 'aac':
      case 'wav':
      case 'flac':
        return Icons.audio_file;
      case 'zip':
      case 'tar':
      case 'gz':
      case 'rar':
        return Icons.folder_zip;
      case 'txt':
      case 'log':
      case 'xml':
      case 'json':
        return Icons.description;
      default:
        return Icons.insert_drive_file;
    }
  }
}

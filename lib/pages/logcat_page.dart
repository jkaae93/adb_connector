import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:adb_connector/services/adb_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LogLine {
  LogLine({
    required this.raw,
    required this.priority,
    required this.tag,
  });

  final String raw;
  final String priority; // V, D, I, W, E, F
  final String tag;

  static LogLine parse(String raw) {
    // threadtime format:
    // 05-08 11:28:00.000  1234  5678 I TAG     : message
    final regex = RegExp(
      r'^\d+-\d+\s+\d+:\d+:\d+\.\d+\s+\d+\s+\d+\s+([VDIWEF])\s+([^:]+):',
    );
    final match = regex.firstMatch(raw);
    return LogLine(
      raw: raw,
      priority: match?.group(1) ?? '',
      tag: match?.group(2)?.trim() ?? '',
    );
  }
}

class LogcatPage extends StatefulWidget {
  const LogcatPage({
    super.key,
    required this.identifier,
    required this.deviceName,
  });

  final String identifier;
  final String deviceName;

  @override
  State<LogcatPage> createState() => _LogcatPageState();
}

class _LogcatPageState extends State<LogcatPage> {
  final AdbService _adbService = AdbService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _filterController = TextEditingController();

  final List<LogLine> _logs = [];
  static const int _maxLogs = 5000;

  Process? _process;
  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;

  bool _isPaused = false;
  bool _autoScroll = true;
  String _filterText = '';
  final Set<String> _priorityFilter = {'V', 'D', 'I', 'W', 'E', 'F'};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _startLogcat();
  }

  @override
  void dispose() {
    _stopLogcat();
    _scrollController.dispose();
    _filterController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final atBottom = _scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 50;
    if (_autoScroll != atBottom) {
      setState(() => _autoScroll = atBottom);
    }
  }

  Future<void> _startLogcat() async {
    try {
      _process = await _adbService.startLogcat(widget.identifier);
      _stdoutSub = _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_onLogLine);
      _stderrSub = _process!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_onLogLine);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('logcat 실행 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _stopLogcat() {
    _stdoutSub?.cancel();
    _stderrSub?.cancel();
    _process?.kill();
    _process = null;
  }

  void _onLogLine(String line) {
    if (_isPaused) return;
    if (line.isEmpty) return;

    final log = LogLine.parse(line);
    setState(() {
      _logs.add(log);
      if (_logs.length > _maxLogs) {
        _logs.removeRange(0, _logs.length - _maxLogs);
      }
    });

    if (_autoScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(
            _scrollController.position.maxScrollExtent,
          );
        }
      });
    }
  }

  void _togglePause() {
    setState(() => _isPaused = !_isPaused);
  }

  void _clearLogs() {
    setState(() => _logs.clear());
  }

  Future<void> _clearDeviceBuffer() async {
    await _adbService.clearLogcat(widget.identifier);
    setState(() => _logs.clear());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('기기 logcat 버퍼를 비웠습니다')),
      );
    }
  }

  void _copyAll() {
    final text = _filteredLogs.map((l) => l.raw).join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_filteredLogs.length}줄 복사됨')),
    );
  }

  void _togglePriority(String p) {
    setState(() {
      if (_priorityFilter.contains(p)) {
        _priorityFilter.remove(p);
      } else {
        _priorityFilter.add(p);
      }
    });
  }

  List<LogLine> get _filteredLogs {
    return _logs.where((log) {
      if (log.priority.isNotEmpty &&
          !_priorityFilter.contains(log.priority)) {
        return false;
      }
      if (_filterText.isNotEmpty &&
          !log.raw.toLowerCase().contains(_filterText.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
  }

  Color _colorForPriority(String p) {
    switch (p) {
      case 'V':
        return Colors.grey.shade600;
      case 'D':
        return Colors.blue.shade700;
      case 'I':
        return Colors.green.shade700;
      case 'W':
        return Colors.orange.shade800;
      case 'E':
        return Colors.red.shade700;
      case 'F':
        return Colors.purple.shade900;
      default:
        return Colors.black87;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredLogs;

    return Scaffold(
      appBar: AppBar(
        title: Text('Logcat - ${widget.deviceName}'),
        actions: [
          IconButton(
            icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
            tooltip: _isPaused ? '재개' : '일시정지',
            onPressed: _togglePause,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: '화면 비우기',
            onPressed: _clearLogs,
          ),
          IconButton(
            icon: const Icon(Icons.cleaning_services),
            tooltip: '기기 버퍼 비우기',
            onPressed: _clearDeviceBuffer,
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: '전체 복사',
            onPressed: _copyAll,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          const Divider(height: 1),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      '로그가 없습니다',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : Scrollbar(
                    controller: _scrollController,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final log = filtered[index];
                        return SelectableText(
                          log.raw,
                          style: TextStyle(
                            fontFamily: 'Menlo',
                            fontSize: 12,
                            color: _colorForPriority(log.priority),
                            height: 1.3,
                          ),
                        );
                      },
                    ),
                  ),
          ),
          _buildStatusBar(filtered.length),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _filterController,
              decoration: InputDecoration(
                hintText: '검색 필터 (태그, 메시지 등)',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: const OutlineInputBorder(),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                suffixIcon: _filterText.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _filterController.clear();
                          setState(() => _filterText = '');
                        },
                      ),
              ),
              onChanged: (v) => setState(() => _filterText = v),
            ),
          ),
          const SizedBox(width: 12),
          ...['V', 'D', 'I', 'W', 'E', 'F'].map(
            (p) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: FilterChip(
                label: Text(p),
                labelStyle: TextStyle(
                  color: _priorityFilter.contains(p)
                      ? _colorForPriority(p)
                      : Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                selected: _priorityFilter.contains(p),
                onSelected: (_) => _togglePriority(p),
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar(int filteredCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: Colors.grey.shade100,
      child: Row(
        children: [
          if (_isPaused)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '일시정지',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.orange.shade900,
                ),
              ),
            )
          else
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '실시간',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.green.shade900,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 12),
          Text(
            '$filteredCount / ${_logs.length}',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade700,
            ),
          ),
          const Spacer(),
          if (!_autoScroll)
            TextButton.icon(
              onPressed: () {
                setState(() => _autoScroll = true);
                if (_scrollController.hasClients) {
                  _scrollController.jumpTo(
                    _scrollController.position.maxScrollExtent,
                  );
                }
              },
              icon: const Icon(Icons.arrow_downward, size: 16),
              label: const Text('맨 아래로', style: TextStyle(fontSize: 11)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
        ],
      ),
    );
  }
}

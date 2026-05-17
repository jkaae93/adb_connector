import 'package:adb_connector/models/logcat_options.dart';
import 'package:adb_connector/services/terminal_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LogcatOptionsDialog extends StatefulWidget {
  const LogcatOptionsDialog({super.key, this.initialTerminalId});

  final String? initialTerminalId;

  @override
  State<LogcatOptionsDialog> createState() => _LogcatOptionsDialogState();
}

class _LogcatOptionsDialogState extends State<LogcatOptionsDialog> {
  static const _formats = [
    'color', 'threadtime', 'time', 'brief', 'tag', 'raw', 'long',
  ];

  static const _suggestedTags = [
    'flutter', 'System.err', 'ActivityManager', 'AndroidRuntime',
    'chromium', 'dalvikvm', 'OpenGLRenderer',
  ];

  static const _bufferOptions = ['main', 'system', 'crash', 'events', 'all'];

  String _format = 'color';
  final List<String> _tags = [];
  final List<String> _buffers = [];
  final TextEditingController _tagInputController = TextEditingController();
  final TextEditingController _regexController = TextEditingController();
  final TextEditingController _maxLinesController = TextEditingController();

  late List<TerminalApp> _installedApps;
  String? _selectedTerminalId;

  @override
  void initState() {
    super.initState();
    _installedApps = TerminalService.instance.installedApps();
    _selectedTerminalId = widget.initialTerminalId ??
        (_installedApps.isNotEmpty ? _installedApps.first.id : null);
  }

  @override
  void dispose() {
    _tagInputController.dispose();
    _regexController.dispose();
    _maxLinesController.dispose();
    super.dispose();
  }

  void _addTag(String tag) {
    final t = tag.trim();
    if (t.isEmpty || _tags.contains(t)) return;
    setState(() {
      _tags.add(t);
      _tagInputController.clear();
    });
  }

  void _addBuffer(String? buffer) {
    if (buffer == null || _buffers.contains(buffer)) return;
    setState(() => _buffers.add(buffer));
  }

  LogcatOptions _buildOptions() => LogcatOptions(
        format: _format,
        tags: List.unmodifiable(_tags),
        buffers: List.unmodifiable(_buffers),
        regexFilter: _regexController.text.trim().isEmpty
            ? null
            : _regexController.text.trim(),
        maxLines: int.tryParse(_maxLinesController.text.trim()),
      );

  String get _previewCommand {
    final args = ['logcat', ..._buildOptions().toArgs()];
    return args.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Logcat 설정'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 미리보기
              _PreviewBanner(command: _previewCommand),
              const SizedBox(height: 16),

              // 터미널 앱 선택
              if (_installedApps.isNotEmpty) ...[
                _SectionLabel('터미널 앱'),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _selectedTerminalId,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: Icon(Icons.terminal, size: 18),
                  ),
                  items: _installedApps
                      .map(
                        (a) => DropdownMenuItem(
                          value: a.id,
                          child: Text(a.name),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedTerminalId = v),
                ),
                const SizedBox(height: 16),
              ],

              // 출력 형식
              _SectionLabel('출력 형식 (-v)'),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _format,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: _formats
                    .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                    .toList(),
                onChanged: (v) => setState(() => _format = v!),
              ),
              const SizedBox(height: 16),

              // Tag 필터
              _SectionLabel('Tag 필터 (-s)'),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        hintText: '태그 선택 또는 직접 입력',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _suggestedTags
                          .map(
                            (t) => DropdownMenuItem(value: t, child: Text(t)),
                          )
                          .toList(),
                      onChanged: (v) { if (v != null) _addTag(v); },
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 130,
                    child: TextField(
                      controller: _tagInputController,
                      decoration: const InputDecoration(
                        hintText: '직접 입력',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: _addTag,
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: '추가',
                    onPressed: () => _addTag(_tagInputController.text),
                  ),
                ],
              ),
              if (_tags.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: _tags
                      .map(
                        (t) => Chip(
                          label: Text(t, style: const TextStyle(fontSize: 12)),
                          deleteIcon: const Icon(Icons.close, size: 14),
                          onDeleted: () => setState(() => _tags.remove(t)),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 16),

              // 버퍼
              _SectionLabel('버퍼 (-b)'),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        hintText: '버퍼 추가',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _bufferOptions
                          .map(
                            (b) => DropdownMenuItem(value: b, child: Text(b)),
                          )
                          .toList(),
                      onChanged: _addBuffer,
                    ),
                  ),
                ],
              ),
              if (_buffers.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: _buffers
                      .map(
                        (b) => Chip(
                          label: Text(b, style: const TextStyle(fontSize: 12)),
                          deleteIcon: const Icon(Icons.close, size: 14),
                          onDeleted: () => setState(() => _buffers.remove(b)),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 16),

              // Regex 필터
              _SectionLabel('Regex 필터 (-e)'),
              const SizedBox(height: 4),
              TextField(
                controller: _regexController,
                decoration: const InputDecoration(
                  hintText: 'E/ActivityManager|I/flutter',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),

              // 최대 라인 수
              _SectionLabel('최대 라인 수 (-m)'),
              const SizedBox(height: 4),
              TextField(
                controller: _maxLinesController,
                decoration: const InputDecoration(
                  hintText: '제한 없음',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.terminal, size: 16),
          label: const Text('터미널에서 실행'),
          onPressed: _selectedTerminalId == null
              ? null
              : () => Navigator.of(context).pop(
                    LogcatRunConfig(
                      options: _buildOptions(),
                      terminalId: _selectedTerminalId!,
                    ),
                  ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      );
}

class _PreviewBanner extends StatelessWidget {
  const _PreviewBanner({required this.command});
  final String command;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          command,
          style: TextStyle(
            fontSize: 11,
            fontFamily: 'monospace',
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
}

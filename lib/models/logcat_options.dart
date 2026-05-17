enum LogcatPreset { all, flutter, custom }

class LogcatRunConfig {
  const LogcatRunConfig({required this.options, required this.terminalId});

  final LogcatOptions options;
  final String terminalId;
}

class LogcatOptions {
  const LogcatOptions({
    this.format = 'color',
    this.tags = const [],
    this.buffers = const [],
    this.regexFilter,
    this.maxLines,
  });

  final String format;
  final List<String> tags;
  final List<String> buffers;
  final String? regexFilter;
  final int? maxLines;

  List<String> toArgs() => [
        '-v', format,
        ...tags.expand((t) => ['-s', t]),
        ...buffers.expand((b) => ['-b', b]),
        if (regexFilter != null && regexFilter!.isNotEmpty) ...[
          '-e',
          regexFilter!,
        ],
        if (maxLines != null) ...['-m', '$maxLines'],
      ];
}

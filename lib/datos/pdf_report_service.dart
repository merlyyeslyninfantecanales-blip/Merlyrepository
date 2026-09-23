import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class PdfReportService {
  PdfReportService._();

  static Future<File> createSimpleReport({
    required String fileName,
    required String title,
    required List<String> lines,
  }) async {
    final reportsDir = await _reportsDirectory();
    final file = File('${reportsDir.path}/${_safeFileName(fileName)}.pdf');
    await file.writeAsBytes(_buildPdf(title: title, lines: lines), flush: true);
    return file;
  }

  static Future<File> createAndSaveReport({
    required String fileName,
    required String title,
    required List<String> lines,
  }) async {
    final file = await createSimpleReport(
      fileName: fileName,
      title: title,
      lines: lines,
    );
    await saveOrShareFile(file, title);
    return file;
  }

  static Future<void> saveOrShareFile(File file, String title) async {
    final saved = await saveFile(file, title);
    if (!saved) {
      await shareFile(file, title);
    }
  }

  static Future<bool> saveFile(File file, String title) async {
    try {
      final bytes = Uint8List.fromList(await file.readAsBytes());
      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar PDF',
        fileName: '${_safeFileName(title)}.pdf',
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        bytes: bytes,
      );
      return savedPath != null;
    } catch (_) {
      return false;
    }
  }

  static Future<void> shareFile(File file, String title) {
    return Share.shareXFiles([XFile(file.path)], subject: title, text: title);
  }

  static Future<Directory> _reportsDirectory() async {
    final baseDir = await getApplicationDocumentsDirectory();
    final reportsDir = Directory('${baseDir.path}/PracticApp/reportes');
    if (!await reportsDir.exists()) {
      await reportsDir.create(recursive: true);
    }
    return reportsDir;
  }

  static String _safeFileName(String value) {
    final safeName = _ascii(value)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return safeName.isEmpty
        ? 'reporte_practicapp_${DateTime.now().millisecondsSinceEpoch}'
        : safeName;
  }

  static List<int> _buildPdf({
    required String title,
    required List<String> lines,
  }) {
    final pageStreams = _contentStreams(title, lines);
    final kids = <String>[];
    final objects = <String>[
      '1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n',
      '',
      '3 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n',
      '4 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>\nendobj\n',
    ];

    for (var i = 0; i < pageStreams.length; i++) {
      final pageObject = 5 + (i * 2);
      final contentObject = pageObject + 1;
      kids.add('$pageObject 0 R');
      objects.add(
        '$pageObject 0 obj\n'
        '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] '
        '/Resources << /Font << /F1 3 0 R /F2 4 0 R >> >> '
        '/Contents $contentObject 0 R >>\n'
        'endobj\n',
      );
      final content = pageStreams[i];
      objects.add(
        '$contentObject 0 obj\n<< /Length ${latin1.encode(content).length} >>\n'
        'stream\n$content\nendstream\nendobj\n',
      );
    }

    objects[1] =
        '2 0 obj\n<< /Type /Pages /Kids [${kids.join(' ')}] /Count ${pageStreams.length} >>\nendobj\n';

    final buffer = StringBuffer('%PDF-1.4\n');
    final offsets = <int>[0];
    for (final object in objects) {
      offsets.add(latin1.encode(buffer.toString()).length);
      buffer.write(object);
    }

    final xrefOffset = latin1.encode(buffer.toString()).length;
    buffer.write('xref\n0 ${objects.length + 1}\n');
    buffer.write('0000000000 65535 f \n');
    for (final offset in offsets.skip(1)) {
      buffer.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
    }
    buffer.write(
      'trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\n'
      'startxref\n$xrefOffset\n%%EOF',
    );

    return latin1.encode(buffer.toString());
  }

  static List<String> _contentStreams(String title, List<String> lines) {
    final sections = _sectionsFrom(lines);
    final pages = <String>[];
    var content = StringBuffer();
    var page = 1;
    var y = _startPage(content, title, page);

    void newPage() {
      _footer(content, page);
      pages.add(content.toString());
      page++;
      content = StringBuffer();
      y = _startPage(content, title, page);
    }

    for (final section in sections) {
      final sectionHeight = _sectionHeight(section);
      if (y - sectionHeight < 72 && y < 650) {
        newPage();
      }
      y = _section(content, section, y, () {
        newPage();
        _sectionHeader(content, '${section.title} (continuacion)', y);
        y -= 28;
      });
      y -= 14;
    }

    _footer(content, page);
    pages.add(content.toString());
    return pages;
  }

  static double _startPage(StringBuffer content, String title, int page) {
    _rect(content, 42, 742, 511, 58, fill: '0.32 0.22 0.78');
    _text(
      content,
      _clean(title),
      60,
      778,
      font: 'F2',
      size: 21,
      color: '1 1 1',
    );
    _text(
      content,
      'PracticApp - Reporte generado automaticamente',
      60,
      759,
      size: 10,
      color: '0.90 0.87 1',
    );
    _text(
      content,
      'Fecha: ${DateTime.now().toIso8601String().split('T').first}',
      410,
      759,
      size: 9,
      color: '0.90 0.87 1',
    );
    _text(content, 'Pagina $page', 500, 28, size: 8, color: '0.45 0.45 0.50');
    return 710;
  }

  static double _section(
    StringBuffer content,
    _ReportSection section,
    double y,
    void Function() newPage,
  ) {
    _sectionHeader(content, section.title, y);
    y -= 28;
    for (var i = 0; i < section.items.length; i++) {
      final item = section.items[i];
      final keyLines = _wrap(item.key, 130, 9);
      final valueLines = _wrap(item.value, 330, 9);
      final rowLines = keyLines.length > valueLines.length
          ? keyLines.length
          : valueLines.length;
      final rowHeight = (16 + (rowLines * 11)).toDouble();
      if (y - rowHeight < 62) {
        newPage();
        y = 682;
      }
      final fill = i.isEven ? '0.98 0.98 1' : '1 1 1';
      _rect(content, 42, y - rowHeight, 511, rowHeight, fill: fill);
      _stroke(
        content,
        42,
        y - rowHeight,
        511,
        rowHeight,
        color: '0.88 0.86 0.94',
      );
      _drawWrapped(
        content,
        keyLines,
        58,
        y - 17,
        font: 'F2',
        size: 9,
        color: '0.18 0.16 0.25',
      );
      _drawWrapped(
        content,
        valueLines,
        195,
        y - 17,
        size: 9,
        color: '0.25 0.25 0.31',
      );
      y -= rowHeight;
    }
    return y;
  }

  static void _sectionHeader(StringBuffer content, String title, double y) {
    _rect(content, 42, y - 22, 511, 22, fill: '0.92 0.89 0.99');
    _stroke(content, 42, y - 22, 511, 22, color: '0.79 0.73 0.93');
    _text(
      content,
      _clean(title).toUpperCase(),
      56,
      y - 15,
      font: 'F2',
      size: 10,
      color: '0.32 0.22 0.78',
    );
  }

  static double _sectionHeight(_ReportSection section) {
    var height = 28.0;
    for (final item in section.items.take(8)) {
      final keyLines = _wrap(item.key, 130, 9);
      final valueLines = _wrap(item.value, 330, 9);
      final rowLines = keyLines.length > valueLines.length
          ? keyLines.length
          : valueLines.length;
      height += 16 + (rowLines * 11);
    }
    return height;
  }

  static List<_ReportSection> _sectionsFrom(List<String> lines) {
    final sections = <_ReportSection>[];
    var title = 'Resumen';
    var items = <_ReportItem>[];

    void flush() {
      if (items.isEmpty) return;
      sections.add(_ReportSection(title, items));
      items = <_ReportItem>[];
    }

    for (final raw in lines) {
      final line = _clean(raw);
      if (line.isEmpty) {
        flush();
        title = 'Detalle';
        continue;
      }
      if (_looksLikeHeading(line)) {
        flush();
        title = line;
        continue;
      }
      items.add(_itemFrom(line));
    }
    flush();

    if (sections.isEmpty) {
      return [
        _ReportSection('Detalle', const [
          _ReportItem('Estado', 'Sin datos disponibles'),
        ]),
      ];
    }
    return sections;
  }

  static _ReportItem _itemFrom(String line) {
    final colon = line.indexOf(':');
    if (colon > 0 && colon < 40) {
      return _ReportItem(
        line.substring(0, colon),
        line.substring(colon + 1).trim(),
      );
    }
    final parts = line.split(' - ');
    if (parts.length > 1) {
      return _ReportItem(parts.first, parts.skip(1).join(' - '));
    }
    return _ReportItem('Detalle', line);
  }

  static bool _looksLikeHeading(String line) {
    if (line.length > 62 || line.contains(':') || line.contains(' - ')) {
      return false;
    }
    final letters = line.replaceAll(RegExp(r'[^A-Za-z ]'), '');
    return letters.length > 3 && line == line.toUpperCase();
  }

  static void _drawWrapped(
    StringBuffer content,
    List<String> lines,
    double x,
    double y, {
    String font = 'F1',
    double size = 9,
    String color = '0 0 0',
  }) {
    for (final line in lines) {
      _text(content, line, x, y, font: font, size: size, color: color);
      y -= 11;
    }
  }

  static List<String> _wrap(String text, double width, double size) {
    final maxChars = (width / (size * 0.52)).floor().clamp(12, 90).toInt();
    final words = _clean(text).split(RegExp(r'\s+'));
    final lines = <String>[];
    var current = '';
    for (final word in words) {
      if (word.isEmpty) continue;
      final candidate = current.isEmpty ? word : '$current $word';
      if (candidate.length <= maxChars) {
        current = candidate;
      } else {
        if (current.isNotEmpty) lines.add(current);
        current = word.length > maxChars
            ? '${word.substring(0, maxChars - 1)}.'
            : word;
      }
    }
    if (current.isNotEmpty) lines.add(current);
    return lines.isEmpty ? ['-'] : lines;
  }

  static void _text(
    StringBuffer content,
    String text,
    double x,
    double y, {
    String font = 'F1',
    double size = 10,
    String color = '0 0 0',
  }) {
    content
      ..writeln('BT')
      ..writeln('$color rg')
      ..writeln('/$font ${size.toStringAsFixed(1)} Tf')
      ..writeln('${x.toStringAsFixed(1)} ${y.toStringAsFixed(1)} Td')
      ..writeln('(${_escape(_clean(text))}) Tj')
      ..writeln('ET');
  }

  static void _rect(
    StringBuffer content,
    double x,
    double y,
    double width,
    double height, {
    required String fill,
  }) {
    content
      ..writeln('q')
      ..writeln('$fill rg')
      ..writeln(
        '${x.toStringAsFixed(1)} ${y.toStringAsFixed(1)} ${width.toStringAsFixed(1)} ${height.toStringAsFixed(1)} re f',
      )
      ..writeln('Q');
  }

  static void _stroke(
    StringBuffer content,
    double x,
    double y,
    double width,
    double height, {
    required String color,
  }) {
    content
      ..writeln('q')
      ..writeln('$color RG')
      ..writeln('0.7 w')
      ..writeln(
        '${x.toStringAsFixed(1)} ${y.toStringAsFixed(1)} ${width.toStringAsFixed(1)} ${height.toStringAsFixed(1)} re S',
      )
      ..writeln('Q');
  }

  static void _footer(StringBuffer content, int page) {
    _text(
      content,
      'PracticApp - Documento generado desde los datos del sistema',
      42,
      28,
      size: 8,
      color: '0.45 0.45 0.50',
    );
  }

  static String _clean(String value) => _ascii(value).trim();

  static String _escape(String value) => value
      .replaceAll('\\', r'\\')
      .replaceAll('(', r'\(')
      .replaceAll(')', r'\)');

  static String _ascii(String value) {
    const replacements = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ñ': 'n',
      'Á': 'A',
      'É': 'E',
      'Í': 'I',
      'Ó': 'O',
      'Ú': 'U',
      'Ñ': 'N',
      '\u00C3\u00A1': 'a',
      '\u00C3\u00A9': 'e',
      '\u00C3\u00AD': 'i',
      '\u00C3\u00B3': 'o',
      '\u00C3\u00BA': 'u',
      '\u00C3\u00B1': 'n',
      '\u00C3\u0081': 'A',
      '\u00C3\u0089': 'E',
      '\u00C3\u008D': 'I',
      '\u00C3\u0093': 'O',
      '\u00C3\u009A': 'U',
      '\u00C3\u0091': 'N',
    };
    var output = value;
    replacements.forEach((key, replacement) {
      output = output.replaceAll(key, replacement);
    });
    return output;
  }
}

class _ReportSection {
  final String title;
  final List<_ReportItem> items;

  const _ReportSection(this.title, this.items);
}

class _ReportItem {
  final String key;
  final String value;

  const _ReportItem(this.key, this.value);
}

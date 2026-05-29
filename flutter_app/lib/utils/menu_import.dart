import 'dart:convert';
import 'package:excel/excel.dart';

class MenuImportRow {
  final int rowNum;
  final Map<String, dynamic> data;

  const MenuImportRow({required this.rowNum, required this.data});
}

List<MenuImportRow> parseMenuImportBytes(List<int> bytes, String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.csv')) {
    return _parseCsv(utf8.decode(bytes));
  }
  if (lower.endsWith('.xlsx') || lower.endsWith('.xls')) {
    return _parseExcel(bytes);
  }
  throw Exception('Use .csv or .xlsx file');
}

List<MenuImportRow> _parseCsv(String text) {
  final lines = const LineSplitter().convert(text.trim());
  if (lines.isEmpty) throw Exception('File is empty');

  final headers = _splitCsvLine(lines.first);
  final headerMap = _headerIndex(headers);
  final rows = <MenuImportRow>[];

  for (var i = 1; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;
    final cells = _splitCsvLine(line);
    final data = _cellsToMap(headerMap, cells);
    if (_isEmptyRow(data)) continue;
    rows.add(MenuImportRow(rowNum: i + 1, data: data));
  }
  return rows;
}

List<String> _splitCsvLine(String line) {
  final out = <String>[];
  final buf = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (c == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        buf.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (c == ',' && !inQuotes) {
      out.add(buf.toString().trim());
      buf.clear();
    } else {
      buf.write(c);
    }
  }
  out.add(buf.toString().trim());
  return out;
}

List<MenuImportRow> _parseExcel(List<int> bytes) {
  final book = Excel.decodeBytes(bytes);
  if (book.tables.isEmpty) throw Exception('No sheet found in workbook');

  final sheet = book.tables[book.tables.keys.first]!;
  if (sheet.maxRows == 0) throw Exception('Sheet is empty');

  final headerRow = sheet.rows.first;
  final headers = headerRow.map((c) => c?.value?.toString().trim() ?? '').toList();
  final headerMap = _headerIndex(headers);
  final rows = <MenuImportRow>[];

  for (var i = 1; i < sheet.rows.length; i++) {
    final cells = sheet.rows[i]
        .map((c) => c?.value?.toString().trim() ?? '')
        .toList();
    if (cells.every((c) => c.isEmpty)) continue;
    final data = _cellsToMap(headerMap, cells);
    if (_isEmptyRow(data)) continue;
    rows.add(MenuImportRow(rowNum: i + 1, data: data));
  }
  return rows;
}

Map<String, int> _headerIndex(List<String> headers) {
  final map = <String, int>{};
  for (var i = 0; i < headers.length; i++) {
    final key = headers[i].toLowerCase().replaceAll(' ', '_');
    if (key.isNotEmpty) map[key] = i;
  }
  const required = ['name', 'category', 'price', 'unit'];
  for (final h in required) {
    if (!map.containsKey(h)) {
      throw Exception('Missing column: $h (required: name, category, price, unit)');
    }
  }
  return map;
}

Map<String, dynamic> _cellsToMap(Map<String, int> headerMap, List<String> cells) {
  String? cell(String key) {
    final idx = headerMap[key];
    if (idx == null || idx >= cells.length) return null;
    final v = cells[idx].trim();
    return v.isEmpty ? null : v;
  }

  return {
    'name': cell('name'),
    'category': cell('category'),
    'price': cell('price'),
    'unit': cell('unit'),
    'track_stock': cell('track_stock'),
    'stock_quantity': cell('stock_quantity'),
    'low_stock_threshold': cell('low_stock_threshold'),
    'is_active': cell('is_active'),
  };
}

bool _isEmptyRow(Map<String, dynamic> data) {
  final name = data['name']?.toString().trim() ?? '';
  return name.isEmpty;
}

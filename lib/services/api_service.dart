import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import '../models/contact.dart';

class ApiService {
  // Defaults
  static const String defaultBase = 'http://172.29.102.240:1400';
  static const String defaultCode = 'PTQT2025';

  static String buildUrl({required String base, required String code}) {
    final cleanBase = base.trim().replaceAll(RegExp(r'/+$'), ''); // remove trailing /
    final cleanCode = code.trim();
    return '$cleanBase/api/ListCustomer?code=${Uri.encodeQueryComponent(cleanCode)}';
  }

  static Future<void> logSend({
  required String base,
  required String ma,
}) async {
  final cleanBase = base.trim().replaceAll(RegExp(r'/+$'), '');
  final url = '$cleanBase/api/ListCustomer/Log?code=${Uri.encodeQueryComponent(ma)}';

  try {
    final res = await http.post(Uri.parse(url));
    if (res.statusCode != 200) {
      print('⚠️ Log API failed');
    } else {
      print('✅ Log success');
    }
  } catch (e) {
    print('❌ Log error');
  }
}



  static Future<List<Contact>> fetchContacts({
    required String base,
    required String code,
  }) async {
    final url = buildUrl(base: base, code: code);

    final res = await http.get(
      Uri.parse(url),
      headers: {'Accept': 'application/xml, text/xml;q=0.9, */*;q=0.8'},
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to load contacts: HTTP ${res.statusCode}');
    }

    final raw = utf8.decode(res.bodyBytes, allowMalformed: true).trim();

    // Parse defensively
    xml.XmlDocument doc;
    try {
      doc = xml.XmlDocument.parse(raw);
    } catch (_) {
      final firstLt = raw.indexOf('<');
      final lastGt = raw.lastIndexOf('>');
      if (firstLt == -1 || lastGt <= firstLt) {
        final preview = raw.substring(0, raw.length.clamp(0, 400));
        throw Exception('Response is not XML. Preview:\n$preview');
      }
      final xmlString = raw.substring(firstLt, lastGt + 1);
      doc = xml.XmlDocument.parse(xmlString);
    }

    final tables = doc.findAllElements('Table');
    if (tables.isEmpty) {
      final root = doc.rootElement.name.toString();
      final preview = raw.substring(0, raw.length.clamp(0, 200));
      throw Exception('No <Table> elements (root: $root). Preview:\n$preview');
    }

    String textOf(xml.XmlElement parent, String tag) {
      final it = parent.findElements(tag);
      return it.isEmpty ? '' : it.first.text.trim();
    }

    return tables.map((t) {
      return Contact(
        ma:     textOf(t, 'Ma'),
        maCB:   textOf(t, 'MaCB'),
        name:   textOf(t, 'HoTen'),
        phone:  textOf(t, 'DienThoai'),
        texSMS: textOf(t, 'TexSMS'),
      );
    }).toList();
  }
}

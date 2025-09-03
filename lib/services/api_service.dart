import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import '../models/contact.dart';

class ApiService {
  // Use the correct host for your setup (AVD can hit this if reachable)
  static const String url =
      'http://172.29.102.240:1400/api/ListCustomer?code=PTQT2025';

  static Future<List<Contact>> fetchContacts() async {
    final res = await http.get(
      Uri.parse(url),
      headers: {
        'Accept': 'application/xml, text/xml;q=0.9, */*;q=0.8',
      },
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to load contacts: HTTP ${res.statusCode}');
    }

    final raw = utf8.decode(res.bodyBytes, allowMalformed: true).trim();

    // 1) Try to parse as-is
    xml.XmlDocument? doc;
    try {
      doc = xml.XmlDocument.parse(raw);
    } catch (_) {
      // 2) If that fails, trim to the outermost XML-looking block
      final firstLt = raw.indexOf('<');
      final lastGt = raw.lastIndexOf('>');
      if (firstLt == -1 || lastGt <= firstLt) {
        // Helpful snippet to see what we actually got
        final preview = raw.substring(0, raw.length.clamp(0, 400));
        throw Exception('Response does not look like XML. Preview:\n$preview');
      }
      final xmlString = raw.substring(firstLt, lastGt + 1);
      doc = xml.XmlDocument.parse(xmlString);
    }

    // 3) Find all <Table> nodes regardless of wrapper/root
    final tables = doc.findAllElements('Table');
    if (tables.isEmpty) {
      // Debug aid: show root + first 200 chars to diagnose
      final rootName = doc.rootElement.name.toString();
      final preview = raw.substring(0, raw.length.clamp(0, 200));
      throw Exception('No <Table> elements found (root: $rootName). Preview:\n$preview');
    }

    String textOf(xml.XmlElement parent, String tag) {
      final el = parent.findElements(tag).isEmpty
          ? null
          : parent.findElements(tag).first;
      return el?.text.trim() ?? '';
    }

    return tables.map((t) {
      return Contact(
        maCB:   textOf(t, 'MaCB'),
        name:   textOf(t, 'HoTen'),
        phone:  textOf(t, 'DienThoai'),
        texSMS: textOf(t, 'TexSMS'),
      );
    }).toList();
  }
}

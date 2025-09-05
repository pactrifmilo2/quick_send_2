import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  final String baseUrl; // e.g. http://172.29.102.240:1400
  final String code;    // e.g. PTQT2025

  const AppConfig({required this.baseUrl, required this.code});

  AppConfig copyWith({String? baseUrl, String? code}) =>
      AppConfig(baseUrl: baseUrl ?? this.baseUrl, code: code ?? this.code);
}

class ConfigService {
  ConfigService._();
  static final ConfigService instance = ConfigService._();

  static const _kBaseUrl = 'base_url';
  static const _kCode = 'code';

  late SharedPreferences _prefs;
  AppConfig _config = const AppConfig(
    baseUrl: 'http://172.29.102.240:1400', // default
    code: 'PTQT2025',                      // default
  );

  AppConfig get config => _config;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final base = _prefs.getString(_kBaseUrl) ?? _config.baseUrl;
    final code = _prefs.getString(_kCode) ?? _config.code;
    _config = AppConfig(baseUrl: base, code: code);
  }

  Future<void> setBaseUrl(String baseUrl) async {
    // normalize: remove any trailing "/" to avoid double slashes
    final normalized = baseUrl.replaceAll(RegExp(r'/+$'), '');
    _config = _config.copyWith(baseUrl: normalized);
    await _prefs.setString(_kBaseUrl, normalized);
  }

  Future<void> setCode(String code) async {
    _config = _config.copyWith(code: code);
    await _prefs.setString(_kCode, code);
  }

  /// Builds: {baseUrl}/api/ListCustomer?code={code}
  Uri buildListCustomerUri() {
    final normalized = _config.baseUrl.replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$normalized/api/ListCustomer')
        .replace(queryParameters: {'code': _config.code});
  }
}

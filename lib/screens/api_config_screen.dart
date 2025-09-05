import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class ApiConfigScreen extends StatefulWidget {
  const ApiConfigScreen({super.key});

  @override
  State<ApiConfigScreen> createState() => _ApiConfigScreenState();
}

class _ApiConfigScreenState extends State<ApiConfigScreen> {
  static const _baseKey = 'api_base';

  late final TextEditingController _baseCtrl =
      TextEditingController(text: ApiService.defaultBase);

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBase = prefs.getString(_baseKey);
    if (savedBase != null && savedBase.isNotEmpty) {
      _baseCtrl.text = savedBase;
    }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseKey, _baseCtrl.text.trim());
    if (mounted) Navigator.of(context).pop(true); // notify caller of changes
  }

  void _resetToDefault() {
    setState(() {
      _baseCtrl.text = ApiService.defaultBase;
    });
  }

  @override
  void dispose() {
    _baseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Settings'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _baseCtrl,
                    decoration: const InputDecoration(
                      labelText: 'API Base',
                      hintText: 'e.g. http://192.168.1.10:1400',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _resetToDefault,
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('Reset to default'),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.save),
                        label: const Text('Save'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Final URL = {base}/api/ListCustomer?code={code}\n'
                    'You can change the code on the Contacts screen.',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
    );
  }
}

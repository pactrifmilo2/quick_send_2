// lib/screens/contact_screen.dart
import 'package:flutter/material.dart';
import 'package:another_telephony/telephony.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/contact.dart';
import '../services/api_service.dart';
import '../widgets/contact_card.dart';
import '../widgets/test_sms_button.dart';


class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final Telephony telephony = Telephony.instance;

  // URL text field (prefill with default)
  late final TextEditingController _urlCtrl =
      TextEditingController(text: ApiService.defaultUrl);

  // Future for loading contacts
  late Future<List<Contact>> _future;

  static const _prefsKey = 'api_url';

  @override
  void initState() {
    super.initState();

    // 1) Initialize with whatever is currently in the controller
    _future = ApiService.fetchContacts(_urlCtrl.text);

    // 2) Load any saved URL and refresh if different
    _loadSavedUrl();

    // 3) Ask SMS permission
    _askPermission();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSavedUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved != null && saved.isNotEmpty && saved != _urlCtrl.text) {
      _urlCtrl.text = saved;
      setState(() {
        _future = ApiService.fetchContacts(_urlCtrl.text);
      });
    }
  }

  Future<void> _saveUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, _urlCtrl.text.trim());
  }

  void _loadFromUrl() async {
    await _saveUrl();
    setState(() {
      _future = ApiService.fetchContacts(_urlCtrl.text);
    });
  }

  Future<void> _askPermission() async {
    final granted =
        await telephony.requestPhoneAndSmsPermissions ?? false;
    if (!granted) {
      debugPrint('SMS permission denied');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contacts'),
      actions: const [
    TestSmsButton(), // <--- here
  ],),
      body: Column(
        children: [
          // URL input row
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'API URL',
                      hintText: 'Enter XML endpoint…',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _loadFromUrl(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Load',
                  icon: const Icon(Icons.download),
                  onPressed: _loadFromUrl,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Data area
          Expanded(
            child: FutureBuilder<List<Contact>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Text('Error: ${snapshot.error}'),
                  );
                }
                final contacts = snapshot.data ?? [];
                if (contacts.isEmpty) {
                  return const Center(child: Text('No contacts found.'));
                }
                return ListView.builder(
                  itemCount: contacts.length,
                  itemBuilder: (context, i) => ContactCard(
                    contact: contacts[i],
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Tap on ${contacts[i].name}')),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

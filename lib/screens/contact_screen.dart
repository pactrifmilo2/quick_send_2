import 'package:flutter/material.dart';
import 'package:another_telephony/telephony.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/contact.dart';
import '../services/api_service.dart';
import '../widgets/contact_card.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final Telephony telephony = Telephony.instance;

  late final TextEditingController _urlCtrl = TextEditingController(
    text: ApiService.defaultUrl,
  );

  late Future<List<Contact>> _future;

  static const _prefsKey = 'api_url';

  final Set<String> _selected = <String>{};

  @override
  void initState() {
    super.initState();
    _future = ApiService.fetchContacts(_urlCtrl.text);
    _loadSavedUrl();
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
      _selected.clear();
      _future = ApiService.fetchContacts(_urlCtrl.text);
    });
  }

  Future<void> _askPermission() async {
    final granted = await telephony.requestPhoneAndSmsPermissions ?? false;
    if (!granted) {
      debugPrint('SMS permission denied');
    }
  }

  void _toggleSelectAll(List<Contact> contacts) {
    final allKeys = contacts.map((c) => c.maCB).toSet();
    final allSelected =
        _selected.length == allKeys.length && allKeys.isNotEmpty;

    setState(() {
      if (allSelected) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(allKeys);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: FutureBuilder<List<Contact>>(
          future: _future,
          builder: (context, snapshot) {
            final total = snapshot.data?.length ?? 0;
            final allSelected = total > 0 && _selected.length == total;

            return IconButton(
              tooltip: allSelected ? 'Clear selection' : 'Select all',
              icon: Icon(allSelected ? Icons.clear_all : Icons.select_all),
              onPressed: snapshot.hasData
                  ? () => _toggleSelectAll(snapshot.data!)
                  : null,
            );
          },
        ),
        title: FutureBuilder<List<Contact>>(
          future: _future,
          builder: (context, snapshot) {
            final total = snapshot.data?.length ?? 0;
            return Text('${_selected.length}/$total selected');
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Send to selected',
            icon: const Icon(Icons.send),
            onPressed: _selected.isEmpty
                ? null
                : () async {
                    final contacts = (await _future)
                        .where((c) => _selected.contains(c.maCB))
                        .toList();

                    for (final c in contacts) {
                      try {
                        await telephony.sendSms(
                          to: c.phone,
                          message: c.texSMS,
                          isMultipart: true,
                          statusListener: (status) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${c.name} (${c.phone}) → $status',
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to send to ${c.name}: $e'),
                            ),
                          );
                        }
                      }
                    }
                  },
          ),
        ],
      ),

      body: Column(
        children: [
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
                  itemBuilder: (context, i) {
                    final c = contacts[i];
                    final key = c.maCB;
                    final isSelected = _selected.contains(key);

                    return ContactCard(
                      contact: c,
                      selected: isSelected,
                      onSelectedChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selected.add(key);
                          } else {
                            _selected.remove(key);
                          }
                        });
                      },
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selected.remove(key);
                          } else {
                            _selected.add(key);
                          }
                        });
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

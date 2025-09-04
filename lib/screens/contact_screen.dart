import 'package:flutter/material.dart';
import 'package:another_telephony/telephony.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

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

  late final TextEditingController _urlCtrl =
      TextEditingController(text: ApiService.defaultUrl);

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
    final allSelected = _selected.length == allKeys.length && allKeys.isNotEmpty;

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

  // ---------- Popup (dialog) ----------
  Future<void> _openContactDialog(Contact c) async {
  final msgCtrl = TextEditingController(text: c.texSMS);
  final tele = Telephony.instance;

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              c.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              c.phone,
              style: const TextStyle(
                fontSize: 20, // same as name
                fontWeight: FontWeight.bold,
                color: Colors.black, // same as name
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(height: 16),
              const Text(
                'Message (TexSMS)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: msgCtrl,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: msgCtrl.text));
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Copied message')),
                );
              }
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.send),
            label: const Text('Send'),
            onPressed: () async {
              final granted = await tele.requestPhoneAndSmsPermissions ?? false;
              if (!granted) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('SMS permission not granted')),
                  );
                }
                return;
              }

              final SmsSendStatusListener listener = (s) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('SMS status: $s')),
                  );
                }
              };

              try {
                await tele.sendSms(
                  to: c.phone,
                  message: msgCtrl.text,
                  isMultipart: true,
                  statusListener: listener,
                );
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Failed to send: $e')),
                  );
                }
              }
            },
          ),
        ],
      );
    },
  );

  msgCtrl.dispose();
}


  Widget _kv(String k, String v) {
    return RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(context).style,
        children: [
          TextSpan(
            text: '$k: ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: v),
        ],
      ),
    );
  }

  // ---------- Bulk send from AppBar ----------
  Future<void> _sendSelected() async {
    final contacts = (await _future)
        .where((c) => _selected.contains(c.maCB))
        .toList();

    if (contacts.isEmpty) return;

    for (final c in contacts) {
      try {
        await telephony.sendSms(
          to: c.phone,
          message: c.texSMS,
          isMultipart: true,
          statusListener: (s) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${c.name} (${c.phone}) → $s')),
              );
            }
          },
        );
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to send to ${c.name}: $e')),
          );
        }
      }
    }
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
            onPressed: _selected.isEmpty ? null : _sendSelected,
          ),
        ],
      ),
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
          // List
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
                      onOpen: () => _openContactDialog(c),
                      onQuickSend: () async {
                        try {
                          await telephony.sendSms(
                            to: c.phone,
                            message: c.texSMS,
                            isMultipart: true,
                            statusListener: (s) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content:
                                          Text('${c.name} (${c.phone}) → $s')),
                                );
                              }
                            },
                          );
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'Failed to send to ${c.name}: $e')),
                            );
                          }
                        }
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

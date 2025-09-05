import 'package:flutter/material.dart';
import 'package:another_telephony/telephony.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

import '../models/contact.dart';
import '../services/api_service.dart';
import '../widgets/contact_card.dart';
import 'api_config_screen.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final Telephony telephony = Telephony.instance;

  static const _baseKey = 'api_base';
  static const _codeKey = 'api_code';

  // Code input shown on this screen
  late final TextEditingController _codeCtrl =
      TextEditingController(text: ApiService.defaultCode);

  late Future<List<Contact>> _future;

  final Set<String> _selected = <String>{};

  @override
  void initState() {
    super.initState();
    _future = _loadAndFetch(); // initial load
    _askPermission();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<Map<String, String>> _loadBaseAndCode() async {
    final prefs = await SharedPreferences.getInstance();
    final base = prefs.getString(_baseKey) ?? ApiService.defaultBase;
    final code = prefs.getString(_codeKey) ?? ApiService.defaultCode;
    // keep the UI in sync with saved code
    if (_codeCtrl.text != code) _codeCtrl.text = code;
    return {'base': base, 'code': code};
  }

  Future<List<Contact>> _loadAndFetch() async {
    final pair = await _loadBaseAndCode();
    return ApiService.fetchContacts(base: pair['base']!, code: pair['code']!);
  }

  Future<void> _saveCode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_codeKey, _codeCtrl.text.trim());
  }

  void _reloadWithCurrent() async {
    await _saveCode();
    setState(() {
      _selected.clear();
      _future = _loadAndFetch();
    });
  }

  Future<void> _openApiSettings() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ApiConfigScreen()),
    );
    if (changed == true) {
      // base changed; reload with new base + current code
      setState(() {
        _selected.clear();
        _future = _loadAndFetch();
      });
    }
  }

  Future<void> _askPermission() async {
    final granted = await telephony.requestPhoneAndSmsPermissions ?? false;
    if (!granted) debugPrint('SMS permission denied');
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

  Future<void> _confirmAndSendSelected() async {
    final contacts = (await _future)
        .where((c) => _selected.contains(c.maCB))
        .toList();
    if (contacts.isEmpty) return;

    final preview = contacts.take(6).toList();
    final remaining = contacts.length - preview.length;

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Send to ${contacts.length} contact${contacts.length > 1 ? 's' : ''}?'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final c in preview)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('• ${c.name}  (${c.phone})'),
                ),
              if (remaining > 0) Text('…and $remaining more'),
              const SizedBox(height: 12),
              const Text(
                'This will send each person their TexSMS message.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton.icon(
            icon: const Icon(Icons.send),
            label: const Text('Send'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (proceed != true) return;

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
      final prefs = await SharedPreferences.getInstance();
      final base = prefs.getString(_baseKey) ?? ApiService.defaultBase;
      ApiService.logSend(base: base, maCB: c.maCB);
    }
  }

  // ===== Contact popup (name + phone same style, editable message) =====
  Future<void> _openContactDialog(Contact c) async {
    final msgCtrl = TextEditingController(text: c.texSMS);
    final tele = Telephony.instance;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(c.phone, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(height: 16),
              const Text('Message (TexSMS)', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: msgCtrl,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () { Clipboard.setData(ClipboardData(text: msgCtrl.text)); },
            child: const Text('Copy'),
          ),
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
          FilledButton.icon(
            icon: const Icon(Icons.send),
            label: const Text('Send'),
            onPressed: () async {
              final granted = await tele.requestPhoneAndSmsPermissions ?? false;
              if (!granted) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx)
                      .showSnackBar(const SnackBar(content: Text('SMS permission not granted')));
                }
                return;
              }
              final SmsSendStatusListener listener = (s) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('SMS status: $s')));
                }
              };
              try {
                await tele.sendSms(
                  to: c.phone,
                  message: msgCtrl.text,
                  isMultipart: true,
                  statusListener: listener,
                );
                final prefs = await SharedPreferences.getInstance();
                final base = prefs.getString(_baseKey) ?? ApiService.defaultBase;
                ApiService.logSend(base: base, maCB: c.maCB);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Failed: $e')));
                }
              }
            },
          ),
        ],
      ),
    );

    msgCtrl.dispose();
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
              onPressed: snapshot.hasData ? () => _toggleSelectAll(snapshot.data!) : null,
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
            tooltip: 'API settings (base)',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openApiSettings,
          ),
          IconButton(
            tooltip: 'Send to selected',
            icon: const Icon(Icons.send),
            onPressed: _selected.isEmpty ? null : _confirmAndSendSelected,
          ),
        ],
      ),
      body: Column(
        children: [
          // Code input row (top of main screen)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Code',
                      hintText: 'e.g. PTQT2025',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _reloadWithCurrent(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Load',
                  icon: const Icon(Icons.download),
                  onPressed: _reloadWithCurrent,
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
                        final prefs = await SharedPreferences.getInstance();
                        final base = prefs.getString(_baseKey) ?? ApiService.defaultBase;
                        ApiService.logSend(base: base, maCB: c.maCB);
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

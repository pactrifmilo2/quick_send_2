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
  static const _pageSizeKey = 'page_size';

  // Code input shown on this screen
  late final TextEditingController _codeCtrl =
      TextEditingController(text: ApiService.defaultCode);

  // Per-page input
  late final TextEditingController _pageSizeCtrl =
      TextEditingController(text: '10');

  late Future<List<Contact>> _future;

  final Set<String> _selected = <String>{};

  // Pagination state
  int _pageSize = 10;
  int _pageIndex = 0; // 0-based

  @override
  void initState() {
    super.initState();
    _future = _loadAndFetch(); // initial load
    _loadPageSize();
    _askPermission();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _pageSizeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPageSize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_pageSizeKey);
    if (saved != null && saved > 0) {
      setState(() {
        _pageSize = saved;
        _pageSizeCtrl.text = saved.toString();
      });
    }
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
    final data = await ApiService.fetchContacts(base: pair['base']!, code: pair['code']!);
    // guard page index if data size changed
    _clampPageIndex(data.length);
    return data;
  }

  Future<void> _saveCode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_codeKey, _codeCtrl.text.trim());
  }

  Future<void> _savePageSize(int size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pageSizeKey, size);
  }

  void _reloadWithCurrent() async {
    await _saveCode();
    setState(() {
      _selected.clear();
      _pageIndex = 0; // reset to first page on new data load
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
        _pageIndex = 0;
        _future = _loadAndFetch();
      });
    }
  }

  Future<void> _askPermission() async {
    final granted = await telephony.requestPhoneAndSmsPermissions ?? false;
    if (!granted) debugPrint('SMS permission denied');
  }

  // ---------- Pagination helpers ----------
  void _clampPageIndex(int totalItems) {
    final pages = _totalPages(totalItems);
    if (pages == 0) {
      _pageIndex = 0;
      return;
    }
    if (_pageIndex >= pages) {
      _pageIndex = pages - 1;
    }
    if (_pageIndex < 0) _pageIndex = 0;
  }

  int _totalPages(int totalItems) {
    if (_pageSize <= 0) return 0;
    return (totalItems / _pageSize).ceil();
  }

  List<Contact> _pageSlice(List<Contact> all) {
    final start = _pageIndex * _pageSize;
    if (start >= all.length) return const [];
    final end = (start + _pageSize).clamp(0, all.length);
    return all.sublist(start, end);
  }

  void _goPrev(int totalItems) {
    setState(() {
      if (_pageIndex > 0) _pageIndex--;
      _clampPageIndex(totalItems);
    });
  }

  void _goNext(int totalItems) {
    setState(() {
      final pages = _totalPages(totalItems);
      if (_pageIndex < pages - 1) _pageIndex++;
      _clampPageIndex(totalItems);
    });
  }

  // ---------- Selection ----------
  void _toggleSelectAll(List<Contact> contactsOnPage) {
    final pageKeys = contactsOnPage.map((c) => c.maCB).toSet(); // selection key
    final allSelectedOnPage = pageKeys.isNotEmpty && pageKeys.every(_selected.contains);

    setState(() {
      if (allSelectedOnPage) {
        _selected.removeAll(pageKeys); // clear only current page
      } else {
        _selected.addAll(pageKeys); // add only current page
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

    // Prefetch base for logging
    final prefs = await SharedPreferences.getInstance();
    final base = prefs.getString(_baseKey) ?? ApiService.defaultBase;

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
            if (s == SendStatus.SENT || s == SendStatus.DELIVERED) {
              ApiService.logSend(base: base, ma: c.ma); // <-- log with Ma
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

  // ===== Contact popup (name + phone same style, editable message) =====
  Future<void> _openContactDialog(Contact c) async {
    final msgCtrl = TextEditingController(text: c.texSMS);
    final tele = Telephony.instance;

    // Prefetch base for logging
    final prefs = await SharedPreferences.getInstance();
    final base = prefs.getString(_baseKey) ?? ApiService.defaultBase;

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
                if (s == SendStatus.SENT || s == SendStatus.DELIVERED) {
                  ApiService.logSend(base: base, ma: c.ma); // <-- log with Ma
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

  // ---------- Page size change ----------
  void _applyPageSizeFromInput() async {
    final raw = _pageSizeCtrl.text.trim();
    final parsed = int.tryParse(raw);
    final newSize = (parsed == null || parsed <= 0) ? 10 : parsed.clamp(1, 1000);
    await _savePageSize(newSize);
    setState(() {
      _pageSize = newSize;
      _pageIndex = 0; // reset to first page
      // No need to refetch; just re-paginate current data.
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Select/Clear only the CURRENT PAGE
        leading: FutureBuilder<List<Contact>>(
          future: _future,
          builder: (context, snapshot) {
            final all = snapshot.data ?? const <Contact>[];
            final page = _pageSlice(all);
            final pageKeys = page.map((c) => c.maCB).toSet();
            final allSelectedOnPage =
                pageKeys.isNotEmpty && pageKeys.every(_selected.contains);

            return IconButton(
              tooltip: allSelectedOnPage ? 'Clear page' : 'Select page',
              icon: Icon(allSelectedOnPage ? Icons.clear_all : Icons.select_all),
              onPressed: page.isEmpty ? null : () => _toggleSelectAll(page),
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
          // Top controls: Code + Per-page
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                // Code input
                Expanded(
                  flex: 2,
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
                // Per page input
                Expanded(
                  child: TextField(
                    controller: _pageSizeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Per page',
                      hintText: 'e.g. 10',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _applyPageSizeFromInput(),
                  ),
                ),
                const SizedBox(width: 8),
                // Load button
                IconButton(
                  tooltip: 'Load',
                  icon: const Icon(Icons.download),
                  onPressed: _reloadWithCurrent,
                ),
                // Apply page size button
                IconButton(
                  tooltip: 'Apply per page',
                  icon: const Icon(Icons.tune),
                  onPressed: _applyPageSizeFromInput,
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

                // Clamp page index after data load
                _clampPageIndex(contacts.length);
                final pageItems = _pageSlice(contacts);
                final totalPages = _totalPages(contacts.length);

                return Column(
                  children: [
                    // The page list
                    Expanded(
                      child: ListView.builder(
                        itemCount: pageItems.length,
                        itemBuilder: (context, i) {
                          final c = pageItems[i];
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
                              // Prefetch base for logging
                              final prefs = await SharedPreferences.getInstance();
                              final base = prefs.getString(_baseKey) ?? ApiService.defaultBase;

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
                                    if (s == SendStatus.SENT || s == SendStatus.DELIVERED) {
                                      ApiService.logSend(base: base, ma: c.ma); // <-- log with Ma
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
                            },
                          );
                        },
                      ),
                    ),
                    // Pager controls
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
                        border: const Border(
                          top: BorderSide(width: 0.5, color: Color(0x1F000000)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text('Page ${totalPages == 0 ? 0 : (_pageIndex + 1)} / $totalPages'),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Previous page',
                            icon: const Icon(Icons.chevron_left),
                            onPressed: _pageIndex > 0
                                ? () => _goPrev(contacts.length)
                                : null,
                          ),
                          IconButton(
                            tooltip: 'Next page',
                            icon: const Icon(Icons.chevron_right),
                            onPressed: (_pageIndex < totalPages - 1)
                                ? () => _goNext(contacts.length)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

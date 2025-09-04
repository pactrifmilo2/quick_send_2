// lib/widgets/contact_card.dart
import 'package:flutter/material.dart';
import 'package:another_telephony/telephony.dart';
import '../models/contact.dart';
import 'package:android_intent_plus/android_intent.dart';

// Optional: only needed if you want the "Open SIM settings" button.
// If you don't add the dependency, set USE_INTENT to false below.
const bool USE_INTENT = true; // flip to false if you don't add android_intent_plus
// ignore: unused_import

final Telephony _telephony = Telephony.instance;

class ContactCard extends StatelessWidget {
  final Contact contact;
  final VoidCallback? onTap;

  const ContactCard({
    super.key,
    required this.contact,
    this.onTap,
  });

  Future<void> _sendSms(BuildContext context) async {
    // 1) Ask for permission right before sending
    final bool granted =
        await _telephony.requestPhoneAndSmsPermissions ?? false;
    if (!granted) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SMS permission not granted')),
      );
      return;
    }

    // 2) Quick capability checks (handle nullables)
    final bool? capable = await _telephony.isSmsCapable;
    final SimState? sim = await _telephony.simState;
    if (capable != true || sim != SimState.READY) {
      if (!context.mounted) return;
      final msg =
          'Cannot send SMS (capable=$capable, sim=$sim). Check SIM/service and try again.';
      _showErrorWithActions(context, msg);
      return;
    }

    // 3) Listen for send status (SENT / DELIVERED)
    final SmsSendStatusListener listener = (SendStatus status) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('SMS status: $status')),
      );
    };

    // 4) Try silent send first
    try {
      await _telephony.sendSms(
        to: contact.phone,
        message: contact.texSMS,
        isMultipart: true,
        statusListener: listener,
      );
      return; // success path handled by listener
    } catch (e) {
      // This is the common "error getting smsmanager, null, null"
      if (!context.mounted) return;
      // 5) Graceful fallback to default SMS app so the user can still send
      await _fallbackToDefaultApp(context, error: e.toString());
    }
  }

  Future<void> _fallbackToDefaultApp(BuildContext context, {required String error}) async {
    // Explain and offer actions
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Can’t send silently'),
        content: Text(
          'Android couldn’t access the SMS manager (often happens on dual-SIM when no default SMS SIM is set).\n\n'
          '• I can open your Messages app with the text prefilled so you can send it manually.\n'
          '• Or you can open SIM settings and set a default SIM for SMS, then try again.\n\n'
          'Error: $error',
        ),
        actions: [
          if (USE_INTENT)
            TextButton(
              onPressed: () {
                // Try to open SIM settings (varies by device; these are broadly supported)
                const actions = [
                  'android.settings.SIM_CARD_SETTINGS',
                  'android.settings.WIRELESS_SETTINGS',
                ];
                for (final a in actions) {
                  AndroidIntent(action: a).launch();
                }
                Navigator.of(context).pop();
              },
              child: const Text('Open SIM settings'),
            ),
          TextButton(
            onPressed: () async {
              // Open default SMS app with prefilled message (user taps Send)
              try {
                await _telephony.sendSmsByDefaultApp(
                  to: contact.phone,
                  message: contact.texSMS,
                );
              } catch (_) {}
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Use Messages app'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showErrorWithActions(BuildContext context, String msg) {
    // For quick UX, show a SnackBar and (optionally) a SIM settings action
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        action: USE_INTENT
            ? SnackBarAction(
                label: 'SIM settings',
                onPressed: () {
                  // best-effort open (device may route to a general settings page)
                  const actions = [
                    'android.settings.SIM_CARD_SETTINGS',
                    'android.settings.WIRELESS_SETTINGS',
                  ];
                  for (final a in actions) {
                    AndroidIntent(action: a).launch();
                  }
                },
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(
            contact.maCB,
            style: const TextStyle(fontSize: 12),
          ),
        ),
        title: Text(contact.name),
        subtitle: Text(contact.phone),
        trailing: IconButton(
          icon: const Icon(Icons.send),
          color: Colors.green,
          onPressed: () => _sendSms(context),
        ),
        onTap: onTap,
      ),
    );
  }
}

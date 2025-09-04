import 'package:flutter/material.dart';
import 'package:another_telephony/telephony.dart';
import '../models/contact.dart';

final Telephony _telephony = Telephony.instance;

class ContactCard extends StatelessWidget {
  final Contact contact;
  final bool selected;
  final ValueChanged<bool?> onSelectedChanged;
  final VoidCallback? onTap;

  const ContactCard({
    super.key,
    required this.contact,
    required this.selected,
    required this.onSelectedChanged,
    this.onTap,
  });

  Future<void> _sendSms(BuildContext context) async {
    final bool granted =
        await _telephony.requestPhoneAndSmsPermissions ?? false;
    if (!granted) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SMS permission not granted')),
      );
      return;
    }

    final bool? capable = await _telephony.isSmsCapable;
    final SimState? sim = await _telephony.simState;
    if (capable != true || sim != SimState.READY) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot send SMS (capable=$capable, sim=$sim)')),
      );
      return;
    }

    final SmsSendStatusListener listener = (SendStatus status) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('SMS status: $status')),
      );
    };

    try {
      await _telephony.sendSms(
        to: contact.phone,
        message: contact.texSMS,
        isMultipart: true,
        statusListener: listener,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Failed to send SMS. If dual-SIM, set default SIM for SMS. Error: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: selected,
              onChanged: onSelectedChanged,
            ),
            CircleAvatar(
              child: Text(
                contact.maCB,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        title: Text(contact.name),
        subtitle: Text(contact.phone),
        trailing: IconButton(
          icon: const Icon(Icons.send),
          color: Colors.green,
          tooltip: 'Send SMS',
          onPressed: () => _sendSms(context),
        ),
        onTap: onTap,
      ),
    );
  }
}

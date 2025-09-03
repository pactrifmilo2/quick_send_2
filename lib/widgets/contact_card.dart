import 'package:flutter/material.dart';
import 'package:another_telephony/telephony.dart';
import '../models/contact.dart';

final Telephony telephony = Telephony.instance;

class ContactCard extends StatelessWidget {
  final Contact contact;
  final VoidCallback? onTap;

  const ContactCard({
    super.key,
    required this.contact,
    this.onTap,
  });

  void _sendSms(BuildContext context) async {
    // Ask permission before sending
    final granted =
        await telephony.requestPhoneAndSmsPermissions ?? false;

    if (!granted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SMS permission not granted')),
        );
      }
      return;
    }

    // Listener for send status
    final SmsSendStatusListener listener = (SendStatus status) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('SMS status: $status')),
        );
      }
    };

    try {
      await telephony.sendSms(
        to: contact.phone,
        message: contact.texSMS,
        isMultipart: true, // safe for long Vietnamese text
        statusListener: listener,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send SMS: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
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

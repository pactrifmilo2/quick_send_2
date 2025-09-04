import 'package:flutter/material.dart';
import 'package:another_telephony/telephony.dart';
import '../models/contact.dart';

final Telephony _telephony = Telephony.instance;

class ContactCard extends StatelessWidget {
  final Contact contact;
  final bool selected;
  final ValueChanged<bool?> onSelectedChanged;
  final VoidCallback onOpen; // open popup
  final VoidCallback? onQuickSend; // optional: quick send from the card

  const ContactCard({
    super.key,
    required this.contact,
    required this.selected,
    required this.onSelectedChanged,
    required this.onOpen,
    this.onQuickSend,
  });

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
          tooltip: 'Quick send SMS',
          onPressed: onQuickSend,
        ),
        onTap: onOpen, // open the popup
      ),
    );
  }
}

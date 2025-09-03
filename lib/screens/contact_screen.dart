import 'package:flutter/material.dart';
import '../models/contact.dart';
import '../services/api_service.dart';
import '../widgets/contact_card.dart' as widgets;
import 'package:another_telephony/telephony.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});
  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final Telephony telephony = Telephony.instance;
  late Future<List<Contact>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService.fetchContacts();
    _askPermission();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contacts')),
      body: FutureBuilder<List<Contact>>(
        future: _future,
        builder: (context, s) {
          if (s.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (s.hasError) {
            return Center(child: Text('Error: ${s.error}'));
          }
          final contacts = s.data ?? [];
          return ListView.builder(
            itemCount: contacts.length,
            itemBuilder: (context, i) => widgets.ContactCard(
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
    );
  }

  Future<void> _askPermission() async {
    final granted = await telephony.requestSmsPermissions ?? false;
    if (!granted) {
      debugPrint("SMS permission denied");
    }
  }
}

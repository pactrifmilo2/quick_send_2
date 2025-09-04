import 'package:flutter/material.dart';
import 'package:another_telephony/telephony.dart';

class TestSmsButton extends StatelessWidget {
  const TestSmsButton({super.key});

  Future<void> _sendTestSms(BuildContext context) async {
    final telephony = Telephony.instance;

    // Ask permission first
    final granted = await telephony.requestPhoneAndSmsPermissions ?? false;
    if (!granted) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SMS permission not granted')),
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
      await telephony.sendSms(
        to: '0963180620',
        message: 'Hello from Flutter',
        isMultipart: true,
        statusListener: listener,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send SMS: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.sms),
      tooltip: 'Send test SMS',
      onPressed: () => _sendTestSms(context),
    );
  }
}

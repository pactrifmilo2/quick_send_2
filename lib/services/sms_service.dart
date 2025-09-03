import 'package:flutter/material.dart';
import 'package:another_telephony/telephony.dart';

class SmsService {
  SmsService._();
  static final SmsService instance = SmsService._();

  final Telephony _telephony = Telephony.instance;
  bool _permissionGranted = false;

  Future<void> ensurePermission(BuildContext context) async {
    if (_permissionGranted) return;
    final granted = await _telephony.requestPhoneAndSmsPermissions ?? false;
    _permissionGranted = granted;
    if (!granted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SMS permission denied')),
      );
    }
  }

  Future<bool> send({
    required String to,
    required String body,
  }) async {
    if (!_permissionGranted) return false;

    bool success = false;

    final listener = (SendStatus status) {
      if (status == SendStatus.SENT || status == SendStatus.DELIVERED) {
        success = true;
      }
    };

    try {
      await _telephony.sendSms(
        to: to,
        message: body,
        isMultipart: true,
        statusListener: listener,
      );
      return success;
    } catch (e) {
      debugPrint('Error sending SMS: $e');
      return false;
    }
  }
}

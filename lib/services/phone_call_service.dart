import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Service responsible for launching direct phone calls from the caregiver
/// interface to linked patients, with graceful fallback for emulators and web.
class PhoneCallService {
  static const MethodChannel _channel = MethodChannel('com.example.medicare_app/phone_call');

  static final PhoneCallService instance = PhoneCallService._internal();
  PhoneCallService._internal();

  /// Validates whether a given phone number is valid and callable.
  bool isValidPhoneNumber(String? phoneNumber) {
    if (phoneNumber == null) return false;
    final digits = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length >= 7;
  }

  /// Initiates a phone call or dialer launch for [phoneNumber].
  ///
  /// On Android, directly invokes `Intent.ACTION_DIAL` pre-filling the phone number.
  /// If on Web, Desktop, or an environment without a native dialer, presents a
  /// styled modal allowing the caregiver to view or copy the patient's number.
  Future<void> makePhoneCall({
    required BuildContext context,
    required String? phoneNumber,
    required String recipientName,
  }) async {
    final rawNumber = phoneNumber?.trim() ?? '';
    final cleanDigits = rawNumber.replaceAll(RegExp(r'[^0-9+]'), '');

    if (cleanDigits.isEmpty || !isValidPhoneNumber(cleanDigits)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              rawNumber.isEmpty
                  ? 'No phone number registered for $recipientName.'
                  : 'Invalid phone number ($rawNumber) for $recipientName.',
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    bool dialerLaunched = false;

    if (!kIsWeb) {
      try {
        final bool? result = await _channel.invokeMethod<bool>('makePhoneCall', {
          'phoneNumber': cleanDigits,
        });
        dialerLaunched = result ?? false;
      } catch (e) {
        debugPrint('PhoneCallService: Native dialer failed: $e');
        dialerLaunched = false;
      }
    }

    if (dialerLaunched) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.phone_in_talk, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text('Opening dialer for $recipientName ($cleanDigits)...')),
              ],
            ),
            backgroundColor: AppColors.brandTeal,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      // Fallback dialog when native dialer isn't available (e.g. Chrome, Emulator without dialer)
      if (context.mounted) {
        _showDialerFallbackSheet(
          context: context,
          recipientName: recipientName,
          phoneNumber: cleanDigits,
        );
      }
    }
  }

  void _showDialerFallbackSheet({
    required BuildContext context,
    required String recipientName,
    required String phoneNumber,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Call $recipientName',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textMuted),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Reach out directly to check on medication adherence.',
                  style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCF2E1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.phone, color: Color(0xFF2E7D4E), size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Phone Number',
                              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                            Text(
                              phoneNumber,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copy Number',
                        icon: const Icon(Icons.copy, color: AppColors.brandTeal, size: 20),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: phoneNumber));
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Copied $phoneNumber to clipboard'),
                              backgroundColor: AppColors.brandTeal,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      try {
                        await _channel.invokeMethod('makePhoneCall', {
                          'phoneNumber': phoneNumber,
                        });
                      } catch (_) {
                        Clipboard.setData(ClipboardData(text: phoneNumber));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Dialer unavailable. Copied $phoneNumber to clipboard.'),
                              backgroundColor: AppColors.brandTeal,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.call, size: 18),
                    label: const Text('Open Phone Dialer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D4E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

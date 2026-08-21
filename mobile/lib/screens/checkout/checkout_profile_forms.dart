import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../models/checkout_profile.dart';
import '../../providers/checkout_profiles_provider.dart';

String _newProfileId(String prefix) {
  final random = Random.secure().nextInt(1 << 32).toRadixString(16);
  return '$prefix-${DateTime.now().microsecondsSinceEpoch}-$random';
}

Future<PaymentCardProfile?> showCardProfileEditor(
  BuildContext context,
  WidgetRef ref, {
  PaymentCardProfile? existing,
}) async {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController(text: existing?.cardholderName);
  final numberController = TextEditingController();
  var month = existing?.expiryMonth ?? DateTime.now().month;
  var year = existing?.expiryYear ?? DateTime.now().year + 1;
  var saving = false;

  final result = await showDialog<PaymentCardProfile>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          title: Text(existing == null ? 'Add Card' : 'Edit Card'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warmBeige,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'This is a simulated payment method. No charge or authorization occurs. The complete card number is never saved or transmitted. Only the cardholder name, network, expiration, and last four digits remain on this device.',
                        style: TextStyle(fontSize: 12, height: 1.45),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [],
                      decoration: const InputDecoration(
                        labelText: 'Cardholder Name',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Enter the cardholder name'
                              : null,
                    ),
                    const SizedBox(height: 14),
                    if (existing == null)
                      TextFormField(
                        controller: numberController,
                        keyboardType: TextInputType.number,
                        autofillHints: const [],
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9 -]')),
                          LengthLimitingTextInputFormatter(24),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Card Number',
                          hintText: '1234 5678 9012 3456',
                        ),
                        validator: (value) => isPlausibleCardNumber(value ?? '')
                            ? null
                            : 'Enter 12 to 19 digits',
                      )
                    else
                      InputDecorator(
                        decoration:
                            const InputDecoration(labelText: 'Saved Card'),
                        child: Text(existing.maskedNumber),
                      ),
                    const SizedBox(height: 14),
                    const Text(
                      'Expiration',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: month,
                            decoration:
                                const InputDecoration(labelText: 'Month'),
                            items: [
                              for (var value = 1; value <= 12; value++)
                                DropdownMenuItem(
                                  value: value,
                                  child: Text(value.toString().padLeft(2, '0')),
                                ),
                            ],
                            onChanged: (value) {
                              if (value != null) month = value;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: year,
                            decoration:
                                const InputDecoration(labelText: 'Year'),
                            items: [
                              for (var value = DateTime.now().year;
                                  value <= DateTime.now().year + 20;
                                  value++)
                                DropdownMenuItem(
                                  value: value,
                                  child: Text(value.toString()),
                                ),
                            ],
                            onChanged: (value) {
                              if (value != null) year = value;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      if (!isValidExpiry(month, year)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Choose a current or future date.'),
                          ),
                        );
                        return;
                      }
                      setDialogState(() => saving = true);
                      final digits = existing == null
                          ? normalizeCardNumber(numberController.text)
                          : '';
                      final profile = PaymentCardProfile(
                        id: existing?.id ?? _newProfileId('card'),
                        cardholderName: nameController.text.trim(),
                        network: existing?.network ?? inferCardNetwork(digits),
                        lastFour: existing?.lastFour ??
                            digits.substring(digits.length - 4),
                        expiryMonth: month,
                        expiryYear: year,
                      );
                      final saved = await ref
                          .read(checkoutProfilesProvider.notifier)
                          .saveCard(profile);
                      numberController.clear();
                      if (saved && dialogContext.mounted) {
                        Navigator.pop(dialogContext, profile);
                      } else if (dialogContext.mounted) {
                        setDialogState(() => saving = false);
                      }
                    },
              child: saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Card'),
            ),
          ],
        );
      },
    ),
  );

  // Keep the controllers alive until the dialog's reverse animation is done.
  await Future<void>.delayed(const Duration(milliseconds: 300));
  numberController.clear();
  numberController.dispose();
  nameController.dispose();
  return result;
}

Future<AddressProfile?> showAddressProfileEditor(
  BuildContext context,
  WidgetRef ref, {
  AddressProfile? existing,
  required String defaultCountry,
}) async {
  final formKey = GlobalKey<FormState>();
  final label = TextEditingController(text: existing?.label ?? 'Home');
  final recipient = TextEditingController(text: existing?.recipientName);
  final line1 = TextEditingController(text: existing?.addressLine1);
  final line2 = TextEditingController(text: existing?.addressLine2);
  final city = TextEditingController(text: existing?.city);
  final region = TextEditingController(text: existing?.region);
  final postalCode = TextEditingController(text: existing?.postalCode);
  final country = TextEditingController(
    text: existing?.country ?? defaultCountry,
  );
  var saving = false;

  String? requiredField(String? value, String message) =>
      value == null || value.trim().isEmpty ? message : null;

  final result = await showDialog<AddressProfile>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(existing == null ? 'Add Address' : 'Edit Address'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _field(label, 'Label',
                      validator: (value) =>
                          requiredField(value, 'Enter a label such as Home')),
                  _field(recipient, 'Recipient Name',
                      validator: (value) =>
                          requiredField(value, 'Enter the recipient name')),
                  _field(line1, 'Address Line 1',
                      validator: (value) =>
                          requiredField(value, 'Enter an address')),
                  _field(line2, 'Address Line 2 (optional)'),
                  _field(city, 'City',
                      validator: (value) =>
                          requiredField(value, 'Enter a city')),
                  _field(region, 'State, Province, or Region (optional)'),
                  _field(postalCode, 'Postal Code (optional)'),
                  _field(country, 'Country or Region',
                      validator: (value) =>
                          requiredField(value, 'Enter a country or region')),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: saving
                ? null
                : () async {
                    if (!(formKey.currentState?.validate() ?? false)) return;
                    setDialogState(() => saving = true);
                    final profile = AddressProfile(
                      id: existing?.id ?? _newProfileId('address'),
                      label: label.text.trim(),
                      recipientName: recipient.text.trim(),
                      addressLine1: line1.text.trim(),
                      addressLine2: line2.text.trim(),
                      city: city.text.trim(),
                      region: region.text.trim(),
                      postalCode: postalCode.text.trim(),
                      country: country.text.trim(),
                    );
                    final saved = await ref
                        .read(checkoutProfilesProvider.notifier)
                        .saveAddress(profile);
                    if (saved && dialogContext.mounted) {
                      Navigator.pop(dialogContext, profile);
                    } else if (dialogContext.mounted) {
                      setDialogState(() => saving = false);
                    }
                  },
            child: saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save Address'),
          ),
        ],
      ),
    ),
  );

  // Keep the controllers alive until the dialog's reverse animation is done.
  await Future<void>.delayed(const Duration(milliseconds: 300));
  for (final controller in [
    label,
    recipient,
    line1,
    line2,
    city,
    region,
    postalCode,
    country,
  ]) {
    controller.dispose();
  }
  return result;
}

Widget _field(
  TextEditingController controller,
  String label, {
  String? Function(String?)? validator,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      textCapitalization: TextCapitalization.words,
      autofillHints: const [],
      decoration: InputDecoration(labelText: label),
      validator: validator,
    ),
  );
}

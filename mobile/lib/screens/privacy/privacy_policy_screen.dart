import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: const [
              Text(
                'Effective date: August 18, 2026',
                style: TextStyle(color: AppColors.slateGrey),
              ),
              SizedBox(height: 18),
              _PolicySummary(),
              _PolicySection(
                title: 'About Impulse',
                body:
                    'Impulse: Fake Shopping is a shopping simulator developed by Rishi Shukla. Users can browse catalogs, add items to a local cart, and place practice orders. Nothing is purchased, no payment is made, and nothing is delivered.',
              ),
              _PolicySection(
                title: 'Information stored on your device',
                body:
                    'The display name you enter, your cart, order history, savings statistics, onboarding status, and the last country and currency response are stored only in local application storage on your device. If you choose to add checkout profiles, cardholder names, masked card details, addresses, defaults, and completed-order checkout snapshots are stored in encrypted local storage. This information is not sent to Impulse or stored in an Impulse user database.',
              ),
              _PolicySection(
                title: 'Simulated cards and addresses',
                body:
                    'Impulse does not require user accounts or authentication. During simulated checkout, you may enter a cardholder name, card number, expiration date, and shipping or billing address. The complete card number is used only on that form to derive the card network and last four digits; it is not persisted or transmitted. Card security codes are never requested. Impulse does not integrate with a payment processor, authorize a card, make a charge, complete a purchase, or arrange a delivery.',
              ),
              _PolicySection(
                title: 'Country and currency selection',
                body:
                    "When the app contacts the Impulse catalog service, the service temporarily processes the connection's IP address to infer a country and select an appropriate currency. This lookup does not use GPS. The IP address is not retained in the Impulse database or application logs and is not associated with a user profile.",
              ),
              _PolicySection(
                title: 'Catalog requests and images',
                body:
                    'Search terms, filters, and catalog requests are processed only to return requested results. Impulse does not retain them or associate them with an identity. Catalog images may be loaded from Open Food Facts, Open Icecat, Wikimedia Commons, Unsplash, or their content-delivery networks. Those services may receive standard connection information and operate under their own privacy policies.',
              ),
              _PolicySection(
                title: 'No advertising or tracking',
                body:
                    'Impulse does not include advertising, behavioral tracking, or analytics SDKs. Impulse does not sell or share personal information for advertising or marketing.',
              ),
              _PolicySection(
                title: 'Device permissions',
                body:
                    'The Android app uses internet access to retrieve catalog information, images, country and currency information, and exchange rates. It does not request access to GPS location, contacts, camera, microphone, photos, or shared device storage.',
              ),
              _PolicySection(
                title: 'Security, retention, and deletion',
                body:
                    "Checkout profiles and checkout snapshots are kept in encrypted local storage. Deleting a reusable card or address does not remove the masked card and address snapshot attached to an older simulated order. Because Impulse does not create accounts or store this information on its servers, there is no server-side personal profile to retain or delete. You can delete all locally stored information by clearing the app's storage, clearing the website's local data, or uninstalling the app.",
              ),
              _PolicySection(
                title: 'Changes to this policy',
                body:
                    "If the app's data practices change, this policy and the relevant app-store disclosures will be updated before those changes are released.",
              ),
              _PolicySection(
                title: 'Contact',
                body:
                    'For privacy questions about Impulse, contact developer Rishi Shukla at rishishukla2k@gmail.com.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PolicySummary extends StatelessWidget {
  const _PolicySummary();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.warmBeigeLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: const Text(
        'Impulse does not create user accounts and does not collect or store personal information in a user database. Impulse does not sell, rent, or use personal information for advertising. The app is a shopping simulator and does not process purchases, payments, or deliveries.',
        style: TextStyle(
          color: AppColors.forestGreen,
          fontWeight: FontWeight.w700,
          height: 1.5,
        ),
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  const _PolicySection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.forestGreen,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              color: AppColors.slateGreyDark,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

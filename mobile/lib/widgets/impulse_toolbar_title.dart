import 'package:flutter/material.dart';

class ImpulseToolbarTitle extends StatelessWidget {
  const ImpulseToolbarTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.asset(
            'web/icons/Icon-192.png',
            key: const Key('impulse-toolbar-logo'),
            width: 28,
            height: 28,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
            semanticLabel: 'Impulse logo',
          ),
        ),
        const SizedBox(width: 9),
        const Text('Impulse'),
      ],
    );
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impulse/widgets/app_network_image.dart';

void main() {
  testWidgets('remote images use the platform-specific bounded renderer',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppNetworkImage(
          imageUrl: 'https://example.invalid/catalog.jpg',
          cacheWidth: 600,
          cacheHeight: 520,
          placeholderBuilder: (_) => const SizedBox(),
          errorBuilder: (_) => const SizedBox(),
        ),
      ),
    );

    if (kIsWeb) {
      final image = tester.widget<Image>(find.byType(Image));
      final provider = image.image as NetworkImage;
      expect(
        provider.webHtmlElementStrategy,
        WebHtmlElementStrategy.prefer,
      );
    } else {
      final image = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(image.memCacheWidth, 600);
      expect(image.memCacheHeight, 520);
      expect(image.maxWidthDiskCache, 600);
      expect(image.maxHeightDiskCache, 520);
    }
  });
}

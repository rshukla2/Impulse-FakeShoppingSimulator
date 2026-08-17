import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Displays remote catalog media without retaining full-resolution images in
/// Flutter's decoded image cache.
///
/// Browsers render remote catalog images as native HTML image elements. This
/// keeps large, mixed-origin catalogs out of the WebGL texture cache and lets
/// the browser manage HTTP caching. Native apps retain disk caching and decode
/// images to the requested bounds.
class AppNetworkImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final int cacheWidth;
  final int cacheHeight;
  final WidgetBuilder placeholderBuilder;
  final WidgetBuilder errorBuilder;
  final String? semanticLabel;

  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    required this.cacheWidth,
    required this.cacheHeight,
    required this.placeholderBuilder,
    required this.errorBuilder,
    this.fit = BoxFit.cover,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Image.network(
        imageUrl,
        fit: fit,
        semanticLabel: semanticLabel,
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : placeholderBuilder(context),
        errorBuilder: (context, _, __) => errorBuilder(context),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      memCacheWidth: cacheWidth,
      memCacheHeight: cacheHeight,
      maxWidthDiskCache: cacheWidth,
      maxHeightDiskCache: cacheHeight,
      placeholder: (context, _) => placeholderBuilder(context),
      errorWidget: (context, _, __) => errorBuilder(context),
    );
  }
}

class Product {
  final String id;
  final String type; // 'shopping', 'grocery', 'food'
  final String name;
  final String? brand;
  final String category;
  final String? cuisine;
  final String? description;
  final String? imageUrl;
  final String source;
  final String? sourceId;
  final double basePriceUsd;
  final double? originalPriceUsd;
  final double displayPrice;
  final double? originalDisplayPrice;
  final String formattedPrice;
  final String? formattedOriginalPrice;
  final String currency;
  final String currencySymbol;
  final double rating;
  final int reviewCount;
  final bool isFictional;
  final String? restaurantId;
  final String? restaurantName;
  final String? imageLicense;
  final String? imageAttribution;

  const Product({
    required this.id,
    required this.type,
    required this.name,
    this.brand,
    required this.category,
    this.cuisine,
    this.description,
    this.imageUrl,
    required this.source,
    this.sourceId,
    required this.basePriceUsd,
    this.originalPriceUsd,
    required this.displayPrice,
    this.originalDisplayPrice,
    required this.formattedPrice,
    this.formattedOriginalPrice,
    required this.currency,
    required this.currencySymbol,
    required this.rating,
    required this.reviewCount,
    this.isFictional = false,
    this.restaurantId,
    this.restaurantName,
    this.imageLicense,
    this.imageAttribution,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? '',
      type: json['type'] ?? 'shopping',
      name: json['name'] ?? '',
      brand: json['brand'],
      category: json['category'] ?? '',
      cuisine: json['cuisine'],
      description: json['description'],
      imageUrl: json['image_url'] ?? json['image'],
      source: json['source'] ?? 'local',
      sourceId: json['source_id'],
      basePriceUsd: (json['base_price_usd'] as num?)?.toDouble() ?? 0.0,
      originalPriceUsd: (json['original_price_usd'] as num?)?.toDouble(),
      displayPrice: (json['display_price'] as num?)?.toDouble() ?? 0.0,
      originalDisplayPrice:
          (json['original_display_price'] as num?)?.toDouble(),
      formattedPrice: json['formatted_price'] ?? '\$0.00',
      formattedOriginalPrice: json['formatted_original_price'],
      currency: json['currency'] ?? 'USD',
      currencySymbol: json['currency_symbol'] ?? '\$',
      rating: (json['rating'] as num?)?.toDouble() ?? 4.5,
      reviewCount: json['review_count'] ?? 100,
      isFictional: json['is_fictional'] ?? false,
      restaurantId: json['restaurant_id'],
      restaurantName: json['restaurant_name'],
      imageLicense: json['image_license'],
      imageAttribution: json['image_attribution'],
    );
  }

  Product copyWith({
    double? displayPrice,
    double? originalDisplayPrice,
    String? formattedPrice,
    String? formattedOriginalPrice,
    String? currency,
    String? currencySymbol,
  }) {
    return Product(
      id: id,
      type: type,
      name: name,
      brand: brand,
      category: category,
      cuisine: cuisine,
      description: description,
      imageUrl: imageUrl,
      source: source,
      sourceId: sourceId,
      basePriceUsd: basePriceUsd,
      originalPriceUsd: originalPriceUsd,
      displayPrice: displayPrice ?? this.displayPrice,
      originalDisplayPrice: originalDisplayPrice ?? this.originalDisplayPrice,
      formattedPrice: formattedPrice ?? this.formattedPrice,
      formattedOriginalPrice:
          formattedOriginalPrice ?? this.formattedOriginalPrice,
      currency: currency ?? this.currency,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      rating: rating,
      reviewCount: reviewCount,
      isFictional: isFictional,
      restaurantId: restaurantId,
      restaurantName: restaurantName,
      imageLicense: imageLicense,
      imageAttribution: imageAttribution,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'name': name,
      'brand': brand,
      'category': category,
      'cuisine': cuisine,
      'description': description,
      'image_url': imageUrl,
      'source': source,
      'source_id': sourceId,
      'base_price_usd': basePriceUsd,
      'original_price_usd': originalPriceUsd,
      'display_price': displayPrice,
      'original_display_price': originalDisplayPrice,
      'formatted_price': formattedPrice,
      'formatted_original_price': formattedOriginalPrice,
      'currency': currency,
      'currency_symbol': currencySymbol,
      'rating': rating,
      'review_count': reviewCount,
      'is_fictional': isFictional,
      'restaurant_id': restaurantId,
      'restaurant_name': restaurantName,
      'image_license': imageLicense,
      'image_attribution': imageAttribution,
    };
  }
}

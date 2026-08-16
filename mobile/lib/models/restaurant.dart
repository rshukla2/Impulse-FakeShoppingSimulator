import 'product.dart';

class Restaurant {
  final String id;
  final String name;
  final String cuisine;
  final String? tagline;
  final String? imageUrl;
  final double rating;
  final int reviewCount;
  final String priceLevel;
  final int dishesCount;
  final List<Product>? menu;

  const Restaurant({
    required this.id,
    required this.name,
    required this.cuisine,
    this.tagline,
    this.imageUrl,
    required this.rating,
    required this.reviewCount,
    required this.priceLevel,
    this.dishesCount = 0,
    this.menu,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      cuisine: json['cuisine'] ?? '',
      tagline: json['tagline'],
      imageUrl: json['image_url'],
      rating: (json['rating'] as num?)?.toDouble() ?? 4.8,
      reviewCount: json['review_count'] ?? 1000,
      priceLevel: json['price_level'] ?? '\$\$',
      dishesCount: json['dishes_count'] ?? 0,
      menu: json['menu'] != null
          ? (json['menu'] as List).map((i) => Product.fromJson(i)).toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'cuisine': cuisine,
      'tagline': tagline,
      'image_url': imageUrl,
      'rating': rating,
      'review_count': reviewCount,
      'price_level': priceLevel,
      'dishes_count': dishesCount,
      'menu': menu?.map((i) => i.toJson()).toList(),
    };
  }
}

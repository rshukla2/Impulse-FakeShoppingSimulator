import 'cart_item.dart';

class SimulatedOrder {
  final String id;
  final DateTime createdAt;
  final List<CartItem> items;
  final double totalAmount;
  final String formattedTotal;
  final String currency;
  final String currencySymbol;
  final int totalItemsCount;
  final double totalBaseUsd;

  const SimulatedOrder({
    required this.id,
    required this.createdAt,
    required this.items,
    required this.totalAmount,
    required this.formattedTotal,
    required this.currency,
    required this.currencySymbol,
    required this.totalItemsCount,
    required this.totalBaseUsd,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'items': items.map((i) => i.toJson()).toList(),
      'total_amount': totalAmount,
      'formatted_total': formattedTotal,
      'currency': currency,
      'currency_symbol': currencySymbol,
      'total_items_count': totalItemsCount,
      'total_base_usd': totalBaseUsd,
    };
  }

  factory SimulatedOrder.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List? ?? [])
        .map((i) => CartItem.fromJson(i))
        .toList();
    final derivedBaseTotal = items.fold<double>(
      0,
      (sum, item) => sum + item.product.basePriceUsd * item.quantity,
    );
    return SimulatedOrder(
      id: json['id'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      items: items,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      formattedTotal: json['formatted_total'] ?? '\$0.00',
      currency: json['currency'] ?? 'USD',
      currencySymbol: json['currency_symbol'] ?? '\$',
      totalItemsCount: json['total_items_count'] ?? 0,
      totalBaseUsd:
          (json['total_base_usd'] as num?)?.toDouble() ?? derivedBaseTotal,
    );
  }
}

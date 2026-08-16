import '../../models/bootstrap_data.dart';
import '../../models/cart_item.dart';
import '../../models/product.dart';
import 'currency_formatter.dart';

double localizedPrice(double baseUsd, BootstrapData bootstrap) {
  final converted = baseUsd * bootstrap.exchangeRate;
  if (bootstrap.currency == 'INR' || bootstrap.currency == 'JPY') {
    return converted.roundToDouble();
  }
  return (converted * 100).roundToDouble() / 100;
}

Product localizeProduct(Product product, BootstrapData bootstrap) {
  final price = localizedPrice(product.basePriceUsd, bootstrap);
  final original = product.originalPriceUsd == null
      ? null
      : localizedPrice(product.originalPriceUsd!, bootstrap);
  return product.copyWith(
    displayPrice: price,
    originalDisplayPrice: original,
    formattedPrice: CurrencyFormatter.format(
      price,
      bootstrap.currency,
      bootstrap.currencySymbol,
    ),
    formattedOriginalPrice: original == null
        ? null
        : CurrencyFormatter.format(
            original,
            bootstrap.currency,
            bootstrap.currencySymbol,
          ),
    currency: bootstrap.currency,
    currencySymbol: bootstrap.currencySymbol,
  );
}

double localizedCartTotal(
  List<CartItem> items,
  BootstrapData bootstrap,
) {
  return items.fold<double>(
    0,
    (sum, item) =>
        sum +
        localizedPrice(item.product.basePriceUsd, bootstrap) * item.quantity,
  );
}

double cartBaseTotalUsd(List<CartItem> items) {
  return items.fold<double>(
    0,
    (sum, item) => sum + item.product.basePriceUsd * item.quantity,
  );
}

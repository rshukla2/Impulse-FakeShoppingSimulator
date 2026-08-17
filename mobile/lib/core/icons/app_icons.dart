import 'package:flutter/material.dart';

/// App-owned icon vocabulary backed by Flutter's bundled Material icons.
///
/// Keeping this small compatibility layer avoids coupling the application to
/// the abandoned `lucide_icons` package, which is incompatible with current
/// Flutter releases.
abstract final class LucideIcons {
  static const apple = Icons.apple_outlined;
  static const camera = Icons.camera_alt_outlined;
  static const check = Icons.check;
  static const checkCircle = Icons.check_circle_outline;
  static const chevronRight = Icons.chevron_right;
  static const coins = Icons.monetization_on_outlined;
  static const creditCard = Icons.credit_card_outlined;
  static const edit2 = Icons.edit_outlined;
  static const globe = Icons.public;
  static const groceries = Icons.shopping_basket_outlined;
  static const heartHandshake = Icons.volunteer_activism_outlined;
  static const home = Icons.home_outlined;
  static const info = Icons.info_outline;
  static const laptop = Icons.laptop_outlined;
  static const mapPin = Icons.location_on_outlined;
  static const minus = Icons.remove;
  static const package = Icons.inventory_2_outlined;
  static const piggyBank = Icons.savings_outlined;
  static const plus = Icons.add;
  static const receipt = Icons.receipt_long_outlined;
  static const search = Icons.search;
  static const settings = Icons.settings_outlined;
  static const shieldCheck = Icons.verified_user_outlined;
  static const shoppingBag = Icons.shopping_bag_outlined;
  static const shoppingCart = Icons.shopping_cart_outlined;
  static const sparkles = Icons.auto_awesome;
  static const star = Icons.star;
  static const trash2 = Icons.delete_outline;
  static const user = Icons.person_outline;
  static const utensils = Icons.restaurant_outlined;
  static const x = Icons.close;
}

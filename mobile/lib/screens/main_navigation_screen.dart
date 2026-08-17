import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impulse/core/icons/app_icons.dart';
import '../core/theme/app_colors.dart';
import 'home/home_screen.dart';
import 'food/food_screen.dart';
import 'groceries/groceries_screen.dart';
import 'shopping/shopping_screen.dart';
import 'orders/orders_screen.dart';

class MainNavigationScreen extends ConsumerStatefulWidget {
  final int initialIndex;

  const MainNavigationScreen({super.key, this.initialIndex = 0});

  @override
  ConsumerState<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 4);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(onSelectTab: _selectTab),
          const FoodScreen(),
          const GroceriesScreen(),
          const ShoppingScreen(),
          const OrdersScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _selectTab,
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.forestGreen,
        selectedItemColor: AppColors.warmBeige,
        unselectedItemColor: AppColors.warmBeigeLight.withValues(alpha: 0.68),
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedFontSize: 11,
        unselectedFontSize: 10,
        items: const [
          BottomNavigationBarItem(icon: Icon(LucideIcons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.utensils),
            label: 'Food',
          ),
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.groceries),
            label: 'Groceries',
          ),
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.shoppingBag),
            label: 'Shopping',
          ),
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.receipt),
            label: 'Orders',
          ),
        ],
      ),
    );
  }

  void _selectTab(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
  }
}

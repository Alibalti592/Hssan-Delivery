import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../cart/cart.dart';
import '../widgets/dark_header.dart';
import 'cart_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';
import 'restaurants_screen.dart';

class _CartTab extends StatelessWidget {
  const _CartTab();

  @override
  Widget build(BuildContext context) {
    final restaurantName = context.watch<CartController>().restaurantName;
    return Column(
      children: [
        DarkHeader(title: 'Mon panier', subtitle: restaurantName),
        const Expanded(child: CartView()),
      ],
    );
  }
}

class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  int _index = 0;

  static const _titles = ['Restaurants', 'Mes commandes'];
  static const _tabs = [
    RestaurantsScreen(),
    OrdersScreen(),
    _CartTab(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // The first two tabs (browse/history) keep a plain light AppBar; the
    // cart and profile tabs render their own dark header instead (matching
    // the design's primary-action screens), so no outer AppBar there.
    final showLightAppBar = _index < _titles.length;

    return Scaffold(
      appBar: showLightAppBar ? AppBar(title: Text(_titles[_index])) : null,
      body: SafeArea(
        top: !showLightAppBar,
        bottom: false,
        child: IndexedStack(index: _index, children: _tabs),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Restaurants',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Commandes',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart),
            label: 'Panier',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

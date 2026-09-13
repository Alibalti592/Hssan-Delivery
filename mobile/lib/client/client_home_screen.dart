import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../cart/cart.dart';
import '../widgets/dark_header.dart';
import 'cart_screen.dart';
import 'home_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';

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

  static const _tabs = [
    HomeScreen(),
    OrdersScreen(),
    _CartTab(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // Home renders its own address/cart header, and the cart/profile tabs
    // render their own dark header (matching the design's primary-action
    // screens) — only "Mes commandes" needs the generic outer AppBar.
    final showLightAppBar = _index == 1;

    return Scaffold(
      appBar: showLightAppBar
          ? AppBar(title: const Text('Mes commandes'))
          : null,
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
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Accueil',
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

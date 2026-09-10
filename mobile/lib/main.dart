import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth/auth_controller.dart';
import 'auth/auth_repository.dart';
import 'auth/login_screen.dart';
import 'cart/cart.dart';
import 'catalogue/catalogue_repository.dart';
import 'client/client_home_screen.dart';
import 'core/api_client.dart';
import 'core/token_storage.dart';
import 'dashboard/dashboard_screen.dart';
import 'deliveries/deliveries_controller.dart';
import 'deliveries/delivery_repository.dart';
import 'orders/orders_repository.dart';
import 'theme.dart';

void main() {
  runApp(const HssanDeliveryApp());
}

class HssanDeliveryApp extends StatefulWidget {
  const HssanDeliveryApp({super.key});

  @override
  State<HssanDeliveryApp> createState() => _HssanDeliveryAppState();
}

class _HssanDeliveryAppState extends State<HssanDeliveryApp> {
  late final AuthController _auth;
  late final ApiClient _api;
  late final DeliveriesController _deliveries;
  late final CatalogueRepository _catalogue;
  late final OrdersRepository _orders;
  late final CartController _cart;

  @override
  void initState() {
    super.initState();

    // The token provider and 401 handler close over _auth, which is assigned
    // just below; they are only ever *called* later, once a request runs.
    _api = ApiClient(
      tokenProvider: () => _auth.token,
      onUnauthorized: () => _auth.onUnauthorized(),
    );
    _auth = AuthController(
      repository: AuthRepository(_api),
      storage: TokenStorage(),
    );
    _deliveries = DeliveriesController(DeliveryRepository(_api));
    _catalogue = CatalogueRepository(_api);
    _orders = OrdersRepository(_api);
    _cart = CartController();

    _auth.bootstrap();
  }

  @override
  void dispose() {
    _api.close();
    _auth.dispose();
    _deliveries.dispose();
    _cart.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _auth),
        ChangeNotifierProvider.value(value: _deliveries),
        ChangeNotifierProvider.value(value: _cart),
        Provider.value(value: _catalogue),
        Provider.value(value: _orders),
      ],
      child: MaterialApp(
        title: 'Delivery Hassen',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    switch (auth.status) {
      case AuthStatus.unknown:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AuthStatus.signedOut:
        return const LoginScreen();
      case AuthStatus.signedIn:
        return auth.account!.isCourier
            ? const DashboardScreen()
            : const ClientHomeScreen();
    }
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'addresses/address_repository.dart';
import 'auth/auth_controller.dart';
import 'auth/auth_repository.dart';
import 'auth/login_screen.dart';
import 'cart/cart.dart';
import 'catalogue/catalogue_repository.dart';
import 'client/client_home_screen.dart';
import 'config.dart';
import 'core/api_client.dart';
import 'core/onboarding_storage.dart';
import 'core/token_storage.dart';
import 'dashboard/dashboard_screen.dart';
import 'deliveries/deliveries_controller.dart';
import 'deliveries/delivery_repository.dart';
import 'onboarding/onboarding_screen.dart';
import 'onboarding/splash_screen.dart';
import 'orders/orders_repository.dart';
import 'theme.dart';

Future<void> main() async {
  // Empty DSN (the default — see config.dart) makes the SDK a no-op: it
  // still runs the app via appRunner, just never sends anything anywhere.
  await SentryFlutter.init(
    (options) => options.dsn = AppConfig.sentryDsn,
    appRunner: () => runApp(const HssanDeliveryApp()),
  );
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
  late final AddressRepository _addresses;
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
    _addresses = AddressRepository(_api);
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
        Provider.value(value: _addresses),
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

class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  final _onboardingStorage = OnboardingStorage();
  bool? _onboardingSeen;

  @override
  void initState() {
    super.initState();
    _onboardingStorage.hasSeenOnboarding().then((seen) {
      if (mounted) setState(() => _onboardingSeen = seen);
    });
  }

  void _completeOnboarding() {
    _onboardingStorage.markSeen();
    setState(() => _onboardingSeen = true);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    switch (auth.status) {
      case AuthStatus.unknown:
        return const SplashScreen();
      case AuthStatus.signedOut:
        if (_onboardingSeen == null) return const SplashScreen();
        if (!_onboardingSeen!) {
          return OnboardingScreen(onDone: _completeOnboarding);
        }
        return const LoginScreen();
      case AuthStatus.signedIn:
        return auth.account!.isCourier
            ? const DashboardScreen()
            : const ClientHomeScreen();
    }
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'addresses/address_repository.dart';
import 'addresses/selected_address.dart';
import 'auth/auth_controller.dart';
import 'auth/auth_repository.dart';
import 'auth/login_screen.dart';
import 'bills/bills_repository.dart';
import 'cart/cart.dart';
import 'catalogue/catalogue_repository.dart';
import 'client/client_home_screen.dart';
import 'client/order_detail_screen.dart';
import 'config.dart';
import 'core/api_client.dart';
import 'courier_location/courier_location_repository.dart';
import 'courier_location/courier_location_service.dart';
import 'core/onboarding_storage.dart';
import 'core/sentry_scrubbing.dart';
import 'core/token_storage.dart';
import 'dashboard/dashboard_screen.dart';
import 'deliveries/deliveries_controller.dart';
import 'deliveries/delivery_detail_screen.dart';
import 'deliveries/delivery_repository.dart';
import 'notifications/notifications_repository.dart';
import 'notifications/push_notification_service.dart';
import 'onboarding/onboarding_screen.dart';
import 'onboarding/splash_screen.dart';
import 'orders/orders_repository.dart';
import 'promotions/offer_screen.dart';
import 'promotions/promotion_sheet.dart';
import 'promotions/promotions_repository.dart';
import 'theme.dart';
import 'widgets/status_bar.dart';

Future<void> main() async {
  // Throws before the app runs if this is a release build pointed at a
  // non-HTTPS backend — see config.dart.
  AppConfig.assertSecureTransportInRelease();

  // Empty DSN (the default — see config.dart) makes the SDK a no-op: it
  // still runs the app via appRunner, just never sends anything anywhere.
  await SentryFlutter.init((options) {
    options.dsn = AppConfig.sentryDsn;
    // Belt-and-suspenders scrubbing — see core/sentry_scrubbing.dart for
    // why this matters even though nothing currently feeds Sentry a
    // request with an Authorization header.
    options.beforeSend = scrubSensitiveEventData;
    options.beforeBreadcrumb = scrubSensitiveBreadcrumbData;
  }, appRunner: () => runApp(const HssanDeliveryApp()));
}

class HssanDeliveryApp extends StatefulWidget {
  const HssanDeliveryApp({super.key});

  @override
  State<HssanDeliveryApp> createState() => _HssanDeliveryAppState();
}

class _HssanDeliveryAppState extends State<HssanDeliveryApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  late final AuthController _auth;
  late final ApiClient _api;
  late final PushNotificationService _pushNotifications;
  late final DeliveriesController _deliveries;
  late final CatalogueRepository _catalogue;
  late final OrdersRepository _orders;
  late final BillsRepository _bills;
  late final AddressRepository _addresses;
  late final PromotionsRepository _promotions;
  late final CourierLocationService _courierLocation;
  late final CartController _cart;
  late final SelectedAddressController _selectedAddress;

  @override
  void initState() {
    super.initState();

    // The token provider and 401 handler close over _auth, which is assigned
    // just below; they are only ever *called* later, once a request runs.
    _api = ApiClient(
      tokenProvider: () => _auth.token,
      onUnauthorized: () => _auth.onUnauthorized(),
      refreshSession: () => _auth.refreshSession(),
    );
    // Both callbacks close over fields assigned later in this initState
    // (_deliveries below) or never during it (_navigatorKey's Navigator only
    // exists once MaterialApp has built) — safe here the same way the
    // tokenProvider/onUnauthorized closures above close over _auth, since
    // neither callback actually runs until a push arrives well after this
    // method returns.
    _pushNotifications = PushNotificationService(
      NotificationsRepository(_api),
      onOrderTap: (orderId) {
        _navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => OrderDetailScreen(orderId: orderId),
          ),
        );
      },
      // A promotion sent to every customer: back to the home screen, with
      // the promotion open on top if it's still running.
      onPromotionTap: (promotionId) async {
        // A tap that launched the app arrives before the saved session is
        // read: without it the request would go out signed out and fail.
        if (!await _signedIn()) return;
        _navigatorKey.currentState?.popUntil((route) => route.isFirst);
        if (promotionId == null) return;
        try {
          final promotion = await _promotions.get(promotionId);
          final navigator = _navigatorKey.currentState;
          final context = _navigatorKey.currentContext;
          if (navigator == null || context == null || !context.mounted) return;
          if (promotion.isOffer) {
            navigator.push(
              MaterialPageRoute(builder: (_) => OfferScreen(offer: promotion)),
            );
          } else {
            showPromotionSheet(context, promotion);
          }
        } catch (_) {
          // Over, or offline: the home screen is a fine place to land.
        }
      },
      onOrderUpdate: (orderId) => _orders.notifyChanged(orderId),
      onDeliveryUpdate: (_) => _deliveries.refresh(silent: true),
      onDeliveryTap: (deliveryId) async {
        // Refreshed first so DeliveryDetailScreen's controller.byId lookup
        // (see deliveries_controller.dart) can find it even on a cold start,
        // before anything else has loaded the courier's delivery list.
        await _deliveries.refresh();
        _navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => DeliveryDetailScreen(deliveryId: deliveryId),
          ),
        );
      },
    );
    _auth = AuthController(
      repository: AuthRepository(_api),
      storage: TokenStorage(),
      pushNotifications: _pushNotifications,
      // Pops any pushed screen (an order/delivery detail opened via
      // Navigator.push, including from a push-notification tap) back to
      // the root route on sign-out, so _Root's home swap to LoginScreen is
      // actually what the user sees instead of a stranded pushed screen.
      onSessionEnded: () {
        _navigatorKey.currentState?.popUntil((route) => route.isFirst);
        // Nothing of this account carries over to the next one on this
        // phone: its address, cart, or a courier's deliveries.
        _selectedAddress.clear();
        _cart.clear();
        _deliveries.clear();
      },
    );
    _deliveries = DeliveriesController(DeliveryRepository(_api));
    _catalogue = CatalogueRepository(_api);
    _orders = OrdersRepository(_api);
    _bills = BillsRepository(_api);
    _addresses = AddressRepository(_api);
    _promotions = PromotionsRepository(_api);
    _courierLocation = CourierLocationService(
      CourierLocationRepository(_api),
      _deliveries,
      // An available courier shows on the admin's map even between orders.
      onDuty: _auth,
      isOnDuty: () {
        final account = _auth.account;
        return account != null && account.isCourier && account.isAvailable;
      },
    );
    _cart = CartController();
    _selectedAddress = SelectedAddressController(_addresses);

    _auth.addListener(_forgetCatalogueOnSignOut);
    _pushNotifications.initialize();
    _auth.bootstrap();
  }

  /// The kept catalogue answers (TtlCache) are the same for everyone, but
  /// the next account on this phone starts from the server all the same.
  void _forgetCatalogueOnSignOut() {
    if (_auth.status != AuthStatus.signedOut) return;
    _catalogue.clearCache();
    _promotions.clearCache();
    _bills.clearCache();
  }

  /// Whether a customer is signed in, waiting first for the saved session
  /// to be read when the app has only just started (a notification tap can
  /// launch it), and for the home screen it leads to.
  Future<bool> _signedIn() async {
    if (_auth.status == AuthStatus.unknown) {
      final resolved = Completer<void>();
      void listener() {
        if (_auth.status != AuthStatus.unknown && !resolved.isCompleted) {
          resolved.complete();
        }
      }

      _auth.addListener(listener);
      try {
        await resolved.future.timeout(const Duration(seconds: 20));
      } on TimeoutException {
        return false;
      } finally {
        _auth.removeListener(listener);
      }
      await WidgetsBinding.instance.endOfFrame;
    }
    return mounted && _auth.status == AuthStatus.signedIn;
  }

  @override
  void dispose() {
    _api.close();
    _auth.removeListener(_forgetCatalogueOnSignOut);
    _auth.dispose();
    _courierLocation.dispose();
    _deliveries.dispose();
    _cart.dispose();
    _selectedAddress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _auth),
        ChangeNotifierProvider.value(value: _deliveries),
        ChangeNotifierProvider.value(value: _cart),
        ChangeNotifierProvider.value(value: _selectedAddress),
        Provider.value(value: _catalogue),
        Provider.value(value: _orders),
        Provider.value(value: _bills),
        Provider.value(value: _addresses),
        Provider.value(value: _promotions),
        Provider.value(value: _pushNotifications),
      ],
      child: MaterialApp(
        title: 'Delivery Hassen',
        debugShowCheckedModeBanner: false,
        navigatorKey: _navigatorKey,
        scaffoldMessengerKey: _pushNotifications.messengerKey,
        // One look whatever the phone's dark mode: every screen is designed
        // on the light theme (brand colors fixed in ~250 places), so
        // following the system's dark mode left white text on white cards.
        theme: buildTheme(),
        themeMode: ThemeMode.light,
        // Dark status bar icons for our white screens, whatever the phone's
        // mode; black headers (DarkHeader, splash, login) set white ones.
        builder: (context, child) => StatusBarDefault(child: child!),
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

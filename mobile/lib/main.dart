import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth/auth_controller.dart';
import 'auth/auth_repository.dart';
import 'auth/login_screen.dart';
import 'core/api_client.dart';
import 'core/token_storage.dart';
import 'dashboard/dashboard_screen.dart';
import 'deliveries/deliveries_controller.dart';
import 'deliveries/delivery_repository.dart';
import 'theme.dart';

void main() {
  runApp(const CourierApp());
}

class CourierApp extends StatefulWidget {
  const CourierApp({super.key});

  @override
  State<CourierApp> createState() => _CourierAppState();
}

class _CourierAppState extends State<CourierApp> {
  late final AuthController _auth;
  late final ApiClient _api;
  late final DeliveriesController _deliveries;

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

    _auth.bootstrap();
  }

  @override
  void dispose() {
    _api.close();
    _auth.dispose();
    _deliveries.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _auth),
        ChangeNotifierProvider.value(value: _deliveries),
      ],
      child: MaterialApp(
        title: 'Delivery Hassen — Livreur',
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
    final status = context.watch<AuthController>().status;

    switch (status) {
      case AuthStatus.unknown:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AuthStatus.signedOut:
        return const LoginScreen();
      case AuthStatus.signedIn:
        return const DashboardScreen();
    }
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../cart/cart.dart';
import '../core/api_exception.dart';
import '../orders/order_models.dart';
import '../orders/orders_repository.dart';
import 'order_confirmed_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _address = TextEditingController();
  final _note = TextEditingController();
  late Future<List<DeliveryZoneOption>> _zonesFuture;
  DeliveryZoneOption? _selectedZone;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _zonesFuture = context.read<OrdersRepository>().listDeliveryZones();
  }

  @override
  void dispose() {
    _address.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit(CartController cart) async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    if (_selectedZone == null) {
      setState(() => _error = 'Choisissez une zone de livraison.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final order = await context.read<OrdersRepository>().createOrder(
        restaurantId: cart.restaurantId!,
        items: cart.lines,
        deliveryAddress: _address.text.trim(),
        deliveryZoneId: _selectedZone!.id,
        note: _note.text.trim(),
      );
      cart.clear();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => OrderConfirmedScreen(order: order)),
        (route) => route.isFirst,
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } on NetworkException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Livraison')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  cart.restaurantName ?? '',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _address,
                  enabled: !_submitting,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Adresse de livraison',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Adresse requise'
                      : null,
                ),
                const SizedBox(height: 16),
                FutureBuilder<List<DeliveryZoneOption>>(
                  future: _zonesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const LinearProgressIndicator();
                    }
                    if (snapshot.hasError) {
                      return Text(
                        'Impossible de charger les zones de livraison.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      );
                    }
                    final zones = snapshot.data ?? const [];
                    return DropdownButtonFormField<DeliveryZoneOption>(
                      initialValue: _selectedZone,
                      decoration: const InputDecoration(
                        labelText: 'Zone de livraison',
                      ),
                      items: zones
                          .map(
                            (z) => DropdownMenuItem(
                              value: z,
                              child: Text('${z.name} — ${z.fee} DT'),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: _submitting
                          ? null
                          : (value) => setState(() => _selectedZone = value),
                    );
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _note,
                  enabled: !_submitting,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Note (optionnel)',
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _TotalRow(
                          label: 'Sous-total',
                          value: cart.subtotal,
                        ),
                        const SizedBox(height: 6),
                        _TotalRow(
                          label: 'Frais de livraison',
                          value: double.tryParse(_selectedZone?.fee ?? '') ?? 0,
                        ),
                        const Divider(height: 20),
                        _TotalRow(
                          label: 'Total',
                          value:
                              cart.subtotal +
                              (double.tryParse(_selectedZone?.fee ?? '') ?? 0),
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _submitting ? null : () => _submit(cart),
                  child: _submitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Confirmer la commande'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.label, required this.value, this.bold = false});

  final String label;
  final double value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          )
        : Theme.of(context).textTheme.bodyMedium;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text('${value.toStringAsFixed(3)} DT', style: style),
      ],
    );
  }
}

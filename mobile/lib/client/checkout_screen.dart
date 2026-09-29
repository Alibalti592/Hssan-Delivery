import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../addresses/address_picker.dart';
import '../addresses/selected_address.dart';
import '../cart/cart.dart';
import '../core/api_exception.dart';
import '../orders/orders_repository.dart';
import '../widgets/dark_header.dart';
import 'order_confirmed_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _note = TextEditingController();
  AddressSelection? _selection;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _onAddressChanged(AddressSelection? selection) {
    setState(() => _selection = selection);
    // Picking another address here also changes "LIVRER À".
    if (selection != null) {
      context.read<SelectedAddressController>().select(selection.address);
    }
  }

  Future<void> _submit(CartController cart) async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    final selection = _selection!;

    setState(() => _submitting = true);
    try {
      final order = await context.read<OrdersRepository>().createOrder(
        restaurantId: cart.restaurantId!,
        items: cart.lines,
        deliveryAddress: selection.address.fullText,
        deliveryZoneId: selection.zone!.id,
        deliveryLatitude: selection.address.latitude,
        deliveryLongitude: selection.address.longitude,
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
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            DarkHeader(
              title: 'Livraison',
              subtitle: cart.restaurantName ?? 'Vérifiez votre commande',
              onBack: _submitting ? null : () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AddressField(
                        label: 'Livrer à',
                        enabled: !_submitting,
                        initialAddress: context
                            .read<SelectedAddressController>()
                            .current,
                        allowOneOff: true,
                        onChanged: _onAddressChanged,
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
                                value:
                                    double.tryParse(
                                      _selection?.zone?.fee ?? '',
                                    ) ??
                                    0,
                              ),
                              const Divider(height: 20),
                              _TotalRow(
                                label: 'Total',
                                value:
                                    cart.subtotal +
                                    (double.tryParse(
                                          _selection?.zone?.fee ?? '',
                                        ) ??
                                        0),
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
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
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
                            : const Text('CONFIRMER LA COMMANDE'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final double value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)
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

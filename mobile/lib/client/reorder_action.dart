import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../cart/cart.dart';
import '../catalogue/catalogue_repository.dart';
import '../core/api_exception.dart';
import '../orders/order_models.dart';
import '../orders/reorder.dart';
import 'cart_screen.dart';

/// "Recommander": puts [order]'s items back in the cart and opens it, after
/// asking before throwing away a cart that already has something in it.
Future<void> startReorder(BuildContext context, ClientOrder order) async {
  final cart = context.read<CartController>();
  final catalogue = context.read<CatalogueRepository>();
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);

  if (!cart.isEmpty) {
    final replace = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remplacer votre panier ?'),
        content: const Text(
          'Votre panier actuel sera vidé pour y remettre cette commande.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Non'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remplacer'),
          ),
        ],
      ),
    );
    if (replace != true) return;
  }

  final ReorderResult result;
  try {
    result = await reorder(order, catalogue: catalogue, cart: cart);
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return;
  } on NetworkException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return;
  }

  if (result.added == 0) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Ces articles ne sont plus disponibles.')),
    );
    return;
  }
  if (result.missing.isNotEmpty) {
    messenger.showSnackBar(
      SnackBar(content: Text('Plus disponible : ${result.missing.join(', ')}')),
    );
  }
  navigator.push(MaterialPageRoute(builder: (_) => const CartScreen()));
}

/// The button, with a spinner while the menu loads.
class ReorderButton extends StatefulWidget {
  const ReorderButton({required this.order, this.compact = false, super.key});

  final ClientOrder order;

  /// A small text button for list cards, instead of a full-width one.
  final bool compact;

  @override
  State<ReorderButton> createState() => _ReorderButtonState();
}

class _ReorderButtonState extends State<ReorderButton> {
  bool _busy = false;

  Future<void> _run() async {
    setState(() => _busy = true);
    try {
      await startReorder(context, widget.order);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = _busy
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.replay, size: 18);
    const label = Text('Recommander');

    if (widget.compact) {
      return TextButton.icon(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
        onPressed: _busy ? null : _run,
        icon: icon,
        label: label,
      );
    }
    return FilledButton.icon(
      onPressed: _busy ? null : _run,
      icon: icon,
      label: label,
    );
  }
}

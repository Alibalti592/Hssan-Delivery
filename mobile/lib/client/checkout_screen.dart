import '../addresses/address_picker.dart';
import '../addresses/selected_address.dart';
import '../cart/cart.dart';
import '../core/api_exception.dart';
import '../orders/order_models.dart';
import '../orders/orders_repository.dart';
import '../theme.dart';
import '../widgets/cash_payment_note.dart';
import '../widgets/dark_header.dart';
import 'dart:async';
import 'order_confirmed_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _note = TextEditingController();
  final _code = TextEditingController();
  AddressSelection? _selection;
  bool _submitting = false;
  String? _error;

  /// The backend's price for this cart and zone, promotion included. Null
  /// until it answers (or without a zone yet): the cart's own sum shows.
  OrderQuote? _quote;

  /// Only the answer to the latest request counts.
  int _quoteGeneration = 0;

  /// A code the backend accepted, sent again with the order.
  String? _appliedCode;
  bool _codeOpen = false;
  bool _checkingCode = false;
  String? _codeError;

  @override
  void dispose() {
    _note.dispose();
    _code.dispose();
    super.dispose();
  }

  void _onAddressChanged(AddressSelection? selection) {
    final zoneChanged = selection?.zone?.id != _selection?.zone?.id;
    setState(() {
      _selection = selection;
      // The old zone's price no longer holds, nor does an answer still on
      // its way for it: the cart's own sum shows until the new one lands.
      if (zoneChanged) {
        _quote = null;
        _quoteGeneration++;
      }
    });
    // Picking another address here also changes "LIVRER À".
    if (selection != null) {
      context.read<SelectedAddressController>().select(selection.address);
    }
    if (zoneChanged) _refreshQuote();
  }

  /// Prices the cart for the chosen zone, with [code] when given (else the
  /// applied one). Returns the backend's message when that fails.
  Future<String?> _refreshQuote({String? code}) async {
    final zone = _selection?.zone;
    final cart = context.read<CartController>();
    if (zone == null || cart.restaurantId == null) return null;

    final generation = ++_quoteGeneration;
    try {
      final quote = await context.read<OrdersRepository>().quoteOrder(
        restaurantId: cart.restaurantId!,
        items: cart.lines,
        deliveryZoneId: zone.id,
        promoCode: code ?? _appliedCode,
      );
      if (mounted && generation == _quoteGeneration) {
        setState(() => _quote = quote);
      }
      return null;
    } on ApiException catch (e) {
      return e.message;
    } on NetworkException catch (e) {
      return e.message;
    }
  }

  Future<void> _applyCode() async {
    final code = _code.text.trim();
    if (code.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _checkingCode = true;
      _codeError = null;
    });
    final error = await _refreshQuote(code: code);
    if (!mounted) return;
    setState(() {
      _checkingCode = false;
      if (error == null) {
        _appliedCode = code;
        _codeOpen = false;
      } else {
        _codeError = error;
      }
    });
  }

  void _removeCode() {
    setState(() {
      _appliedCode = null;
      _code.clear();
    });
    _refreshQuote();
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
        promoCode: _appliedCode,
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
        // DarkHeader pads itself for the status bar.
        top: false,
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
                      _PromoCodeSection(
                        controller: _code,
                        open: _codeOpen,
                        checking: _checkingCode,
                        error: _codeError,
                        appliedCode: _appliedCode,
                        quote: _quote,
                        enabled: !_submitting,
                        onOpen: () => setState(() => _codeOpen = true),
                        onApply: _applyCode,
                        onRemove: _removeCode,
                      ),
                      const SizedBox(height: 12),
                      _Summary(
                        quote: _quote,
                        localSubtotal: cart.subtotal,
                        localFee: double.tryParse(_selection?.zone?.fee ?? ''),
                      ),
                      const SizedBox(height: 12),
                      const CashPaymentNote(),
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

/// "J'ai un code promo": a link that opens a field, then the applied code
/// as a chip. Says so when an automatic promotion beats the code.
class _PromoCodeSection extends StatelessWidget {
  const _PromoCodeSection({
    required this.controller,
    required this.open,
    required this.checking,
    required this.error,
    required this.appliedCode,
    required this.quote,
    required this.enabled,
    required this.onOpen,
    required this.onApply,
    required this.onRemove,
  });

  final TextEditingController controller;
  final bool open;
  final bool checking;
  final String? error;
  final String? appliedCode;
  final OrderQuote? quote;
  final bool enabled;
  final VoidCallback onOpen;
  final VoidCallback onApply;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final applied = appliedCode;

    if (applied != null) {
      final codeWins =
          quote?.promoCode != null &&
          quote!.promoCode!.toLowerCase() == applied.toLowerCase();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            decoration: BoxDecoration(
              color: successBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_offer, size: 18, color: successText),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Code ${applied.toUpperCase()} appliqué',
                    style: const TextStyle(
                      color: successText,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Retirer le code',
                  onPressed: enabled ? onRemove : null,
                  icon: const Icon(Icons.close, size: 18, color: successText),
                ),
              ],
            ),
          ),
          if (!codeWins && quote?.promotionTitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                '« ${quote!.promotionTitle} » est plus avantageuse : '
                "c'est elle qui s'applique.",
                style: textTheme.bodySmall?.copyWith(color: mutedText),
              ),
            ),
        ],
      );
    }

    if (!open) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: enabled ? onOpen : null,
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
          icon: const Icon(Icons.local_offer_outlined, size: 18),
          label: const Text("J'ai un code promo"),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            autofocus: true,
            enabled: enabled && !checking,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onApply(),
            decoration: InputDecoration(
              labelText: 'Code promo',
              prefixIcon: const Icon(Icons.local_offer_outlined),
              errorText: error,
              errorMaxLines: 2,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 52),
              padding: const EdgeInsets.symmetric(horizontal: 18),
            ),
            onPressed: enabled && !checking ? onApply : null,
            child: checking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Appliquer'),
          ),
        ),
      ],
    );
  }
}

/// Sous-total, réduction, livraison, total: the backend's figures once it
/// has answered, the cart's own sum before that.
class _Summary extends StatelessWidget {
  const _Summary({
    required this.quote,
    required this.localSubtotal,
    required this.localFee,
  });

  final OrderQuote? quote;
  final double localSubtotal;
  final double? localFee;

  @override
  Widget build(BuildContext context) {
    final quote = this.quote;
    double amount(String value) => double.tryParse(value) ?? 0;

    final subtotal = quote != null ? amount(quote.subtotal) : localSubtotal;
    final fee = quote != null ? amount(quote.deliveryFee) : (localFee ?? 0);
    final discount = quote != null ? amount(quote.discountAmount) : 0.0;
    final total = quote != null
        ? amount(quote.totalAmount)
        : subtotal + (localFee ?? 0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _TotalRow(label: 'Sous-total', value: subtotal),
            if (discount > 0) ...[
              const SizedBox(height: 6),
              _TotalRow(
                label: quote?.promotionTitle ?? 'Réduction',
                value: -discount,
                color: successText,
                icon: Icons.local_offer_outlined,
              ),
            ],
            const SizedBox(height: 6),
            _TotalRow(label: 'Frais de livraison', value: fee),
            const Divider(height: 20),
            _TotalRow(label: 'Total', value: total, bold: true),
            if (discount > 0) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Vous économisez ${discount.toStringAsFixed(3)} DT',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: successText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
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
    this.color,
    this.icon,
  });

  final String label;
  final double value;
  final bool bold;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final base = bold
        ? Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)
        : Theme.of(context).textTheme.bodyMedium;
    final style = color == null
        ? base
        : base?.copyWith(color: color, fontWeight: FontWeight.w700);

    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(
            label,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value < 0
              ? '-${(-value).toStringAsFixed(3)} DT'
              : '${value.toStringAsFixed(3)} DT',
          style: style,
        ),
      ],
    );
  }
}

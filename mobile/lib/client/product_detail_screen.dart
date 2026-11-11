import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../cart/cart.dart';
import '../catalogue/catalogue_models.dart';
import '../theme.dart';
import '../widgets/app_photo.dart';
import '../widgets/quantity_stepper.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    required this.product,
    required this.restaurantName,
    super.key,
  });

  final Product product;
  final String restaurantName;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;

  /// The chosen size/portion; the first one is preselected so the price
  /// shown is always one the customer can actually order.
  late ProductOption? _option = widget.product.hasOptions
      ? widget.product.options.first
      : null;

  /// The extras ticked, by group name.
  final Map<String, Set<String>> _picked = {};

  /// What was ticked, in the product's own order — the order's too.
  List<PickedExtra> get _extras => [
    for (final group in widget.product.extraGroups)
      for (final choice in group.choices)
        if (_picked[group.name]?.contains(choice.name) ?? false)
          PickedExtra(
            group: group.name,
            name: choice.name,
            price: choice.price,
          ),
  ];

  /// The first required group with nothing ticked yet, if any.
  ProductExtraGroup? get _missing => widget.product.extraGroups
      .where((g) => g.required && (_picked[g.name]?.isEmpty ?? true))
      .firstOrNull;

  void _toggle(ProductExtraGroup group, ProductExtraChoice choice) {
    setState(() {
      final picked = _picked.putIfAbsent(group.name, () => <String>{});
      if (picked.contains(choice.name)) {
        picked.remove(choice.name);
      } else {
        // One pick only: the new one replaces the old.
        if (!group.multiple) picked.clear();
        picked.add(choice.name);
      }
    });
  }

  Future<void> _addToCart() async {
    final cart = context.read<CartController>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (cart.belongsToDifferentRestaurant(widget.product.restaurantId)) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remplacer le panier ?'),
          content: Text(
            'Votre panier contient des articles de ${cart.restaurantName}. '
            'L\'ajouter videra ce panier pour commencer une commande chez '
            '${widget.restaurantName}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remplacer'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    cart.add(
      widget.product,
      restaurantName: widget.restaurantName,
      quantity: _quantity,
      option: _option,
      extras: _extras,
    );
    navigator.pop();
    final label = _option == null
        ? widget.product.name
        : '${widget.product.name} (${_option!.name})';
    messenger.showSnackBar(SnackBar(content: Text('$label ajouté au panier')));
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final extras = _extras;
    final unitPrice =
        (double.tryParse(_option?.price ?? product.price) ?? 0) +
        extras.fold(0.0, (sum, e) => sum + (double.tryParse(e.price) ?? 0));
    final total = unitPrice * _quantity;
    final missing = _missing;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: AppPhoto(
                    product.photoUrl,
                    icon: Icons.restaurant_outlined,
                    iconSize: 48,
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: CircleAvatar(
                    backgroundColor: Colors.white,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: navy),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (product.description != null &&
                        product.description!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        product.description!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    if (product.hasOptions) ...[
                      const SizedBox(height: 20),
                      Text(
                        'Taille',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final option in product.options)
                            ChoiceChip(
                              label: Text(
                                '${option.name} · ${option.price} DT',
                              ),
                              selected: option.name == _option?.name,
                              onSelected: (_) =>
                                  setState(() => _option = option),
                            ),
                        ],
                      ),
                    ],
                    for (final group in product.extraGroups)
                      _ExtraGroupSection(
                        group: group,
                        picked: _picked[group.name] ?? const {},
                        onToggle: (choice) => _toggle(group, choice),
                      ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        QuantityStepper(
                          large: true,
                          quantity: _quantity,
                          onDecrement: _quantity > 1
                              ? () => setState(() => _quantity--)
                              : null,
                          onIncrement:
                              _quantity < CartController.maxQuantityPerProduct
                              ? () => setState(() => _quantity++)
                              : null,
                        ),
                        Text(
                          '${total.toStringAsFixed(3)} DT',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  // A required group left empty: say which, rather than
                  // letting the order fail later.
                  onPressed: missing == null ? _addToCart : null,
                  child: Text(
                    missing == null
                        ? 'AJOUTER AU PANIER'
                        : 'CHOISISSEZ : ${missing.name.toUpperCase()}',
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

/// One group of extras ("Sauces", "Boisson"...): its name, whether it's
/// required, how many can be picked, and a row per choice with its price.
class _ExtraGroupSection extends StatelessWidget {
  const _ExtraGroupSection({
    required this.group,
    required this.picked,
    required this.onToggle,
  });

  final ProductExtraGroup group;
  final Set<String> picked;
  final ValueChanged<ProductExtraChoice> onToggle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final missing = group.required && picked.isEmpty;

    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  group.name,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: !group.required
                      ? fieldFill
                      : missing
                      ? warnBg
                      : successBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  !group.required
                      ? 'Facultatif'
                      : missing
                      ? 'Obligatoire'
                      : 'Choisi',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: !group.required
                        ? mutedText
                        : missing
                        ? warnText
                        : successText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            group.multiple ? 'Plusieurs choix possibles' : 'Un seul choix',
            style: textTheme.bodySmall?.copyWith(color: mutedText),
          ),
          const SizedBox(height: 6),
          for (final choice in group.choices)
            _ExtraChoiceRow(
              choice: choice,
              multiple: group.multiple,
              selected: picked.contains(choice.name),
              onTap: () => onToggle(choice),
            ),
        ],
      ),
    );
  }
}

class _ExtraChoiceRow extends StatelessWidget {
  const _ExtraChoiceRow({
    required this.choice,
    required this.multiple,
    required this.selected,
    required this.onTap,
  });

  final ProductExtraChoice choice;
  final bool multiple;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = accentOf(context);
    final icon = multiple
        ? (selected ? Icons.check_box : Icons.check_box_outline_blank)
        : (selected ? Icons.radio_button_checked : Icons.radio_button_off);

    return Semantics(
      checked: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            children: [
              Icon(icon, size: 22, color: selected ? accent : mutedText),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  choice.name,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              Text(
                choice.isFree ? 'Gratuit' : '+${choice.price} DT',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: choice.isFree ? mutedText : accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

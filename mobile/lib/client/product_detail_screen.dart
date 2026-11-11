import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../cart/cart.dart';
import '../catalogue/catalogue_models.dart';
import '../theme.dart';
import '../widgets/app_photo.dart';
import '../widgets/quantity_stepper.dart';
import 'cart_screen.dart';

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

  /// Each group's section, to bring a required one left empty into view.
  final Map<String, GlobalKey> _groupKeys = {};

  /// The required group the customer was just sent back to, outlined until
  /// something is picked in it.
  String? _flagged;

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
      if (_flagged == group.name && picked.isNotEmpty) _flagged = null;
    });
  }

  /// "Ajouter" with a required group still empty: scroll to it and outline
  /// it, rather than a button that silently does nothing.
  void _showMissing(ProductExtraGroup group) {
    setState(() => _flagged = group.name);
    final target = _groupKeys[group.name]?.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        alignment: 0.1,
      );
    }
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
    messenger.showSnackBar(
      SnackBar(
        content: Text('$label ajouté au panier'),
        action: SnackBarAction(
          label: 'VOIR LE PANIER',
          onPressed: () => navigator.push(
            MaterialPageRoute(builder: (_) => const CartScreen()),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final textTheme = Theme.of(context).textTheme;
    final extras = _extras;
    final unitPrice =
        (double.tryParse(_option?.price ?? product.price) ?? 0) +
        extras.fold(0.0, (sum, e) => sum + (double.tryParse(e.price) ?? 0));
    final total = unitPrice * _quantity;
    final missing = _missing;
    final hasPhoto = product.photoUrl != null && product.photoUrl!.isNotEmpty;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            stretch: true,
            expandedHeight: hasPhoto ? 260 : 150,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 1,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: navy, size: 20),
                  tooltip: 'Retour',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: AppPhoto(
                product.photoUrl,
                icon: Icons.restaurant_outlined,
                iconSize: 48,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    product.hasOptions
                        ? 'À partir de ${product.price} DT'
                        : '${product.price} DT',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: navy,
                    ),
                  ),
                  if (product.description != null &&
                      product.description!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      product.description!,
                      style: textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF5B6472),
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (product.hasOptions)
            SliverToBoxAdapter(
              child: _ChoiceSection(
                title: 'Taille',
                subtitle: 'Choisissez-en 1',
                badge: _Badge.done,
                children: [
                  for (final option in product.options)
                    _ChoiceRow(
                      label: option.name,
                      price: '${option.price} DT',
                      multiple: false,
                      selected: option.name == _option?.name,
                      onTap: () => setState(() => _option = option),
                    ),
                ],
              ),
            ),
          for (final group in product.extraGroups)
            SliverToBoxAdapter(
              child: _ChoiceSection(
                key: _groupKeys.putIfAbsent(group.name, GlobalKey.new),
                title: group.name,
                subtitle: _subtitle(group, _picked[group.name]?.length ?? 0),
                badge: !group.required
                    ? _Badge.optional
                    : (_picked[group.name]?.isEmpty ?? true)
                    ? _Badge.required
                    : _Badge.done,
                flagged: _flagged == group.name,
                children: [
                  for (final choice in group.choices)
                    _ChoiceRow(
                      label: choice.name,
                      price: choice.isFree ? 'Gratuit' : '+${choice.price} DT',
                      free: choice.isFree,
                      multiple: group.multiple,
                      selected:
                          _picked[group.name]?.contains(choice.name) ?? false,
                      onTap: () => _toggle(group, choice),
                    ),
                ],
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
      bottomNavigationBar: _AddBar(
        quantity: _quantity,
        onDecrement: _quantity > 1 ? () => setState(() => _quantity--) : null,
        onIncrement: _quantity < CartController.maxQuantityPerProduct
            ? () => setState(() => _quantity++)
            : null,
        label: missing == null
            ? 'Ajouter · ${total.toStringAsFixed(3)} DT'
            : 'Choisir : ${missing.name}',
        onPressed: missing == null ? _addToCart : () => _showMissing(missing),
      ),
    );
  }

  /// "Choisissez-en 1", "2 choisis", "Plusieurs choix possibles"...
  static String _subtitle(ProductExtraGroup group, int picked) {
    if (!group.multiple) return 'Choisissez-en 1';
    if (picked > 0) return picked == 1 ? '1 choisi' : '$picked choisis';
    return group.required
        ? 'Au moins 1, plusieurs possibles'
        : 'Plusieurs choix possibles';
  }
}

enum _Badge { optional, required, done }

/// A group of choices: a tinted header (its name, how many to pick, and
/// whether it's required) over a row per choice. [flagged] outlines it when
/// the customer is sent back to it.
class _ChoiceSection extends StatelessWidget {
  const _ChoiceSection({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.children,
    this.flagged = false,
    super.key,
  });

  final String title;
  final String subtitle;
  final _Badge badge;
  final List<Widget> children;
  final bool flagged;

  @override
  Widget build(BuildContext context) {
    final (badgeText, badgeColor, badgeBg) = switch (badge) {
      _Badge.optional => ('Facultatif', mutedText, Colors.white),
      _Badge.required => ('Obligatoire', warnText, warnBg),
      _Badge.done => ('✓', successText, successBg),
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(
            color: flagged ? warnText : Colors.transparent,
            width: 1.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: flagged ? warnBg : const Color(0xFFF4F6F9),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        flagged ? 'Faites un choix pour continuer' : subtitle,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: flagged ? warnText : mutedText,
                          fontWeight: flagged ? FontWeight.w700 : null,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: badge == _Badge.done ? 9 : 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 20, endIndent: 20),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// One choice: a checkbox (several) or a round button (one), its name and
/// its price, with the whole row as the tap target.
class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.price,
    required this.multiple,
    required this.selected,
    required this.onTap,
    this.free = false,
  });

  final String label;
  final String price;
  final bool multiple;
  final bool selected;
  final bool free;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = accentOf(context);
    final icon = multiple
        ? (selected ? Icons.check_box_rounded : Icons.check_box_outline_blank)
        : (selected ? Icons.radio_button_checked : Icons.radio_button_off);

    return Semantics(
      checked: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  icon,
                  key: ValueKey(selected),
                  size: 24,
                  color: selected ? accent : const Color(0xFFB5BCC7),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              Text(
                price,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: free ? mutedText : const Color(0xFF3A4250),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Always in view at the bottom: how many, and the button with the total
/// on it — or, while a required group is empty, which one to fill.
class _AddBar extends StatelessWidget {
  const _AddBar({
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
    required this.label,
    required this.onPressed,
  });

  final int quantity;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              QuantityStepper(
                quantity: quantity,
                onDecrement: onDecrement,
                onIncrement: onIncrement,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: onPressed,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(label, maxLines: 1),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

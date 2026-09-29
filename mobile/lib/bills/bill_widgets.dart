import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../theme.dart';
import 'bill_models.dart';
import 'bills_repository.dart';

/// A provider's logo on a white tile — or, until the admin uploads one, its
/// name on a tile in the brand's colour, so the screen never looks broken.
class BillProviderLogo extends StatelessWidget {
  const BillProviderLogo({required this.provider, this.size = 56, super.key});

  final BillProvider provider;
  final double size;

  /// Brand colours of the providers seeded by the backend migration; any
  /// other provider gets a neutral dark tile.
  static const _brandColors = {
    'STEG': Color(0xFF1B4F9C),
    'SONEDE': Color(0xFF0093D0),
    'TUNISIE TELECOM': Color(0xFF0060A9),
    'TOPNET': Color(0xFFE2001A),
    'IZI – BANQUE ZITOUNA': Color(0xFF00843D),
    'WAFA CASH': Color(0xFFF39200),
  };

  Color get _color =>
      _brandColors[provider.name.toUpperCase()] ?? const Color(0xFF2D3748);

  /// "STEG", "IZI", "Wafa Cash" -> short enough to fit the tile.
  String get _label {
    final name = provider.name.split('–').first.trim();
    final words = name.split(RegExp(r'\s+'));
    if (name.length <= 6) return name.toUpperCase();
    return words.map((w) => w.isEmpty ? '' : w[0]).join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.24);
    final logoUrl = provider.logoUrl;

    if (logoUrl != null) {
      return Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.1),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: radius,
          border: Border.all(color: cardBorder),
        ),
        child: Image.network(
          AppConfig.resolvePhotoUrl(logoUrl),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stack) => _badge(radius),
        ),
      );
    }

    return _badge(radius);
  }

  Widget _badge(BorderRadius radius) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(color: _color, borderRadius: radius),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          _label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: size * 0.26,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

/// The client's photo of their bill. It isn't public (see the backend's
/// OrderController::billPhoto), so it loads with the bearer token; tapping
/// it opens it full screen, zoomable, for reading the numbers.
class BillPhotoThumbnail extends StatelessWidget {
  const BillPhotoThumbnail({required this.photoUrl, super.key});

  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    final headers = context.read<BillsRepository>().photoHeaders;
    final url = AppConfig.resolvePhotoUrl(photoUrl);

    Widget image(BoxFit fit) => Image.network(
      url,
      headers: headers,
      fit: fit,
      errorBuilder: (context, error, stack) => const Center(
        child: Icon(Icons.broken_image_outlined, color: mutedText),
      ),
    );

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              // The theme's app bar title style is dark; this one sits on
              // black.
              title: const Text(
                'Photo de la facture',
                style: TextStyle(color: Colors.white),
              ),
            ),
            body: InteractiveViewer(
              maxScale: 5,
              child: Center(child: image(BoxFit.contain)),
            ),
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 88,
          height: 88,
          color: fieldFill,
          child: image(BoxFit.cover),
        ),
      ),
    );
  }
}

/// Provider, reference (or who receives the mandat), amount and photo — the
/// same block on the client's order page and the courier's job page.
class BillDetailsCard extends StatelessWidget {
  const BillDetailsCard({
    required this.bill,
    this.recipientName,
    this.recipientPhone,
    this.onCallRecipient,
    super.key,
  });

  final BillInfo bill;
  final String? recipientName;
  final String? recipientPhone;

  /// Shown as a call button next to the mandat's receiver (courier side).
  final VoidCallback? onCallRecipient;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                BillProviderLogo(provider: bill.provider, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bill.isTransfer ? 'Mandat' : 'Facture',
                        style: textTheme.bodySmall?.copyWith(color: mutedText),
                      ),
                      Text(
                        bill.provider.name,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${bill.amount} DT',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (bill.isTransfer)
              _Line(
                icon: Icons.person_outline,
                label: 'Bénéficiaire',
                value: [
                  recipientName,
                  recipientPhone,
                ].whereType<String>().join(' · '),
                trailing: onCallRecipient == null
                    ? null
                    : IconButton(
                        tooltip: 'Appeler le bénéficiaire',
                        onPressed: onCallRecipient,
                        icon: const Icon(Icons.phone),
                      ),
              )
            else
              _Line(
                icon: Icons.tag,
                label: 'Référence',
                value: bill.reference ?? '—',
              ),
            if (bill.photoUrl != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  BillPhotoThumbnail(photoUrl: bill.photoUrl!),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Photo de la facture\nAppuyez pour agrandir',
                      style: textTheme.bodySmall?.copyWith(color: mutedText),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: mutedText),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: textTheme.bodySmall?.copyWith(color: mutedText),
              ),
              Text(
                value,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

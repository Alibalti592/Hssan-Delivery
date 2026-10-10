import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../addresses/address_picker.dart';
import '../addresses/selected_address.dart';
import '../client/order_confirmed_screen.dart';
import '../core/api_exception.dart';
import '../core/phone_format.dart';
import '../theme.dart';
import '../widgets/dark_header.dart';
import 'bill_models.dart';
import 'bill_widgets.dart';
import 'bills_repository.dart';

/// Picks a photo from the camera or the gallery; swapped out in tests.
typedef BillPhotoPicker = Future<XFile?> Function(ImageSource source);

/// Details of one Factures request: the bill's reference (or, for a mandat,
/// who receives the money), the amount, an optional photo of the bill, and
/// where the courier collects the cash. Shows what to hand the courier —
/// the amount plus the zone's delivery fee — before sending.
class BillFormScreen extends StatefulWidget {
  const BillFormScreen({required this.provider, this.pickPhoto, super.key});

  final BillProvider provider;
  final BillPhotoPicker? pickPhoto;

  /// Mirrors the backend's BillOrderService::MAX_AMOUNT.
  static const maxAmount = 2000;

  @override
  State<BillFormScreen> createState() => _BillFormScreenState();
}

class _BillFormScreenState extends State<BillFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reference = TextEditingController();
  final _amount = TextEditingController();
  final _recipientName = TextEditingController();
  final _recipientPhone = TextEditingController();
  final _note = TextEditingController();
  AddressSelection? _selection;
  XFile? _photo;
  Uint8List? _photoBytes;
  bool _submitting = false;
  String? _error;

  bool get _isTransfer => widget.provider.isTransfer;

  @override
  void initState() {
    super.initState();
    _amount.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _reference.dispose();
    _amount.dispose();
    _recipientName.dispose();
    _recipientPhone.dispose();
    _note.dispose();
    super.dispose();
  }

  /// "85,5" or "85.5" -> "85.5"; null when it isn't a positive amount with
  /// at most 3 decimals.
  static String? _normalizeAmount(String raw) {
    final value = raw.trim().replaceAll(',', '.');
    if (!RegExp(r'^\d{1,7}(\.\d{1,3})?$').hasMatch(value)) return null;
    return value;
  }

  String? _validateAmount(String? raw) {
    final value = _normalizeAmount(raw ?? '');
    if (value == null) return 'Montant invalide';
    final amount = double.parse(value);
    if (amount <= 0) return 'Montant invalide';
    if (amount > BillFormScreen.maxAmount) {
      return 'Maximum ${BillFormScreen.maxAmount} DT par demande';
    }
    return null;
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picker =
        widget.pickPhoto ??
        (source) => ImagePicker().pickImage(
          source: source,
          maxWidth: 1600,
          imageQuality: 80,
        );
    try {
      final photo = await picker(source);
      if (photo == null) return;
      final bytes = await photo.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photo = photo;
        _photoBytes = bytes;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible d'ouvrir la photo.")),
      );
    }
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    final place = _selection!;

    final bills = context.read<BillsRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _submitting = true);
    try {
      var order = await bills.createBillOrder(
        providerId: widget.provider.id,
        amount: _normalizeAmount(_amount.text)!,
        address: place.address.fullText,
        deliveryZoneId: place.zone!.id,
        latitude: place.address.latitude,
        longitude: place.address.longitude,
        reference: _isTransfer ? null : _reference.text.trim(),
        recipientName: _isTransfer ? _recipientName.text.trim() : null,
        recipientPhone: _isTransfer ? _recipientPhone.text.trim() : null,
        note: _note.text.trim(),
      );

      if (_photoBytes != null) {
        try {
          order = await bills.uploadBillPhoto(
            order.id,
            bytes: _photoBytes!,
            filename: _photo!.name,
          );
        } on Exception {
          // The request itself went through; the courier still gets the
          // reference, so don't make the client start over.
          messenger.showSnackBar(
            const SnackBar(
              content: Text(
                "Demande envoyée, mais la photo n'a pas pu être jointe.",
              ),
            ),
          );
        }
      }

      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => OrderConfirmedScreen(order: order)),
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
    final provider = widget.provider;

    return Scaffold(
      body: SafeArea(
        // DarkHeader pads itself for the status bar.
        top: false,
        bottom: false,
        child: Column(
          children: [
            DarkHeader(
              title: provider.name,
              subtitle: _isTransfer ? 'Envoyer un mandat' : 'Payer une facture',
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
                      Row(
                        children: [
                          BillProviderLogo(provider: provider, size: 48),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _isTransfer
                                  ? 'Le livreur récupère l’argent chez vous, '
                                        'envoie le mandat et vous rapporte le reçu.'
                                  : 'Le livreur récupère la facture et l’argent '
                                        'chez vous, la paie et vous rapporte le reçu.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (_isTransfer) ...[
                        TextFormField(
                          controller: _recipientName,
                          enabled: !_submitting,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Nom du bénéficiaire',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Nom requis'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _recipientPhone,
                          enabled: !_submitting,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Téléphone du bénéficiaire',
                          ),
                          validator: validatePhone,
                        ),
                      ] else
                        TextFormField(
                          controller: _reference,
                          enabled: !_submitting,
                          decoration: const InputDecoration(
                            labelText: 'Référence de la facture',
                            helperText: 'Numéro de contrat ou de facture',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Référence requise'
                              : null,
                        ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _amount,
                        enabled: !_submitting,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: _isTransfer
                              ? 'Montant à envoyer'
                              : 'Montant de la facture',
                          suffixText: 'DT',
                        ),
                        validator: _validateAmount,
                      ),
                      if (!_isTransfer) ...[
                        const SizedBox(height: 20),
                        _PhotoPicker(
                          bytes: _photoBytes,
                          enabled: !_submitting,
                          onPick: _pickPhoto,
                          onRemove: () => setState(() {
                            _photo = null;
                            _photoBytes = null;
                          }),
                        ),
                      ],
                      const SizedBox(height: 20),
                      AddressField(
                        label: _isTransfer
                            ? "Récupérer l'argent à"
                            : 'Récupérer la facture à',
                        enabled: !_submitting,
                        allowOneOff: true,
                        initialAddress: context
                            .read<SelectedAddressController>()
                            .current,
                        onChanged: (v) => setState(() => _selection = v),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _note,
                        enabled: !_submitting,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Note pour le livreur (optionnel)',
                        ),
                      ),
                      const SizedBox(height: 20),
                      _CashSummary(
                        amount: _normalizeAmount(_amount.text),
                        fee: _selection?.zone?.fee,
                        isTransfer: _isTransfer,
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
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _isTransfer
                                    ? 'ENVOYER LE MANDAT'
                                    : 'PAYER LA FACTURE',
                              ),
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

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.bytes,
    required this.enabled,
    required this.onPick,
    required this.onRemove,
  });

  final Uint8List? bytes;
  final bool enabled;
  final void Function(ImageSource) onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Photo de la facture (optionnel)',
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Aide le livreur à retrouver la bonne facture.',
            style: textTheme.bodySmall?.copyWith(color: mutedText),
          ),
          const SizedBox(height: 12),
          if (bytes != null)
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(
                    bytes!,
                    width: 88,
                    height: 88,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      OutlinedButton.icon(
                        onPressed: enabled
                            ? () => onPick(ImageSource.camera)
                            : null,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Reprendre'),
                      ),
                      TextButton.icon(
                        onPressed: enabled ? onRemove : null,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Retirer'),
                      ),
                    ],
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: enabled
                        ? () => onPick(ImageSource.camera)
                        : null,
                    icon: const Icon(Icons.photo_camera_outlined, size: 18),
                    label: const Text('Caméra'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: enabled
                        ? () => onPick(ImageSource.gallery)
                        : null,
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('Galerie'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// "What to hand the courier": amount + delivery fee, as soon as both are
/// known.
class _CashSummary extends StatelessWidget {
  const _CashSummary({
    required this.amount,
    required this.fee,
    required this.isTransfer,
  });

  final String? amount;
  final String? fee;
  final bool isTransfer;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final amountValue = amount == null ? null : double.tryParse(amount!);
    final feeValue = fee == null ? null : double.tryParse(fee!);
    final total = (amountValue != null && feeValue != null)
        ? (amountValue + feeValue).toStringAsFixed(3)
        : null;

    Widget row(String label, String value, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: bold
                ? textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)
                : textTheme.bodyMedium,
          ),
          Text(
            value,
            style: bold
                ? textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)
                : textTheme.bodyMedium,
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fieldFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          row(
            isTransfer ? 'Montant du mandat' : 'Montant de la facture',
            amountValue == null ? '—' : '${amountValue.toStringAsFixed(3)} DT',
          ),
          row('Frais de livraison', fee == null ? '—' : '$fee DT'),
          const Divider(height: 18),
          row(
            'À remettre au livreur',
            total == null ? '—' : '$total DT',
            bold: true,
          ),
        ],
      ),
    );
  }
}

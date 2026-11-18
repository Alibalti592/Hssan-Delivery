import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/widgets/app_photo.dart';

void main() {
  test('photos decode at the size shown, in device pixels', () {
    // A restaurant card's photo has no width of its own: it decodes at the
    // card's width. Decoding the full upload instead (a logo can be
    // thousands of pixels wide) made the home feed stutter and freeze.
    expect(AppPhoto.decodeWidth(300, 2), 600);
    expect(AppPhoto.decodeWidth(120.4, 3), 361);
    // Nothing bounds it: full size is the only option.
    expect(AppPhoto.decodeWidth(double.infinity, 2), isNull);
    expect(AppPhoto.decodeWidth(0, 2), isNull);
  });

  test('photos come in the smallest copy wide enough', () {
    // A dish in a menu: 96 wide on a 3x phone.
    expect(
      AppPhoto.variantPath('/uploads/products/abc.jpg', 288),
      '/uploads/products/w480/abc.webp',
    );
    // A card on the home screen.
    expect(
      AppPhoto.variantPath('/uploads/restaurants/logo.png', 700),
      '/uploads/restaurants/w960/logo.webp',
    );
    // Full width on most phones still takes the 960 copy.
    expect(
      AppPhoto.variantPath('/uploads/products/abc.jpeg', 1080),
      '/uploads/products/w960/abc.webp',
    );
    // Wider than that, or size unknown: the original.
    expect(AppPhoto.variantPath('/uploads/products/abc.jpg', 1300), isNull);
    expect(AppPhoto.variantPath('/uploads/products/abc.jpg', null), isNull);
    // Not a catalogue upload: no copies to ask for.
    expect(AppPhoto.variantPath('/api/orders/3/bill-photo', 300), isNull);
  });
}

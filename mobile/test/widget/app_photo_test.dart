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
}

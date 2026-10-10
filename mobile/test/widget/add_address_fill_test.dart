import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile/addresses/address_repository.dart';
import 'package:mobile/addresses/pin_map.dart';
import 'package:mobile/addresses/reverse_geocoder.dart';
import 'package:mobile/client/add_address_screen.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/orders/orders_repository.dart';
import 'package:provider/provider.dart';

import 'test_utils.dart';

/// Answers every lookup with [answer], counting them.
class _FakeGeocoder extends ReverseGeocoder {
  _FakeGeocoder(this.answer);

  String? answer;
  final asked = <LatLng>[];

  @override
  Future<String?> addressAt(LatLng point) async {
    asked.add(point);
    return answer;
  }
}

/// The zone the server says covers a pin (null: none, a 404).
Map<String, dynamic>? _locatedZone;
final _locateAsked = <String>[];

Widget _app() {
  final api = ApiClient(
    tokenProvider: () => 'jwt-123',
    onUnauthorized: () {},
    httpClient: MockClient((request) async {
      if (request.url.path == '/api/delivery-zones/locate') {
        _locateAsked.add(request.url.query);
        return _locatedZone == null
            ? jsonResponse({'message': 'Aucune zone'}, 404)
            : jsonResponse(_locatedZone!);
      }
      return jsonResponse([
        {'id': 1, 'name': 'Bizerte centre', 'fee': '4.000'},
        {'id': 2, 'name': 'Corniche', 'fee': '5.000'},
      ]);
    }),
  );
  return MultiProvider(
    providers: [
      Provider<AddressRepository>.value(value: AddressRepository(api)),
      Provider<OrdersRepository>.value(value: OrdersRepository(api)),
    ],
    child: const MaterialApp(home: AddAddressScreen()),
  );
}

Finder get _addressField => find.widgetWithText(TextFormField, 'Adresse');

String _addressText(WidgetTester tester) =>
    tester.widget<TextFormField>(_addressField).controller!.text;

/// A tap on the map, then the wait for the pin to settle and the lookup.
Future<void> _tapMap(WidgetTester tester, Offset offset) async {
  await tester.tapAt(tester.getCenter(find.byType(FlutterMap)) + offset);
  // Past flutter_map's double-tap window, then the settle delay.
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pumpAndSettle();
}

void main() {
  late ReverseGeocoder real;
  setUp(() {
    PinMap.offline = true;
    real = ReverseGeocoder.instance;
    _locatedZone = null;
    _locateAsked.clear();
  });
  tearDown(() => ReverseGeocoder.instance = real);

  testWidgets('tapping the map puts the pin there and fills the address in', (
    tester,
  ) async {
    final geocoder = _FakeGeocoder('12 Rue de Marseille, Bizerte');
    ReverseGeocoder.instance = geocoder;
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(_addressText(tester), isEmpty);

    await _tapMap(tester, const Offset(40, 30));

    expect(geocoder.asked, hasLength(1));
    expect(geocoder.asked.single, isNot(defaultMapCenter));
    expect(_addressText(tester), '12 Rue de Marseille, Bizerte');

    // Placed again: the filled-in address follows the pin.
    geocoder.answer = 'Avenue Habib Bourguiba, Corniche, Bizerte';
    await _tapMap(tester, const Offset(-30, -20));
    expect(_addressText(tester), 'Avenue Habib Bourguiba, Corniche, Bizerte');
  });

  testWidgets('never replaces an address the client typed', (tester) async {
    final geocoder = _FakeGeocoder('12 Rue de Marseille, Bizerte');
    ReverseGeocoder.instance = geocoder;
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.enterText(_addressField, 'Chez Ali, derrière la poste');
    await _tapMap(tester, const Offset(40, 30));

    expect(_addressText(tester), 'Chez Ali, derrière la poste');
  });

  testWidgets('the zone covering the pin is filled in by itself', (
    tester,
  ) async {
    ReverseGeocoder.instance = _FakeGeocoder('Corniche, Bizerte');
    _locatedZone = {'id': 2, 'name': 'Corniche', 'fee': '5.000'};
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await _tapMap(tester, const Offset(40, 30));

    expect(_locateAsked, hasLength(1));
    expect(find.text('Corniche — 5.000 DT'), findsOneWidget);
    expect(
      find.text("Choisie d'après la position sur la carte"),
      findsOneWidget,
    );
  });

  testWidgets('a zone the client picked stays when the pin moves', (
    tester,
  ) async {
    ReverseGeocoder.instance = _FakeGeocoder('Bizerte');
    _locatedZone = {'id': 2, 'name': 'Corniche', 'fee': '5.000'};
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Zone de livraison'));
    await tester.tap(find.text('Zone de livraison'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bizerte centre — 4.000 DT').last);
    await tester.pumpAndSettle();

    await _tapMap(tester, const Offset(40, 30));

    expect(find.text('Bizerte centre — 4.000 DT'), findsOneWidget);
    expect(find.text('Corniche — 5.000 DT'), findsNothing);
  });

  testWidgets('outside every zone, the client picks it', (tester) async {
    ReverseGeocoder.instance = _FakeGeocoder('Menzel Jemil');
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await _tapMap(tester, const Offset(40, 30));

    expect(_locateAsked, hasLength(1));
    expect(find.textContaining('DT'), findsNothing);
    expect(find.text("Choisie d'après la position sur la carte"), findsNothing);
  });

  test('formats a Nominatim result as number street, area, town', () {
    expect(
      ReverseGeocoder.formatAddress({
        'address': {
          'house_number': '12',
          'road': 'Rue de Marseille',
          'suburb': 'Bizerte Nord',
          'city': 'Bizerte',
          'country': 'Tunisie',
        },
      }),
      '12 Rue de Marseille, Bizerte Nord, Bizerte',
    );
    expect(
      ReverseGeocoder.formatAddress({
        'address': {'road': 'Avenue Habib Bourguiba', 'town': 'Menzel Jemil'},
      }),
      'Avenue Habib Bourguiba, Menzel Jemil',
    );
    expect(
      ReverseGeocoder.formatAddress({
        'address': <String, dynamic>{},
        'display_name': 'Corniche, Bizerte, Gouvernorat de Bizerte, Tunisie',
      }),
      'Corniche, Bizerte, Gouvernorat de Bizerte',
    );
    expect(ReverseGeocoder.formatAddress({'error': 'Unable to geocode'}), null);
  });
}

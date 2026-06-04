import 'package:flutter_test/flutter_test.dart';

import 'package:filstock/src/store.dart';
import 'package:filstock/src/storage.dart';

void main() {
  test('génération de code unique et incrément des compteurs', () {
    final store = AppStore(Storage());
    final c1 = store.generateSpoolCode('PLA', 'Noir');
    final c2 = store.generateSpoolCode('PLA', 'Noir');
    expect(c1, 'PLA-NOIR-001');
    expect(c2, 'PLA-NOIR-002');
  });

  test('export/import round-trip conserve les bobines', () {
    final store = AppStore(Storage());
    store.saveSpool(
      brand: 'Bambu',
      material: 'PLA',
      qty: 80,
      pack: 'open',
      loc: 'stock',
      type: 'mounted',
      notes: 'test',
      traits: const [],
      color: '#1a1a1a',
      colorName: 'Noir',
    );
    final json = store.exportJson();

    final other = AppStore(Storage());
    final res = other.importJson(json, merge: false);
    expect(res.added, 1);
    expect(other.spools.first.brand, 'Bambu');
    expect(other.spools.first.qty, 80);
  });
}

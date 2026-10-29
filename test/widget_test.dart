import 'package:flutter_test/flutter_test.dart';
import 'package:untitled13/models/cantique.dart';

void main() {
  group('Cantique.fromJson', () {
    test('maps a complete catalogue entry', () {
      final cantique = Cantique.fromJson({
        'id': 12,
        'titre': 'Espoir',
        'auteur': 'Chorale',
        'paroles': 'Couplet 1',
      });

      expect(cantique.id, '12');
      expect(cantique.titre, 'Espoir');
      expect(cantique.auteur, 'Chorale');
      expect(cantique.paroles, 'Couplet 1');
      expect(cantique.isFavorite, isFalse);
    });

    test('uses safe defaults for optional text fields', () {
      final cantique = Cantique.fromJson({'id': '13'});

      expect(cantique.id, '13');
      expect(cantique.titre, 'Sans titre');
      expect(cantique.auteur, 'Auteur inconnu');
      expect(cantique.paroles, isEmpty);
    });
  });
}

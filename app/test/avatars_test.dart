import 'package:flutter_test/flutter_test.dart';
import 'package:nestkeep/avatars.dart';

void main() {
  group('avatarById', () {
    test('falls back to the house avatar for null and unknown ids', () {
      expect(avatarById(null).id, 'house');
      expect(avatarById('').id, 'house');
      expect(avatarById('not-a-real-avatar').id, 'house');
      expect(avatarById(null).proOnly, isFalse);
    });

    test('resolves known free and pro ids', () {
      expect(avatarById('owl').label, 'Owl');
      expect(avatarById('owl').proOnly, isFalse);
      expect(avatarById('dragon').label, 'Dragon');
      expect(avatarById('dragon').proOnly, isTrue);
    });

    test('the custom photo avatar resolves outside the catalogue', () {
      // Build 20: id 'custom' is the user's own photo. It is not one
      // of the 12 catalogue entries (the picker adds it as a last
      // tile), and it is Pro-only.
      expect(avatarById('custom').id, 'custom');
      expect(avatarById('custom').label, 'Yours');
      expect(avatarById('custom').proOnly, isTrue);
      expect(avatarCatalogue.any((a) => a.id == 'custom'), isFalse);
    });
  });

  group('catalogue', () {
    test('has 12 avatars: 6 free and 6 pro', () {
      expect(avatarCatalogue.length, 12);
      expect(avatarCatalogue.where((a) => !a.proOnly).length, 6);
      expect(avatarCatalogue.where((a) => a.proOnly).length, 6);
    });

    test('ids are unique and every entry has an emoji and a label', () {
      expect(avatarCatalogue.map((a) => a.id).toSet().length, 12);
      expect(
        avatarCatalogue.every((a) => a.emoji.isNotEmpty && a.label.isNotEmpty),
        isTrue,
      );
    });
  });
}

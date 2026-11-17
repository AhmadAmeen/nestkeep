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

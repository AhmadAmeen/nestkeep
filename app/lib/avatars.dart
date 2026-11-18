/// The avatar catalogue: a little personality for the Today header and
/// Profile, drawn with emoji so there are no image assets to ship.
/// Six are free; six are a quiet Pro extra. Picking one is cosmetic
/// only, and a lapsed Pro keeps the avatar they already chose.
class AvatarDef {
  final String id;
  final String emoji;
  final String label;
  final bool proOnly;

  const AvatarDef({
    required this.id,
    required this.emoji,
    required this.label,
    this.proOnly = false,
  });
}

/// The catalogue, free first. The first entry (house) is the default
/// and the fallback for any unknown stored id.
const avatarCatalogue = [
  AvatarDef(id: 'house', emoji: '🏠', label: 'House'),
  AvatarDef(id: 'owl', emoji: '🦉', label: 'Owl'),
  AvatarDef(id: 'sunflower', emoji: '🌻', label: 'Sunflower'),
  AvatarDef(id: 'cat', emoji: '🐱', label: 'Cat'),
  AvatarDef(id: 'wrench', emoji: '🔧', label: 'Fixer'),
  AvatarDef(id: 'star', emoji: '⭐', label: 'Star'),
  AvatarDef(id: 'crown', emoji: '👑', label: 'Crown', proOnly: true),
  AvatarDef(id: 'rocket', emoji: '🚀', label: 'Rocket', proOnly: true),
  AvatarDef(id: 'lion', emoji: '🦁', label: 'Lion', proOnly: true),
  AvatarDef(id: 'robot', emoji: '🤖', label: 'Robot', proOnly: true),
  AvatarDef(id: 'gem', emoji: '💎', label: 'Gem', proOnly: true),
  AvatarDef(id: 'dragon', emoji: '🐲', label: 'Dragon', proOnly: true),
];

/// The user's own photo avatar (build 20, Pro): not a catalogue
/// entry — the picker adds it as a final tile of its own. The photo
/// itself lives in the app documents folder as custom_avatar.jpg,
/// local only, never synced, like receipt photos. The emoji here is
/// only a placeholder glyph; wherever avatars render, a stored photo
/// replaces it, and a missing photo falls back to the house avatar.
const customAvatarDef = AvatarDef(
  id: 'custom',
  emoji: '📷',
  label: 'Yours',
  proOnly: true,
);

/// Resolve a stored avatar id, falling back to the house avatar for
/// null or unknown values.
AvatarDef avatarById(String? id) {
  if (id == customAvatarDef.id) return customAvatarDef;
  for (final a in avatarCatalogue) {
    if (a.id == id) return a;
  }
  return avatarCatalogue.first;
}

import 'dart:io';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../db.dart';
import '../models.dart';
import '../plan.dart';
import '../sync.dart';
import '../theme.dart';
import '../widgets.dart';
import '../widgets/home_photo.dart';

/// Human labels for the stored home-type values, matching the words
/// onboarding used when it asked.
String homeTypeLabel(String type) => switch (type) {
      'townhouse' => 'Townhouse',
      'condo' => 'Condo',
      'apartment' => 'Apartment',
      _ => 'House',
    };

String _heatingLabel(String heating) => switch (heating) {
      'heat_pump' => 'Heat pump',
      'boiler' => 'Boiler / radiators',
      'none' => 'Other / none',
      _ => 'Forced air furnace',
    };

String _coolingLabel(String cooling) => switch (cooling) {
      'window' => 'Window units',
      'none' => 'No AC',
      _ => 'Central AC',
    };

String _climateLabel(String climate) => switch (climate) {
      'cold' => 'Freezing cold',
      'hot' => 'Rarely cold',
      _ => 'Mild',
    };

/// The home's facts on one screen: its photo (build 20), name, type,
/// year built and the onboarding answers that shape the plan — all
/// editable since build 20 via the Edit action, using the wizard's
/// own option lists. Editing updates the stored facts only: it never
/// regenerates the plan or changes the user's chosen jobs (the
/// build-10 selection governs those).
class HomeDetailsScreen extends StatefulWidget {
  final AppState state;
  final VoidCallback onOpenPaywall;

  const HomeDetailsScreen({
    super.key,
    required this.state,
    required this.onOpenPaywall,
  });

  @override
  State<HomeDetailsScreen> createState() => _HomeDetailsScreenState();
}

class _HomeDetailsScreenState extends State<HomeDetailsScreen> {
  AppState get state => widget.state;

  bool _editing = false;
  final TextEditingController _name = TextEditingController();
  String _type = 'house';
  String _heating = 'forced_air';
  String _cooling = 'central';
  String _climate = 'mild';
  Set<String> _features = {};

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _startEdit() {
    final home = state.activeHome!;
    final profile = state.profileFor(home.id);
    _name.text = home.name;
    _type = profile?.homeType ?? home.type;
    _heating = profile?.heating ?? 'forced_air';
    _cooling = profile?.cooling ?? 'central';
    _climate = profile?.climate ?? 'mild';
    _features = {
      for (final (key, _) in homeFeatureOptions)
        if (profile?.feature(key) ?? false) key,
    };
    setState(() => _editing = true);
  }

  Future<void> _save() async {
    final home = state.activeHome!;
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final updatedHome = Home(
      id: home.id,
      name: name,
      addressLine: home.addressLine,
      type: _type,
      yearBuilt: home.yearBuilt,
      sqft: home.sqft,
      updatedAt: DateTime.now(),
    );
    final base = state.profileFor(home.id) ??
        const HomeProfile(
          homeType: 'house',
          heating: 'forced_air',
          cooling: 'central',
          hasBasement: false,
          hasGarage: false,
          hasDeck: false,
          hasSprinklers: false,
          hasSoftener: false,
          hasChimney: false,
        );
    var profile = base.copyWith(
      homeType: _type,
      heating: _heating,
      cooling: _cooling,
      climate: _climate,
    );
    for (final (key, _) in homeFeatureOptions) {
      profile = profile.withFeature(key, _features.contains(key));
    }
    await AppDb.updateHome(updatedHome);
    await saveProfile(home.id!, profile);
    // Mirror into state the way other edits do, then reload + sync.
    // Facts only: no plan regeneration, no selection change.
    state.profiles[home.id!] = profile;
    final i = state.homes.indexWhere((h) => h.id == home.id);
    if (i >= 0) state.homes[i] = updatedHome;
    state.activeHome = updatedHome;
    await state.reload();
    SyncService.syncNow();
    if (!mounted) return;
    setState(() => _editing = false);
    showTicker(context, 'Home updated');
  }

  @override
  Widget build(BuildContext context) {
    final home = state.activeHome!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home details'),
        actions: [
          if (_editing)
            TextButton(
              onPressed: () => setState(() => _editing = false),
              child: const Text('Cancel'),
            )
          else
            TextButton(
              onPressed: _startEdit,
              child: const Text('Edit'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _photoSection(context, home),
          const SizedBox(height: 20),
          if (_editing) ..._editForm(context, home) else ..._facts(context, home),
        ],
      ),
    );
  }

  /// The home's photo at the top (build 20): the picture itself when
  /// one is set (tap to replace or remove), otherwise an add row.
  /// Adding or replacing is Pro since build 21 (a free tap opens the
  /// paywall); a photo already set stays visible and removable for
  /// everyone. The file lives on this phone only.
  Widget _photoSection(BuildContext context, Home home) {
    final path = state.homePhotoPath(home.id!);
    final file = path == null ? null : File(path);
    if (file != null && file.existsSync()) {
      return GestureDetector(
        onTap: () => showHomePhotoActions(context, state, home.id!,
            onOpenPaywall: widget.onOpenPaywall),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.file(file, fit: BoxFit.cover),
          ),
        ),
      );
    }
    return NkCard(
      onTap: () => pickHomePhoto(context, state, home.id!,
          replacing: false, onOpenPaywall: widget.onOpenPaywall),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: context.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(Icons.add_a_photo_outlined,
                color: context.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add home photo',
                  style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: context.navyText),
                ),
                Text(
                  'A picture of your home, kept on this phone',
                  style: TextStyle(fontSize: 13, color: context.muted),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: context.muted),
        ],
      ),
    );
  }

  List<Widget> _facts(BuildContext context, Home home) {
    final profile = state.profileFor(home.id);
    final features = profile == null
        ? const <String>[]
        : <String>[
            if (profile.hasBasement) 'Basement / crawlspace',
            if (profile.hasGarage) 'Garage',
            if (profile.hasDeck) 'Deck / patio',
            if (profile.hasSprinklers) 'Sprinkler system',
            if (profile.hasSoftener) 'Water softener',
            if (profile.hasChimney) 'Fireplace / chimney',
            if (profile.hasPool) 'Pool / hot tub',
            if (profile.hasSeptic) 'Septic system',
            if (profile.hasWell) 'Well water',
            if (profile.hasSolar) 'Solar panels',
            if (profile.hasGenerator) 'Standby generator',
            if (profile.hasEvCharger) 'EV charger',
          ];
    return [
      NkCard(
        child: Column(
          children: [
            _fact(context, 'Name', home.name),
            _divider(context),
            if (home.addressLine.isNotEmpty) ...[
              _fact(context, 'Address', home.addressLine),
              _divider(context),
            ],
            _fact(context, 'Type', homeTypeLabel(home.type)),
            _divider(context),
            _fact(context, 'Built', '${home.yearBuilt}'),
            if (home.sqft != null) ...[
              _divider(context),
              _fact(context, 'Size', '${home.sqft} sq ft'),
            ],
          ],
        ),
      ),
      if (profile != null) ...[
        const SizedBox(height: 20),
        const SectionHeading('About this home'),
        const SizedBox(height: 10),
        NkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fact(context, 'Heating', _heatingLabel(profile.heating)),
              _divider(context),
              _fact(context, 'Cooling', _coolingLabel(profile.cooling)),
              _divider(context),
              _fact(context, 'Winters', _climateLabel(profile.climate)),
              if (features.isNotEmpty) ...[
                _divider(context),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('What it has',
                          style: TextStyle(
                              fontSize: 13, color: context.muted)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final f in features)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: context.primary
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check,
                                      size: 13, color: context.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    f,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: context.navyText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'These answers shape which jobs the plan suggests. Changing '
          'them updates the facts only — the jobs you chose stay as '
          'they are.',
          style: TextStyle(fontSize: 13, color: context.muted, height: 1.4),
        ),
      ],
    ];
  }

  List<Widget> _editForm(BuildContext context, Home home) {
    return [
      NkCard(
        child: TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Home name'),
        ),
      ),
      const SizedBox(height: 20),
      const SectionHeading('About this home'),
      const SizedBox(height: 10),
      NkCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _question('What kind of home?'),
            _chips(homeTypeOptions, _type, (v) => setState(() => _type = v)),
            const SizedBox(height: 18),
            _question('How is it heated?'),
            _chips(heatingOptions, _heating,
                (v) => setState(() => _heating = v)),
            const SizedBox(height: 18),
            _question('How is it cooled?'),
            _chips(coolingOptions, _cooling,
                (v) => setState(() => _cooling = v)),
            const SizedBox(height: 18),
            _question('Winters where you live?'),
            _chips(climateOptions, _climate,
                (v) => setState(() => _climate = v)),
            const SizedBox(height: 18),
            _question('What does it have?'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (key, label) in homeFeatureOptions)
                  FilterChip(
                    label: Text(label),
                    selected: _features.contains(key),
                    onSelected: (on) => setState(() {
                      if (on) {
                        _features.add(key);
                      } else {
                        _features.remove(key);
                      }
                    }),
                  ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: _save,
        child: const Text('Save changes'),
      ),
      const SizedBox(height: 12),
      Text(
        'Saving updates the facts only. Your plan and your chosen '
        'jobs do not change.',
        style: TextStyle(fontSize: 13, color: context.muted, height: 1.4),
      ),
    ];
  }

  Widget _question(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _chips(
    List<(String, String)> options,
    String value,
    ValueChanged<String> onChanged,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (v, label) in options)
          ChoiceChip(
            label: Text(label),
            selected: value == v,
            onSelected: (on) {
              if (on) onChanged(v);
            },
          ),
      ],
    );
  }

  Widget _fact(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(label,
                style: TextStyle(fontSize: 13, color: context.muted)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: context.navyText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(BuildContext context) =>
      Divider(height: 1, color: context.line);
}

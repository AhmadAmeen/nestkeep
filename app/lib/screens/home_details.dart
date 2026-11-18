import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets.dart';

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

/// The home's facts on one screen (build 18): name, type, year built
/// and the onboarding answers that shape the plan. Read-only — the app
/// has never had an edit path for these; they were set when the home
/// was added.
class HomeDetailsScreen extends StatelessWidget {
  final AppState state;

  const HomeDetailsScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final home = state.activeHome!;
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
    return Scaffold(
      appBar: AppBar(title: const Text('Home details')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
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
              'These are the answers from when this home was set up. They decide which jobs the plan suggests.',
              style: TextStyle(fontSize: 13, color: context.muted, height: 1.4),
            ),
          ],
        ],
      ),
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

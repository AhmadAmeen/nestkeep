import 'package:flutter/material.dart';

import '../app_state.dart';
import '../db.dart';
import '../models.dart';
import '../plan.dart';
import '../reminders.dart';
import '../theme.dart';

/// First-run setup: a few questions about the home, then the full seasonal
/// plan is generated on the phone in under a minute. No sign-in wall, ever.
class OnboardingScreen extends StatefulWidget {
  final AppState state;
  final VoidCallback onDone;

  const OnboardingScreen({super.key, required this.state, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _name = TextEditingController(text: 'My home');
  final _address = TextEditingController();
  final _year = TextEditingController(text: '1998');
  String _type = 'house';
  String _heating = 'forced_air';
  String _cooling = 'central';
  bool _basement = true;
  bool _garage = true;
  bool _deck = true;
  bool _sprinklers = false;
  bool _softener = false;
  bool _chimney = false;
  bool _pool = false;
  bool _septic = false;
  bool _well = false;
  bool _solar = false;
  bool _generator = false;
  bool _evCharger = false;
  String _climate = 'mild';
  bool _building = false;

  Future<void> _build() async {
    setState(() => _building = true);
    final now = DateTime.now();
    final homeId = await AppDb.insertHome(Home(
      name: _name.text.trim().isEmpty ? 'My home' : _name.text.trim(),
      addressLine: _address.text.trim(),
      type: _type,
      yearBuilt: int.tryParse(_year.text.trim()) ?? 1998,
      updatedAt: now,
    ));
    final profile = HomeProfile(
      homeType: _type,
      heating: _heating,
      cooling: _cooling,
      hasBasement: _basement,
      hasGarage: _garage,
      hasDeck: _deck,
      hasSprinklers: _sprinklers,
      hasSoftener: _softener,
      hasChimney: _chimney,
      hasPool: _pool,
      hasSeptic: _septic,
      hasWell: _well,
      hasSolar: _solar,
      hasGenerator: _generator,
      hasEvCharger: _evCharger,
      climate: _climate,
    );
    await generatePlan(homeId, profile, widget.state.templates, now);
    await saveProfile(homeId, profile);
    widget.state.homes = await AppDb.homes();
    final home = widget.state.homes.firstWhere((h) => h.id == homeId);
    await widget.state.setActiveHome(home);
    await Reminders.requestPermissions();
    await Reminders.reschedule(widget.state.tasks);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            Text('Welcome home.',
                style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: context.navyText)),
            const SizedBox(height: 6),
            Text(
              'Answer a few questions and NestKeep builds your home\'s full '
              'maintenance plan: what to do, when, what it costs, and what it '
              'costs to ignore. No account needed, ever.',
              style: TextStyle(color: context.muted, height: 1.45, fontSize: 15),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Home name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _address,
              decoration: const InputDecoration(
                  labelText: 'Address line (just for your header)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _year,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Year built'),
            ),
            const SizedBox(height: 22),
            _question('What kind of home?'),
            _chips(
              value: _type,
              options: const [
                ('house', 'House'),
                ('townhouse', 'Townhouse'),
                ('condo', 'Condo'),
                ('apartment', 'Apartment'),
              ],
              onChanged: (v) => setState(() => _type = v),
            ),
            const SizedBox(height: 18),
            _question('How is it heated?'),
            _chips(
              value: _heating,
              options: const [
                ('forced_air', 'Forced air furnace'),
                ('heat_pump', 'Heat pump'),
                ('boiler', 'Boiler / radiators'),
                ('none', 'Other / none'),
              ],
              onChanged: (v) => setState(() => _heating = v),
            ),
            const SizedBox(height: 18),
            _question('How is it cooled?'),
            _chips(
              value: _cooling,
              options: const [
                ('central', 'Central AC'),
                ('window', 'Window units'),
                ('none', 'No AC'),
              ],
              onChanged: (v) => setState(() => _cooling = v),
            ),
            const SizedBox(height: 18),
            _question('Winters where you live?'),
            _chips(
              value: _climate,
              options: const [
                ('cold', 'Freezing cold'),
                ('mild', 'Mild'),
                ('hot', 'Rarely cold'),
              ],
              onChanged: (v) => setState(() => _climate = v),
            ),
            const SizedBox(height: 18),
            _question('What does it have?'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _toggle('Basement / crawlspace', _basement,
                    (v) => setState(() => _basement = v)),
                _toggle('Garage', _garage, (v) => setState(() => _garage = v)),
                _toggle('Deck / patio', _deck, (v) => setState(() => _deck = v)),
                _toggle('Sprinkler system', _sprinklers,
                    (v) => setState(() => _sprinklers = v)),
                _toggle('Water softener', _softener,
                    (v) => setState(() => _softener = v)),
                _toggle('Fireplace / chimney', _chimney,
                    (v) => setState(() => _chimney = v)),
                _toggle('Pool / hot tub', _pool,
                    (v) => setState(() => _pool = v)),
                _toggle('Septic system', _septic,
                    (v) => setState(() => _septic = v)),
                _toggle('Well water', _well, (v) => setState(() => _well = v)),
                _toggle('Solar panels', _solar,
                    (v) => setState(() => _solar = v)),
                _toggle('Standby generator', _generator,
                    (v) => setState(() => _generator = v)),
                _toggle('EV charger', _evCharger,
                    (v) => setState(() => _evCharger = v)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Only jobs that fit your answers make your plan. Everything '
              'else is left out, and every job in the plan says why it is there.',
              style: TextStyle(color: context.muted, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _building ? null : _build,
              child: Text(_building ? 'Building your plan…' : 'Build my plan'),
            ),
            const SizedBox(height: 10),
            Text(
              'Everything stays on this phone. An optional free account only adds backup.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: context.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _question(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text,
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700, color: context.navyText)),
    );
  }

  Widget _chips({
    required String value,
    required List<(String, String)> options,
    required void Function(String) onChanged,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options)
          ChoiceChip(
            label: Text(o.$2),
            selected: value == o.$1,
            onSelected: (_) => onChanged(o.$1),
          ),
      ],
    );
  }

  Widget _toggle(String label, bool value, void Function(bool) onChanged) {
    return FilterChip(
      label: Text(label),
      selected: value,
      onSelected: onChanged,
    );
  }
}

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../db.dart';
import '../models.dart';
import '../plan.dart';
import '../reminders.dart';
import '../theme.dart';
import '../widgets.dart';

/// First-run setup as a step wizard: one question focus per step, then
/// the full seasonal plan is generated on the phone in under a minute.
/// No sign-in wall, ever. Defaults are pre-filled on every step, so Next
/// is always available and going back never loses an answer.
class OnboardingScreen extends StatefulWidget {
  final AppState state;
  final VoidCallback onDone;

  const OnboardingScreen({super.key, required this.state, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _stepCount = 6;

  final _name = TextEditingController(text: 'My home');
  final _address = TextEditingController();
  final _year = TextEditingController(text: '1998');
  final _pages = PageController();
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
  int _step = 0;

  bool get _last => _step == _stepCount - 1;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _year.dispose();
    _pages.dispose();
    super.dispose();
  }

  HomeProfile get _profile => HomeProfile(
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

  void _goTo(int step) {
    setState(() => _step = step);
    _pages.animateToPage(
      step,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

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
    final profile = _profile;
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
        child: Column(
          children: [
            // Progress chrome: "Step X of 6" plus a progress bar.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Step ${_step + 1} of $_stepCount',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.muted),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (_step + 1) / _stepCount,
                      minHeight: 6,
                      backgroundColor: context.line,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _step = i),
                children: [
                  _stepPage([
                    _headline('Welcome home.'),
                    const SizedBox(height: 6),
                    Text(
                      'Answer a few questions and NestKeep builds your '
                      'home\'s full maintenance plan. No account needed, ever.',
                      style: TextStyle(
                          color: context.muted, height: 1.45, fontSize: 15),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _name,
                      decoration:
                          const InputDecoration(labelText: 'Home name'),
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
                      decoration:
                          const InputDecoration(labelText: 'Year built'),
                    ),
                  ]),
                  _stepPage([
                    _headline('What kind of home?'),
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
                  ]),
                  _stepPage([
                    _headline('Heating and cooling'),
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
                    const SizedBox(height: 22),
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
                  ]),
                  _stepPage([
                    _headline('Winters where you live?'),
                    _chips(
                      value: _climate,
                      options: const [
                        ('cold', 'Freezing cold'),
                        ('mild', 'Mild'),
                        ('hot', 'Rarely cold'),
                      ],
                      onChanged: (v) => setState(() => _climate = v),
                    ),
                  ]),
                  _stepPage([
                    _headline('What does it have?'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _toggle('Basement / crawlspace', _basement,
                            (v) => setState(() => _basement = v)),
                        _toggle('Garage', _garage,
                            (v) => setState(() => _garage = v)),
                        _toggle('Deck / patio', _deck,
                            (v) => setState(() => _deck = v)),
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
                        _toggle('Well water', _well,
                            (v) => setState(() => _well = v)),
                        _toggle('Solar panels', _solar,
                            (v) => setState(() => _solar = v)),
                        _toggle('Standby generator', _generator,
                            (v) => setState(() => _generator = v)),
                        _toggle('EV charger', _evCharger,
                            (v) => setState(() => _evCharger = v)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Only jobs that fit your answers make your plan. '
                      'Everything else is left out, and every job in the '
                      'plan says why it is there.',
                      style: TextStyle(
                          color: context.muted, fontSize: 13, height: 1.4),
                    ),
                  ]),
                  _summaryStep(),
                ],
              ),
            ),
            // Bottom navigation row: Back (from step 2 on) and Next,
            // replaced by the build button on the last step.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: [
                  if (_step > 0)
                    TextButton(
                      onPressed: _building ? null : () => _goTo(_step - 1),
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  if (_last)
                    FilledButton(
                      onPressed: _building ? null : _build,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 26, vertical: 13),
                        textStyle: const TextStyle(
                            fontSize: 15.5, fontWeight: FontWeight.w700),
                      ),
                      child: Text(
                          _building ? 'Building your plan…' : 'Build my plan'),
                    )
                  else
                    FilledButton(
                      onPressed: () => _goTo(_step + 1),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 26, vertical: 13),
                        textStyle: const TextStyle(
                            fontSize: 15.5, fontWeight: FontWeight.w700),
                      ),
                      child: const Text('Next'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Last step: the live plan summary for the answers given so far.
  Widget _summaryStep() {
    final templates = widget.state.templates;
    final included =
        templates.where((t) => templateApplies(t, _profile)).length;
    final leftOut = templates.length - included;
    return _stepPage([
      _headline('Your plan is ready'),
      NkCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$included jobs',
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: context.navyText),
            ),
            const SizedBox(height: 4),
            Text(
              'built for your home from your answers, each with steps, '
              'what it costs to do, and what it costs to skip.',
              style:
                  TextStyle(color: context.muted, height: 1.4, fontSize: 14.5),
            ),
            const SizedBox(height: 10),
            Text(
              '$leftOut left out because they do not apply to your home.',
              style:
                  TextStyle(color: context.muted, height: 1.4, fontSize: 14.5),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Icon(Icons.lock_outline, size: 18, color: context.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Everything stays on this phone. An optional free account '
              'only adds backup.',
              style: TextStyle(color: context.muted, fontSize: 13.5),
            ),
          ),
        ],
      ),
    ]);
  }

  Widget _stepPage(List<Widget> children) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: children,
    );
  }

  Widget _headline(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(text,
          style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: context.navyText)),
    );
  }

  Widget _question(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text,
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.navyText)),
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

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../db.dart';
import '../models.dart';
import '../plan.dart';
import '../reminders.dart';
import '../theme.dart';
import 'finding_jobs.dart';
import 'job_picker.dart';

/// First-run setup as a step wizard: one question focus per step, then
/// the user ticks exactly which library jobs they want and the plan is
/// built from those ticks on the phone in under a minute. No sign-in
/// wall, ever. Defaults are pre-filled on every step, so Next is always
/// available and going back never loses an answer.
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

  /// True while the "Finding jobs for you" loader covers the wizard,
  /// between the last question step and the job picker. The loader is
  /// not a numbered step: the progress chrome hides behind it.
  bool _showFinder = false;

  void _startFinder() => setState(() => _showFinder = true);

  void _finderDone() {
    setState(() => _showFinder = false);
    _goTo(_stepCount - 1);
  }

  /// The user's own ticks on the final step. Null until they change
  /// anything: before that, the picker follows the answers and pre-ticks
  /// every job that applies to this home.
  Set<String>? _pickedJobs;

  bool get _last => _step == _stepCount - 1;

  /// The jobs the plan will be built from: the user's ticks once they
  /// have made any, otherwise everything their answers say applies.
  Set<String> get _effectiveSelection =>
      _pickedJobs ??
      widget.state.templates
          .where((t) => templateApplies(t, _profile))
          .map((t) => t.id)
          .toSet();

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
    final selected = _effectiveSelection;
    await generatePlan(homeId, profile, widget.state.templates, now,
        onlyTemplateIds: selected);
    await savePlanSelection(homeId, selected);
    await saveProfile(homeId, profile);
    widget.state.homes = await AppDb.homes();
    final home = widget.state.homes.firstWhere((h) => h.id == homeId);
    await widget.state.setActiveHome(home);
    await Reminders.requestPermissions();
    await Reminders.reschedule(widget.state.tasks, widget.state.appliances);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
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
                        Image.asset('assets/icon.png', width: 64, height: 64),
                        const SizedBox(height: 16),
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
                          options: homeTypeOptions,
                          onChanged: (v) => setState(() => _type = v),
                        ),
                      ]),
                      _stepPage([
                        _headline('Heating and cooling'),
                        _question('How is it heated?'),
                        _chips(
                          value: _heating,
                          options: heatingOptions,
                          onChanged: (v) => setState(() => _heating = v),
                        ),
                        const SizedBox(height: 22),
                        _question('How is it cooled?'),
                        _chips(
                          value: _cooling,
                          options: coolingOptions,
                          onChanged: (v) => setState(() => _cooling = v),
                        ),
                      ]),
                      _stepPage([
                        _headline('Winters where you live?'),
                        _chips(
                          value: _climate,
                          options: climateOptions,
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
                          'Next you pick exactly which jobs go into your plan. '
                          'Nothing is added on its own: we pre-tick the jobs '
                          'that fit your answers, and you untick anything you '
                          'do not want.',
                          style: TextStyle(
                              color: context.muted, fontSize: 13, height: 1.4),
                        ),
                      ]),
                      _jobsStep(),
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
                          onPressed: _building || _effectiveSelection.isEmpty
                              ? null
                              : _build,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 26, vertical: 13),
                            textStyle: const TextStyle(
                                fontSize: 15.5, fontWeight: FontWeight.w700),
                          ),
                          child: Text(_building
                              ? 'Building your plan…'
                              : 'Build my plan · ${_effectiveSelection.length} jobs'),
                        )
                      else
                        FilledButton(
                          // From the last question, Next first plays the
                          // "Finding jobs for you" loader; the loader's
                          // onDone moves on to the picker step.
                          onPressed: () => _step == _stepCount - 2
                              ? _startFinder()
                              : _goTo(_step + 1),
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
            // The finder covers the whole wizard, progress chrome and
            // buttons included, while it plays; the PageView stays
            // mounted underneath so the step position is kept.
            if (_showFinder)
              Positioned.fill(
                child: ColoredBox(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: FindingJobsView(onDone: _finderDone),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Last step: the job picker. Every library job is listed, grouped by
  /// category; the ones that fit the answers are pre-ticked, everything
  /// else waits unticked. Only ticked jobs enter the plan.
  Widget _jobsStep() {
    return _stepPage([
      _headline('Choose your jobs'),
      Text(
        'Tick the jobs you want in your plan. Tap a job to see its steps.',
        style: TextStyle(color: context.muted, height: 1.45, fontSize: 15),
      ),
      const SizedBox(height: 16),
      JobPickerList(
        templates: widget.state.templates,
        selected: _effectiveSelection,
        onChanged: (s) => setState(() => _pickedJobs = s),
      ),
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
          _OptionTile(
            label: o.$2,
            selected: value == o.$1,
            onTap: () => onChanged(o.$1),
          ),
      ],
    );
  }

  Widget _toggle(String label, bool value, void Function(bool) onChanged) {
    return _OptionTile(
      label: label,
      selected: value,
      onTap: () => onChanged(!value),
    );
  }
}

/// One selectable answer in the wizard: a rounded tile with a hairline
/// border that picks up the app accent (2px border, tinted fill, soft
/// shadow, check mark) when selected. The modern form look, shared by
/// the single-choice questions and the feature toggles.
class _OptionTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = context.primary;
    return Container(
      decoration: BoxDecoration(
        color: selected
            ? accent.withValues(alpha: 0.10)
            : (context.isDark ? NkColors.darkCard : NkColors.lightCard),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? accent : context.line,
          width: selected ? 2 : 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected) ...[
                  Icon(Icons.check_circle, size: 17, color: accent),
                  const SizedBox(width: 7),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: context.navyText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

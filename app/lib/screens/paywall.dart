import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../billing.dart';
import '../pricing.dart';
import '../theme.dart';
import '../widgets.dart';

/// The Pro paywall. Honest by design: it says exactly what stays free, and
/// lapsed Pro never locks anyone out of their own data. Redesigned in
/// build 16 as a sales page in the app's own language: a gradient hero,
/// a value anchor against the $120-a-year rivals, benefit rows, three
/// selectable plan cards and one pinned buy button whose label follows
/// the selection. All purchase, restore and entitlement calls are the
/// same wiring the plain page used; only the presentation changed.
class PaywallScreen extends StatefulWidget {
  final AppState state;
  final Billing billing;

  const PaywallScreen({super.key, required this.state, required this.billing});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  // The premium gold of the badge celebrations (build 12).
  static const _goldLight = Color(0xFFF6C453);
  static const _goldDeep = Color(0xFFE8A33D);
  static const _goldInk = Color(0xFF3A2703);

  /// The selected plan card; yearly is the hero plan and starts selected.
  String _selectedId = Billing.yearlyId;

  AppState get state => widget.state;
  Billing get billing => widget.billing;

  /// The price to print for a product: Play's base recurring price
  /// once product details have loaded (never a trial or intro phase's
  /// price — see pricing.dart), the USD list price before that.
  DisplayPrice _display(String id, String fallback, int fallbackMicros) =>
      billing.displayPrice(id) ??
      DisplayPrice(
        formatted: fallback,
        amountMicros: fallbackMicros,
        currencyCode: 'USD',
      );

  DisplayPrice get _yearly =>
      _display(Billing.yearlyId, '\$29.99', 29990000);
  DisplayPrice get _monthly => _display(Billing.monthlyId, '\$4.99', 4990000);
  DisplayPrice get _lifetime =>
      _display(Billing.lifetimeId, '\$79.99', 79990000);

  String get _buyLabel => switch (_selectedId) {
        Billing.monthlyId => 'Go Pro, ${_monthly.formatted}/month',
        Billing.lifetimeId => 'Get Lifetime, ${_lifetime.formatted}',
        _ => 'Start my 14 free days',
      };

  /// The yearly card's subline: the trial, then the real recurring
  /// price, then its per-month equivalent when the currency is known.
  String get _yearlySub {
    final perMonth = _yearly.perMonthFormatted;
    return '14 days free, then ${_yearly.formatted} a year.'
        '${perMonth == null ? '' : ' That\'s $perMonth a month.'}';
  }

  @override
  Widget build(BuildContext context) {
    if (state.isPro) return _proActive(context);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _hero(context, proActive: false),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'The plan, reminders and receipt scanning stay free '
                      'forever. Pro is for the vault, the money view and '
                      'more homes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: context.muted, height: 1.45, fontSize: 13.5),
                    ),
                    const SizedBox(height: 16),
                    _valueAnchor(context),
                    const SizedBox(height: 22),
                    for (final f in _benefits) ...[
                      _benefitRow(context, f),
                      const SizedBox(height: 14),
                    ],
                    const SizedBox(height: 8),
                    const SectionHeading('Choose a plan'),
                    const SizedBox(height: 12),
                    _planCard(
                      context,
                      id: Billing.yearlyId,
                      name: 'Pro Yearly',
                      price: '${_yearly.formatted}/year',
                      sub: _yearlySub,
                      pill: 'BEST VALUE',
                    ),
                    const SizedBox(height: 12),
                    _planCard(
                      context,
                      id: Billing.monthlyId,
                      name: 'Pro Monthly',
                      price: '${_monthly.formatted}/month',
                      sub: 'Flexible. Cancel anytime.',
                    ),
                    const SizedBox(height: 12),
                    _planCard(
                      context,
                      id: Billing.lifetimeId,
                      name: 'Lifetime',
                      price: '${_lifetime.formatted} once',
                      sub: 'Pay once, yours forever. No subscription.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _buyBar(context),
      ],
    );
  }

  static const _benefits = [
    (
      Icons.add_task,
      'Unlimited custom jobs',
      'Add your own jobs on top of the plan, with no limit.',
    ),
    (
      Icons.kitchen_outlined,
      'Every appliance tracked, with photos and invoice',
      'Warranty dates and paperwork for every appliance, in one place.',
    ),
    (
      Icons.folder_outlined,
      'Home documents and spaces',
      'Deeds, insurance and manuals, filed under the whole home or a '
          'space you name.',
    ),
    (
      Icons.photo_library_outlined,
      'Receipt photos kept in the app',
      'Backed up with the purchase, ready when a warranty claim needs '
          'proof.',
    ),
    (
      Icons.savings_outlined,
      'Cost tracker with year view and category totals',
      'What the home really costs, year by year and category by category.',
    ),
    (
      Icons.picture_as_pdf_outlined,
      'PDF home report for insurance or selling',
      'A tidy summary of the home and its history, ready to hand over.',
    ),
    (
      Icons.home_work_outlined,
      'Up to 3 homes on one plan',
      'Your home, a second home or a rental, all covered together.',
    ),
    (
      Icons.ios_share_outlined,
      'Full backup export',
      'Everything you have saved, exported whenever you want it.',
    ),
  ];

  /// The gradient band at the top: the nest icon in a glowing circle
  /// with a gold crown, the name, and one line about what Pro is. The
  /// gradient wears the user's accent: vivid purple family in light
  /// mode, deep purple in dark.
  Widget _hero(BuildContext context, {required bool proActive}) {
    final primary = context.primary;
    final dark = context.isDark;
    final begin = dark
        ? Color.lerp(primary, Colors.black, 0.68)!
        : Color.lerp(primary, Colors.white, 0.10)!;
    final end = dark
        ? Color.lerp(primary, Colors.black, 0.38)!
        : Color.lerp(primary, Colors.black, 0.16)!;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [begin, end],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 26),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 86,
                    height: 86,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.28),
                          blurRadius: 28,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.asset('assets/icon.png',
                          width: 62, height: 62),
                    ),
                  ),
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [_goldLight, _goldDeep],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Icon(Icons.workspace_premium,
                          size: 18, color: _goldInk),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'NestKeep Pro',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Everything your home needs, in one place.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withValues(alpha: 0.88),
                  height: 1.35,
                ),
              ),
              if (proActive) ...[
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_goldLight, _goldDeep],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, size: 16, color: _goldInk),
                      SizedBox(width: 6),
                      Text(
                        'Pro is active',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _goldInk,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// The honest price anchor, from the competitor research: the big
  /// rivals charge up to $120 a year for this class of app. The
  /// wording follows the resolved price's currency (build 24): a
  /// USD price keeps the $120 figure; any other currency drops it
  /// for the "four times more" multiple, so the line never mixes
  /// currencies. See valueAnchorParts in pricing.dart.
  Widget _valueAnchor(BuildContext context) {
    final base = TextStyle(fontSize: 14.5, height: 1.4, color: context.muted);
    final strong = base.copyWith(
        fontWeight: FontWeight.w700, color: context.navyText);
    final anchor = valueAnchorParts(_yearly);
    // IntrinsicHeight: the accent-bar NkCard stretches a Row, which
    // needs a finite height inside the scrolling column.
    return IntrinsicHeight(
      child: NkCard(
        accentLeft: NkColors.amber,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          const Icon(Icons.sell_outlined, color: NkColors.amber, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: base,
                children: [
                  TextSpan(text: anchor.before),
                  TextSpan(text: anchor.highlight, style: strong),
                  TextSpan(text: anchor.middle),
                  TextSpan(text: anchor.price, style: strong),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _benefitRow(
      BuildContext context, (IconData, String, String) benefit) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: context.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(benefit.$1, size: 22, color: context.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                benefit.$2,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  color: context.navyText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                benefit.$3,
                style: TextStyle(
                    fontSize: 13.5, color: context.muted, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// One selectable plan card. Tapping selects; the pinned buy button
  /// below does the buying, through the same Billing.buy as always.
  Widget _planCard(
    BuildContext context, {
    required String id,
    required String name,
    required String price,
    required String sub,
    String? pill,
  }) {
    final selected = _selectedId == id;
    final primary = context.primary;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (selected
                    ? primary
                    : (context.isDark ? Colors.black : NkColors.lightNavy))
                .withValues(alpha: selected ? 0.20 : 0.08),
            blurRadius: selected ? 20 : 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: context.isDark ? NkColors.darkCard : NkColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => setState(() => _selectedId = id),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? primary : context.line,
                width: selected ? 2 : 1,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 23,
                  height: 23,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? primary
                          : context.muted.withValues(alpha: 0.55),
                      width: 2,
                    ),
                  ),
                  child: selected
                      ? Center(
                          child: Container(
                            width: 11,
                            height: 11,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: primary,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w700,
                                color: context.navyText,
                              ),
                            ),
                          ),
                          if (pill != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [_goldLight, _goldDeep],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                pill,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: _goldInk,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        price,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: context.navyText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sub,
                        style: TextStyle(
                            fontSize: 13, color: context.muted, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The pinned buy area: one button that buys the selected plan,
  /// restore underneath, and the small print.
  Widget _buyBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.isDark ? NkColors.darkCard : NkColors.lightCard,
        border: Border(top: BorderSide(color: context.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => billing.buy(_selectedId),
                  child: Text(_buyLabel),
                ),
              ),
              TextButton(
                onPressed: () => billing.restore(),
                child: const Text('Restore purchases'),
              ),
              Text(
                'Cancel anytime in Google Play. The trial converts only '
                'if you stay. Prices shown in your local currency.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 12, color: context.muted, height: 1.4),
              ),
              const SizedBox(height: 4),
              Text(
                'If Pro lapses, everything you already saved stays fully '
                'usable; the Pro extras simply pause.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 12, color: context.muted, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The already-Pro state: same hero, a gold active chip, and the plan
  /// card with the manage link, exactly as wired before.
  Widget _proActive(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _hero(context, proActive: true),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: NkCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified,
                        color: NkColors.green, size: 26),
                    const SizedBox(width: 10),
                    Text(
                      'Pro is active',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: context.navyText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Plan: ${state.entitlement.source.name}'
                  '${state.entitlement.expiry != null ? ' · renews or ends ${state.entitlement.expiry!.month}/${state.entitlement.expiry!.day}/${state.entitlement.expiry!.year}' : ''}',
                  style: TextStyle(color: context.muted),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => launchUrl(
                    Uri.parse(
                        'https://play.google.com/store/account/subscriptions'),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: const Text('Manage or cancel in Google Play'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../billing.dart';
import '../theme.dart';
import '../widgets.dart';

/// The Pro paywall. Honest by design: it says exactly what stays free, and
/// lapsed Pro never locks anyone out of their own data.
class PaywallScreen extends StatelessWidget {
  final AppState state;
  final Billing billing;

  const PaywallScreen({super.key, required this.state, required this.billing});

  String _price(String id, String fallback) =>
      billing.product(id)?.price ?? fallback;

  @override
  Widget build(BuildContext context) {
    if (state.isPro) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text('NestKeep Pro',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: context.navyText)),
          const SizedBox(height: 12),
          NkCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.verified, color: NkColors.green, size: 26),
                    SizedBox(width: 10),
                    Text('Pro is active',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
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
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text('NestKeep Pro',
            style: TextStyle(
                fontSize: 26, fontWeight: FontWeight.w800, color: context.navyText)),
        const SizedBox(height: 6),
        Text(
          'The plan, reminders and receipt scanning stay free forever. '
          'Pro is for the vault, the money view and more homes.',
          style: TextStyle(color: context.muted, height: 1.45),
        ),
        const SizedBox(height: 18),
        for (final f in const [
          (Icons.add_task, 'Unlimited custom jobs on top of the plan'),
          (Icons.kitchen_outlined, 'Every appliance tracked, with its photos and invoice'),
          (Icons.photo_library_outlined, 'Receipt photos kept in the app and backed up'),
          (Icons.savings_outlined, 'Cost tracker with year view and category totals'),
          (Icons.picture_as_pdf_outlined, 'PDF home report for insurance or selling'),
          (Icons.home_work_outlined, 'Up to 3 homes on one plan'),
          (Icons.ios_share_outlined, 'Full backup export'),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(f.$1, size: 21, color: NkColors.green),
                const SizedBox(width: 10),
                Expanded(child: Text(f.$2, style: const TextStyle(fontSize: 15))),
              ],
            ),
          ),
        const SizedBox(height: 14),
        _PlanCard(
          title: 'Yearly',
          price: '${_price(Billing.yearlyId, '\$29.99')} / year',
          badge: '7 days free · best value',
          highlight: true,
          onTap: () => billing.buy(Billing.yearlyId),
        ),
        const SizedBox(height: 12),
        _PlanCard(
          title: 'Monthly',
          price: '${_price(Billing.monthlyId, '\$4.99')} / month',
          badge: 'Flexible',
          onTap: () => billing.buy(Billing.monthlyId),
        ),
        const SizedBox(height: 12),
        _PlanCard(
          title: 'Lifetime',
          price: _price(Billing.lifetimeId, '\$79.99'),
          badge: 'One payment, yours forever',
          onTap: () => billing.buy(Billing.lifetimeId),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => billing.restore(),
          child: const Text('Restore purchases'),
        ),
        Text(
          'Subscriptions are handled by Google Play and can be cancelled there any time. '
          'If Pro lapses, everything you already saved stays fully usable; the Pro extras simply pause.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: context.muted, height: 1.4),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String badge;
  final bool highlight;
  final VoidCallback onTap;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.badge,
    required this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return NkCard(
      onTap: onTap,
      accentLeft: highlight ? NkColors.amber : null,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: context.navyText)),
                Text(badge,
                    style: TextStyle(
                        fontSize: 13,
                        color: highlight ? NkColors.amber : context.muted,
                        fontWeight:
                            highlight ? FontWeight.w700 : FontWeight.normal)),
              ],
            ),
          ),
          Text(price,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: context.navyText)),
        ],
      ),
    );
  }
}

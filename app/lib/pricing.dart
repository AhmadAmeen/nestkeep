import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:intl/intl.dart';

/// Display pricing for the paywall, resolved honestly.
///
/// A subscription's [ProductDetails.price] is the FIRST pricing phase
/// of the first offer Play returns. With a free-trial offer in front,
/// that phase is the trial itself, so the raw price reads "Free" and
/// the paywall once announced "Pro is Free" (build 19 fix). The price
/// a subscriber actually pays, period after period, is the base plan's
/// recurring phase: positive, and recurring forever. Everything the
/// paywall prints derives from that phase, never from an intro phase.

/// One pricing phase, flattened out of the platform wrappers so the
/// choice of the base phase is a pure, testable function.
class PricePhase {
  /// ISO 8601 billing period, e.g. 'P1Y' or 'P1M'.
  final String period;
  final int amountMicros;
  final String formattedPrice;
  final String currencyCode;

  /// True when the phase recurs until cancelled (the base plan's own
  /// phase), false for finite phases like a free trial or an intro
  /// price that runs for a fixed number of cycles.
  final bool recursForever;

  const PricePhase({
    required this.period,
    required this.amountMicros,
    required this.formattedPrice,
    required this.currencyCode,
    required this.recursForever,
  });
}

/// The phase that represents what a subscriber pays every period once
/// any offer has run its course: a positive phase that recurs forever.
/// Falls back to the last positive phase (base phases follow intro
/// phases), and to null when no phase costs anything.
PricePhase? pickBasePhase(List<PricePhase> phases) {
  final positive = [for (final p in phases) if (p.amountMicros > 0) p];
  if (positive.isEmpty) return null;
  for (final p in positive) {
    if (p.recursForever) return p;
  }
  return positive.last;
}

/// Play's formatter always prints a decimal part for decimal
/// currencies, so a whole amount arrives as "Rs 8,300.00" (or
/// "8.300,00 €" in suffix locales). The trailing ".00" reads as noise
/// (build 20): strip a zero decimal part — exactly two zeros after a
/// '.' or ',' separator, followed only by a possible currency suffix —
/// and leave any real fractional part ("$29.99", "Rs 100.50")
/// untouched. Exactly two zeros, so a zero-decimal currency's
/// thousands separator ("¥1,000") is never mistaken for decimals.
String formatDisplayPrice(String formatted) {
  final trimmed = formatted.trim();
  final m = RegExp(r'[.,]0{2}(?=\D*$)').firstMatch(trimmed);
  if (m == null) return formatted;
  return (trimmed.substring(0, m.start) + trimmed.substring(m.end)).trim();
}

/// A price ready to print: Play's own formatting for the amount, plus
/// the raw amount and currency for derived figures like a per-month
/// equivalent.
class DisplayPrice {
  final String formatted;
  final int? amountMicros;
  final String? currencyCode;

  const DisplayPrice({
    required this.formatted,
    this.amountMicros,
    this.currencyCode,
  });

  /// The per-month equivalent of a yearly price, formatted in the
  /// price's own currency; null when the amount or currency is unknown
  /// (callers then simply omit the clause). A whole amount prints with
  /// no decimal part ("Rs 700", not "Rs 700.00").
  String? get perMonthFormatted {
    final micros = amountMicros;
    final code = currencyCode;
    if (micros == null || code == null) return null;
    final value = micros / 12 / 1000000;
    final format = NumberFormat.simpleCurrency(name: code);
    if (value == value.roundToDouble()) {
      format.minimumFractionDigits = 0;
      format.maximumFractionDigits = 0;
    }
    return format.format(value);
  }
}

/// Every pricing phase of a product, across all of its offers. On
/// Android the platform wrapper behind any one offer entry carries the
/// whole offer list, so one entry is enough. Empty for one-time
/// products and on platforms without phase data.
List<PricePhase> phasesOf(ProductDetails details) {
  if (details is GooglePlayProductDetails) {
    final offers = details.productDetails.subscriptionOfferDetails;
    if (offers != null) {
      return [
        for (final offer in offers)
          for (final p in offer.pricingPhases)
            PricePhase(
              period: p.billingPeriod,
              amountMicros: p.priceAmountMicros,
              formattedPrice: p.formattedPrice,
              currencyCode: p.priceCurrencyCode,
              recursForever:
                  p.recurrenceMode == RecurrenceMode.infiniteRecurring,
            ),
      ];
    }
  }
  return const [];
}

/// The display price for one product: the base phase for a
/// subscription; for a one-time product (or a platform without phases)
/// the product's own price, which is already its base price.
DisplayPrice displayPriceOf(ProductDetails details) {
  final base = pickBasePhase(phasesOf(details));
  if (base != null) {
    return DisplayPrice(
      formatted: formatDisplayPrice(base.formattedPrice),
      amountMicros: base.amountMicros,
      currencyCode: base.currencyCode,
    );
  }
  return DisplayPrice(
    formatted: formatDisplayPrice(details.price),
    amountMicros: (details.rawPrice * 1000000).round(),
    currencyCode: details.currencyCode,
  );
}

/// The paywall's value-anchor line, in pieces (build 24): the text
/// before the bolded comparison, the comparison itself, the text
/// between, and the bolded price clause. The line compares Pro's
/// yearly price against what rival home apps charge, and it must
/// never mix currencies. When the resolved yearly price is USD,
/// the comparison is the researched figure itself (HouseWell
/// charges $120 a year against our $29.99). In any other currency
/// the dollar figure is dropped and the comparison becomes the
/// multiple from the same research — four times — beside the
/// resolved local price. An unknown currency takes the multiple
/// branch too: the dollar claim is only made when the price is
/// known to be dollars.
({String before, String highlight, String middle, String price})
valueAnchorParts(DisplayPrice yearly) {
  final price = '${yearly.formatted} a year.';
  if (yearly.currencyCode == 'USD') {
    return (
      before: 'Other home apps charge up to ',
      highlight: '\$120 a year',
      middle: ' for this. Pro is ',
      price: price,
    );
  }
  return (
    before: 'Other home apps charge up to ',
    highlight: 'four times more',
    middle: ' for this. Pro is ',
    price: price,
  );
}

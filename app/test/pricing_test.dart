import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:nestkeep/pricing.dart';

PricePhase _phase({
  required String period,
  required int micros,
  required String formatted,
  bool forever = false,
  int cycles = 0,
}) => PricePhase(
  period: period,
  amountMicros: micros,
  formattedPrice: formatted,
  currencyCode: 'PKR',
  recursForever: forever,
);

void main() {
  group('pickBasePhase', () {
    test('a free trial in front resolves to the base yearly phase', () {
      final base = pickBasePhase([
        _phase(period: 'P14D', micros: 0, formatted: 'Free', cycles: 1),
        _phase(
          period: 'P1Y',
          micros: 8400000000,
          formatted: 'Rs 8,400.00',
          forever: true,
        ),
      ]);
      expect(base, isNotNull);
      expect(base!.formattedPrice, 'Rs 8,400.00');
      expect(base.amountMicros, 8400000000);
      expect(base.period, 'P1Y');
    });

    test('a lone base monthly phase is picked as itself', () {
      final base = pickBasePhase([
        _phase(
          period: 'P1M',
          micros: 1400000000,
          formatted: 'Rs 1,400.00',
          forever: true,
        ),
      ]);
      expect(base!.formattedPrice, 'Rs 1,400.00');
    });

    test('an intro price phase does not shadow the recurring base', () {
      final base = pickBasePhase([
        _phase(
          period: 'P1M',
          micros: 100000000,
          formatted: 'Rs 100.00',
          cycles: 3,
        ),
        _phase(
          period: 'P1M',
          micros: 1400000000,
          formatted: 'Rs 1,400.00',
          forever: true,
        ),
      ]);
      expect(base!.formattedPrice, 'Rs 1,400.00');
    });

    test('with no forever phase, the last positive phase wins', () {
      final base = pickBasePhase([
        _phase(
          period: 'P1M',
          micros: 100000000,
          formatted: 'Rs 100.00',
          cycles: 1,
        ),
        _phase(
          period: 'P1M',
          micros: 900000000,
          formatted: 'Rs 900.00',
          cycles: 11,
        ),
      ]);
      expect(base!.formattedPrice, 'Rs 900.00');
    });

    test('empty and all-free phase lists resolve to null', () {
      expect(pickBasePhase(const []), isNull);
      expect(
        pickBasePhase([
          _phase(period: 'P14D', micros: 0, formatted: 'Free', cycles: 1),
        ]),
        isNull,
      );
    });
  });

  group('displayPriceOf', () {
    test('a Play subscription with a trial offer prints its base price', () {
      // The shape Play returns for the yearly plan: a trial offer whose
      // first phase is free, then the base plan's recurring phase. The
      // platform's own ProductDetails.price for the trial entry is
      // "Free" — the bug this pricing path exists to fix.
      final wrapper = ProductDetailsWrapper(
        description: 'Pro, yearly',
        name: 'NestKeep Pro',
        productId: 'nestkeep_pro_yearly',
        productType: ProductType.subs,
        title: 'NestKeep Pro',
        subscriptionOfferDetails: [
          SubscriptionOfferDetailsWrapper(
            basePlanId: 'yearly',
            offerId: 'free-trial',
            offerTags: const [],
            offerIdToken: 'token-trial',
            pricingPhases: [
              PricingPhaseWrapper(
                billingCycleCount: 1,
                billingPeriod: 'P14D',
                formattedPrice: 'Free',
                priceAmountMicros: 0,
                priceCurrencyCode: 'PKR',
                recurrenceMode: RecurrenceMode.finiteRecurring,
              ),
              PricingPhaseWrapper(
                billingCycleCount: 0,
                billingPeriod: 'P1Y',
                formattedPrice: 'Rs 8,400.00',
                priceAmountMicros: 8400000000,
                priceCurrencyCode: 'PKR',
                recurrenceMode: RecurrenceMode.infiniteRecurring,
              ),
            ],
          ),
          SubscriptionOfferDetailsWrapper(
            basePlanId: 'yearly',
            offerTags: const [],
            offerIdToken: 'token-base',
            pricingPhases: [
              PricingPhaseWrapper(
                billingCycleCount: 0,
                billingPeriod: 'P1Y',
                formattedPrice: 'Rs 8,400.00',
                priceAmountMicros: 8400000000,
                priceCurrencyCode: 'PKR',
                recurrenceMode: RecurrenceMode.infiniteRecurring,
              ),
            ],
          ),
        ],
      );
      final details = GooglePlayProductDetails.fromProductDetails(wrapper);
      expect(
        details.first.price,
        'Free',
        reason: 'the trial entry really does lead with the free phase',
      );
      final display = displayPriceOf(details.first);
      // The resolved price prints without the trailing ".00" Play
      // adds to whole amounts (build 20).
      expect(display.formatted, 'Rs 8,400');
      expect(display.amountMicros, 8400000000);
      expect(display.currencyCode, 'PKR');
      // 8,400,000,000 micros a year is 700 a month, in the phase's own
      // currency (the test locale renders PKR's symbol as "Rs").
      expect(display.perMonthFormatted, contains('700'));
      expect(display.perMonthFormatted, startsWith('Rs'));
    });

    test('a one-time Play product prints its plain price', () {
      final wrapper = ProductDetailsWrapper(
        description: 'Pro, forever',
        name: 'NestKeep Pro',
        productId: 'nestkeep_lifetime',
        productType: ProductType.inapp,
        title: 'NestKeep Pro',
        oneTimePurchaseOfferDetails: OneTimePurchaseOfferDetailsWrapper(
          formattedPrice: 'Rs 22,200.00',
          priceAmountMicros: 22200000000,
          priceCurrencyCode: 'PKR',
        ),
      );
      final details = GooglePlayProductDetails.fromProductDetails(wrapper);
      final display = displayPriceOf(details.first);
      expect(display.formatted, 'Rs 22,200');
      expect(display.amountMicros, 22200000000);
    });

    test('plain product details fall back to their own price', () {
      final details = ProductDetails(
        id: 'nestkeep_pro_monthly',
        title: 'Pro Monthly',
        description: '',
        price: '\$4.99',
        rawPrice: 4.99,
        currencyCode: 'USD',
      );
      final display = displayPriceOf(details);
      expect(display.formatted, '\$4.99');
      expect(display.amountMicros, 4990000);
      expect(display.currencyCode, 'USD');
    });

    test('per-month is omitted when amount or currency is unknown', () {
      const display = DisplayPrice(formatted: '\$29.99');
      expect(display.perMonthFormatted, isNull);
    });

    test('per-month of the USD list price is \$2.50', () {
      const display = DisplayPrice(
        formatted: '\$29.99',
        amountMicros: 29990000,
        currencyCode: 'USD',
      );
      expect(display.perMonthFormatted, '\$2.50');
    });

    test('a whole per-month equivalent prints with no decimals', () {
      const display = DisplayPrice(
        formatted: 'Rs 8,400',
        amountMicros: 8400000000,
        currencyCode: 'PKR',
      );
      // intl's PKR pattern carries no space after the symbol (the
      // fractional form is 'Rs700.00'); the whole form drops the
      // decimals and nothing else.
      expect(display.perMonthFormatted, 'Rs700');
    });
  });

  group('formatDisplayPrice', () {
    test('strips a trailing zero decimal part', () {
      expect(formatDisplayPrice('Rs 8,300.00'), 'Rs 8,300');
      expect(formatDisplayPrice('\$30.00'), '\$30');
      expect(formatDisplayPrice('Rs 22,200.00'), 'Rs 22,200');
    });

    test('strips a comma decimal separator, suffix currency included', () {
      expect(formatDisplayPrice('8.300,00 €'), '8.300 €');
      expect(formatDisplayPrice('29,00 €'), '29 €');
    });

    test('leaves real fractional amounts untouched', () {
      expect(formatDisplayPrice('\$29.99'), '\$29.99');
      expect(formatDisplayPrice('Rs 100.50'), 'Rs 100.50');
      expect(formatDisplayPrice('\$4.99'), '\$4.99');
    });

    test('leaves prices with no decimal part untouched', () {
      expect(formatDisplayPrice('Rs 8,300'), 'Rs 8,300');
      expect(formatDisplayPrice('Free'), 'Free');
      expect(formatDisplayPrice('¥1,000'), '¥1,000');
    });
  });

  group('valueAnchorParts (build 24: never mix currencies)', () {
    test('a USD yearly price keeps the researched \$120 comparison',
        () {
      final parts = valueAnchorParts(const DisplayPrice(
        formatted: '\$29.99',
        amountMicros: 29990000,
        currencyCode: 'USD',
      ));
      expect(parts.before, 'Other home apps charge up to ');
      expect(parts.highlight, '\$120 a year');
      expect(parts.middle, ' for this. Pro is ');
      expect(parts.price, '\$29.99 a year.');
    });

    test('any other currency drops the dollar figure for the '
        'four-times multiple beside the local price', () {
      final parts = valueAnchorParts(const DisplayPrice(
        formatted: 'Rs 8,300',
        amountMicros: 8300000000,
        currencyCode: 'PKR',
      ));
      expect(parts.highlight, 'four times more');
      expect(parts.price, 'Rs 8,300 a year.');
      final line =
          '${parts.before}${parts.highlight}${parts.middle}${parts.price}';
      expect(line, contains('Rs 8,300'));
      expect(line, isNot(contains('\$')));
      expect(line, isNot(contains('120')));
    });

    test('an unknown currency takes the multiple branch too', () {
      final parts = valueAnchorParts(
          const DisplayPrice(formatted: '29.99'));
      expect(parts.highlight, 'four times more');
    });
  });
}

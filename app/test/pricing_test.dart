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
      expect(display.formatted, 'Rs 8,400.00');
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
      expect(display.formatted, 'Rs 22,200.00');
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
  });
}

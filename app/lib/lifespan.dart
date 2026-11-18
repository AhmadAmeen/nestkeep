import 'package:flutter/material.dart';

import 'models.dart';
import 'theme.dart';

/// Appliance lifespan: how far through its expected working life an
/// appliance is, in the HouseWell-style bands the user can act on.
/// Pure date math on the Appliance row, so it is fully testable.

/// How many appliances a free plan tracks. Pro tracks every appliance.
const freeApplianceLimit = 5;

enum LifeStatus { good, monitor, replaceSoon }

/// Typical working life in years, matched loosely against appliance
/// names. Order matters: 'dishwasher' must be checked before 'washer'
/// because it contains it.
const lifespanDefaultsYears = <String, int>{
  'freezer': 16,
  'refrigerator': 12,
  'fridge': 12,
  'dishwasher': 10,
  'washing machine': 10,
  'washer': 10,
  'dryer': 10,
  'water heater': 12,
  'heat pump': 15,
  'air conditioner': 15,
  'hvac': 15,
  'furnace': 15,
  'oven': 15,
  'range': 15,
  'stove': 15,
  'microwave': 9,
  'boiler': 20,
};

int typicalLifespanYears(String applianceName) {
  final n = applianceName.toLowerCase();
  for (final e in lifespanDefaultsYears.entries) {
    if (n.contains(e.key)) return e.value;
  }
  return 10; // unknown appliances: a decade is the honest middle
}

/// The lifespan in force for this appliance: the owner's own number
/// when they set one, otherwise the typical value for its kind.
int effectiveLifespan(Appliance a) =>
    a.lifespanYears ?? typicalLifespanYears(a.name);

double _ageYears(Appliance a, DateTime now) {
  final p = a.purchaseDate;
  if (p == null) return 0;
  final days = now.difference(p).inDays;
  if (days <= 0) return 0;
  return days / 365.25;
}

/// Fraction of expected life used up: 0 = new, 1 = at the end of its
/// typical life. Clamped to 1.2 so a very old appliance does not run
/// off the scale. No purchase date means no clock: 0.
double lifeUsed(Appliance a, DateTime now) {
  if (a.purchaseDate == null) return 0;
  final used = _ageYears(a, now) / effectiveLifespan(a);
  return used.clamp(0.0, 1.2).toDouble();
}

/// Fraction of expected life REMAINING: 1 = brand new, 0 = at (or
/// past) the end of its typical life. This is what the life bar
/// draws (build 24): the bar starts full and drains as the
/// appliance ages, matching the "Life left ~N yrs" label beside it.
/// No purchase date means no clock: 0, so the undated track stays
/// empty under its "add a purchase date" label.
double lifeRemaining(Appliance a, DateTime now) {
  if (a.purchaseDate == null) return 0;
  return (1 - lifeUsed(a, now)).clamp(0.0, 1.0).toDouble();
}

LifeStatus lifeStatus(Appliance a, DateTime now) {
  if (a.purchaseDate == null) return LifeStatus.good;
  final used = lifeUsed(a, now);
  if (used < 0.7) return LifeStatus.good;
  if (used < 0.95) return LifeStatus.monitor;
  return LifeStatus.replaceSoon;
}

String lifeStatusLabel(LifeStatus s) => switch (s) {
      LifeStatus.good => 'Good shape',
      LifeStatus.monitor => 'Monitor',
      LifeStatus.replaceSoon => 'Replace soon',
    };

Color lifeStatusColor(LifeStatus s) => switch (s) {
      LifeStatus.good => NkColors.lifeGreen,
      LifeStatus.monitor => NkColors.amber,
      LifeStatus.replaceSoon => NkColors.red,
    };

/// The year-of-life the appliance is in: completed years + 1, so a
/// three-month-old fridge is in "Year 1". Once past its expected life
/// it stops counting up the label and just shows its age in years.
int lifeYearIndex(Appliance a, DateTime now) {
  final age = _ageYears(a, now);
  final completed = age.floor();
  if (age >= effectiveLifespan(a)) return completed;
  return completed + 1;
}

/// "Year 3 of about 12"
String lifeLabel(Appliance a, DateTime now) =>
    'Year ${lifeYearIndex(a, now)} of about ${effectiveLifespan(a)}';

/// "Life left ~9 yrs", or the honest budgeting nudge once an appliance
/// is at the end of its typical life.
String lifeLeftLabel(Appliance a, DateTime now) {
  if (lifeStatus(a, now) == LifeStatus.replaceSoon) {
    return 'Budget for a new one';
  }
  final left = (effectiveLifespan(a) - _ageYears(a, now)).ceil();
  return 'Life left ~$left yrs';
}

// ---------- owner condition tags ----------
//
// The owner's own call on how a machine is doing, stored on the
// appliance row as one of these values (null = not set). Deliberately
// separate from the life bands above: the bands are age maths, this
// is the owner looking at the machine. Both show on the card.

const conditionExcellent = 'excellent';
const conditionGood = 'good';
const conditionBad = 'bad';
const conditionWornOut = 'worn_out';

const conditionValues = [
  conditionExcellent,
  conditionGood,
  conditionBad,
  conditionWornOut,
];

String conditionLabel(String condition) => switch (condition) {
      conditionExcellent => 'Excellent',
      conditionGood => 'Good',
      conditionBad => 'Bad',
      conditionWornOut => 'Worn out',
      _ => 'Set condition',
    };

Color conditionColor(String condition) => switch (condition) {
      conditionExcellent => NkColors.lifeGreen,
      conditionGood => NkColors.green,
      conditionBad => NkColors.amber,
      conditionWornOut => NkColors.red,
      _ => NkColors.green,
    };

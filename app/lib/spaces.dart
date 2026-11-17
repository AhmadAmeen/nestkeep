import 'package:flutter/material.dart';

/// The small icon set a home space can wear. Spaces store the key
/// string (HomeSpace.icon in models.dart); this map is the only place keys
/// become real icons, so a renamed or added icon never breaks old rows.
const spaceIcons = <String, IconData>{
  'kitchen': Icons.kitchen_outlined,
  'bathroom': Icons.bathtub_outlined,
  'bedroom': Icons.bed_outlined,
  'living': Icons.weekend_outlined,
  'garden': Icons.yard_outlined,
  'roof': Icons.roofing_outlined,
  'garage': Icons.garage_outlined,
  'laundry': Icons.local_laundry_service_outlined,
  'office': Icons.desk_outlined,
  'general': Icons.home_outlined,
};

/// The keys in picker order.
const spaceIconKeys = [
  'kitchen',
  'bathroom',
  'bedroom',
  'living',
  'garden',
  'roof',
  'garage',
  'laundry',
  'office',
  'general',
];

IconData spaceIcon(String key) => spaceIcons[key] ?? Icons.home_outlined;

/// Human label for a preset key, used in the icon picker.
String spaceIconLabel(String key) => key[0].toUpperCase() + key.substring(1);

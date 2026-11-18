import 'package:flutter/material.dart';

import '../app_state.dart';
import 'documents_section.dart';

/// The Documents screen (build 18 moved it off the My Home hub): a
/// thin shell hosting the existing Documents section — the Pro gate,
/// the spaces chips, the photo grid and the add flow all live there.
class DocumentsScreen extends StatelessWidget {
  final AppState state;
  final VoidCallback onOpenPaywall;

  const DocumentsScreen({
    super.key,
    required this.state,
    required this.onOpenPaywall,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Documents')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          DocumentsSection(state: state, onOpenPaywall: onOpenPaywall),
        ],
      ),
    );
  }
}

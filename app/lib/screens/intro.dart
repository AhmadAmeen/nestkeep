import 'package:flutter/material.dart';

import '../theme.dart';

/// First-run intro: five slides that teach the app before the home setup
/// form. Shown once to new users (no home yet, intro not seen); also
/// replayable from Profile via [replay], where the last button reads
/// "Done" and simply closes.
class IntroScreen extends StatefulWidget {
  final VoidCallback onDone;
  final bool replay;

  const IntroScreen({super.key, required this.onDone, this.replay = false});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _Slide {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  const _Slide(this.icon, this.color, this.title, this.body);
}

const _slides = [
  _Slide(
    Icons.home_outlined,
    NkColors.lightNavy,
    'Your home, handled.',
    'NestKeep turns the dozens of small jobs your home needs into one '
        'simple plan, and reminds you before they turn into big bills.',
  ),
  _Slide(
    Icons.checklist_outlined,
    NkColors.lightPrimary,
    'A plan built for your home',
    'Answer a few questions about your home and get a seasonal plan from '
        '70+ real jobs, each with plain steps, what it costs to do, and '
        'what it costs to skip.',
  ),
  _Slide(
    Icons.donut_large_outlined,
    NkColors.green,
    'Know your home\u2019s health',
    'A clear score shows what is overdue, what is coming up, and the one '
        'thing worth doing today. No black box: it shows its work.',
  ),
  _Slide(
    Icons.document_scanner_outlined,
    Color(0xFFF5A623),
    'Snap a receipt, done',
    'Photograph a receipt and NestKeep files the appliance, starts its '
        'warranty clock, and logs the spend. No typing, nothing uploaded.',
  ),
  _Slide(
    Icons.lock_outline,
    Color(0xFF7A5AF8),
    'Private by design',
    'No account needed, and everything works on your phone. Sign in with '
        'Google only if you want your home backed up and synced.',
  ),
];

class _IntroScreenState extends State<IntroScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _last => _page == _slides.length - 1;

  void _next() {
    if (_last) {
      widget.onDone();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final s = _slides[i];
                  final color = context.isDark && s.color == NkColors.lightNavy
                      ? NkColors.darkPrimary
                      : s.color;
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(32, 48, 32, 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (i == 0)
                          // The brand moment: the nest artwork itself,
                          // not a generic icon tile.
                          Image.asset(
                            'assets/icon.png',
                            width: 96,
                            height: 96,
                          )
                        else
                          Container(
                            width: 104,
                            height: 104,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Icon(s.icon, size: 52, color: color),
                          ),
                        const SizedBox(height: 36),
                        Text(
                          s.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w800,
                            color: context.navyText,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          s.body,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15.5,
                            color: context.muted,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3.5),
                    width: i == _page ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? (context.isDark
                              ? NkColors.darkPrimary
                              : NkColors.lightPrimary)
                          : context.line,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            // Controls
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: _last
                  ? SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: widget.onDone,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          textStyle: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        child: Text(widget.replay ? 'Done' : 'Set up my home'),
                      ),
                    )
                  : Row(
                      children: [
                        TextButton(
                          onPressed: widget.onDone,
                          child: const Text('Skip'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: _next,
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
}

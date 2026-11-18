import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'actions.dart';
import 'app_state.dart';
import 'billing.dart';
import 'db.dart';
import 'models.dart';
import 'reminders.dart';
import 'screens/expenses.dart';
import 'screens/intro.dart';
import 'screens/my_home.dart';
import 'screens/onboarding.dart';
import 'screens/paywall.dart';
import 'screens/plan_screen.dart';
import 'screens/profile.dart';
import 'screens/scan.dart';
import 'screens/settings.dart';
import 'screens/task_detail.dart';
import 'screens/today.dart';
import 'theme.dart';
import 'widgets.dart';
import 'widgets/avatar_menu.dart';
import 'widgets/badge_celebration.dart';

/// Watches the app's routes so the Shell knows when it is back on
/// top after a pushed screen pops (one of the nudges that re-offers
/// a queued badge celebration; see _ShellState._maybeCelebrate).
final RouteObserver<PageRoute<dynamic>> appRouteObserver =
    RouteObserver<PageRoute<dynamic>>();

/// Tracks the route on top of the root navigator for the badge
/// celebration presenter (build 20). The original bug: a save flow
/// reloaded state — queueing a celebration — and then popped its own
/// route; a celebration dialog pushed in between was what that pop
/// closed, stranding the user on the form. So celebrations are only
/// presented once navigation has fully settled: the route on top is
/// a page, its transition has finished, and no navigation event has
/// happened since the offer was made (every event bumps [serial]).
/// Build 24 adds the Shell's settle delay on top: the offer must
/// also survive ~550ms after the last transition ends, and any
/// navigation event in that window restarts the wait (see
/// _ShellState._celebrationSettleDelay). Anything less and the
/// offer waits for the next nudge — a pop, a push, or the next
/// state change — so the celebration is never lost, just never
/// early.
class CelebrationObserver extends NavigatorObserver {
  Route<dynamic>? topRoute;
  int serial = 0;
  VoidCallback? onRouteSettled;

  void _track(Route<dynamic>? route) {
    topRoute = route;
    serial++;
    WidgetsBinding.instance
        .addPostFrameCallback((_) => onRouteSettled?.call());
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _track(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _track(previousRoute);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _track(newRoute);

  /// True when a celebration may go on screen: a page (not a dialog
  /// or sheet) is on top and its transition has finished.
  bool get canPresent {
    final route = topRoute;
    if (route is! PageRoute) return false;
    final status = route.animation?.status;
    return status == null || status == AnimationStatus.completed;
  }
}

final celebrationObserver = CelebrationObserver();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Guest mode must work even if Firebase is unreachable; the account
    // features simply stay off until it connects.
  }
  await Reminders.init();
  runApp(const NestKeepApp());
}

class NestKeepApp extends StatefulWidget {
  const NestKeepApp({super.key});

  @override
  State<NestKeepApp> createState() => _NestKeepAppState();
}

class _NestKeepAppState extends State<NestKeepApp> {
  final AppState state = AppState();
  final Billing billing = Billing();
  ThemeMode themeMode = ThemeMode.system;
  bool introSeen = false;

  @override
  void initState() {
    super.initState();
    state.init().then((_) async {
      final saved = await AppDb.getSetting('themeMode');
      final seenIntro = await AppDb.getSetting('introSeen');
      if (saved != null || seenIntro != null) {
        setState(() {
          if (saved != null) {
            themeMode = ThemeMode.values.firstWhere(
              (m) => m.name == saved,
              orElse: () => ThemeMode.system,
            );
          }
          introSeen = seenIntro == '1';
        });
      }
      await billing.init(state);
      if (state.hasHome) {
        await Reminders.reschedule(state.tasks, state.appliances);
      }
    });
  }

  @override
  void dispose() {
    billing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The builder wraps the whole app so an accent change repaints the
    // theme itself, not just the screens under it.
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        return MaterialApp(
          title: 'NestKeep',
          theme: nkLightTheme(state.accent),
          darkTheme: nkDarkTheme(state.accent),
          themeMode: themeMode,
          navigatorObservers: [appRouteObserver, celebrationObserver],
          home: _home(),
        );
      },
    );
  }

  Widget _home() {
    if (!state.loaded) {
      return const SplashScreen();
    }
    if (!state.hasHome) {
      if (!introSeen) {
        return IntroScreen(
          onDone: () async {
            await AppDb.setSetting('introSeen', '1');
            setState(() => introSeen = true);
          },
        );
      }
      return OnboardingScreen(state: state, onDone: () => setState(() {}));
    }
    return Shell(
      state: state,
      billing: billing,
      themeMode: themeMode,
      onThemeChanged: (mode) async {
        setState(() => themeMode = mode);
        await AppDb.setSetting('themeMode', mode.name);
      },
    );
  }
}

/// Branded splash shown while the local state loads (the load is fast;
/// the splash keeps the first paint on-brand instead of a bare spinner).
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/icon.png',
              width: 84,
              height: 84,
            ),
            const SizedBox(height: 20),
            Text(
              'NestKeep',
              style: TextStyle(
                fontSize: 31,
                fontWeight: FontWeight.w800,
                color: context.navyText,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Your home, handled.',
              style: TextStyle(fontSize: 15, color: context.muted),
            ),
            const SizedBox(height: 30),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ],
        ),
      ),
    );
  }
}

class Shell extends StatefulWidget {
  final AppState state;
  final Billing billing;
  final ThemeMode themeMode;
  final void Function(ThemeMode) onThemeChanged;

  const Shell({
    super.key,
    required this.state,
    required this.billing,
    required this.themeMode,
    required this.onThemeChanged,
  });

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with RouteAware {
  int _tab = 0;
  bool _celebrationShowing = false;

  AppState get state => widget.state;

  @override
  void initState() {
    super.initState();
    // The ticker center's celebration gate reads this Shell's live
    // state (build 23): tickers requested while a celebration is
    // showing or pending queue behind it instead of expiring
    // unseen underneath it.
    TickerCenter.gateClosed = () => _celebrationInTheWay;
    state.addListener(_maybeCelebrate);
    celebrationObserver.onRouteSettled = _maybeCelebrate;
    // Catch anything earned before the Shell existed (e.g. during
    // onboarding) on the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeCelebrate());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) appRouteObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    TickerCenter.gateClosed = null;
    appRouteObserver.unsubscribe(this);
    if (celebrationObserver.onRouteSettled == _maybeCelebrate) {
      celebrationObserver.onRouteSettled = null;
    }
    state.removeListener(_maybeCelebrate);
    super.dispose();
  }

  /// A pushed screen popped and the Shell is on top again: one more
  /// nudge to offer any celebration that queued while it was covered.
  @override
  void didPopNext() => _maybeCelebrate();

  /// Badge celebrations drain one at a time. Offers arrive from the
  /// state listener (a reload queued one), from the route observer
  /// (navigation settled), and from didPopNext. The offer is only
  /// taken up once navigation has fully settled — see
  /// [CelebrationObserver] — so a celebration can never be pushed
  /// in the middle of a save flow's own navigation, where the flow's
  /// next pop would close the dialog instead of its route (the
  /// build-20 appliance-save bug). An unsettled offer is not lost:
  /// the next nudge re-offers it.
  /// Tickers queue behind celebrations (build 23): the ticker
  /// center's gate reads this live — a celebration showing or
  /// waiting — so a confirmation requested while one is in the way
  /// lines up instead of expiring unseen under the celebration's
  /// backdrop. [TickerCenter.release] is called on every
  /// celebration nudge; it flushes the waiting tickers, in order,
  /// once the last celebration is gone.
  bool get _celebrationInTheWay =>
      _celebrationShowing || state.pendingCelebrations.isNotEmpty;

  /// The settle delay (build 24): how long navigation must stay
  /// settled before a celebration may be presented. Build 20's
  /// guard — present on the first frame after the offer, if the
  /// route on top looks settled — was not enough on a real phone:
  /// a save flow reloads (queueing the badge) and only THEN pops
  /// its form, and a frame landing in that gap presented the
  /// celebration over the form, so the flow's own pop closed the
  /// celebration dialog instead of the form and the user never
  /// reached the listing (Grand's report, reproduced in
  /// celebration_settle_test). Now the offer must survive this
  /// long after the last route transition ends; any navigation
  /// event during the wait restarts it, so a celebration is never
  /// on the stack while routes are being pushed or popped.
  static const _celebrationSettleDelay = Duration(milliseconds: 550);

  /// The navigation serial the current offer's wait is anchored to,
  /// and the frame timestamp the wait started from (stamped once
  /// presenting first becomes possible; while a transition is still
  /// running it keeps moving, so the delay counts from the end of
  /// the transition, not from the offer).
  int? _offerSerial;
  Duration? _offerSince;
  bool _offerLoopRunning = false;

  void _maybeCelebrate() {
    TickerCenter.release();
    if (_celebrationShowing || state.pendingCelebrations.isEmpty) {
      _offerSerial = null;
      _offerSince = null;
      return;
    }
    final serial = celebrationObserver.serial;
    if (_offerSerial != serial) {
      // A fresh offer, or navigation moved since the wait began:
      // the wait restarts from the latest event.
      _offerSerial = serial;
      _offerSince = null;
    }
    _keepOfferLoopRunning();
  }

  /// The offer loop: one post-frame callback at a time, re-armed
  /// while an offer waits, so the settle delay is measured on frame
  /// timestamps (real vsync on a phone, the test clock in tests)
  /// rather than on a timer that could fire mid-navigation.
  void _keepOfferLoopRunning() {
    if (_offerLoopRunning) return;
    _offerLoopRunning = true;
    WidgetsBinding.instance.addPostFrameCallback(_offerFrame);
    WidgetsBinding.instance.scheduleFrame();
  }

  void _offerFrame(Duration timeStamp) {
    _offerLoopRunning = false;
    if (!mounted ||
        _celebrationShowing ||
        state.pendingCelebrations.isEmpty) {
      _offerSerial = null;
      _offerSince = null;
      return;
    }
    final serial = celebrationObserver.serial;
    if (serial != _offerSerial) {
      // Navigation moved during the wait: restart it from here.
      _offerSerial = serial;
      _offerSince = timeStamp;
      _keepOfferLoopRunning();
      return;
    }
    if (!celebrationObserver.canPresent) {
      // A route transition is still running, or a dialog or sheet
      // is on top: presenting stays impossible, and the delay
      // counts from when it becomes possible — keep the wait
      // anchored to this frame.
      _offerSince = timeStamp;
      _keepOfferLoopRunning();
      return;
    }
    _offerSince ??= timeStamp;
    if (timeStamp - _offerSince! < _celebrationSettleDelay) {
      _keepOfferLoopRunning();
      return;
    }
    _offerSerial = null;
    _offerSince = null;
    _showCelebration();
  }

  Future<void> _showCelebration() async {
    if (!mounted || _celebrationShowing || state.pendingCelebrations.isEmpty) {
      return;
    }
    _celebrationShowing = true;
    final badge = state.pendingCelebrations.first;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: false,
      builder: (ctx) => BadgeCelebrationOverlay(
        badge: badge,
        onDismiss: () => Navigator.of(ctx).pop(),
      ),
    );
    _celebrationShowing = false;
    // Consuming notifies listeners, which queues the next celebration
    // if there is one; the release nudge runs off that same notify.
    // Release once more here for the case where the queue just
    // emptied, so any tickers that waited behind this celebration
    // flush now.
    state.consumeCelebration(badge.id);
    TickerCenter.release();
  }

  void _openPaywall() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('NestKeep Pro')),
        body: PaywallScreen(state: state, billing: widget.billing),
      ),
    ));
  }

  void _openTask(TaskInstance task) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TaskDetailScreen(state: state, task: task),
    ));
  }

  void _openIntro() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (ctx) => IntroScreen(
        replay: true,
        onDone: () => Navigator.of(ctx).pop(),
      ),
    ));
  }

  void _openExpenses() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Costs')),
        body: ExpensesScreen(state: state, onOpenPaywall: _openPaywall),
      ),
    ));
  }

  void _openSettings() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: SettingsScreen(
          state: state,
          onOpenPaywall: _openPaywall,
          onShowIntro: _openIntro,
        ),
      ),
    ));
  }

  /// The header avatar lives on every tab; its menu is the way to the
  /// picker, the paywall and Settings from anywhere. The Profile row
  /// is omitted while already on the Profile tab.
  void _onAvatarTap() {
    showAvatarMenu(
      context,
      state: state,
      onOpenPaywall: _openPaywall,
      onOpenSettings: _openSettings,
      onOpenProfile: _tab == 4 ? null : () => setState(() => _tab = 4),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      TodayScreen(
        state: state,
        onSeeAllPlan: () => setState(() => _tab = 1),
        onOpenTask: _openTask,
        onQuickDone: (t, r) => completeTask(state, t,
            costPaid: r.cost, doneBy: r.doneBy, doneNote: r.note),
        onAvatarTap: _onAvatarTap,
      ),
      PlanScreen(
        state: state,
        onOpenTask: _openTask,
        onOpenPaywall: _openPaywall,
        onAvatarTap: _onAvatarTap,
      ),
      ScanScreen(state: state, onAvatarTap: _onAvatarTap),
      MyHomeScreen(
        state: state,
        onOpenScan: () => setState(() => _tab = 2),
        onOpenCosts: _openExpenses,
        onOpenPaywall: _openPaywall,
        onAvatarTap: _onAvatarTap,
        onAddHome: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => OnboardingScreen(
            state: state,
            onDone: () => Navigator.of(context).pop(),
          ),
        )),
      ),
      ProfileScreen(
        state: state,
        themeMode: widget.themeMode,
        onThemeChanged: widget.onThemeChanged,
        onOpenPaywall: _openPaywall,
        onOpenSettings: _openSettings,
        onAvatarTap: _onAvatarTap,
      ),
    ];
    return Scaffold(
      body: SafeArea(child: pages[_tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today), label: 'Today'),
          NavigationDestination(icon: Icon(Icons.checklist_outlined), selectedIcon: Icon(Icons.checklist), label: 'Plan'),
          NavigationDestination(icon: Icon(Icons.document_scanner_outlined), selectedIcon: Icon(Icons.document_scanner), label: 'Scan'),
          NavigationDestination(icon: Icon(Icons.house_outlined), selectedIcon: Icon(Icons.house), label: 'My Home(s)'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

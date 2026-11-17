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
import 'screens/task_detail.dart';
import 'screens/today.dart';
import 'theme.dart';

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

class _ShellState extends State<Shell> {
  int _tab = 0;

  AppState get state => widget.state;

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

  @override
  Widget build(BuildContext context) {
    final pages = [
      TodayScreen(
        state: state,
        onSeeAllPlan: () => setState(() => _tab = 1),
        onOpenTask: _openTask,
        onQuickDone: (t) => completeTask(state, t),
      ),
      PlanScreen(state: state, onOpenTask: _openTask, onOpenPaywall: _openPaywall),
      ScanScreen(state: state),
      MyHomeScreen(
        state: state,
        onOpenScan: () => setState(() => _tab = 2),
        onOpenCosts: _openExpenses,
        onOpenPaywall: _openPaywall,
      ),
      ProfileScreen(
        state: state,
        themeMode: widget.themeMode,
        onThemeChanged: widget.onThemeChanged,
        onOpenPaywall: _openPaywall,
        onShowIntro: _openIntro,
        onAddHome: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => OnboardingScreen(
            state: state,
            onDone: () => Navigator.of(context).pop(),
          ),
        )),
      ),
    ];
    return Scaffold(
      body: SafeArea(child: pages[_tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Today'),
          NavigationDestination(icon: Icon(Icons.checklist_outlined), selectedIcon: Icon(Icons.checklist), label: 'Plan'),
          NavigationDestination(icon: Icon(Icons.document_scanner_outlined), selectedIcon: Icon(Icons.document_scanner), label: 'Scan'),
          NavigationDestination(icon: Icon(Icons.house_outlined), selectedIcon: Icon(Icons.house), label: 'My Home'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _brandName = 'BENOIT OLIVIER';
const _primaryNavy = Color(0xFF06111F);
const _electricCyan = Color(0xFF3F00FA);
const _success = Color(0xFF2DD4BF);
const _warning = Color(0xFFF59E0B);
const _danger = Color(0xFFEF4444);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BenoitOperationsApp());
}

class BenoitOperationsApp extends StatelessWidget {
  const BenoitOperationsApp({
    super.key,
    this.store,
    this.screenshotMode = const bool.fromEnvironment('SCREENSHOT_MODE'),
  });

  final LocalStore? store;
  final bool screenshotMode;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _electricCyan,
      brightness: Brightness.light,
      primary: const Color(0xFF007E8E),
      secondary: const Color(0xFF455A64),
      tertiary: const Color(0xFF0F766E),
      surface: const Color(0xFFF7FAFC),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: _brandName,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF3F7FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: _primaryNavy,
          foregroundColor: Colors.white,
          centerTitle: false,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFFE3EAF0)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF007E8E),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      home: OperationsShell(
        store: store ?? LocalStore(),
        screenshotMode: screenshotMode,
      ),
    );
  }
}

class OperationsShell extends StatefulWidget {
  const OperationsShell({
    required this.store,
    required this.screenshotMode,
    super.key,
  });

  final LocalStore store;
  final bool screenshotMode;

  @override
  State<OperationsShell> createState() => _OperationsShellState();
}

class _OperationsShellState extends State<OperationsShell> {
  late final OperationsState state;
  int selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    state = OperationsState(
      store: widget.store,
      screenshotMode: widget.screenshotMode,
    )..load();
  }

  @override
  void dispose() {
    state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        if (!state.isLoaded) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final screens = <Widget>[
          DashboardScreen(state: state),
          VisitorsScreen(state: state),
          TasksScreen(state: state),
          ComplianceScreen(state: state),
          SettingsScreen(state: state),
        ];

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 16,
            title: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset('docs/icon.png', width: 34, height: 34),
                ),
                const SizedBox(width: 12),
                const Flexible(
                  child: Text(
                    _brandName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          body: screens[selectedIndex],
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) =>
                setState(() => selectedIndex = index),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.analytics_outlined),
                selectedIcon: Icon(Icons.analytics),
                label: 'Overview',
              ),
              NavigationDestination(
                icon: Icon(Icons.badge_outlined),
                selectedIcon: Icon(Icons.badge),
                label: 'Visitors',
              ),
              NavigationDestination(
                icon: Icon(Icons.task_alt_outlined),
                selectedIcon: Icon(Icons.task_alt),
                label: 'Tasks',
              ),
              NavigationDestination(
                icon: Icon(Icons.verified_user_outlined),
                selectedIcon: Icon(Icons.verified_user),
                label: 'Compliance',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),
        );
      },
    );
  }
}

class OperationsState extends ChangeNotifier {
  OperationsState({required this.store, required this.screenshotMode});

  final LocalStore store;
  final bool screenshotMode;
  bool isLoaded = false;
  List<RevenueEntry> revenue = [];
  List<VisitorRecord> visitors = [];
  List<OpsTask> tasks = [];
  List<ComplianceReport> reports = [];
  AppPrefs prefs = const AppPrefs(
    monthlyTarget: 82000,
    compactView: false,
    dailyBrief: true,
  );

  Future<void> load() async {
    if (screenshotMode) {
      _loadSeedData();
      isLoaded = true;
      notifyListeners();
      return;
    }

    final snapshot = await store.read();
    revenue = snapshot.revenue;
    visitors = snapshot.visitors;
    tasks = snapshot.tasks;
    reports = snapshot.reports;
    prefs = snapshot.prefs;

    if (revenue.isEmpty &&
        visitors.isEmpty &&
        tasks.isEmpty &&
        reports.isEmpty) {
      _loadStarterData();
      await _save();
    }

    isLoaded = true;
    notifyListeners();
  }

  double get revenueTotal => revenue.fold(0, (sum, item) => sum + item.amount);

  double get revenueTargetProgress {
    if (prefs.monthlyTarget <= 0) {
      return 0;
    }
    return (revenueTotal / prefs.monthlyTarget).clamp(0, 1);
  }

  int get activeVisitors =>
      visitors.where((item) => item.checkOut == null).length;

  int get openTasks => tasks.where((task) => !task.done).length;

  int get complianceScore {
    if (reports.isEmpty) {
      return 0;
    }
    final totalItems = reports.fold<int>(
      0,
      (sum, item) => sum + item.totalItems,
    );
    final completed = reports.fold<int>(
      0,
      (sum, item) => sum + item.completedItems,
    );
    if (totalItems == 0) {
      return 0;
    }
    return ((completed / totalItems) * 100).round();
  }

  List<String> get activityFeed {
    final lines = <String>[
      if (revenue.isNotEmpty)
        '${revenue.last.channel} posted ${formatCurrency(revenue.last.amount)}',
      if (visitors.isNotEmpty)
        '${visitors.first.name} checked in for ${visitors.first.purpose.toLowerCase()}',
      if (tasks.any((task) => !task.done))
        '${tasks.firstWhere((task) => !task.done).title} is still open',
      if (reports.isNotEmpty)
        '${reports.first.area} report is at ${reports.first.percentComplete}%',
    ];
    return lines.take(4).toList();
  }

  Future<void> addRevenue(double amount, String channel) async {
    revenue = [
      ...revenue,
      RevenueEntry(
        id: createId(),
        date: DateTime.now(),
        amount: amount,
        channel: channel,
      ),
    ];
    await _saveAndNotify();
  }

  Future<void> addVisitor({
    required String name,
    required String company,
    required String purpose,
    required String host,
  }) async {
    visitors = [
      VisitorRecord(
        id: createId(),
        name: name,
        company: company,
        purpose: purpose,
        host: host,
        checkIn: DateTime.now(),
      ),
      ...visitors,
    ];
    await _saveAndNotify();
  }

  Future<void> checkOutVisitor(String id) async {
    visitors = [
      for (final visitor in visitors)
        if (visitor.id == id)
          visitor.copyWith(checkOut: DateTime.now(), forceCheckOut: true)
        else
          visitor,
    ];
    await _saveAndNotify();
  }

  Future<void> addTask({
    required String title,
    required String owner,
    required String area,
    required int priority,
  }) async {
    tasks = [
      OpsTask(
        id: createId(),
        title: title,
        owner: owner,
        area: area,
        dueDate: DateTime.now().add(const Duration(days: 2)),
        priority: priority,
      ),
      ...tasks,
    ];
    await _saveAndNotify();
  }

  Future<void> toggleTask(String id) async {
    tasks = [
      for (final task in tasks)
        if (task.id == id) task.copyWith(done: !task.done) else task,
    ];
    await _saveAndNotify();
  }

  Future<void> addComplianceReport({
    required String title,
    required String area,
    required int completedItems,
    required int totalItems,
    required String note,
  }) async {
    reports = [
      ComplianceReport(
        id: createId(),
        title: title,
        area: area,
        completedItems: completedItems,
        totalItems: math.max(totalItems, completedItems),
        dueDate: DateTime.now().add(const Duration(days: 7)),
        note: note,
      ),
      ...reports,
    ];
    await _saveAndNotify();
  }

  Future<void> updatePrefs(AppPrefs updated) async {
    prefs = updated;
    await _saveAndNotify();
  }

  Future<void> clearLocalData() async {
    revenue = [];
    visitors = [];
    tasks = [];
    reports = [];
    prefs = const AppPrefs(
      monthlyTarget: 82000,
      compactView: false,
      dailyBrief: true,
    );
    await store.clear();
    notifyListeners();
  }

  Future<void> _saveAndNotify() async {
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    if (screenshotMode) {
      return;
    }
    await store.write(
      AppSnapshot(
        revenue: revenue,
        visitors: visitors,
        tasks: tasks,
        reports: reports,
        prefs: prefs,
      ),
    );
  }

  void _loadStarterData() {
    final now = DateTime.now();
    revenue = [
      RevenueEntry(
        id: 'r1',
        date: now.subtract(const Duration(days: 9)),
        amount: 8700,
        channel: 'Service desk',
      ),
      RevenueEntry(
        id: 'r2',
        date: now.subtract(const Duration(days: 6)),
        amount: 12100,
        channel: 'Retail floor',
      ),
      RevenueEntry(
        id: 'r3',
        date: now.subtract(const Duration(days: 3)),
        amount: 9600,
        channel: 'Business accounts',
      ),
      RevenueEntry(id: 'r4', date: now, amount: 14350, channel: 'Renewals'),
    ];
    visitors = [
      VisitorRecord(
        id: 'v1',
        name: 'Nadia Laurent',
        company: 'Aster Supply',
        purpose: 'Vendor review',
        host: 'Operations',
        checkIn: now.subtract(const Duration(minutes: 46)),
      ),
    ];
    tasks = [
      OpsTask(
        id: 't1',
        title: 'BENOIT OLIVIER',
        owner: 'Finance',
        area: 'Revenue',
        dueDate: now.add(const Duration(days: 1)),
        priority: 3,
      ),
      OpsTask(
        id: 't2',
        title: 'Confirm visitor badges returned',
        owner: 'Front desk',
        area: 'Visitors',
        dueDate: now.add(const Duration(days: 1)),
        priority: 2,
      ),
    ];
    reports = [
      ComplianceReport(
        id: 'c1',
        title: 'Opening controls',
        area: 'Daily operations',
        completedItems: 17,
        totalItems: 20,
        dueDate: now.add(const Duration(days: 1)),
        note: 'Inventory count and access review remain open.',
      ),
    ];
  }

  void _loadSeedData() {
    final now = DateTime(2026, 5, 12, 10, 30);
    prefs = const AppPrefs(
      monthlyTarget: 92000,
      compactView: false,
      dailyBrief: true,
    );
    revenue = [
      RevenueEntry(
        id: 'r1',
        date: now.subtract(const Duration(days: 20)),
        amount: 5200,
        channel: 'Service desk',
      ),
      RevenueEntry(
        id: 'r2',
        date: now.subtract(const Duration(days: 17)),
        amount: 6800,
        channel: 'Retail floor',
      ),
      RevenueEntry(
        id: 'r3',
        date: now.subtract(const Duration(days: 13)),
        amount: 7400,
        channel: 'Online orders',
      ),
      RevenueEntry(
        id: 'r4',
        date: now.subtract(const Duration(days: 9)),
        amount: 11200,
        channel: 'Business accounts',
      ),
      RevenueEntry(
        id: 'r5',
        date: now.subtract(const Duration(days: 6)),
        amount: 9800,
        channel: 'Service desk',
      ),
      RevenueEntry(
        id: 'r6',
        date: now.subtract(const Duration(days: 3)),
        amount: 14200,
        channel: 'Renewals',
      ),
      RevenueEntry(id: 'r7', date: now, amount: 15850, channel: 'Retail floor'),
    ];
    visitors = [
      VisitorRecord(
        id: 'v1',
        name: 'Claire Marchand',
        company: 'Northline Partners',
        purpose: 'Compliance walkthrough',
        host: 'Olivier',
        checkIn: now.subtract(const Duration(minutes: 28)),
      ),
      VisitorRecord(
        id: 'v2',
        name: 'Yanis Bellamy',
        company: 'SecureGate',
        purpose: 'Badge audit',
        host: 'Front desk',
        checkIn: now.subtract(const Duration(hours: 2)),
        checkOut: now.subtract(const Duration(minutes: 35)),
      ),
      VisitorRecord(
        id: 'v3',
        name: 'Emma Roche',
        company: 'Aster Supply',
        purpose: 'Delivery exception',
        host: 'Operations',
        checkIn: now.subtract(const Duration(minutes: 52)),
      ),
    ];
    tasks = [
      OpsTask(
        id: 't1',
        title: 'Resolve revenue variance above threshold',
        owner: 'Finance',
        area: 'Revenue',
        dueDate: now.add(const Duration(days: 1)),
        priority: 3,
      ),
      OpsTask(
        id: 't2',
        title: 'Confirm badge return from morning vendors',
        owner: 'Front desk',
        area: 'Visitors',
        dueDate: now,
        priority: 2,
      ),
      OpsTask(
        id: 't3',
        title: 'Publish weekly compliance exceptions',
        owner: 'Operations',
        area: 'Compliance',
        dueDate: now.add(const Duration(days: 3)),
        priority: 2,
      ),
      OpsTask(
        id: 't4',
        title: 'Close archived task evidence',
        owner: 'Admin',
        area: 'Records',
        dueDate: now.subtract(const Duration(days: 1)),
        priority: 1,
        done: true,
      ),
    ];
    reports = [
      ComplianceReport(
        id: 'c1',
        title: 'Daily opening controls',
        area: 'Front office',
        completedItems: 22,
        totalItems: 24,
        dueDate: now.add(const Duration(days: 1)),
        note: 'Two evidence photos must be reviewed on site.',
      ),
      ComplianceReport(
        id: 'c2',
        title: 'Visitor log reconciliation',
        area: 'Security desk',
        completedItems: 15,
        totalItems: 18,
        dueDate: now.add(const Duration(days: 2)),
        note: 'Badge return entries are pending supervisor signoff.',
      ),
      ComplianceReport(
        id: 'c3',
        title: 'Revenue control file',
        area: 'Finance',
        completedItems: 13,
        totalItems: 16,
        dueDate: now.add(const Duration(days: 5)),
        note: 'Daily deposits are matched; variance notes need review.',
      ),
    ];
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({required this.state, super.key});

  final OperationsState state;

  @override
  Widget build(BuildContext context) {
    return AppScrollView(
      children: [
        _HeroPanel(state: state),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 700 ? 4 : 2;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: columns == 4 ? 1.35 : 1.05,
              children: [
                MetricCard(
                  icon: Icons.payments_outlined,
                  label: 'Revenue',
                  value: formatCurrency(state.revenueTotal),
                  accent: _electricCyan,
                ),
                MetricCard(
                  icon: Icons.trending_up,
                  label: 'Target',
                  value: '${(state.revenueTargetProgress * 100).round()}%',
                  accent: _success,
                ),
                MetricCard(
                  icon: Icons.badge_outlined,
                  label: 'On site',
                  value: '${state.activeVisitors}',
                  accent: const Color(0xFF38BDF8),
                ),
                MetricCard(
                  icon: Icons.task_alt,
                  label: 'Open tasks',
                  value: '${state.openTasks}',
                  accent: _warning,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Revenue analytics',
          trailing: FilledButton.icon(
            onPressed: () => showRevenueSheet(context, state),
            icon: const Icon(Icons.add_chart),
            label: const Text('Add revenue'),
          ),
          child: SizedBox(
            height: 170,
            child: RevenueChart(entries: state.revenue),
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Today',
          child: Column(
            children: [
              for (final activity in state.activityFeed)
                ListTile(
                  dense: state.prefs.compactView,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE5FBFD),
                    child: Icon(Icons.bolt, color: Color(0xFF007E8E)),
                  ),
                  title: Text(activity),
                  subtitle: const Text('Local workspace update'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.state});

  final OperationsState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _primaryNavy,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF14324C)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'docs/featured.png',
              fit: BoxFit.cover,
              color: Colors.black.withValues(alpha: 0.36),
              colorBlendMode: BlendMode.darken,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Operations control',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Revenue, visitors, tasks, and compliance in one local workspace.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.86),
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 9,
                    value: state.revenueTargetProgress,
                    backgroundColor: Colors.white.withValues(alpha: 0.22),
                    color: _electricCyan,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${formatCurrency(state.revenueTotal)} of ${formatCurrency(state.prefs.monthlyTarget)} monthly target',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class VisitorsScreen extends StatelessWidget {
  const VisitorsScreen({required this.state, super.key});

  final OperationsState state;

  @override
  Widget build(BuildContext context) {
    final active = state.visitors
        .where((item) => item.checkOut == null)
        .toList();
    final complete = state.visitors
        .where((item) => item.checkOut != null)
        .toList();

    return AppScrollView(
      children: [
        SectionHeader(
          title: 'Visitor management',
          action: FilledButton.icon(
            onPressed: () => showVisitorSheet(context, state),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('New visitor'),
          ),
        ),
        const SizedBox(height: 12),
        if (active.isEmpty)
          const EmptyCard(
            icon: Icons.badge_outlined,
            title: 'No visitors on site',
            body: 'Current visitor records appear here.',
          )
        else
          for (final visitor in active)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: VisitorTile(
                visitor: visitor,
                onTap: () => openVisitorDetail(context, state, visitor),
                onCheckOut: () => state.checkOutVisitor(visitor.id),
              ),
            ),
        const SizedBox(height: 8),
        SectionCard(
          title: 'Completed visits',
          child: Column(
            children: [
              for (final visitor in complete)
                ListTile(
                  leading: const Icon(
                    Icons.how_to_reg,
                    color: Color(0xFF007E8E),
                  ),
                  title: Text(visitor.name),
                  subtitle: Text(
                    '${visitor.company} - ${formatShortDate(visitor.checkIn)}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => openVisitorDetail(context, state, visitor),
                ),
              if (complete.isEmpty)
                const ListTile(
                  leading: Icon(Icons.history),
                  title: Text('No completed visits yet'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class VisitorTile extends StatelessWidget {
  const VisitorTile({
    required this.visitor,
    required this.onTap,
    required this.onCheckOut,
    super.key,
  });

  final VisitorRecord visitor;
  final VoidCallback onTap;
  final VoidCallback onCheckOut;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFE5FBFD),
                child: Text(
                  visitor.name.isEmpty ? '?' : visitor.name[0].toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF007E8E),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      visitor.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${visitor.company} - ${visitor.purpose}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Host: ${visitor.host}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Check out',
                onPressed: onCheckOut,
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VisitorDetailPage extends StatelessWidget {
  const VisitorDetailPage({
    required this.state,
    required this.visitorId,
    super.key,
  });

  final OperationsState state;
  final String visitorId;

  @override
  Widget build(BuildContext context) {
    final visitor = state.visitors.firstWhere((item) => item.id == visitorId);
    final active = visitor.checkOut == null;

    return Scaffold(
      appBar: AppBar(title: const Text('Visitor details')),
      body: AppScrollView(
        children: [
          SectionCard(
            title: visitor.name,
            child: Column(
              children: [
                DetailRow(
                  icon: Icons.business,
                  label: 'Company',
                  value: visitor.company,
                ),
                DetailRow(
                  icon: Icons.assignment_ind,
                  label: 'Purpose',
                  value: visitor.purpose,
                ),
                DetailRow(
                  icon: Icons.person_pin,
                  label: 'Host',
                  value: visitor.host,
                ),
                DetailRow(
                  icon: Icons.login,
                  label: 'Check-in',
                  value: formatShortDate(visitor.checkIn),
                ),
                DetailRow(
                  icon: active ? Icons.radio_button_checked : Icons.logout,
                  label: 'Status',
                  value: active ? 'Currently on site' : 'Checked out',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (active)
            FilledButton.icon(
              onPressed: () {
                state.checkOutVisitor(visitor.id);
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.logout),
              label: const Text('Check out visitor'),
            ),
        ],
      ),
    );
  }
}

class TasksScreen extends StatelessWidget {
  const TasksScreen({required this.state, super.key});

  final OperationsState state;

  @override
  Widget build(BuildContext context) {
    final open = state.tasks.where((task) => !task.done).toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));
    final closed = state.tasks.where((task) => task.done).toList();

    return AppScrollView(
      children: [
        SectionHeader(
          title: 'Task management',
          action: FilledButton.icon(
            onPressed: () => showTaskSheet(context, state),
            icon: const Icon(Icons.add_task),
            label: const Text('Add task'),
          ),
        ),
        const SizedBox(height: 12),
        for (final task in open)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TaskTile(
              task: task,
              onToggle: () => state.toggleTask(task.id),
            ),
          ),
        if (open.isEmpty)
          const EmptyCard(
            icon: Icons.task_alt,
            title: 'No open tasks',
            body: 'Completed work stays available below.',
          ),
        const SizedBox(height: 8),
        SectionCard(
          title: 'Closed work',
          child: Column(
            children: [
              for (final task in closed)
                CheckboxListTile(
                  value: task.done,
                  onChanged: (_) => state.toggleTask(task.id),
                  title: Text(task.title),
                  subtitle: Text('${task.area} - ${task.owner}'),
                  secondary: const Icon(
                    Icons.check_circle,
                    color: Color(0xFF0F766E),
                  ),
                ),
              if (closed.isEmpty)
                const ListTile(
                  leading: Icon(Icons.inbox_outlined),
                  title: Text('No closed tasks yet'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class TaskTile extends StatelessWidget {
  const TaskTile({required this.task, required this.onToggle, super.key});

  final OpsTask task;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final color = switch (task.priority) {
      3 => _danger,
      2 => _warning,
      _ => _success,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 5,
              height: 78,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      StatusChip(icon: Icons.person, label: task.owner),
                      StatusChip(
                        icon: Icons.workspaces_outline,
                        label: task.area,
                      ),
                      StatusChip(
                        icon: Icons.event,
                        label: formatShortDate(task.dueDate),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Mark complete',
              onPressed: onToggle,
              icon: const Icon(Icons.check),
            ),
          ],
        ),
      ),
    );
  }
}

class ComplianceScreen extends StatelessWidget {
  const ComplianceScreen({required this.state, super.key});

  final OperationsState state;

  @override
  Widget build(BuildContext context) {
    return AppScrollView(
      children: [
        SectionHeader(
          title: 'Compliance reporting',
          action: FilledButton.icon(
            onPressed: () => showComplianceSheet(context, state),
            icon: const Icon(Icons.post_add),
            label: const Text('Add report'),
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Readiness score',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${state.complianceScore}%',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF007E8E),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text('Checklist completion across active reports.'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                minHeight: 10,
                borderRadius: BorderRadius.circular(8),
                value: (state.complianceScore / 100).clamp(0, 1),
                color: _success,
                backgroundColor: const Color(0xFFE2E8F0),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (final report in state.reports)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ReportTile(report: report),
          ),
      ],
    );
  }
}

class ReportTile extends StatelessWidget {
  const ReportTile({required this.report, super.key});

  final ComplianceReport report;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_user, color: Color(0xFF007E8E)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    report.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  '${report.percentComplete}%',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: report.percentComplete / 100,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
              color: report.percentComplete >= 90 ? _success : _warning,
              backgroundColor: const Color(0xFFE2E8F0),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                StatusChip(icon: Icons.work_outline, label: report.area),
                StatusChip(
                  icon: Icons.fact_check,
                  label: '${report.completedItems}/${report.totalItems} checks',
                ),
                StatusChip(
                  icon: Icons.event_available,
                  label: formatShortDate(report.dueDate),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(report.note),
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({required this.state, super.key});

  final OperationsState state;

  @override
  Widget build(BuildContext context) {
    return AppScrollView(
      children: [
        SectionCard(
          title: 'Workspace',
          child: Column(
            children: [
              SwitchListTile(
                value: state.prefs.compactView,
                onChanged: (value) =>
                    state.updatePrefs(state.prefs.copyWith(compactView: value)),
                title: const Text('Compact lists'),
                secondary: const Icon(Icons.density_medium),
              ),
              SwitchListTile(
                value: state.prefs.dailyBrief,
                onChanged: (value) =>
                    state.updatePrefs(state.prefs.copyWith(dailyBrief: value)),
                title: const Text('Daily brief'),
                secondary: const Icon(Icons.summarize_outlined),
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Monthly revenue target'),
                subtitle: Text(formatCurrency(state.prefs.monthlyTarget)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Local records',
          child: Column(
            children: [
              DetailRow(
                icon: Icons.payments_outlined,
                label: 'Revenue entries',
                value: '${state.revenue.length}',
              ),
              DetailRow(
                icon: Icons.badge_outlined,
                label: 'Visitor records',
                value: '${state.visitors.length}',
              ),
              DetailRow(
                icon: Icons.task_alt,
                label: 'Task records',
                value: '${state.tasks.length}',
              ),
              DetailRow(
                icon: Icons.verified_user_outlined,
                label: 'Compliance reports',
                value: '${state.reports.length}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Privacy',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Records stay on this device. The app has no account, no cloud sync, no analytics, and no advertising tracking.',
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: state.screenshotMode
                    ? null
                    : () => confirmClearData(context, state),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Clear local records'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.title, required this.action, super.key});

  final String title;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: _primaryNavy,
            ),
          ),
        ),
        const SizedBox(width: 10),
        action,
      ],
    );
  }
}

class AppScrollView extends StatelessWidget {
  const AppScrollView({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(padding: const EdgeInsets.all(16), children: children),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.title,
    required this.child,
    this.trailing,
    super.key,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: _primaryNavy,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent),
            const Spacer(),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: _primaryNavy,
              ),
            ),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({required this.icon, required this.label, super.key});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6F8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF007E8E)),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class DetailRow extends StatelessWidget {
  const DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF007E8E)),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyCard extends StatelessWidget {
  const EmptyCard({
    required this.icon,
    required this.title,
    required this.body,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF007E8E)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RevenueChart extends StatelessWidget {
  const RevenueChart({required this.entries, super.key});

  final List<RevenueEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(child: Text('No revenue entries yet'));
    }
    return CustomPaint(
      painter: RevenueChartPainter(entries),
      child: const SizedBox.expand(),
    );
  }
}

class RevenueChartPainter extends CustomPainter {
  RevenueChartPainter(this.entries);

  final List<RevenueEntry> entries;

  @override
  void paint(Canvas canvas, Size size) {
    final sorted = [...entries]..sort((a, b) => a.date.compareTo(b.date));
    final maxAmount = sorted.map((item) => item.amount).reduce(math.max);
    final barWidth = size.width / (sorted.length * 1.8);
    final gap = barWidth * 0.8;
    final baseY = size.height - 18;
    final chartHeight = size.height - 34;
    final axis = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1;
    final barPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF04D9E8), Color(0xFF007E8E)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    final linePaint = Paint()
      ..color = _primaryNavy
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final dotPaint = Paint()..color = _electricCyan;

    for (var i = 0; i < 4; i++) {
      final y = 10 + (chartHeight / 3) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), axis);
    }

    final points = <Offset>[];
    for (var i = 0; i < sorted.length; i++) {
      final height = (sorted[i].amount / maxAmount) * chartHeight;
      final x = i * (barWidth + gap) + gap / 2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, baseY - height, barWidth, height),
        const Radius.circular(4),
      );
      canvas.drawRRect(rect, barPaint);
      points.add(Offset(x + barWidth / 2, baseY - height));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, linePaint);
    for (final point in points) {
      canvas.drawCircle(point, 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant RevenueChartPainter oldDelegate) {
    return oldDelegate.entries != entries;
  }
}

Future<void> showRevenueSheet(
  BuildContext context,
  OperationsState state,
) async {
  final amountController = TextEditingController();
  final channelController = TextEditingController(text: 'Retail floor');
  final formKey = GlobalKey<FormState>();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      return FormSheet(
        title: 'Add revenue',
        formKey: formKey,
        children: [
          TextFormField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Amount'),
            validator: (value) {
              final amount = double.tryParse(value ?? '');
              if (amount == null || amount <= 0) {
                return 'Enter a positive amount';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: channelController,
            decoration: const InputDecoration(labelText: 'Channel'),
            validator: requiredText,
          ),
        ],
        onSave: () {
          if (!formKey.currentState!.validate()) {
            return;
          }
          state.addRevenue(
            double.parse(amountController.text),
            channelController.text.trim(),
          );
          Navigator.of(context).pop();
        },
      );
    },
  );
}

Future<void> showVisitorSheet(
  BuildContext context,
  OperationsState state,
) async {
  final nameController = TextEditingController();
  final companyController = TextEditingController();
  final purposeController = TextEditingController();
  final hostController = TextEditingController(text: 'Operations');
  final formKey = GlobalKey<FormState>();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      return FormSheet(
        title: 'New visitor',
        formKey: formKey,
        children: [
          TextFormField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Visitor name'),
            validator: requiredText,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: companyController,
            decoration: const InputDecoration(labelText: 'Company'),
            validator: requiredText,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: purposeController,
            decoration: const InputDecoration(labelText: 'Purpose'),
            validator: requiredText,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: hostController,
            decoration: const InputDecoration(labelText: 'Host'),
            validator: requiredText,
          ),
        ],
        onSave: () {
          if (!formKey.currentState!.validate()) {
            return;
          }
          state.addVisitor(
            name: nameController.text.trim(),
            company: companyController.text.trim(),
            purpose: purposeController.text.trim(),
            host: hostController.text.trim(),
          );
          Navigator.of(context).pop();
        },
      );
    },
  );
}

Future<void> showTaskSheet(BuildContext context, OperationsState state) async {
  final titleController = TextEditingController();
  final ownerController = TextEditingController(text: 'Operations');
  final areaController = TextEditingController(text: 'Revenue');
  var priority = 2;
  final formKey = GlobalKey<FormState>();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return FormSheet(
            title: 'Add task',
            formKey: formKey,
            children: [
              TextFormField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Task title'),
                validator: requiredText,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: ownerController,
                decoration: const InputDecoration(labelText: 'Owner'),
                validator: requiredText,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: areaController,
                decoration: const InputDecoration(labelText: 'Area'),
                validator: requiredText,
              ),
              const SizedBox(height: 12),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(
                    value: 1,
                    label: Text('Low'),
                    icon: Icon(Icons.flag_outlined),
                  ),
                  ButtonSegment(
                    value: 2,
                    label: Text('Med'),
                    icon: Icon(Icons.flag),
                  ),
                  ButtonSegment(
                    value: 3,
                    label: Text('High'),
                    icon: Icon(Icons.priority_high),
                  ),
                ],
                selected: {priority},
                onSelectionChanged: (values) =>
                    setSheetState(() => priority = values.first),
              ),
            ],
            onSave: () {
              if (!formKey.currentState!.validate()) {
                return;
              }
              state.addTask(
                title: titleController.text.trim(),
                owner: ownerController.text.trim(),
                area: areaController.text.trim(),
                priority: priority,
              );
              Navigator.of(context).pop();
            },
          );
        },
      );
    },
  );
}

Future<void> showComplianceSheet(
  BuildContext context,
  OperationsState state,
) async {
  final titleController = TextEditingController();
  final areaController = TextEditingController(text: 'Front office');
  final completeController = TextEditingController(text: '8');
  final totalController = TextEditingController(text: '10');
  final noteController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      return FormSheet(
        title: 'Add report',
        formKey: formKey,
        children: [
          TextFormField(
            controller: titleController,
            decoration: const InputDecoration(labelText: 'Report title'),
            validator: requiredText,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: areaController,
            decoration: const InputDecoration(labelText: 'Area'),
            validator: requiredText,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: completeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Complete'),
                  validator: wholeNumberText,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: totalController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Total'),
                  validator: wholeNumberText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: noteController,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Note'),
            validator: requiredText,
          ),
        ],
        onSave: () {
          if (!formKey.currentState!.validate()) {
            return;
          }
          state.addComplianceReport(
            title: titleController.text.trim(),
            area: areaController.text.trim(),
            completedItems: int.parse(completeController.text),
            totalItems: int.parse(totalController.text),
            note: noteController.text.trim(),
          );
          Navigator.of(context).pop();
        },
      );
    },
  );
}

class FormSheet extends StatelessWidget {
  const FormSheet({
    required this.title,
    required this.formKey,
    required this.children,
    required this.onSave,
    super.key,
  });

  final String title;
  final GlobalKey<FormState> formKey;
  final List<Widget> children;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              ...children,
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onSave,
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void openVisitorDetail(
  BuildContext context,
  OperationsState state,
  VisitorRecord visitor,
) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) =>
          VisitorDetailPage(state: state, visitorId: visitor.id),
    ),
  );
}

Future<void> confirmClearData(
  BuildContext context,
  OperationsState state,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Clear local records?'),
      content: const Text(
        'This removes locally saved operations records from this device.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Clear'),
        ),
      ],
    ),
  );
  if (confirmed ?? false) {
    await state.clearLocalData();
  }
}

String? requiredText(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Required';
  }
  return null;
}

String? wholeNumberText(String? value) {
  final parsed = int.tryParse(value ?? '');
  if (parsed == null || parsed < 0) {
    return 'Enter a whole number';
  }
  return null;
}

String formatCurrency(double amount) {
  final rounded = amount.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < rounded.length; i++) {
    final position = rounded.length - i;
    buffer.write(rounded[i]);
    if (position > 1 && position % 3 == 1) {
      buffer.write(',');
    }
  }
  return '\$${buffer.toString()}';
}

String formatShortDate(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${date.month}/${date.day} $hour:$minute';
}

String createId() => DateTime.now().microsecondsSinceEpoch.toString();

class LocalStore {
  static const _snapshotKey = 'operations_snapshot_v1';

  Future<AppSnapshot> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_snapshotKey);
    if (raw == null) {
      return AppSnapshot.empty();
    }
    return AppSnapshot.fromJson(jsonDecode(raw) as Map<String, Object?>);
  }

  Future<void> write(AppSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_snapshotKey, jsonEncode(snapshot.toJson()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_snapshotKey);
  }
}

class AppSnapshot {
  const AppSnapshot({
    required this.revenue,
    required this.visitors,
    required this.tasks,
    required this.reports,
    required this.prefs,
  });

  factory AppSnapshot.empty() {
    return const AppSnapshot(
      revenue: [],
      visitors: [],
      tasks: [],
      reports: [],
      prefs: AppPrefs(
        monthlyTarget: 82000,
        compactView: false,
        dailyBrief: true,
      ),
    );
  }

  factory AppSnapshot.fromJson(Map<String, Object?> json) {
    return AppSnapshot(
      revenue: parseList(json['revenue'], RevenueEntry.fromJson),
      visitors: parseList(json['visitors'], VisitorRecord.fromJson),
      tasks: parseList(json['tasks'], OpsTask.fromJson),
      reports: parseList(json['reports'], ComplianceReport.fromJson),
      prefs: json['prefs'] is Map
          ? AppPrefs.fromJson((json['prefs']! as Map).cast<String, Object?>())
          : AppSnapshot.empty().prefs,
    );
  }

  final List<RevenueEntry> revenue;
  final List<VisitorRecord> visitors;
  final List<OpsTask> tasks;
  final List<ComplianceReport> reports;
  final AppPrefs prefs;

  Map<String, Object?> toJson() => {
    'revenue': revenue.map((item) => item.toJson()).toList(),
    'visitors': visitors.map((item) => item.toJson()).toList(),
    'tasks': tasks.map((item) => item.toJson()).toList(),
    'reports': reports.map((item) => item.toJson()).toList(),
    'prefs': prefs.toJson(),
  };
}

List<T> parseList<T>(
  Object? value,
  T Function(Map<String, Object?> json) parse,
) {
  if (value is! List) {
    return [];
  }
  return value
      .whereType<Map>()
      .map((item) => parse(item.cast<String, Object?>()))
      .toList();
}

class RevenueEntry {
  const RevenueEntry({
    required this.id,
    required this.date,
    required this.amount,
    required this.channel,
  });

  factory RevenueEntry.fromJson(Map<String, Object?> json) {
    return RevenueEntry(
      id: json['id'] as String? ?? createId(),
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      channel: json['channel'] as String? ?? 'Revenue',
    );
  }

  final String id;
  final DateTime date;
  final double amount;
  final String channel;

  Map<String, Object?> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'amount': amount,
    'channel': channel,
  };
}

class VisitorRecord {
  const VisitorRecord({
    required this.id,
    required this.name,
    required this.company,
    required this.purpose,
    required this.host,
    required this.checkIn,
    this.checkOut,
  });

  factory VisitorRecord.fromJson(Map<String, Object?> json) {
    return VisitorRecord(
      id: json['id'] as String? ?? createId(),
      name: json['name'] as String? ?? 'Visitor',
      company: json['company'] as String? ?? 'Company',
      purpose: json['purpose'] as String? ?? 'Visit',
      host: json['host'] as String? ?? 'Operations',
      checkIn:
          DateTime.tryParse(json['checkIn'] as String? ?? '') ?? DateTime.now(),
      checkOut: DateTime.tryParse(json['checkOut'] as String? ?? ''),
    );
  }

  final String id;
  final String name;
  final String company;
  final String purpose;
  final String host;
  final DateTime checkIn;
  final DateTime? checkOut;

  VisitorRecord copyWith({
    String? id,
    String? name,
    String? company,
    String? purpose,
    String? host,
    DateTime? checkIn,
    DateTime? checkOut,
    bool forceCheckOut = false,
  }) {
    return VisitorRecord(
      id: id ?? this.id,
      name: name ?? this.name,
      company: company ?? this.company,
      purpose: purpose ?? this.purpose,
      host: host ?? this.host,
      checkIn: checkIn ?? this.checkIn,
      checkOut: forceCheckOut ? checkOut : checkOut ?? this.checkOut,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'company': company,
    'purpose': purpose,
    'host': host,
    'checkIn': checkIn.toIso8601String(),
    'checkOut': checkOut?.toIso8601String(),
  };
}

class OpsTask {
  const OpsTask({
    required this.id,
    required this.title,
    required this.owner,
    required this.area,
    required this.dueDate,
    required this.priority,
    this.done = false,
  });

  factory OpsTask.fromJson(Map<String, Object?> json) {
    return OpsTask(
      id: json['id'] as String? ?? createId(),
      title: json['title'] as String? ?? 'Task',
      owner: json['owner'] as String? ?? 'Operations',
      area: json['area'] as String? ?? 'General',
      dueDate:
          DateTime.tryParse(json['dueDate'] as String? ?? '') ?? DateTime.now(),
      priority: (json['priority'] as num?)?.toInt() ?? 2,
      done: json['done'] as bool? ?? false,
    );
  }

  final String id;
  final String title;
  final String owner;
  final String area;
  final DateTime dueDate;
  final int priority;
  final bool done;

  OpsTask copyWith({bool? done}) {
    return OpsTask(
      id: id,
      title: title,
      owner: owner,
      area: area,
      dueDate: dueDate,
      priority: priority,
      done: done ?? this.done,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'owner': owner,
    'area': area,
    'dueDate': dueDate.toIso8601String(),
    'priority': priority,
    'done': done,
  };
}

class ComplianceReport {
  const ComplianceReport({
    required this.id,
    required this.title,
    required this.area,
    required this.completedItems,
    required this.totalItems,
    required this.dueDate,
    required this.note,
  });

  factory ComplianceReport.fromJson(Map<String, Object?> json) {
    return ComplianceReport(
      id: json['id'] as String? ?? createId(),
      title: json['title'] as String? ?? 'Report',
      area: json['area'] as String? ?? 'Operations',
      completedItems: (json['completedItems'] as num?)?.toInt() ?? 0,
      totalItems: (json['totalItems'] as num?)?.toInt() ?? 1,
      dueDate:
          DateTime.tryParse(json['dueDate'] as String? ?? '') ?? DateTime.now(),
      note: json['note'] as String? ?? 'No notes recorded.',
    );
  }

  final String id;
  final String title;
  final String area;
  final int completedItems;
  final int totalItems;
  final DateTime dueDate;
  final String note;

  int get percentComplete {
    if (totalItems <= 0) {
      return 0;
    }
    return ((completedItems / totalItems) * 100).clamp(0, 100).round();
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'area': area,
    'completedItems': completedItems,
    'totalItems': totalItems,
    'dueDate': dueDate.toIso8601String(),
    'note': note,
  };
}

class AppPrefs {
  const AppPrefs({
    required this.monthlyTarget,
    required this.compactView,
    required this.dailyBrief,
  });

  factory AppPrefs.fromJson(Map<String, Object?> json) {
    return AppPrefs(
      monthlyTarget: (json['monthlyTarget'] as num?)?.toDouble() ?? 82000,
      compactView: json['compactView'] as bool? ?? false,
      dailyBrief: json['dailyBrief'] as bool? ?? true,
    );
  }

  final double monthlyTarget;
  final bool compactView;
  final bool dailyBrief;

  AppPrefs copyWith({
    double? monthlyTarget,
    bool? compactView,
    bool? dailyBrief,
  }) {
    return AppPrefs(
      monthlyTarget: monthlyTarget ?? this.monthlyTarget,
      compactView: compactView ?? this.compactView,
      dailyBrief: dailyBrief ?? this.dailyBrief,
    );
  }

  Map<String, Object?> toJson() => {
    'monthlyTarget': monthlyTarget,
    'compactView': compactView,
    'dailyBrief': dailyBrief,
  };
}

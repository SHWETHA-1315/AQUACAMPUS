import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'campus_store.dart';
import 'water_budget.dart';
import 'water_math.dart';

// AQUACAMPUS · Sky, ocean and white design language
const sea = Color(0xFF0675C9);
const ink = Color(0xFF103B63);
const pale = Color(0xFFF0F9FF);
const amber = Color(0xFFF5A524);
const brightSky = Color(0xFF53CFFF);
const oceanBlue = Color(0xFF074E99);
final formatter = NumberFormat('#,##0.#');
String litres(num value) => '${formatter.format(value)} L';
String briefTime(dynamic value) {
  if (value == null || '$value'.trim().isEmpty) return 'Not recorded';
  final d = DateTime.tryParse('$value');
  return d == null
      ? 'Unknown time'
      : DateFormat('dd MMM, h:mm a').format(d.toLocal());
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = CampusStore();
  await store.initialize();
  runApp(AquaApp(store: store));
}

class AquaApp extends StatelessWidget {
  const AquaApp({super.key, required this.store});
  final CampusStore store;
  @override
  Widget build(BuildContext context) => MaterialApp(
            title: 'AQUACAMPUS',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
                useMaterial3: true,
                scaffoldBackgroundColor: pale,
                colorScheme: ColorScheme.fromSeed(
                    seedColor: sea, primary: sea, surface: Colors.white),
                appBarTheme: const AppBarTheme(
                    backgroundColor: Colors.white,
                    foregroundColor: ink,
                    centerTitle: false),
                inputDecorationTheme: InputDecorationTheme(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                        borderSide: const BorderSide(color: Color(0xFFC9E6FA))),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                        borderSide: const BorderSide(color: Color(0xFFC9E6FA))),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13)),
                elevatedButtonTheme: ElevatedButtonThemeData(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: sea,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 46),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)))),
                cardTheme: CardThemeData(
                    color: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                        side: const BorderSide(color: Color(0xFFCEE8F8))))),
            // Preserve Navigator and ThemeData while Firestore streams update.
            home: AnimatedBuilder(
              animation: store,
              builder: (context, _) => store.loading
                  ? const Scaffold(body: Center(child: CircularProgressIndicator()))
                  : !store.cloud
                      ? BackendRequiredPage(store: store)
                      : !store.signedIn
                          ? EntryPage(store: store)
                          : !store.approved
                              ? ApprovalPage(store: store)
                              : AppShell(store: store),
            ),
          );
}

class EntryPage extends StatefulWidget {
  const EntryPage({super.key, required this.store});
  final CampusStore store;
  @override
  State<EntryPage> createState() => _EntryPageState();
}

/// Waves and ocean light are drawn in Flutter. No external images or
/// third-party websites are used by the mobile application.
class OceanHero extends StatelessWidget {
  const OceanHero({
    super.key,
    required this.title,
    required this.subtitle,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
      height: compact ? 158 : 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        gradient: const LinearGradient(
          colors: [brightSky, sea, oceanBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x2459A8D7), blurRadius: 24, offset: Offset(0, 12))
        ],
      ),
      child: ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: CustomPaint(
              painter: OceanWavePainter(),
              child: Padding(
                  padding: EdgeInsets.all(compact ? 21 : 27),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 46, height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.white54),
                        ),
                        child: const Icon(Icons.water_drop_rounded, size: 30, color: Colors.white),
                      ),
                      SizedBox(height: compact ? 10 : 15),
                      Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 24 : 31,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.8,
                        )),
                      const SizedBox(height: 4),
                      Text(subtitle, maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFFE3F7FF), fontSize: 12)),
                    ],
                  )))));

}

class OceanWavePainter extends CustomPainter {
  const OceanWavePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final farWave = Path()
      ..moveTo(0, size.height * .73)
      ..quadraticBezierTo(size.width * .28, size.height * .58,
          size.width * .54, size.height * .75)
      ..quadraticBezierTo(size.width * .83, size.height * .92,
          size.width, size.height * .63)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(farWave, Paint()..color = Colors.white.withValues(alpha: .12));
    final nearWave = Path()
      ..moveTo(0, size.height * .87)
      ..quadraticBezierTo(size.width * .30, size.height * .72,
          size.width * .62, size.height * .91)
      ..quadraticBezierTo(size.width * .83, size.height * 1.0,
          size.width, size.height * .83)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(nearWave, Paint()..color = Colors.white.withValues(alpha: .20));
    final ripple = Paint()
      ..color = Colors.white.withValues(alpha: .16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawArc(Rect.fromLTWH(size.width * .70, size.height * .08,
      size.width * .44, size.width * .44), 0.2, 3.3, false, ripple);
  }
  @override
  bool shouldRepaint(covariant OceanWavePainter oldDelegate) => false;
}

class BackendRequiredPage extends StatelessWidget {
  const BackendRequiredPage({super.key, required this.store});
  final CampusStore store;
  @override
  Widget build(BuildContext context) => Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 530),
            child: ListView(shrinkWrap: true,
              padding: const EdgeInsets.all(22),
              children: [
                const OceanHero(
                  title: 'AQUACAMPUS',
                  subtitle: 'One campus. One secure water network.',
                ),
                const SizedBox(height: 22),
                const Surface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.cloud_off_rounded, color: sea, size: 38),
                      SizedBox(height: 10),
                      Text('Campus connection required',
                        style: TextStyle(fontWeight: FontWeight.w900,
                            fontSize: 19, color: ink)),
                      SizedBox(height: 8),
                      Text(
                        'AQUACAMPUS uses real Firebase accounts and live water records only. '
                        'The administrator must provide an Android app built for the campus Firebase project. '
                        'No example readings, simulated logins or local-mode access are available.',
                        style: TextStyle(height: 1.6, color: ink)),
                    ],
                  ),
                ),
                if (store.message != null) ...[
                  const SizedBox(height: 8),
                  InfoBanner(store.message!, warning: true),
                ],
              ],
            ),
          ),
        ),
      ));
}

class _EntryPageState extends State<EntryPage> {
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  bool create = false;
  bool busy = false;
  bool showPassword = false;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEAF8FF), Colors.white, Color(0xFFE6F6FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const OceanHero(
                      title: 'AQUACAMPUS',
                      subtitle: 'Your campus water, connected in real time.',
                    ),
                    const SizedBox(height: 22),
                    Surface(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          const Icon(Icons.verified_user_outlined, color: sea),
                          const SizedBox(width: 9),
                          Expanded(child: Text(
                            create ? 'Create your campus account' : 'Welcome back',
                            style: const TextStyle(fontWeight: FontWeight.w900,
                                fontSize: 21, color: ink),
                          )),
                        ]),
                        const SizedBox(height: 7),
                        const Text('Secure sign-in · Firebase Authentication',
                          style: TextStyle(fontSize: 12, color: Colors.black54)),
                        const SizedBox(height: 18),
                        if (create) ...[
                          TextField(
                            controller: name,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.person_outline),
                              labelText: 'Your full name',
                            ),
                          ),
                          const SizedBox(height: 13),
                        ],
                        TextField(
                          controller: email,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.alternate_email),
                            labelText: 'College email address',
                          ),
                        ),
                        const SizedBox(height: 13),
                        TextField(
                          controller: password,
                          obscureText: !showPassword,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.lock_outline),
                            labelText: 'Password',
                            suffixIcon: IconButton(
                              icon: Icon(showPassword
                                ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                              onPressed: () =>
                                setState(() => showPassword = !showPassword),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: busy ? null : () async {
                            if (!email.text.contains('@') ||
                                password.text.length < 6 ||
                                (create && name.text.trim().length < 2)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text(
                                  'Enter a valid email, password (6+ characters), and full name.')),
                              );
                              return;
                            }
                            setState(() => busy = true);
                            try {
                              await store.emailLogin(email.text.trim(), password.text,
                                create: create, name: name.text.trim());
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(create
                                  ? 'Account created. Await admin verification.'
                                  : 'Signed in to campus.'),
                              ));
                            } catch (error) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('$error')),
                              );
                            } finally {
                              if (mounted) setState(() => busy = false);
                            }
                          },
                          icon: Icon(create ? Icons.person_add_alt_1 : Icons.login),
                          label: Text(busy ? 'Connecting…'
                              : create ? 'Request campus account' : 'Sign in'),
                        ),
                        const SizedBox(height: 8),
                        if (!create)
                          TextButton.icon(
                            onPressed: busy ? null : () async {
                              if (!email.text.contains('@')) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text(
                                    'Enter your registered email first.')),
                                );
                                return;
                              }
                              setState(() => busy = true);
                              try {
                                await store.sendPasswordReset(email.text);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text(
                                    'If this address is registered, check your email for a reset link.')),
                                );
                              } catch (error) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(
                                    'Could not request reset: $error')),
                                );
                              } finally {
                                if (mounted) setState(() => busy = false);
                              }
                            },
                            icon: const Icon(Icons.key_outlined, size: 17),
                            label: const Text('Forgot password?'),
                          ),
                        TextButton(
                          onPressed: busy ? null : () => setState(() => create = !create),
                          child: Text(create
                            ? 'Already registered? Sign in'
                            : 'New to AQUACAMPUS? Register'),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Admin approves every account and assigns an official role, '
                          'hostel and room. Only verified inputs appear in the water network.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: Colors.black54,
                              height: 1.6),
                        ),
                      ],
                    )),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ApprovalPage extends StatelessWidget {
  const ApprovalPage({super.key, required this.store});
  final CampusStore store;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('AQUACAMPUS')),
      body: Center(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.verified_user_outlined, color: sea, size: 64),
                const SizedBox(height: 18),
                const Text('Approval pending',
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                const Text(
                    'Your account was created. Campus Admin must approve you and assign your hostel, room or staff role. Role selection is NOT public in live mode.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 14),
                if (!store.emailVerified) ...[
                  const Text(
                    'Verify your email using the Firebase link we sent. '
                    'A real campus administrator must then approve your role.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: () async {
                      try {
                        await store.resendEmailVerification();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text(
                            'Verification email sent. Check your inbox.')),
                        );
                      } catch (error) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$error')),
                        );
                      }
                    },
                    icon: const Icon(Icons.mark_email_unread_outlined),
                    label: const Text('Resend verification email'),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      try {
                        final verified = await store.refreshEmailVerification();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(verified
                            ? 'Email verified. Await campus admin approval.'
                            : 'Email not verified yet. Open your verification link.'),
                        ));
                      } catch (error) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$error')),
                        );
                      }
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('I verified my email · Refresh'),
                  ),
                ] else
                  const Text(
                    'Email verified. Awaiting the campus administrator.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: sea, fontWeight: FontWeight.w600),
                  ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                    onPressed: store.logout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out')),
              ]))));
}

String _nice(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

class NavItem {
  const NavItem(this.label, this.icon);
  final String label;
  final IconData icon;
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.store});
  final CampusStore store;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  String page = 'Overview';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.store.refreshOnResume();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final pages = [
      const NavItem('Overview', Icons.dashboard_rounded),
      const NavItem('Planner', Icons.event_note_rounded),
      if (!s.isTeacher) const NavItem('Rooms', Icons.meeting_room_outlined),
      const NavItem('Facilities', Icons.apartment_rounded),
      const NavItem('Tanks', Icons.water_rounded),
      const NavItem('Requests', Icons.playlist_add_check_circle_rounded),
      const NavItem('SOS', Icons.sos_rounded),
      const NavItem('Notices', Icons.campaign_rounded),
      if (s.isAdmin) const NavItem('Members', Icons.people_alt_rounded)
    ];
    final current = pages.any((item) => item.label == page) ? page : 'Overview';
    Widget body;
    switch (current) {
      case 'Planner':
        body = PlannerPage(store: s);
        break;
      case 'Rooms':
        body = RoomDemandPage(store: s);
        break;
      case 'Facilities':
        body = FacilitiesPage(store: s);
        break;
      case 'Tanks':
        body = TanksPage(store: s);
        break;
      case 'Requests':
        body = RequestsPage(store: s);
        break;
      case 'SOS':
        body = SOSPage(store: s);
        break;
      case 'Notices':
        body = NoticesPage(store: s);
        break;
      case 'Members':
        body = MembersPage(store: s);
        break;
      default:
        body = OverviewPage(store: s);
    }
    return Scaffold(
        appBar: AppBar(
            title: Row(children: [
              const Icon(Icons.water_drop_rounded, color: sea),
              const SizedBox(width: 7),
              const Text('AQUACAMPUS',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(width: 10),
              Flexible(
                  child: Text('· $current',
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: Colors.black54, fontSize: 14)))
            ]),
            actions: [
              IconButton(
                tooltip: s.backendConnected
                    ? 'Firebase synchronized · tap to refresh'
                    : 'Waiting for Firebase · tap to reconnect',
                onPressed: s.retrySync,
                icon: Icon(
                  s.backendConnected ? Icons.cloud_done_rounded
                      : Icons.cloud_sync_outlined,
                  color: s.backendConnected ? sea : amber,
                ),
              ),
              IconButton(
                  tooltip: 'Sign out / switch role',
                  onPressed: s.logout,
                  icon: const Icon(Icons.logout_rounded)),
            ]),
        drawer: Drawer(
            child: SafeArea(
                child: Column(children: [
          Container(
              width: double.infinity,
              color: const Color(0xFF09579F),
              padding: const EdgeInsets.all(23),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.water_drop, color: Colors.white, size: 35),
                    const SizedBox(height: 13),
                    Text(s.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18)),
                    const SizedBox(height: 4),
                    Text(
                        '${_nice(s.role)} · Verified campus access',
                        style: const TextStyle(
                            color: Color(0xFFD7F4FF), fontSize: 12)),
                    if (s.myFacilityId.isNotEmpty)
                      Text(s.facilityName(s.myFacilityId),
                          style: const TextStyle(
                              color: Color(0xFFD7F4FF), fontSize: 12)),
                  ])),
          Expanded(
              child: ListView(children: [
            for (final item in pages)
              ListTile(
                leading:
                    Icon(item.icon, color: current == item.label ? sea : ink),
                title: Text(item.label),
                selected: current == item.label,
                onTap: () {
                  setState(() => page = item.label);
                  Navigator.pop(context);
                },
                trailing: item.label == 'SOS' &&
                        s.isStaff &&
                        s.sos.any((x) => x['status'] == 'open')
                    ? CircleAvatar(
                        radius: 11,
                        backgroundColor: Colors.red,
                        child: Text(
                            '${s.sos.where((x) => x['status'] == 'open').length}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11)))
                    : null,
              )
          ])),
          const Padding(
              padding: EdgeInsets.all(15),
              child: Text(
                  'Tank levels require manual measurement. Supply confirmation is a human action.',
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                  textAlign: TextAlign.center)),
        ]))),
        body: Builder(
            builder: (context) => Column(children: [
                  if (s.message != null)
                    MaterialBanner(content: Text(s.message!), actions: [
                      TextButton(
                          onPressed: s.clearMessage, child: const Text('CLOSE'))
                    ]),
                  Expanded(child: body),
                ])),
        bottomNavigationBar: !['Overview', 'Requests', 'SOS', 'Tanks']
                .contains(current)
            ? null
            : NavigationBar(
            height: 72,
            backgroundColor: Colors.white,
            indicatorColor: const Color(0xFFD7F0FF),
            selectedIndex: current == 'Overview'
                ? 0
                : current == 'Requests'
                    ? 1
                    : current == 'SOS'
                        ? 2
                        : 3,
            onDestinationSelected: (index) => setState(
                () => page = ['Overview', 'Requests', 'SOS', 'Tanks'][index]),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: 'Home'),
              NavigationDestination(
                  icon: Icon(Icons.fact_check_outlined),
                  selectedIcon: Icon(Icons.fact_check),
                  label: 'Requests'),
              NavigationDestination(
                  icon: Icon(Icons.sos_outlined),
                  selectedIcon: Icon(Icons.sos),
                  label: 'SOS'),
              NavigationDestination(
                  icon: Icon(Icons.water_drop_outlined),
                  selectedIcon: Icon(Icons.water_drop),
                  label: 'Tanks'),
            ]));
  }
}

class ScreenBody extends StatelessWidget {
  const ScreenBody({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.action,
  });

  final String title, subtitle;
  final List<Widget> children;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFFEDF9FF), Colors.white, Color(0xFFF4FBFF)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),
    child: ListView.builder(
      key: PageStorageKey<String>('aquacampus-scroll-$title'),
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 30),
      // Lazily mount/render cards instead of creating every Firestore
      // request/tank/facility card up front on each listener update.
      itemCount: children.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Row(children: [
            Expanded(child: OceanHero(
              title: title, subtitle: subtitle, compact: true)),
            if (action != null) ...[
              const SizedBox(width: 9),
              action!,
            ],
          ]);
        }
        if (index == 1) return const SizedBox(height: 21);
        return children[index - 2];
      },
    ),
  );
}

class Surface extends StatelessWidget {
  const Surface({super.key, required this.child, this.padding = 16});
  final Widget child;
  final double padding;
  @override
  Widget build(BuildContext context) => Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(padding: EdgeInsets.all(padding), child: child));
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key});
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(2, 16, 0, 11),
      child: Text(title,
          style: const TextStyle(
              fontSize: 17, fontWeight: FontWeight.w800, color: ink)));
}

class MetricBox extends StatelessWidget {
  const MetricBox(this.label, this.value, this.icon,
      {super.key, this.accent = sea});
  final String label, value;
  final IconData icon;
  final Color accent;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: accent, size: 23),
            const SizedBox(height: 10),
            Text(value,
                style: const TextStyle(
                    fontSize: 21, fontWeight: FontWeight.w900, color: ink)),
            const SizedBox(height: 5),
            Text(label,
                style: const TextStyle(color: Colors.black54, fontSize: 11))
          ])));
}

class InfoBanner extends StatelessWidget {
  const InfoBanner(this.message, {super.key, this.warning = false});
  final String message;
  final bool warning;
  @override
  Widget build(BuildContext context) => Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: warning ? const Color(0xFFFFF3D8) : const Color(0xFFE5F5FF),
          borderRadius: BorderRadius.circular(13)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(warning ? Icons.warning_amber : Icons.info_outline,
            color: warning ? const Color(0xFF966112) : sea, size: 20),
        const SizedBox(width: 9),
        Expanded(
            child: Text(message,
                style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: warning ? const Color(0xFF7D591F) : ink)))
      ]));
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) {
    final isBad = status == 'open' || status == 'rejected';
    final isGood = status == 'fulfilled' || status == 'resolved';
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: isBad
                ? const Color(0xFFFFE9E3)
                : isGood
                    ? const Color(0xFFDFF5FF)
                    : const Color(0xFFFFF2D6),
            borderRadius: BorderRadius.circular(30)),
        child: Text(_nice(status),
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isBad
                    ? const Color(0xFFA64232)
                    : isGood
                        ? const Color(0xFF13734B)
                        : const Color(0xFF92661A))));
  }
}

Future<bool> execute(BuildContext context, Future<void> Function() operation,
    {String success = 'Saved successfully'}) async {
  try {
    await operation();
    if (!context.mounted) return true;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(success), backgroundColor: sea));
    return true;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error'),
            backgroundColor: const Color(0xFFB74335)),
      );
    }
    return false;
  }
}

Widget _empty(String text) => Surface(
    child: Center(
        child: Padding(
            padding: const EdgeInsets.all(18),
            child: Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54, fontSize: 12)))));
Widget _labelValue(String name, String value) => Padding(
    padding: const EdgeInsets.only(top: 7),
    child: Row(children: [
      Expanded(
          child: Text(name,
              style: const TextStyle(color: Colors.black54, fontSize: 12))),
      Flexible(
          child: Text(value,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
              textAlign: TextAlign.end))
    ]));

class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key, required this.store});
  final CampusStore store;
  @override
  Widget build(BuildContext context) {
    final s = store;
    final myFacilities = s.visibleFacilities;
    final available =
        myFacilities.fold(0.0, (a, f) => a + s.availableFor('${f['id']}'));
    final pending =
        s.visibleRequests.where((r) => r['status'] == 'pending').length;
    final activeSOS =
        s.isStaff ? s.sos.where((a) => a['status'] == 'open').length : 0;
    final target =
        s.isStudent || s.isWarden ? s.facility(s.myFacilityId) : null;
    final share = target == null
        ? 0.0
        : WaterMath.perPersonShare(s.availableFor('${target['id']}'),
            nval(target['occupants']).toInt());
    final notice = s.visibleNotices;
    return ScreenBody(
        title: 'Hello, ${s.name.split(' ').first} 👋',
        subtitle:
            '${_nice(s.role)} · Campus water management',
        children: [
          if (!s.backendConnected)
            const InfoBanner(
              'Waiting for a fresh campus database connection. Edits are disabled until Firebase responds. Tap the cloud icon above to retry.',
              warning: true,
            ),
          if (s.isStaff && activeSOS > 0)
            InfoBanner(
                '$activeSOS urgent SOS report(s) need water worker/admin attention.',
                warning: true),
          LayoutBuilder(builder: (context, constraints) {
            final width = constraints.maxWidth;
            final item = (width - 9) / 2;
            return Wrap(spacing: 9, runSpacing: 9, children: [
              SizedBox(
                  width: item,
                  child: MetricBox(
                    'Measured tank estimate',
                    s.visibleTanks.isEmpty
                        ? 'No registered tanks'
                        : s.visibleTanks.every((t) =>
                            '${t['lastMeasuredAt'] ?? ''}'.isNotEmpty)
                            ? litres(available)
                            : s.visibleTanks.any((t) =>
                                '${t['lastMeasuredAt'] ?? ''}'.isNotEmpty)
                                ? 'Partial · ${litres(available)}'
                                : 'Awaiting input',
                    Icons.water_drop,
                  )),
              SizedBox(
                  width: item,
                  child: MetricBox(
                      'Pending requests', '$pending', Icons.pending_actions,
                      accent: amber)),
              SizedBox(
                  width: item,
                  child: MetricBox(
                      'Facilities', '${myFacilities.length}', Icons.apartment)),
              SizedBox(
                  width: item,
                  child: MetricBox(
                      s.isStaff ? 'Open SOS' : 'Tank readings',
                      s.isStaff ? '$activeSOS' : '${s.visibleTanks.length}',
                      Icons.notification_important_outlined,
                      accent: const Color(0xFFBA6558))),
            ]);
          }),
          if (target != null) ...[
            const SectionTitle('Your hostel water budget'),
            Surface(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('${target['name']}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                  _labelValue(
                    'Measured/estimated stored volume',
                    s.facilityWaterSummary('${target['id']}'),
                  ),
                  _labelValue('Registered population estimate',
                      '${target['occupants']}'),
                  _labelValue('Indicative share (15% reserve)',
                      s.hasCompleteReadingsFor('${target['id']}')
                          ? litres(share) : 'Requires all tank readings'),
                  const SizedBox(height: 12),
                  const Text(
                      'Informational planning figure, NOT an enforced personal allowance. Drinking and essential hygiene must be prioritised.',
                      style: TextStyle(
                          fontSize: 11, color: Colors.black54, height: 1.5)),
                ]))
          ],
          const SectionTitle('Water status by location'),
          if (myFacilities.isEmpty)
            _empty(
                'No locations assigned. Ask your campus admin to configure and assign a facility.'),
          for (final f in myFacilities)
            Surface(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Expanded(
                        child: Text('${f['name']}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w800))),
                    StatusPill('${f['type']}')
                  ]),
                  _labelValue('Water from staff measurements',
                    s.facilityWaterSummary('${f['id']}')),
                  if (f['type'] == 'canteen')
                    _labelValue('Today supplied / allowed',
                        '${litres(s.dailyUsed('${f['id']}'))} / ${litres(nval(f['dailyCapLitres']))}'),
                  if (f['type'] == 'hostel')
                    _labelValue('Residents (configured)', '${f['occupants']}'),
                ])),
          const SectionTitle('Automatic in-app low-water warnings'),
          for (final f in myFacilities)
            if (s.hasCompleteReadingsFor('${f['id']}') &&
                s.availableFor('${f['id']}') <= s.lowWaterThreshold(f))
              InfoBanner(
                '${f['name']}: about ${litres(s.availableFor('${f['id']}'))} remaining, below the configured ${litres(s.lowWaterThreshold(f))} threshold. '
                '${f['type'] == 'hostel' ? 'Indicative per-resident share after 15% reserve: ${litres(WaterMath.perPersonShare(s.availableFor('${f['id']}'), nval(f['occupants']).toInt()))}. ' : ''}'
                'Worker must verify the dipstick reading; this is not an automatic tank sensor.',
                warning: true,
              ),
          const SectionTitle('Announcements'),
          if (notice.isEmpty) _empty('No announcements yet'),
          for (final n in notice.take(3))
            Surface(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('${n['message']}',
                      style: const TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 7),
                  Text(briefTime(n['createdAt']),
                      style:
                          const TextStyle(color: Colors.black45, fontSize: 11)),
                ])),
          const InfoBanner(
              'Tank litres = tank cross-section × manually entered water height. No sensor readings, automatic valve control or push notifications are implied.'),
        ]);
  }
}

// Demand forecasting uses manually recorded tank levels and activity requests. No
// hardware sensing or implicit measurement of people who have not submitted a plan.
class PlannerPage extends StatelessWidget {
  const PlannerPage({super.key, required this.store});
  final CampusStore store;

  @override
  Widget build(BuildContext context) {
    final s = store;
    final today = dateKey();
    final requestsToday = s.visibleRequests.where((request) {
      final created = DateTime.tryParse('${request['createdAt']}');
      return created != null &&
          dateKey(created.toLocal()) == today &&
          request['status'] != 'rejected';
    }).toList();
    final totalExtra = requestsToday.fold<double>(
        0, (sum, r) => sum + nval(r['quantityLitres']).toDouble());
    final supplied = requestsToday
        .where((r) => r['status'] == 'fulfilled')
        .fold<double>(
            0, (sum, r) => sum + nval(r['approvedLitres']).toDouble());
    final pending = requestsToday.where((r) => r['status'] == 'pending').length;
    final fullVisibility = s.isStaff || s.isWarden;
    return ScreenBody(
        title: 'Today’s water plan',
        subtitle: '$today · Facility demand and volunteer activity planning',
        action: IconButton.filled(
            onPressed: () => RequestsPage(store: s)._request(context),
            icon: const Icon(Icons.add),
            tooltip: 'Add planned activity'),
        children: [
          InfoBanner(fullVisibility
              ? 'Activity demand is based on submitted requests only. Admin can configure the essential litres per resident for each hostel. No automatic metering.'
              : 'This is your own submitted activity demand, NOT every resident’s usage. Essential drinking, bathing, sanitation and accessibility must never be blocked by an app estimate.'),
          LayoutBuilder(builder: (ctx, box) {
            final w = (box.maxWidth - 10) / 2;
            return Wrap(spacing: 10, runSpacing: 10, children: [
              SizedBox(
                  width: w,
                  child: MetricBox('Submitted extra demand', litres(totalExtra),
                      Icons.water_drop_outlined)),
              SizedBox(
                  width: w,
                  child: MetricBox('Confirmed supplied', litres(supplied),
                      Icons.check_circle_outline)),
              SizedBox(
                  width: w,
                  child: MetricBox('Awaiting worker review', '$pending',
                      Icons.pending_actions,
                      accent: amber)),
              SizedBox(
                  width: w,
                  child: MetricBox('Locations', '${s.visibleFacilities.length}',
                      Icons.apartment)),
            ]);
          }),
          const SectionTitle('Facility demand and supply'),
          if (s.visibleFacilities.isEmpty)
            _empty('Awaiting location assignment from admin.'),
          for (final f in s.visibleFacilities)
            _facilityForecast(f, requestsToday, fullVisibility),
          const SectionTitle('Activity totals submitted today'),
          if (requestsToday.isEmpty)
            _empty(
                'No activity requests for today. Tap + to tell your water worker what is needed.'),
          for (final activity in activityNames)
            if (requestsToday.any((r) => r['activity'] == activity))
              Surface(
                  child: Row(children: [
                Expanded(
                    child: Text(activity,
                        style: const TextStyle(fontWeight: FontWeight.w700))),
                Text(
                    litres(requestsToday
                        .where((r) => r['activity'] == activity)
                        .fold<double>(
                            0,
                            (sum, r) =>
                                sum + nval(r['quantityLitres']).toDouble())),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, color: sea)),
              ])),
          const SectionTitle('Plan a water-saving activity'),
          Surface(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                const Text(
                    'Choose bathing, laundry, room cleaning, cooking or another activity. Enter people/loads and an adjustable water rate. Worker receives the request instantly when Firebase is configured.',
                    style: TextStyle(
                        fontSize: 12, color: Colors.black54, height: 1.6)),
                const SizedBox(height: 11),
                ElevatedButton.icon(
                    onPressed: () => RequestsPage(store: s)._request(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Submit today’s water requirement')),
              ])),
          const InfoBanner(
              'This app plans supply; a worker must confirm any physical delivery. Demand forecasting can be inaccurate if residents do not submit activity plans.'),
        ]);
  }

  Widget _facilityForecast(Map<String, dynamic> f,
      List<Map<String, dynamic>> today, bool fullVisibility) {
    final id = '${f['id']}';
    final activityDemand = today
        .where((r) => r['facilityId'] == id)
        .fold<double>(
            0, (sum, r) => sum + nval(r['quantityLitres']).toDouble());
    final residents = f['type'] == 'hostel' ? nval(f['occupants']).toInt() : 0;
    if (!store.hasCompleteReadingsFor(id)) {
      return Surface(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${f['name']}',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          const SizedBox(height: 9),
          Text(store.tanksFor(id).isEmpty
              ? 'No registered tanks for this location. Ask your Admin to add a real tank before forecasting.'
              : 'Water forecast unavailable: ${store.missingReadingsFor(id)} of ${store.tanksFor(id).length} tank(s) need a worker measurement.',
            style: const TextStyle(color: Colors.black54)),
        ],
      ));
    }
    final available = store.availableFor(id);
    final essentialRate = store.essentialRate(f);
    final budget = WaterBudget.estimate(
      storedLitres: available,
      residents: residents,
      essentialLitresPerResident: essentialRate,
      requestedExtraLitres: activityDemand,
    );
    final baseline = budget.essential;
    final predicted = budget.totalDemand;
    final shortage = budget.totalShortfall;
    final fill = budget.coveredFraction;
    return Surface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
            child: Text('${f['name']}',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800))),
        StatusPill('${f['type']}')
      ]),
      const SizedBox(height: 9),
      _labelValue('Tank-based stored water estimate', litres(available)),
      if (residents > 0)
        _labelValue(
            'Essential plan (${formatter.format(essentialRate)} L × $residents)', litres(baseline)),
      _labelValue(
          fullVisibility
              ? 'Submitted activity demand'
              : 'Your submitted activities',
          litres(activityDemand)),
      if (fullVisibility || residents == 0)
        _labelValue('Combined forecast', litres(predicted)),
      const SizedBox(height: 8),
      ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
              value: fill,
              minHeight: 9,
              color: shortage > 0
                  ? const Color(0xFFDA9845)
                  : const Color(0xFF19A9D9),
              backgroundColor: const Color(0xFFD9EDFB))),
      if (shortage > 0 && fullVisibility)
        Padding(
            padding: const EdgeInsets.only(top: 10),
            child: InfoBanner(
                budget.essentialAtRisk
                    ? 'URGENT: estimated essential water shortage ${litres(budget.essentialShortfall)}. Arrange supply and protect drinking/sanitation.'
                    : 'Flexible activity shortage ${litres(shortage)}. Reschedule optional laundry/cleaning, subject to student needs. 15% reserve included.',
                warning: true)),
      if (!fullVisibility && residents > 0)
        const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
                'Other residents’ unsubmitted/approved demand is not shown in this personal view.',
                style: TextStyle(fontSize: 11, color: Colors.black54))),
    ]));
  }
}

/// Room-level, today-only summaries. Students only have access to their own
/// request records; wardens and staff see the records permitted by Firestore.
class RoomDemandPage extends StatelessWidget {
  const RoomDemandPage({super.key, required this.store});
  final CampusStore store;

  @override
  Widget build(BuildContext context) {
    final today = dateKey();
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final request in store.visibleRequests) {
      final facilityId = '${request['facilityId'] ?? ''}';
      if (store.facility(facilityId)?['type'] != 'hostel') continue;
      final time = DateTime.tryParse('${request['createdAt']}');
      if (time == null || dateKey(time.toLocal()) != today) continue;
      final room = '${request['room'] ?? ''}'.trim();
      final key = '$facilityId::${room.isEmpty ? 'Unassigned room' : room}';
      groups.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(request);
    }
    final entries = groups.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return ScreenBody(
      title: 'Room water demand',
      subtitle: 'Today · hostel room-wise submitted activity plans',
      children: [
        InfoBanner(store.isStudent
            ? 'You can see only water requests submitted by your account, not another student’s private activity history.'
            : 'Room totals reflect requests received so far, not automatic water meters or complete essential needs.'),
        if (entries.isEmpty)
          _empty('No hostel room activity requests received today. Students can add plans from the Requests tab.'),
        for (final entry in entries)
          Surface(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${store.facilityName(entry.key.split('::').first)} · Room ${entry.key.split('::').last}',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 7),
              _labelValue('Requests', '${entry.value.length}'),
              _labelValue('Submitted demand',
                litres(entry.value.fold<double>(
                  0, (total, r) => total + nval(r['quantityLitres']).toDouble()))),
              _labelValue('Worker approved',
                litres(entry.value.where((r) =>
                  r['status'] == 'approved' || r['status'] == 'fulfilled')
                  .fold<double>(0, (total, r) =>
                  total + nval(r['approvedLitres']).toDouble()))),
              _labelValue('Confirmed physically supplied',
                litres(entry.value.where((r) => r['status'] == 'fulfilled')
                  .fold<double>(0, (total, r) =>
                  total + nval(r['approvedLitres']).toDouble()))),
              _labelValue('Waiting for worker',
                '${entry.value.where((r) => r['status'] == 'pending').length}'),
              const SizedBox(height: 7),
              Text(
                entry.value.map((r) =>
                  '${r['activity']}: ${litres(nval(r['quantityLitres']))}').join('  ·  '),
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          )),
      ],
    );
  }
}

class FacilitiesPage extends StatelessWidget {
  const FacilitiesPage({super.key, required this.store});
  final CampusStore store;
  @override
  Widget build(BuildContext context) => ScreenBody(
          title: 'Campus facilities',
          subtitle:
              'Hostels, academic buildings, and canteens managed separately.',
          action: store.isAdmin
              ? IconButton.filled(
                  onPressed: () => _addFacility(context),
                  icon: const Icon(Icons.add),
                  tooltip: 'Add location')
              : null,
          children: [
            for (final type in facilityTypes) ...[
              SectionTitle(
                  '${_nice(type)}${type == 'college' ? ' blocks' : 's'}'),
              if (!store.visibleFacilities.any((f) => f['type'] == type))
                _empty('No $type assigned'),
              for (final f
                  in store.visibleFacilities.where((f) => f['type'] == type))
                Surface(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Row(children: [
                        Expanded(
                            child: Text('${f['name']}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16))),
                        StatusPill(type),
                        if (store.isAdmin)
                          IconButton(
                            onPressed: () => _editFacility(context, f),
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Edit water policy',
                          )
                      ]),
                      _labelValue('Floors', '${f['floors']}'),
                      _labelValue('Restrooms', '${f['restrooms']}'),
                      if (type == 'hostel')
                        _labelValue('Residents', '${f['occupants']}'),
                      if (type == 'canteen')
                        _labelValue('Daily supply cap',
                            litres(nval(f['dailyCapLitres']))),
                      _labelValue('Low-water warning level',
                          litres(store.lowWaterThreshold(f))),
                      if (type == 'hostel')
                        _labelValue('Essential planning baseline',
                          '${formatter.format(store.essentialRate(f))} L / resident / day'),
                      _labelValue(
                        'Water from manual measurement',
                        store.facilityWaterSummary('${f['id']}'),
                      ),
                    ])),
            ],
          ]);
  Future<void> _editFacility(
      BuildContext context, Map<String, dynamic> facility) async {
    final name = TextEditingController(text: '${facility['name']}');
    final people = TextEditingController(text: '${facility['occupants']}');
    final floors = TextEditingController(text: '${facility['floors']}');
    final toilets = TextEditingController(text: '${facility['restrooms']}');
    final cap = TextEditingController(text: '${facility['dailyCapLitres']}');
    final threshold =
        TextEditingController(text: '${store.lowWaterThreshold(facility)}');
    final essential =
        TextEditingController(text: '${store.essentialRate(facility)}');
    final isHostel = facility['type'] == 'hostel';
    final isCanteen = facility['type'] == 'canteen';
    await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Edit campus water policy'),
              content: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: name,
                    decoration: const InputDecoration(labelText: 'Facility name')),
                const SizedBox(height: 10),
                TextField(controller: floors, keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Number of floors')),
                const SizedBox(height: 10),
                TextField(controller: toilets, keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Restroom count')),
                if (isHostel) ...[
                  const SizedBox(height: 10),
                  TextField(controller: people, keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Hostel residents')),
                  const SizedBox(height: 10),
                  TextField(controller: essential,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Essential litres per resident/day')),
                ],
                if (isCanteen) ...[
                  const SizedBox(height: 10),
                  TextField(controller: cap,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Daily canteen cap (litres)')),
                ],
                const SizedBox(height: 10),
                TextField(controller: threshold,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Low-water threshold (litres)')),
                const SizedBox(height: 10),
                const Text('Low-water alerts appear in the app after workers enter measured levels. Physical supply is manual.',
                    style: TextStyle(fontSize: 11, color: Colors.black54)),
              ])),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel')),
                ElevatedButton(onPressed: () async {
                  final residents = int.tryParse(people.text);
                  final floorCount = int.tryParse(floors.text);
                  final restroomCount = int.tryParse(toilets.text);
                  final supplyLimit = double.tryParse(cap.text);
                  final lowLevel = double.tryParse(threshold.text);
                  final rate = double.tryParse(essential.text);
                  if (name.text.trim().isEmpty ||
                      residents == null || residents < 0 ||
                      (isHostel && residents == 0) ||
                      floorCount == null || floorCount < 1 ||
                      restroomCount == null || restroomCount < 0 ||
                      supplyLimit == null || !supplyLimit.isFinite ||
                      supplyLimit < 0 || (isCanteen && supplyLimit == 0) ||
                      lowLevel == null || !lowLevel.isFinite || lowLevel < 0 ||
                      rate == null || !rate.isFinite || rate < 1 || rate > 1000) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                        content: Text('Enter valid numbers for each field')));
                    return;
                  }
                  final saved = await execute(ctx, () => store.updateFacility(
                        '${facility['id']}',
                        name: name.text,
                        occupants: residents,
                        floors: floorCount,
                        restrooms: restroomCount,
                        dailyCapLitres: supplyLimit,
                        lowWaterThresholdLitres: lowLevel,
                        essentialLitresPerResident: rate,
                      ), success: 'Water management policy saved');
                  if (saved && ctx.mounted) Navigator.pop(ctx);
                }, child: const Text('Save changes')),
              ],
            ));
    name.dispose();
    people.dispose();
    floors.dispose();
    toilets.dispose();
    cap.dispose();
    threshold.dispose();
    essential.dispose();
  }

  Future<void> _addFacility(BuildContext context) async {
    final name = TextEditingController(),
        people = TextEditingController(),
        floors = TextEditingController(),
        toilets = TextEditingController(),
        cap = TextEditingController(),
        threshold = TextEditingController(),
        essential = TextEditingController();
    String type = 'hostel';
    await showDialog<void>(
        context: context,
        builder: (dialog) => StatefulBuilder(
            builder: (context, setDialog) => AlertDialog(
                  title: const Text('Add facility'),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(
                        controller: name,
                        decoration:
                            const InputDecoration(labelText: 'Facility name')),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                        initialValue: type,
                        decoration:
                            const InputDecoration(labelText: 'Facility type'),
                        items: [
                          for (final t in facilityTypes)
                            DropdownMenuItem(value: t, child: Text(_nice(t)))
                        ],
                        onChanged: (v) => setDialog(() => type = v ?? type)),
                    const SizedBox(height: 10),
                    TextField(
                        controller: floors,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Floors')),
                    const SizedBox(height: 10),
                    TextField(
                        controller: toilets,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Restrooms')),
                    if (type == 'hostel') ...[
                      const SizedBox(height: 10),
                      TextField(
                          controller: people,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Number of residents')),
                      const SizedBox(height: 10),
                      TextField(
                          controller: essential,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'Essential litres per resident / day'))
                    ],
                    if (type == 'canteen') ...[
                      const SizedBox(height: 10),
                      TextField(
                          controller: cap,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Daily water cap (litres)'))
                    ],
                    const SizedBox(height: 10),
                    TextField(
                      controller: threshold,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Low-water threshold (litres)'),
                    ),
                  ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel')),
                    ElevatedButton(
                        onPressed: () async {
                          final p = int.tryParse(people.text),
                              fl = int.tryParse(floors.text),
                              r = int.tryParse(toilets.text),
                              c = double.tryParse(cap.text),
                              low = double.tryParse(threshold.text),
                              rate = double.tryParse(essential.text);
                          if (name.text.trim().isEmpty ||
                              fl == null ||
                              fl < 1 ||
                              r == null ||
                              r < 0 ||
                              (type == 'hostel' && (p == null || p < 1 ||
                                  rate == null || !rate.isFinite ||
                                  rate <= 0 || rate > 1000)) ||
                              (type == 'canteen' &&
                                  (c == null || !c.isFinite || c <= 0)) ||
                              low == null || !low.isFinite || low < 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Enter valid positive values')));
                            return;
                          }
                          final saved = await execute(
                              context,
                              () => store.addFacility(
                                  name: name.text,
                                  type: type,
                                  occupants: type == 'hostel' ? p ?? 0 : 0,
                                  floors: fl,
                                  restrooms: r,
                                  dailyCapLitres:
                                      type == 'canteen' ? c ?? 0 : 0,
                                  lowWaterThresholdLitres: low,
                                  essentialLitresPerResident:
                                      type == 'hostel' ? rate ?? 1 : 1),
                              success: 'Facility created');
                          if (saved && context.mounted) Navigator.pop(context);
                        },
                        child: const Text('Save'))
                  ],
                )));
    name.dispose();
    people.dispose();
    floors.dispose();
    toilets.dispose();
    cap.dispose();
    threshold.dispose();
    essential.dispose();
  }
}

class TanksPage extends StatelessWidget {
  const TanksPage({super.key, required this.store});
  final CampusStore store;
  @override
  Widget build(BuildContext context) => ScreenBody(
          title: 'Water tanks',
          subtitle:
              'Manual ruler/dipstick readings are converted to litres using tank dimensions.',
          action: store.isAdmin
              ? IconButton.filled(
                  onPressed: () => _addTank(context),
                  icon: const Icon(Icons.add),
                  tooltip: 'Add tank')
              : null,
          children: [
            const InfoBanner(
                'Rectangular: length × width × water height ÷ 1,000. Upright cylinder: π × (diameter ÷ 2)² × water height ÷ 1,000. All dimensions in cm.'),
            if (store.visibleTanks.isEmpty)
              _empty(
                  'No tanks yet. Admin can add a tank and worker can record its height.'),
            for (final t in store.visibleTanks)
              Surface(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('${t['name']}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 16)),
                            Text(store.facilityName('${t['facilityId']}'),
                                style: const TextStyle(
                                    color: Colors.black54, fontSize: 11)),
                          ])),
                      if (store.isStaff)
                        IconButton.filledTonal(
                            onPressed: () => _addReading(context, t),
                            icon: const Icon(Icons.straighten),
                            tooltip: 'Update water height')
                    ]),
                    const SizedBox(height: 12),
                    if ('${t['lastMeasuredAt'] ?? ''}'.isNotEmpty)
                    ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                            value: nval(t['heightCm']) > 0
                                ? (nval(t['waterHeightCm']) /
                                        nval(t['heightCm']))
                                    .clamp(0, 1)
                                    .toDouble()
                                : 0,
                            minHeight: 12,
                            backgroundColor: const Color(0xFFE5F1EB),
                            color: const Color(0xFF18AD99))),
                    _labelValue(
                        'Estimated water from reading',
                        '${t['lastMeasuredAt'] ?? ''}'.isEmpty
                            ? 'Awaiting manual measurement'
                            : litres(store.tankAvailable(t))),
                    _labelValue(
                        'Tank maximum capacity', litres(store.tankCapacity(t))),
                    _labelValue('Manual water-height reading',
                        '${t['lastMeasuredAt'] ?? ''}'.isEmpty
                            ? 'Not recorded'
                            : '${formatter.format(nval(t['waterHeightCm']))} / ${formatter.format(nval(t['heightCm']))} cm'),
                    _labelValue(
                        'Shape',
                        t['shape'] == 'cylinder'
                            ? 'Upright cylinder'
                            : 'Rectangular'),
                    if (store.isStaff &&
                        store.readingHistory('${t['id']}').isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Text('Recent manual readings',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                      for (final reading in store.readingHistory('${t['id']}').take(3))
                        _labelValue(
                          briefTime(reading['measuredAt']),
                          '${formatter.format(nval(reading['waterHeightCm']))} cm · ${litres(nval(reading['estimatedLitres']))}',
                        ),
                    ],
                    Text(
                        'Last measured: ${t['lastMeasuredAt'] == '' ? 'Not measured' : briefTime(t['lastMeasuredAt'])}',
                        style: const TextStyle(
                            color: Colors.black45, fontSize: 11)),
                  ])),
          ]);
  Future<void> _addReading(
      BuildContext context, Map<String, dynamic> tank) async {
    final height = TextEditingController();
    await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: Text('Measure ${tank['name']}'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('Tank height: ${tank['heightCm']} cm'),
                  const SizedBox(height: 12),
                  TextField(
                      controller: height,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'Measured water height (cm)')),
                  const SizedBox(height: 9),
                  const Text(
                      'Enter the vertical water depth using a ruler/dipstick. Never guess a sensor reading.',
                      style: TextStyle(fontSize: 11, color: Colors.black54)),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel')),
                  ElevatedButton(
                      onPressed: () async {
                        final value = double.tryParse(height.text);
                        if (value == null ||
                            !value.isFinite ||
                            value < 0 ||
                            value > nval(tank['heightCm'])) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                              content:
                                  Text('Reading must fit tank dimensions')));
                          return;
                        }
                        final saved = await execute(ctx,
                            () => store.recordReading('${tank['id']}', value),
                            success: 'Manual tank reading saved');
                        if (saved && ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Save reading'))
                ]));
    height.dispose();
  }

  Future<void> _addTank(BuildContext context) async {
    if (store.facilities.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Add a facility first')));
      return;
    }
    final name = TextEditingController(),
        length = TextEditingController(),
        width = TextEditingController(),
        height = TextEditingController(),
        diameter = TextEditingController();
    String shape = 'rect', facilityId = '${store.facilities.first['id']}';
    await showDialog<void>(
        context: context,
        builder: (dialog) => StatefulBuilder(
            builder: (ctx, setDialog) => AlertDialog(
                  title: const Text('Register water tank'),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(
                        controller: name,
                        decoration:
                            const InputDecoration(labelText: 'Tank name')),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                        initialValue: facilityId,
                        decoration:
                            const InputDecoration(labelText: 'Location'),
                        items: [
                          for (final f in store.facilities)
                            DropdownMenuItem(
                                value: '${f['id']}',
                                child: Text('${f['name']}'))
                        ],
                        onChanged: (v) =>
                            setDialog(() => facilityId = v ?? facilityId)),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                        initialValue: shape,
                        decoration:
                            const InputDecoration(labelText: 'Tank shape'),
                        items: const [
                          DropdownMenuItem(
                              value: 'rect', child: Text('Rectangular')),
                          DropdownMenuItem(
                              value: 'cylinder',
                              child: Text('Upright cylinder'))
                        ],
                        onChanged: (v) => setDialog(() => shape = v ?? shape)),
                    const SizedBox(height: 10),
                    if (shape == 'rect') ...[
                      TextField(
                          controller: length,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Internal length (cm)')),
                      const SizedBox(height: 10),
                      TextField(
                          controller: width,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Internal width (cm)')),
                    ] else
                      TextField(
                          controller: diameter,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Internal diameter (cm)')),
                    const SizedBox(height: 10),
                    TextField(
                        controller: height,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Internal tank height (cm)')),
                  ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel')),
                    ElevatedButton(
                        onPressed: () async {
                          final l = double.tryParse(length.text),
                              w = double.tryParse(width.text),
                              h = double.tryParse(height.text),
                              d = double.tryParse(diameter.text);
                          if (name.text.trim().isEmpty ||
                              h == null ||
                              h <= 0 ||
                              !h.isFinite ||
                              (shape == 'rect' &&
                                  (l == null ||
                                      w == null ||
                                      l <= 0 ||
                                      w <= 0)) ||
                              (shape == 'cylinder' && (d == null || d <= 0))) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Complete valid tank dimensions')));
                            return;
                          }
                          final saved = await execute(
                              ctx,
                              () => store.addTank(
                                  name: name.text,
                                  facilityId: facilityId,
                                  shape: shape,
                                  lengthCm: l ?? 0,
                                  widthCm: w ?? 0,
                                  heightCm: h,
                                  diameterCm: d ?? 0),
                              success: 'Tank registered');
                          if (saved && ctx.mounted) Navigator.pop(ctx);
                        },
                        child: const Text('Create'))
                  ],
                )));
    name.dispose();
    length.dispose();
    width.dispose();
    height.dispose();
    diameter.dispose();
  }
}

class RequestsPage extends StatelessWidget {
  const RequestsPage({super.key, required this.store});
  final CampusStore store;
  @override
  Widget build(BuildContext context) {
    final list = store.visibleRequests;
    return ScreenBody(
        title: 'Water demand',
        subtitle:
            'Members request extra litres. Worker reviews and records actual supply.',
        action: IconButton.filled(
            onPressed: () => _request(context),
            icon: const Icon(Icons.add),
            tooltip: 'Request water'),
        children: [
          InfoBanner(store.isStaff
              ? 'Approve requests first, then mark water as supplied. Canteen allocations are checked against the daily cap.'
              : 'Bathing, laundry, room cleaning and other additional demands are estimates. Requests do not trigger physical valves.'),
          if (list.isEmpty)
            _empty('No water requests. Tap + to plan an activity.'),
          for (final r in list)
            Surface(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text('${r['activity']}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 16)),
                          Text(
                              '${store.facilityName('${r['facilityId']}')}  ·  ${r['requestedByName']}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black54)),
                        ])),
                    StatusPill('${r['status']}')
                  ]),
                  const SizedBox(height: 5),
                  _labelValue('People / loads', '${r['peopleCount']}'),
                  _labelValue('Rate',
                      '${formatter.format(nval(r['litresPerPerson']))} L / person or load'),
                  _labelValue(
                      'Requested quantity', litres(nval(r['quantityLitres']))),
                  if (r['status'] == 'approved' || r['status'] == 'fulfilled')
                    _labelValue(
                        'Approved quantity', litres(nval(r['approvedLitres']))),
                  if ('${r['room'] ?? ''}'.isNotEmpty)
                    _labelValue('Room', '${r['room']}'),
                  if ('${r['notes'] ?? ''}'.isNotEmpty)
                    Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Text('${r['notes']}',
                            style: const TextStyle(fontSize: 12))),
                  const SizedBox(height: 5),
                  Text(briefTime(r['createdAt']),
                      style:
                          const TextStyle(fontSize: 11, color: Colors.black45)),
                  if (store.isStaff && r['status'] == 'pending')
                    Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Wrap(spacing: 8, children: [
                          OutlinedButton.icon(
                              onPressed: () => execute(
                                  context,
                                  () => store.decideRequest('${r['id']}',
                                      approve: false),
                                  success: 'Request rejected'),
                              icon: const Icon(Icons.close, size: 17),
                              label: const Text('Reject')),
                          ElevatedButton.icon(
                              onPressed: () => _approve(context, r),
                              icon: const Icon(Icons.check, size: 17),
                              label: const Text('Approve')),
                        ])),
                  if (store.isStaff && r['status'] == 'approved')
                    Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: ElevatedButton.icon(
                            icon: const Icon(Icons.local_shipping_outlined),
                            label: const Text('Confirm water supplied'),
                            onPressed: () => execute(context,
                                () => store.fulfillRequest('${r['id']}'),
                                success: 'Water supply recorded'))),
                ])),
          if (store.isStaff)
            const InfoBanner(
                '“Supplied” means the worker manually confirms delivery. App does not control pumps/valves or independently verify water volume.'),
        ]);
  }

  Future<void> _request(BuildContext context) async {
    final choices = store.visibleFacilities;
    if (choices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Admin must assign a facility first')));
      return;
    }
    String facilityId = '${choices.first['id']}';
    String? activity;
    final people = TextEditingController(),
        rate = TextEditingController(),
        notes = TextEditingController();
    await showDialog<void>(
        context: context,
        builder: (dialog) => StatefulBuilder(
            builder: (ctx, setDialog) => AlertDialog(
                  title: const Text('Request water'),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    DropdownButtonFormField<String>(
                        initialValue: facilityId,
                        decoration:
                            const InputDecoration(labelText: 'Location'),
                        items: [
                          for (final f in choices)
                            DropdownMenuItem(
                                value: '${f['id']}',
                                child: Text('${f['name']}'))
                        ],
                        onChanged: (v) =>
                            setDialog(() => facilityId = v ?? facilityId)),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                        initialValue: activity,
                        decoration:
                            const InputDecoration(labelText: 'Activity'),
                        items: [
                          for (final a in activityNames)
                            DropdownMenuItem(value: a, child: Text(a))
                        ],
                        onChanged: (v) =>
                            setDialog(() => activity = v)),
                    const SizedBox(height: 10),
                    TextField(
                        controller: people,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'People / laundry loads')),
                    const SizedBox(height: 10),
                    TextField(
                        controller: rate,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Estimated litres per person / load')),
                    const SizedBox(height: 10),
                    TextField(
                        controller: notes,
                        decoration: const InputDecoration(
                            labelText: 'Details (optional)'),
                        maxLines: 2),
                    const SizedBox(height: 13),
                    AnimatedBuilder(
                        animation: Listenable.merge([people, rate]),
                        builder: (ctx, _) => Text(
                            'Total: ${litres((int.tryParse(people.text) ?? 0) * (double.tryParse(rate.text) ?? 0))}',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: sea))),
                    const SizedBox(height: 6),
                    const Text(
                        'Enter your actual planned demand; no quantity is filled in automatically.',
                        style: TextStyle(fontSize: 11, color: Colors.black54)),
                  ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel')),
                    ElevatedButton(
                        onPressed: () async {
                          final count = int.tryParse(people.text),
                              value = double.tryParse(rate.text);
                          if (activity == null ||
                              count == null ||
                              count < 1 ||
                              count > 500 ||
                              value == null ||
                              !value.isFinite ||
                              value <= 0 ||
                              value > 1000) {
                            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                                content: Text(
                                    'Enter valid people/loads and water rate')));
                            return;
                          }
                          final saved = await execute(
                              ctx,
                              () => store.addRequest(
                                  facilityId: facilityId,
                                  activity: activity!,
                                  peopleCount: count,
                                  litresPerPerson: value,
                                  notes: notes.text),
                              success: 'Request sent to water worker');
                          if (saved && ctx.mounted) Navigator.pop(ctx);
                        },
                        child: const Text('Send request'))
                  ],
                )));
    people.dispose();
    rate.dispose();
    notes.dispose();
  }

  Future<void> _approve(
      BuildContext context, Map<String, dynamic> request) async {
    final requested = nval(request['quantityLitres']).toDouble();
    final amount = TextEditingController(text: '$requested');
    await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Approve water allocation'),
                content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Requested: ${litres(requested)}'),
                      const SizedBox(height: 13),
                      TextField(
                          controller: amount,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'Approve litres')),
                      const SizedBox(height: 9),
                      const Text(
                          'Approve now. Confirm supply after water is physically delivered.',
                          style:
                              TextStyle(color: Colors.black54, fontSize: 11)),
                    ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel')),
                  ElevatedButton(
                      onPressed: () async {
                        final value = double.tryParse(amount.text);
                        if (value == null ||
                            !value.isFinite ||
                            value <= 0 ||
                            value > requested) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                              content: Text('Invalid approval quantity')));
                          return;
                        }
                        final saved = await execute(
                            ctx,
                            () => store.decideRequest('${request['id']}',
                                approve: true, approvedLitres: value),
                            success: 'Water approved for worker supply');
                        if (saved && ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Approve'))
                ]));
    amount.dispose();
  }
}

class SOSPage extends StatelessWidget {
  const SOSPage({super.key, required this.store});
  final CampusStore store;
  @override
  Widget build(BuildContext context) {
    final active = store.sos.where((x) => x['status'] == 'open').toList()
      ..sort((a, b) => '${b['createdAt']}'.compareTo('${a['createdAt']}'));
    final resolved = store.sos.where((x) => x['status'] == 'resolved').toList();
    return ScreenBody(
        title: 'Water emergency SOS',
        subtitle:
            'Report leaks or pipe damage. Reports are readable ONLY by admins and water workers.',
        action: IconButton.filled(
            onPressed: () => _report(context),
            icon: const Icon(Icons.add_alert),
            tooltip: 'Send SOS'),
        children: [
          const InfoBanner(
              'A submitted SOS reaches the live workers/admin incident board via Firestore while they have the app open. Hardware valve shutdown and OS push alerts are NOT implemented.'),
          if (store.isStaff) ...[
            SectionTitle('Active incidents (${active.length})'),
            if (active.isEmpty) _empty('No unresolved water emergencies'),
            for (final alert in active) _alert(context, alert),
            SectionTitle('Resolved incidents (${resolved.length})'),
            for (final alert in resolved.take(20)) _alert(context, alert),
          ] else ...[
            Surface(
                child: Column(children: [
              const Icon(Icons.privacy_tip_outlined, color: sea, size: 36),
              const SizedBox(height: 12),
              const Text('Private emergency channel',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 7),
              const Text(
                  'Students, teachers and wardens may SUBMIT a location-specific SOS. Only worker/admin accounts can VIEW or resolve incident details.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12, color: Colors.black54, height: 1.6)),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                  onPressed: () => _report(context),
                  icon: const Icon(Icons.sos),
                  label: const Text('Report a leak / pipe burst'))
            ]))
          ],
        ]);
  }

  Widget _alert(BuildContext context, Map<String, dynamic> alert) => Surface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(store.facilityName('${alert['facilityId']}'),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800))),
          StatusPill('${alert['status']}')
        ]),
        _labelValue('Floor', '${alert['floor']}'),
        _labelValue('Restroom / landmark', '${alert['restroom']}'),
        _labelValue('Reported by', '${alert['createdByName']}'),
        const SizedBox(height: 8),
        Text('${alert['detail']}',
            style: const TextStyle(fontSize: 12, height: 1.5)),
        const SizedBox(height: 7),
        Text(briefTime(alert['createdAt']),
            style: const TextStyle(fontSize: 11, color: Colors.black54)),
        if (alert['status'] == 'open' && store.isStaff)
          Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ElevatedButton.icon(
                  onPressed: () => execute(
                      context, () => store.closeSOS('${alert['id']}'),
                      success: 'SOS marked resolved'),
                  icon: const Icon(Icons.check),
                  label: const Text('Mark resolved'))),
      ]));
  Future<void> _report(BuildContext context) async {
    // A hostel student may report a leak from any academic building or canteen,
    // while hostel incidents remain limited to the assigned hostel.
    final locations = store.isStudent
        ? store.facilities
            .where((f) =>
                f['id'] == store.myFacilityId ||
                f['type'] == 'college' ||
                f['type'] == 'canteen')
            .toList()
        : store.visibleFacilities;
    if (locations.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No location assigned')));
      return;
    }
    String facilityId = '${locations.first['id']}';
    final floor = TextEditingController(),
        restroom = TextEditingController(),
        details = TextEditingController();
    await showDialog<void>(
        context: context,
        builder: (dialog) => StatefulBuilder(
            builder: (ctx, setDialog) => AlertDialog(
                  title: const Text('🚨 Report water emergency'),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    DropdownButtonFormField<String>(
                        initialValue: facilityId,
                        decoration: const InputDecoration(
                            labelText: 'Building / Hostel / Canteen'),
                        items: [
                          for (final f in locations)
                            DropdownMenuItem(
                                value: '${f['id']}',
                                child: Text('${f['name']}'))
                        ],
                        onChanged: (v) =>
                            setDialog(() => facilityId = v ?? facilityId)),
                    const SizedBox(height: 10),
                    TextField(
                        controller: floor,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Floor number')),
                    const SizedBox(height: 10),
                    TextField(
                        controller: restroom,
                        decoration: const InputDecoration(
                            labelText: 'Restroom / landmark')),
                    const SizedBox(height: 10),
                    TextField(
                        controller: details,
                        maxLines: 3,
                        decoration: const InputDecoration(
                            labelText:
                                'Problem: pipe burst, leak, overflow...')),
                  ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel')),
                    ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFB74335)),
                        onPressed: () async {
                          final f = int.tryParse(floor.text),
                              limit =
                                  nval(store.facility(facilityId)?['floors'])
                                      .toInt();
                          if (f == null ||
                              f < 0 ||
                              f > limit ||
                              restroom.text.trim().isEmpty ||
                              details.text.trim().isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                                content: Text(
                                    'Enter a valid floor, location and description')));
                            return;
                          }
                          final saved = await execute(
                              ctx,
                              () => store.createSOS(
                                  facilityId: facilityId,
                                  floor: f,
                                  restroom: restroom.text,
                                  detail: details.text),
                              success:
                                  'SOS sent to campus water workers and admins');
                          if (saved && ctx.mounted) Navigator.pop(ctx);
                        },
                        child: const Text('SEND SOS'))
                  ],
                )));
    floor.dispose();
    restroom.dispose();
    details.dispose();
  }
}

class NoticesPage extends StatelessWidget {
  const NoticesPage({super.key, required this.store});
  final CampusStore store;
  @override
  Widget build(BuildContext context) => ScreenBody(
          title: 'Campus announcements',
          subtitle:
              'Admin water shortage alerts and location-wide supply information.',
          action: store.isAdmin
              ? IconButton.filled(
                  onPressed: () => _send(context),
                  icon: const Icon(Icons.add_comment),
                  tooltip: 'Broadcast message')
              : null,
          children: [
            if (store.isAdmin)
              const InfoBanner(
                  'Admin broadcasts appear on the notice feed of members using the app. To notify devices when closed, Firebase Cloud Messaging setup is required.'),
            if (store.visibleNotices.isEmpty) _empty('No messages yet'),
            for (final n in store.visibleNotices)
              Surface(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      const Icon(Icons.campaign_outlined, color: sea),
                      const SizedBox(width: 7),
                      Expanded(
                          child: Text(
                              '${n['targetFacilityId'] ?? ''}'.isEmpty
                                  ? 'All campus'
                                  : store
                                      .facilityName('${n['targetFacilityId']}'),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800))),
                      Text(briefTime(n['createdAt']),
                          style: const TextStyle(
                              fontSize: 10, color: Colors.black45))
                    ]),
                    const SizedBox(height: 12),
                    Text('${n['message']}',
                        style: const TextStyle(fontSize: 13, height: 1.6)),
                  ])),
          ]);
  Future<void> _send(BuildContext context) async {
    final content = TextEditingController();
    String target = '';
    await showDialog<void>(
        context: context,
        builder: (dialog) => StatefulBuilder(
            builder: (ctx, setDialog) => AlertDialog(
                    title: const Text('Send campus broadcast'),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      DropdownButtonFormField<String>(
                          initialValue: target,
                          decoration: const InputDecoration(
                              labelText: 'Target audience'),
                          items: [
                            const DropdownMenuItem(
                                value: '', child: Text('Entire campus')),
                            for (final f in store.facilities)
                              DropdownMenuItem(
                                  value: '${f['id']}',
                                  child: Text('${f['name']}')),
                          ],
                          onChanged: (v) =>
                              setDialog(() => target = v ?? target)),
                      const SizedBox(height: 12),
                      TextField(
                          controller: content,
                          maxLines: 4,
                          decoration: const InputDecoration(
                              labelText:
                                  'e.g. Only 500 L is available. Please reduce optional water use.')),
                    ]),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel')),
                      ElevatedButton(
                          onPressed: () async {
                            if (content.text.trim().isEmpty) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                      content: Text('Type a message')));
                              return;
                            }
                            final saved = await execute(ctx,
                                () => store.postNotice(target, content.text),
                                success: 'Broadcast posted');
                            if (saved && ctx.mounted) Navigator.pop(ctx);
                          },
                          child: const Text('Broadcast'))
                    ])));
    content.dispose();
  }
}

class MembersPage extends StatelessWidget {
  const MembersPage({super.key, required this.store});
  final CampusStore store;
  @override
  Widget build(BuildContext context) => ScreenBody(
          title: 'Member permissions',
          subtitle:
              'Admin approves registration, sets role, assigns hostel/college and room.',
          children: [
            const InfoBanner(
                'SECURITY: New Firebase sign-ups are pending Students. Only Admin may approve or promote them to Worker, Warden, Teacher or Admin.'),
            if (store.people.isEmpty)
              _empty(
                  'No registered cloud members. New users will appear here after Firebase is configured and an admin account is bootstrapped.'),
            for (final p in store.people)
              Surface(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Expanded(
                          child: Text('${p['name'] ?? p['email'] ?? 'Member'}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800))),
                      StatusPill(p['approved'] == true ? 'approved' : 'pending')
                    ]),
                    Text('${p['email'] ?? ''}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black54)),
                    _labelValue('Role', '${p['role']}'),
                    _labelValue(
                        'Facility', store.facilityName('${p['facilityId']}')),
                    if (p['id'] != store.uid)
                      Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                              onPressed: () => _edit(context, p),
                              icon: const Icon(Icons.manage_accounts),
                              label: const Text('Assign / Approve'))),
                  ])),
          ]);
  Future<void> _edit(BuildContext context, Map<String, dynamic> member) async {
    String role = '${member['role']}',
        facilityId = '${member['facilityId'] ?? ''}';
    bool approved = member['approved'] == true;
    final room = TextEditingController(text: '${member['room'] ?? ''}');
    await showDialog<void>(
        context: context,
        builder: (dialog) => StatefulBuilder(
            builder: (ctx, setDialog) => AlertDialog(
                    title: Text('Edit ${member['name']}'),
                    content: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      SwitchListTile(
                          value: approved,
                          title: const Text('Approve member'),
                          onChanged: (v) => setDialog(() => approved = v)),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                          initialValue: role,
                          decoration:
                              const InputDecoration(labelText: 'Access role'),
                          items: [
                            for (final r in roleNames)
                              DropdownMenuItem(value: r, child: Text(_nice(r)))
                          ],
                          onChanged: (v) => setDialog(() => role = v ?? role)),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                          initialValue: store.facility(facilityId) == null
                              ? ''
                              : facilityId,
                          decoration: const InputDecoration(
                              labelText: 'Assigned facility'),
                          items: [
                            const DropdownMenuItem(
                                value: '', child: Text('None / all buildings')),
                            for (final f in store.facilities)
                              DropdownMenuItem(
                                  value: '${f['id']}',
                                  child: Text('${f['name']}'))
                          ],
                          onChanged: (v) =>
                              setDialog(() => facilityId = v ?? facilityId)),
                      const SizedBox(height: 10),
                      TextField(
                          controller: room,
                          decoration: const InputDecoration(
                              labelText: 'Room (for students)')),
                    ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel')),
                      ElevatedButton(
                          onPressed: () async {
                            if ((role == 'student' || role == 'warden') &&
                                approved &&
                                store.facility(facilityId)?['type'] !=
                                    'hostel') {
                              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                                  content: Text(
                                      'Students and wardens need a valid hostel')));
                              return;
                            }
                            final saved = await execute(
                                ctx,
                                () => store.changeMember('${member['id']}',
                                    approved: approved,
                                    role: role,
                                    facilityId: facilityId,
                                    room: room.text),
                                success: 'Member permissions updated');
                            if (saved && ctx.mounted) Navigator.pop(ctx);
                          },
                          child: const Text('Save member'))
                    ])));
    room.dispose();
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:pit_stop/screens/park_screen.dart';
import 'package:pit_stop/screens/settings_screen.dart';
import 'package:pit_stop/screens/login_screen.dart';
import 'package:pit_stop/screens/register_screen.dart';
import 'package:pit_stop/screens/lots_screen.dart';
import 'package:pit_stop/screens/availability_screen.dart';
import 'package:pit_stop/screens/lot_overview_screen.dart';
import 'package:pit_stop/theme_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // When a user signs in, load their saved theme preferences from Firestore
  FirebaseAuth.instance.authStateChanges().listen((user) async {
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data();
      if (data != null && data['settings'] != null) {
        final settings = Map<String, dynamic>.from(data['settings'] as Map);
        final modeStr = settings['mode'] as String?;
        final seedVal = settings['seedColor'];

        ThemeMode mode = ThemeMode.system;
        if (modeStr == 'light') mode = ThemeMode.light;
        if (modeStr == 'dark') mode = ThemeMode.dark;

        if (seedVal is int) {
          themeManager.setSeedColor(Color(seedVal));
        }
        themeManager.setThemeMode(mode);
      }
    } catch (e) {
      // ignore errors and keep defaults
    }
  });
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of my app
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeManager,
      builder: (context, _) {
            final lightScheme = ColorScheme.fromSeed(seedColor: themeManager.seedColor);
            final darkScheme = ColorScheme.fromSeed(seedColor: themeManager.seedColor, brightness: Brightness.dark);

            return MaterialApp(
              title: 'Pit Stop',
              theme: ThemeData(
                colorScheme: lightScheme,
                textTheme: GoogleFonts.orbitronTextTheme(ThemeData.light().textTheme),
                primaryTextTheme: GoogleFonts.orbitronTextTheme(ThemeData.light().primaryTextTheme),
                appBarTheme: AppBarTheme(
                  backgroundColor: lightScheme.primary,
                  foregroundColor: lightScheme.onPrimary,
                  titleTextStyle: GoogleFonts.orbitron(fontSize: 20, fontWeight: FontWeight.w600, color: lightScheme.onPrimary),
                  toolbarTextStyle: GoogleFonts.orbitronTextTheme().bodyMedium?.copyWith(color: lightScheme.onPrimary),
                ),
              ),
              darkTheme: ThemeData(
                colorScheme: darkScheme,
                textTheme: GoogleFonts.orbitronTextTheme(ThemeData.dark().textTheme),
                primaryTextTheme: GoogleFonts.orbitronTextTheme(ThemeData.dark().primaryTextTheme),
                appBarTheme: AppBarTheme(
                  backgroundColor: darkScheme.primary,
                  foregroundColor: darkScheme.onPrimary,
                  titleTextStyle: GoogleFonts.orbitron(fontSize: 20, fontWeight: FontWeight.w600, color: darkScheme.onPrimary),
                  toolbarTextStyle: GoogleFonts.orbitronTextTheme().bodyMedium?.copyWith(color: darkScheme.onPrimary),
                ),
              ),
          themeMode: themeManager.mode,
          // Start the app at the login screen so users must log in first.
          initialRoute: '/login',
          routes: {
            '/': (context) => const MyHomePage(title: 'Pit Stop'),
            '/park': (context) => const ParkScreen(),
            '/lots': (context) => const LotsScreen(),
            '/availability': (context) => const AvailabilityScreen(),
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),
            '/settings': (context) => const SettingsScreen(),
          },
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
        drawer: Drawer(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: <Widget>[
                  DrawerHeader(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    child: const Text(
                      'Menu',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.local_parking),
                    title: const Text('Park'),
                    onTap: () {
                      Navigator.pop(context); // close drawer
                      Navigator.pushNamed(context, '/park');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.location_city),
                    title: const Text('Lots'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/lots');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.assessment),
                    title: const Text('Availability'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/availability');
                    },
                  ),
                  // Login/Register removed from the drawer — login happens first on app start
                  // and registration is reachable from the Login screen.
                  ListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text('Settings'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/settings');
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Log out'),
              onTap: () async {
                Navigator.pop(context); // close drawer first
                final navigator = Navigator.of(context);
                await FirebaseAuth.instance.signOut();
                if (!mounted) return;
                navigator.pushReplacementNamed('/login');
              },
            ),
          ],
        ),
      ),
      body: Center(
        child: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, authSnap) {
            final user = authSnap.data;
            String displayName = 'Welcome';

            if (user == null) {
              displayName = 'Welcome';
              // still show image and message below
            }

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
              stream: user != null
                  ? FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots()
                  : const Stream<DocumentSnapshot<Map<String, dynamic>>?>.empty(),
              builder: (context, docSnap) {
                if (docSnap.hasData && docSnap.data?.exists == true) {
                  final data = docSnap.data?.data();
                  if (data != null && data['name'] != null && (data['name'] as String).isNotEmpty) {
                    displayName = 'Welcome, ${data['name']}';
                  } else if (user?.email != null) {
                    displayName = 'Welcome, ${user!.email}';
                  }
                } else if (user?.email != null) {
                  displayName = 'Welcome, ${user!.email}';
                }

                final brightness = Theme.of(context).brightness;
                final imageAsset = brightness == Brightness.dark
                    ? 'assets/images/DarkMode.png'
                    : 'assets/images/3DCARS_ONLY.png';

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      displayName,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Welcome to Pit Stop — use the menu to navigate.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    Image.asset(
                      imageAsset,
                      width: 220,
                      height: 140,
                      fit: BoxFit.contain,
                      errorBuilder: (c, e, s) => const SizedBox.shrink(),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
      // We removed the counter and FAB to keep the home screen simple.
      // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}

import 'package:flutter/material.dart';
import 'package:pit_stop/theme_manager.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // A small palette of seed colors to choose from.
  final List<Color> _colors = [
    Colors.red,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.teal,
    Colors.green,
    Colors.orange,
    const Color.fromARGB(255, 246, 152, 188),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String themeModeToString(ThemeMode mode) {
      switch (mode) {
        case ThemeMode.light:
          return 'light';
        case ThemeMode.dark:
          return 'dark';
        case ThemeMode.system:
          return 'system';
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text('Appearance', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),

          // Theme mode card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Theme mode', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  AnimatedBuilder(
                    animation: themeManager,
                    builder: (context, _) {
                      return DropdownButtonFormField<ThemeMode>(
                        initialValue: themeManager.mode,
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: ThemeMode.system, child: Text('Follow system')),
                          DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                          DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                        ],
                        onChanged: (mode) async {
                          if (mode == null) return;
                          themeManager.setThemeMode(mode);
                          // persist per-user preference if signed in
                          final user = FirebaseAuth.instance.currentUser;
                          if (user != null) {
                            await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
                              {
                                'settings': {
                                  'mode': themeModeToString(mode),
                                  'seedColor': themeManager.seedColor.value,
                                }
                              },
                              SetOptions(merge: true),
                            );
                          }
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Color selection card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Primary color', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  const Text('Pick a color to customize the app accent.'),
                  const SizedBox(height: 12),
                  AnimatedBuilder(
                    animation: themeManager,
                    builder: (context, _) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('Preview', style: theme.textTheme.bodyMedium),
                              const SizedBox(width: 12),
                              Container(
                                width: 56,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: themeManager.seedColor,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.12),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: _colors.map((c) {
                              final selected = c == themeManager.seedColor;
                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(24),
                                  onTap: () async {
                                    themeManager.setSeedColor(c);
                                    final user = FirebaseAuth.instance.currentUser;
                                    if (user != null) {
                                      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
                                        {
                                          'settings': {
                                            'mode': themeModeToString(themeManager.mode),
                                            'seedColor': themeManager.seedColor.value,
                                          }
                                        },
                                        SetOptions(merge: true),
                                      );
                                    }
                                  },
                                  child: Container(
                                    width: 52,
                                    height: 52,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: c,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.15),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                      border: selected ? Border.all(color: Colors.white, width: 3) : null,
                                    ),
                                    child: selected ? const Icon(Icons.check, color: Colors.white) : null,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          Text('Notes', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text('Theme changes apply immediately across the app. Choosing "Follow system" will use the device appearance.'),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'lots_screen.dart';

class AvailabilityScreen extends StatelessWidget {
  const AvailabilityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Availability')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('parking_spots').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          // Predefined lot order to display (even if empty)
          final lotNames = ['Lot 1', 'Lot 2', 'Magnolia', 'Up Lot', 'The Point'];

          // Aggregate totals by lot
          final Map<String, Map<String, int>> counts = {};
          for (final d in docs) {
            final data = d.data();
            final lot = (data['lot'] as String?) ?? 'Unknown';
            counts.putIfAbsent(lot, () => {'total': 0, 'available': 0});
            counts[lot]!['total'] = counts[lot]!['total']! + 1;
            if (data['taken'] != true) {
              counts[lot]!['available'] = counts[lot]!['available']! + 1;
            }
          }

          // Compute overall totals
          final overallTotal = counts.values.fold<int>(0, (p, e) => p + (e['total'] ?? 0));
          final overallAvailable = counts.values.fold<int>(0, (p, e) => p + (e['available'] ?? 0));

          // Build list of lots: predefined order first, then any additional lots
          final additionalLots = counts.keys.where((k) => !lotNames.contains(k)).toList();
          final displayLots = [...lotNames, ...additionalLots];

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$overallAvailable / $overallTotal spots open', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: overallTotal > 0 ? overallAvailable / overallTotal : 0),
                const SizedBox(height: 20),
                const Text('Real-time spot overview by lot'),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    children: displayLots.map((lot) {
                      final c = counts[lot];
                      final total = c != null ? c['total'] ?? 0 : 0;
                      final available = c != null ? c['available'] ?? 0 : 0;
                      return ListTile(
                        title: Text(lot),
                        subtitle: Text('$available / $total available'),
                        trailing: SizedBox(
                          width: 48,
                          height: 24,
                          child: total == 0
                              ? const Text('—')
                              : LinearProgressIndicator(value: total == 0 ? 0 : available / total),
                        ),
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => LotsScreen(lot: lot)));
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

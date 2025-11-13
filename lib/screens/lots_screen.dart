import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LotsScreen extends StatelessWidget {
  final String? lot;
  const LotsScreen({super.key, this.lot});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Lots')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: (lot == null)
            ? FirebaseFirestore.instance.collection('parking_spots').orderBy('index').snapshots()
            : FirebaseFirestore.instance.collection('parking_spots').where('lot', isEqualTo: lot).orderBy('index').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;

          return Padding(
            padding: const EdgeInsets.all(12.0),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                childAspectRatio: 1.2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data();
                final taken = data['taken'] == true;
                final owner = data['owner'] as String?;
                final id = doc.id;

                Color color;
                if (taken) {
                  if (owner != null && uid != null && owner == uid) {
                    color = Colors.blue; // your spot
                  } else {
                    color = Colors.grey; // taken by someone else
                  }
                } else {
                  color = Colors.white; // available
                }

                return GestureDetector(
                  onTap: () async {
                      if (taken) {
                      // if it's your spot, offer to unpark
                      if (owner != null && uid != null && owner == uid) {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Unpark here?'),
                            content: const Text('Remove your parked marker from this spot?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                              TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Unpark')),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          // transactionally clear if owner still matches
                          await FirebaseFirestore.instance.runTransaction((tx) async {
                            final snapshot = await tx.get(doc.reference);
                            final current = snapshot.data();
                            if (current == null) throw Exception('Spot missing');
                            final ownerNow = current['owner'] as String?;
                            if (ownerNow == uid) {
                              tx.update(doc.reference, {'taken': false, 'owner': null, 'ts': FieldValue.serverTimestamp()});
                            } else {
                              throw Exception('Spot ownership changed');
                            }
                          });
                        }
                      }
                    } else {
                      // attempt to park here: transactionally set taken if currently false
                      if (user == null) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in to park')));
                        return;
                      }
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Park here?'),
                          content: const Text('Reserve this spot for your car.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                            TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Park')),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        try {
                          await FirebaseFirestore.instance.runTransaction((tx) async {
                            final snapshot = await tx.get(doc.reference);
                            final current = snapshot.data();
                            if (current == null || current['taken'] == false) {
                              tx.update(doc.reference, {'taken': true, 'owner': user.uid, 'ts': FieldValue.serverTimestamp()});
                            } else {
                              throw Exception('Spot already taken');
                            }
                          });
                        } catch (e) {
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not park: $e')));
                        }
                      }
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Spot ${data['index'] ?? id}', style: TextStyle(color: taken ? Colors.white : Colors.black)),
                          if (taken && owner != null) Text('by ${owner.substring(0, 6)}', style: TextStyle(fontSize: 10, color: taken ? Colors.white70 : Colors.black54)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

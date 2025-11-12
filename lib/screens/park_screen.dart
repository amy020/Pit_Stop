import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ParkScreen extends StatefulWidget {
  const ParkScreen({super.key});

  @override
  State<ParkScreen> createState() => _ParkScreenState();
}

class _ParkScreenState extends State<ParkScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  LatLng? _currentLocation;
  LatLng? _parkedLocation;
  bool _loading = true;

  static const CameraPosition _fallback = CameraPosition(
    target: LatLng(37.4219999, -122.0840575), // fallback to Googleplex
    zoom: 16,
  );

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
    });

    // Ensure permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      // can't get location; leave _currentLocation null
      // still try to load parked marker from Firestore so user can see saved location
    } else {
      try {
        final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
        _currentLocation = LatLng(pos.latitude, pos.longitude);
      } catch (_) {
        _currentLocation = null;
      }
    }

    // Load parked location from Firestore for the current user (if any)
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final data = doc.data();
        if (data != null && data['parking'] != null) {
          final p = Map<String, dynamic>.from(data['parking'] as Map);
          final lat = (p['lat'] as num).toDouble();
          final lng = (p['lng'] as num).toDouble();
          _parkedLocation = LatLng(lat, lng);
        }
      } catch (_) {}
    }

    setState(() {
      _loading = false;
    });

    // If we have a controller and a location, move camera smoothly
    if (_parkedLocation != null) {
      await _centerOnLatLng(_parkedLocation!, zoom: 18);
    } else if (_currentLocation != null) {
      await _centerOnLatLng(_currentLocation!, zoom: 17);
    }
  }

  Future<void> _park() async {
    setState(() {
      _loading = true;
    });

    try {
      // Prefer current GPS location; if not available, use center of map
      LatLng pos;
      if (_currentLocation != null) {
        pos = _currentLocation!;
      } else {
        final c = await _controller.future;
        final cam = await c.getVisibleRegion();
        // approximate center
        pos = LatLng((cam.northeast.latitude + cam.southwest.latitude) / 2,
            (cam.northeast.longitude + cam.southwest.longitude) / 2);
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'parking': {
            'lat': pos.latitude,
            'lng': pos.longitude,
            'ts': FieldValue.serverTimestamp(),
          }
        }, SetOptions(merge: true));

        if (!mounted) return;
        setState(() {
          _parkedLocation = pos;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Parked location saved')));
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You must be signed in to park')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving location: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unpark() async {
    setState(() {
      _loading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'parking': FieldValue.delete(),
        }, SetOptions(merge: true));

        if (!mounted) return;
        setState(() {
          _parkedLocation = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Parking marker removed')));
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You must be signed in to unpark')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error removing location: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Smoothly center the map on a given LatLng with optional zoom
  Future<void> _centerOnLatLng(LatLng latlng, {double zoom = 17}) async {
    try {
      final controller = await _controller.future;
      await controller.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(target: latlng, zoom: zoom),
      ));
    } catch (_) {}
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};
    if (_parkedLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId('parked'),
        position: _parkedLocation!,
        infoWindow: const InfoWindow(title: 'Parked here'),
      ));
    }
    if (_currentLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId('you'),
        position: _currentLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'You are here'),
      ));
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Park')),
      body: Stack(
        children: [
          _loading
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
                  initialCameraPosition: _currentLocation != null
                      ? CameraPosition(target: _currentLocation!, zoom: 17)
                      : _fallback,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  markers: _buildMarkers(),
                  onMapCreated: (GoogleMapController controller) {
                    if (!_controller.isCompleted) _controller.complete(controller);
                  },
                ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 24,
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading ? null : _park,
                    child: const Text('Park'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_loading || _parkedLocation == null) ? null : () async {
                      // ask for confirmation before unpark
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Remove parked marker?'),
                          content: const Text('Are you sure you want to remove your parked location?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                            TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Remove')),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await _unpark();
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                    child: const Text('Unpark'),
                  ),
                ),
              ],
            ),
          ),
          // Floating re-center button (parked or current)
          Positioned(
            top: 12,
            right: 12,
            child: FloatingActionButton.small(
              onPressed: () async {
                if (_parkedLocation != null) {
                  await _centerOnLatLng(_parkedLocation!, zoom: 18);
                } else if (_currentLocation != null) {
                  await _centerOnLatLng(_currentLocation!, zoom: 17);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No location available to center')));
                }
              },
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }
}
